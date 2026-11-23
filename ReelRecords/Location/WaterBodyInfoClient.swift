import CoreLocation
import Foundation
import SwiftUI

enum WaterBodyInfoError: Error, Equatable, Sendable {
    case offlineOrUnavailable
}

protocol WaterBodyInfoProviding: Sendable {
    func cachedSelection(
        near coordinate: CatchCoordinate,
        hintName: String?
    ) -> WaterBodySelection?

    func resolveWaterBody(
        at coordinate: CatchCoordinate,
        hintName: String?
    ) async throws -> WaterBodySelection?

    func cachedInfo(for selection: WaterBodySelection) -> WaterBodyInfo?

    func fetchInfo(
        for selection: WaterBodySelection,
        forceRefresh: Bool
    ) async throws -> WaterBodyInfo
}

extension WaterBodyInfoProviding {
    func cachedSelection(
        near _: CatchCoordinate,
        hintName _: String?
    ) -> WaterBodySelection? {
        nil
    }

    func fetchInfo(for selection: WaterBodySelection) async throws -> WaterBodyInfo {
        try await fetchInfo(for: selection, forceRefresh: false)
    }
}

extension EnvironmentValues {
    @Entry var waterBodyInfoProvider: any WaterBodyInfoProviding = UnavailableWaterBodyInfoProvider()
}

struct WaterBodyInfoClient: WaterBodyInfoProviding, Sendable {
    typealias Loader = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    typealias Clock = @Sendable () -> Date
    typealias RegionResolver = @Sendable (CatchCoordinate) async -> String?

    private let loader: Loader
    private let cache: WaterBodyInfoCache
    private let now: Clock
    private let regionResolver: RegionResolver

    init(
        session: URLSession = .shared,
        cache: WaterBodyInfoCache = .shared,
        now: @escaping Clock = { .now },
        regionResolver: @escaping RegionResolver = WaterBodyInfoClient.reverseGeocodeRegion
    ) {
        loader = { request in
            try await session.data(for: request)
        }
        self.cache = cache
        self.now = now
        self.regionResolver = regionResolver
    }

    init(
        loader: @escaping Loader,
        cache: WaterBodyInfoCache = WaterBodyInfoCache(),
        now: @escaping Clock = { .now },
        regionResolver: @escaping RegionResolver = { _ in nil }
    ) {
        self.loader = loader
        self.cache = cache
        self.now = now
        self.regionResolver = regionResolver
    }

    func cachedSelection(
        near coordinate: CatchCoordinate,
        hintName: String?
    ) -> WaterBodySelection? {
        let trimmedHint = hintName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyHint = trimmedHint?.isEmpty == false ? trimmedHint : nil
        return cache.findSelection(near: coordinate, hintName: nonEmptyHint)
    }

    func resolveWaterBody(
        at coordinate: CatchCoordinate,
        hintName: String?
    ) async throws -> WaterBodySelection? {
        let trimmedHint = hintName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyHint = trimmedHint?.isEmpty == false ? trimmedHint : nil

        if let nonEmptyHint, !WaterBodyNameClassifier.looksLikeWaterName(nonEmptyHint) {
            return await resolveNonKeyword(hint: nonEmptyHint, at: coordinate)
        }

        async let regionSubtitle = regionResolver(coordinate)

        switch await fetchOverpassWaterCandidate(at: coordinate, hintName: nonEmptyHint) {
        case let .found(candidate):
            let resolved = await selection(from: candidate, regionSubtitle: regionSubtitle)
            cache.saveSelection(resolved)
            return resolved
        case .confirmedEmpty:
            return await hintFallback(nonEmptyHint, at: coordinate, regionSubtitle: regionSubtitle)
        case .failed:
            if let cachedSelection = cache.findSelection(near: coordinate, hintName: nonEmptyHint) {
                return cachedSelection
            }
            return await hintFallback(nonEmptyHint, at: coordinate, regionSubtitle: regionSubtitle)
        }
    }

    func cachedInfo(for selection: WaterBodySelection) -> WaterBodyInfo? {
        guard var cached = cache.load(waterID: selection.id) else { return nil }
        let currentDate = now()
        if let gauge = cached.riverGauge {
            let fetchStale = !cache.isGaugeFresh(cached, now: currentDate)
            cached.isRiverGaugeStale = fetchStale || Self.isGaugeReadingOld(gauge, now: currentDate)
        }
        return cached
    }

    func fetchInfo(
        for selection: WaterBodySelection,
        forceRefresh: Bool
    ) async throws -> WaterBodyInfo {
        let currentDate = now()
        let cached = cache.load(waterID: selection.id)

        if !forceRefresh, let cached, cache.isStaticFresh(cached, now: currentDate) {
            return await refreshGaugeIfNeeded(cached: cached, selection: selection, now: currentDate)
        }

        return try await fetchAllSources(for: selection, cached: cached, now: currentDate)
    }
}

private extension WaterBodyInfoClient {
    private static let maxLiveGaugeObservationAge: TimeInterval = 2 * 60 * 60

    static func isGaugeReadingOld(_ gauge: RiverGaugeReading, now currentDate: Date) -> Bool {
        guard let observedAt = gauge.observedAt else { return true }
        return currentDate.timeIntervalSince(observedAt) > maxLiveGaugeObservationAge
    }

    func resolveNonKeyword(hint: String, at coordinate: CatchCoordinate) async -> WaterBodySelection? {
        switch await fetchOverpassWaterCandidate(at: coordinate, hintName: hint) {
        case let .found(candidate)
            where CatchDiscovery.normalized(candidate.name) == CatchDiscovery.normalized(hint):
            let resolved = await selection(from: candidate, regionSubtitle: regionResolver(coordinate))
            cache.saveSelection(resolved)
            return resolved
        case .found, .confirmedEmpty:
            return nil
        case .failed:
            return cache.findSelection(near: coordinate, hintName: hint)
        }
    }

    func hintFallback(
        _ hint: String?,
        at coordinate: CatchCoordinate,
        regionSubtitle: String?
    ) -> WaterBodySelection? {
        guard let hint, WaterBodyNameClassifier.looksLikeWaterName(hint) else { return nil }
        let fallback = WaterBodySelection(
            id: WaterBodySelection.canonicalID(name: hint, coordinate: coordinate),
            name: hint,
            waterType: WaterBodyNameClassifier.classify(name: hint),
            coordinate: coordinate,
            regionSubtitle: regionSubtitle,
            wikipediaTag: nil
        )
        cache.saveSelection(fallback)
        return fallback
    }

    func selection(
        from candidate: OverpassWaterCandidate,
        regionSubtitle: String?
    ) -> WaterBodySelection {
        WaterBodySelection(
            id: WaterBodySelection.canonicalID(name: candidate.name, coordinate: candidate.coordinate),
            name: candidate.name,
            waterType: candidate.waterType,
            coordinate: candidate.coordinate,
            regionSubtitle: regionSubtitle,
            wikipediaTag: candidate.wikipediaTag
        )
    }

    func refreshGaugeIfNeeded(
        cached: WaterBodyInfo,
        selection: WaterBodySelection,
        now currentDate: Date
    ) async -> WaterBodyInfo {
        let shouldRefreshGauge = selection.waterType.supportsLiveRiverGauge || cached.riverGauge != nil
        guard shouldRefreshGauge, !cache.isGaugeFresh(cached, now: currentDate) else {
            return cached
        }
        guard case let .success(gauge) = await fetchUSGSGauge(
            around: selection.coordinate,
            waterName: selection.name
        ) else {
            var staleCopy = cached
            staleCopy.isRiverGaugeStale = cached.riverGauge != nil
            return staleCopy
        }
        let updated = WaterBodyInfo(
            waterID: cached.waterID,
            name: cached.name,
            waterType: cached.waterType,
            regionSubtitle: cached.regionSubtitle,
            coordinate: cached.coordinate,
            overview: cached.overview,
            wikipediaURL: cached.wikipediaURL,
            accessPoints: cached.accessPoints,
            species: cached.species,
            photos: cached.photos,
            riverGauge: gauge,
            fetchedAt: cached.fetchedAt,
            gaugeFetchedAt: currentDate,
            isFromOfflineCache: false,
            isRiverGaugeStale: gauge.map { Self.isGaugeReadingOld($0, now: currentDate) } ?? false
        )
        cache.save(updated)
        return updated
    }

    func fetchAllSources(
        for selection: WaterBodySelection,
        cached: WaterBodyInfo?,
        now currentDate: Date
    ) async throws -> WaterBodyInfo {
        let shouldQueryGauge = selection.waterType.supportsLiveRiverGauge || selection.waterType == .water
        async let accessOutcome = fetchAccessPoints(around: selection.coordinate)
        async let wikiOutcome = fetchWikipediaSummary(for: selection)
        async let inatOutcome = fetchINaturalist(around: selection.coordinate)
        async let usgsOutcome: SourceOutcome<RiverGaugeReading?> = shouldQueryGauge
            ? fetchUSGSGauge(around: selection.coordinate, waterName: selection.name)
            : .skipped

        let (access, wiki, inat, usgs) = await (accessOutcome, wikiOutcome, inatOutcome, usgsOutcome)
        let anySucceeded = access.didSucceed || wiki.didSucceed || inat.didSucceed || usgs.didSucceed

        if !anySucceeded {
            if var stale = cached {
                stale.isFromOfflineCache = true
                stale.isRiverGaugeStale = stale.riverGauge != nil && !cache.isGaugeFresh(stale, now: currentDate)
                return stale
            }
            throw WaterBodyInfoError.offlineOrUnavailable
        }

        let merged = mergeSources(
            selection: selection,
            cached: cached,
            outcomes: SourceOutcomes(access: access, wiki: wiki, inat: inat, usgs: usgs),
            now: currentDate
        )
        cache.save(merged)
        return merged
    }

    func mergeSources(
        selection: WaterBodySelection,
        cached: WaterBodyInfo?,
        outcomes: SourceOutcomes,
        now currentDate: Date
    ) -> WaterBodyInfo {
        let overview = outcomes.wiki.didSucceed ? outcomes.wiki.value??.extract : cached?.overview
        let wikipediaURL = outcomes.wiki.didSucceed ? outcomes.wiki.value??.pageURL : cached?.wikipediaURL
        let accessPoints = outcomes.access.didSucceed ? (outcomes.access.value ?? []) : (cached?.accessPoints ?? [])
        let species = outcomes.inat.didSucceed ? (outcomes.inat.value?.species ?? []) : (cached?.species ?? [])
        let photos = outcomes.inat.didSucceed
            ? Array((outcomes.inat.value?.photos ?? []).prefix(6))
            : (cached?.photos ?? [])
        let riverGauge = outcomes.usgs.didSucceed ? (outcomes.usgs.value ?? nil) : cached?.riverGauge
        let gaugeFetchedAt = outcomes.usgs.didSucceed ? currentDate : cached?.gaugeFetchedAt
        let wasGaugeFresh = cached.map { cache.isGaugeFresh($0, now: currentDate) } ?? false
        let isGaugeStale = riverGauge.map { gauge in
            let fetchStale = !outcomes.usgs.didSucceed && !wasGaugeFresh
            return fetchStale || Self.isGaugeReadingOld(gauge, now: currentDate)
        } ?? false
        let allStaticSucceeded = outcomes.access.didSucceed && outcomes.wiki.didSucceed && outcomes.inat.didSucceed
        // If an initial fetch had partial failures, backdate so failed sources retry after 5 minutes.
        let retrySoonDate = currentDate.addingTimeInterval(-(WaterBodyInfoCache.staticInfoTTL - 300))
        let fetchedAt: Date = if allStaticSucceeded {
            currentDate
        } else if let cached {
            cached.fetchedAt
        } else {
            retrySoonDate
        }

        return WaterBodyInfo(
            waterID: selection.id,
            name: selection.name,
            waterType: selection.waterType,
            regionSubtitle: selection.regionSubtitle ?? cached?.regionSubtitle,
            coordinate: selection.coordinate,
            overview: overview,
            wikipediaURL: wikipediaURL,
            accessPoints: accessPoints,
            species: species,
            photos: photos,
            riverGauge: riverGauge,
            fetchedAt: fetchedAt,
            gaugeFetchedAt: gaugeFetchedAt,
            isFromOfflineCache: false,
            isRiverGaugeStale: isGaugeStale
        )
    }

    func fetchOverpassWaterCandidate(
        at coordinate: CatchCoordinate,
        hintName: String?
    ) async -> OverpassLookupOutcome {
        guard let request = WaterBodySourceRequests.overpassResolve(at: coordinate),
              let data = await performRequest(request)
        else {
            return .failed
        }
        do {
            if let candidate = try WaterBodySourceParsers.parseOverpassWaterCandidate(
                from: data,
                fallbackCoordinate: coordinate,
                hintName: hintName
            ) {
                return .found(candidate)
            }
            return .confirmedEmpty
        } catch {
            return .failed
        }
    }

    func fetchAccessPoints(around coordinate: CatchCoordinate) async -> SourceOutcome<[WaterBodyAccessPoint]> {
        guard let request = WaterBodySourceRequests.overpassAccess(around: coordinate),
              let data = await performRequest(request),
              let parsed = try? WaterBodySourceParsers.parseOverpassAccessPoints(from: data, near: coordinate)
        else {
            return .failed
        }
        return .success(parsed)
    }

    func fetchWikipediaSummary(for selection: WaterBodySelection) async -> SourceOutcome<WikipediaSummaryResult?> {
        var candidates: [(title: String, requiresGeoMatch: Bool)] = []
        if let tag = selection.wikipediaTag, !tag.isEmpty {
            candidates.append((tag, false))
        }
        if let region = selection.regionSubtitle, !region.isEmpty {
            candidates.append(("\(selection.name), \(region)", false))
        }
        candidates.append((selection.name, true))

        var sawHTTPResponse = false
        for candidate in candidates {
            guard let request = WaterBodySourceRequests.wikipediaSummary(title: candidate.title) else { continue }
            switch await performDetailedRequest(request) {
            case let .success(data):
                sawHTTPResponse = true
                if let summary = try? WaterBodySourceParsers.parseWikipediaSummary(from: data) {
                    let isGeoOK = wikipediaMatchesLocation(
                        summary,
                        selection: selection,
                        requiresGeo: candidate.requiresGeoMatch
                    )
                    if isGeoOK {
                        return .success(summary)
                    }
                }
            case .notFound:
                sawHTTPResponse = true
            case .failed:
                continue
            }
        }
        return sawHTTPResponse ? .success(nil) : .failed
    }

    func wikipediaMatchesLocation(
        _ summary: WikipediaSummaryResult,
        selection: WaterBodySelection,
        requiresGeo: Bool
    ) -> Bool {
        guard requiresGeo else { return true }
        guard let wikiCoord = summary.coordinate else { return false }
        let origin = CLLocation(latitude: selection.coordinate.latitude, longitude: selection.coordinate.longitude)
        let target = CLLocation(latitude: wikiCoord.latitude, longitude: wikiCoord.longitude)
        return origin.distance(from: target) <= 15000
    }

    func fetchINaturalist(around coordinate: CatchCoordinate) async -> SourceOutcome<INaturalistResult> {
        guard let request = WaterBodySourceRequests.iNaturalist(around: coordinate),
              let data = await performRequest(request),
              let parsed = try? WaterBodySourceParsers.parseINaturalistObservations(from: data)
        else {
            return .failed
        }
        return .success(parsed)
    }

    func fetchUSGSGauge(
        around coordinate: CatchCoordinate,
        waterName: String
    ) async -> SourceOutcome<RiverGaugeReading?> {
        guard let request = WaterBodySourceRequests.usgsGauge(around: coordinate),
              let data = await performRequest(request)
        else {
            return .failed
        }
        do {
            let parsed = try WaterBodySourceParsers.parseUSGSGaugeReading(
                from: data,
                near: coordinate,
                waterName: waterName
            )
            return .success(parsed)
        } catch {
            return .failed
        }
    }

    func performRequest(_ request: URLRequest) async -> Data? {
        if case let .success(data) = await performDetailedRequest(request) {
            return data
        }
        return nil
    }

    func performDetailedRequest(_ request: URLRequest) async -> HTTPResult {
        do {
            let (data, response) = try await loader(request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            if (200 ... 299).contains(http.statusCode) {
                return .success(data)
            }
            if http.statusCode == 404 {
                return .notFound
            }
            return .failed
        } catch {
            return .failed
        }
    }

    static func reverseGeocodeRegion(at coordinate: CatchCoordinate) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else {
            return nil
        }
        let parts = [placemark.locality, placemark.administrativeArea]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
