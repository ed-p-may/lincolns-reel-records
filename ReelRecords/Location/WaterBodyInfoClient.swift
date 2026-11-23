import CoreLocation
import Foundation
import SwiftUI

enum WaterBodyInfoError: Error, Equatable, Sendable {
    case offlineOrUnavailable
}

protocol WaterBodyInfoProviding: Sendable {
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
        cache: WaterBodyInfoCache = WaterBodyInfoCache(),
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

    func resolveWaterBody(
        at coordinate: CatchCoordinate,
        hintName: String?
    ) async throws -> WaterBodySelection? {
        let trimmedHint = hintName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyHint = trimmedHint?.isEmpty == false ? trimmedHint : nil

        if let nonEmptyHint, !WaterBodyNameClassifier.looksLikeWaterName(nonEmptyHint) {
            return await resolveNonKeywordHint(nonEmptyHint, at: coordinate)
        }

        async let regionSubtitle = regionResolver(coordinate)

        if let candidate = await fetchOverpassWaterCandidate(at: coordinate, hintName: nonEmptyHint) {
            return await selection(from: candidate, regionSubtitle: regionSubtitle)
        }

        if let nonEmptyHint, WaterBodyNameClassifier.looksLikeWaterName(nonEmptyHint) {
            return await WaterBodySelection(
                id: WaterBodySelection.canonicalID(name: nonEmptyHint, coordinate: coordinate),
                name: nonEmptyHint,
                waterType: WaterBodyNameClassifier.classify(name: nonEmptyHint),
                coordinate: coordinate,
                regionSubtitle: regionSubtitle,
                wikipediaTag: nil
            )
        }
        return nil
    }

    func cachedInfo(for selection: WaterBodySelection) -> WaterBodyInfo? {
        cache.load(waterID: selection.id)
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

    private func resolveNonKeywordHint(
        _ hint: String,
        at coordinate: CatchCoordinate
    ) async -> WaterBodySelection? {
        guard let candidate = await fetchOverpassWaterCandidate(at: coordinate, hintName: hint),
              CatchDiscovery.normalized(candidate.name) == CatchDiscovery.normalized(hint)
        else {
            return nil
        }
        let region = await regionResolver(candidate.coordinate)
        return selection(from: candidate, regionSubtitle: region)
    }

    private func selection(
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

    private func refreshGaugeIfNeeded(
        cached: WaterBodyInfo,
        selection: WaterBodySelection,
        now currentDate: Date
    ) async -> WaterBodyInfo {
        let shouldRefreshGauge = selection.waterType.supportsLiveRiverGauge || cached.riverGauge != nil
        guard shouldRefreshGauge,
              !cache.isGaugeFresh(cached, now: currentDate),
              case let .success(gauge) = await fetchUSGSGauge(around: selection.coordinate)
        else {
            return cached
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
            riverGauge: gauge ?? cached.riverGauge,
            fetchedAt: cached.fetchedAt,
            gaugeFetchedAt: currentDate,
            isFromOfflineCache: false
        )
        cache.save(updated)
        return updated
    }

    private func fetchAllSources(
        for selection: WaterBodySelection,
        cached: WaterBodyInfo?,
        now currentDate: Date
    ) async throws -> WaterBodyInfo {
        let shouldQueryGauge = selection.waterType.supportsLiveRiverGauge || selection.waterType == .water
        async let accessOutcome = fetchAccessPoints(around: selection.coordinate)
        async let wikiOutcome = fetchWikipediaSummary(for: selection)
        async let inatOutcome = fetchINaturalist(around: selection.coordinate)
        async let usgsOutcome: SourceOutcome<RiverGaugeReading?> = shouldQueryGauge
            ? fetchUSGSGauge(around: selection.coordinate)
            : .skipped

        let (access, wiki, inat, usgs) = await (accessOutcome, wikiOutcome, inatOutcome, usgsOutcome)
        let anySucceeded = access.didSucceed || wiki.didSucceed || inat.didSucceed || usgs.didSucceed

        if !anySucceeded {
            if var stale = cached {
                stale.isFromOfflineCache = true
                return stale
            }
            throw WaterBodyInfoError.offlineOrUnavailable
        }

        let wikiSummary = wiki.value ?? nil
        let inatResult = inat.value
        var photos: [WaterBodyPhoto] = []
        if let wikiPhoto = wikiSummary?.photo {
            photos.append(wikiPhoto)
        }
        if let inatPhotos = inatResult?.photos {
            photos.append(contentsOf: inatPhotos)
        }

        let info = WaterBodyInfo(
            waterID: selection.id,
            name: selection.name,
            waterType: selection.waterType,
            regionSubtitle: selection.regionSubtitle,
            coordinate: selection.coordinate,
            overview: wikiSummary?.extract,
            wikipediaURL: wikiSummary?.pageURL,
            accessPoints: access.value ?? [],
            species: inatResult?.species ?? [],
            photos: Array(photos.prefix(6)),
            riverGauge: usgs.value ?? nil,
            fetchedAt: currentDate,
            gaugeFetchedAt: usgs.didSucceed ? currentDate : nil,
            isFromOfflineCache: false
        )
        cache.save(info)
        return info
    }

    private func fetchOverpassWaterCandidate(
        at coordinate: CatchCoordinate,
        hintName: String?
    ) async -> OverpassWaterCandidate? {
        guard let request = WaterBodySourceRequests.overpassResolve(at: coordinate),
              let data = await performRequest(request)
        else {
            return nil
        }
        return try? WaterBodySourceParsers.parseOverpassWaterCandidate(
            from: data,
            fallbackCoordinate: coordinate,
            hintName: hintName
        )
    }

    private func fetchAccessPoints(
        around coordinate: CatchCoordinate
    ) async -> SourceOutcome<[WaterBodyAccessPoint]> {
        guard let request = WaterBodySourceRequests.overpassAccess(around: coordinate),
              let data = await performRequest(request),
              let parsed = try? WaterBodySourceParsers.parseOverpassAccessPoints(from: data, near: coordinate)
        else {
            return .failed
        }
        return .success(parsed)
    }

    private func fetchWikipediaSummary(
        for selection: WaterBodySelection
    ) async -> SourceOutcome<WikipediaSummaryResult?> {
        var titles: [String] = []
        if let tag = selection.wikipediaTag, !tag.isEmpty {
            titles.append(tag)
        }
        if let region = selection.regionSubtitle, !region.isEmpty {
            titles.append("\(selection.name), \(region)")
        }
        titles.append(selection.name)

        var sawHTTPResponse = false
        for title in titles {
            guard let request = WaterBodySourceRequests.wikipediaSummary(title: title) else { continue }
            switch await performDetailedRequest(request) {
            case let .success(data):
                sawHTTPResponse = true
                if let summary = try? WaterBodySourceParsers.parseWikipediaSummary(from: data) {
                    return .success(summary)
                }
            case .notFound:
                sawHTTPResponse = true
            case .failed:
                continue
            }
        }
        return sawHTTPResponse ? .success(nil) : .failed
    }

    private func fetchINaturalist(
        around coordinate: CatchCoordinate
    ) async -> SourceOutcome<INaturalistResult> {
        guard let request = WaterBodySourceRequests.iNaturalist(around: coordinate),
              let data = await performRequest(request),
              let parsed = try? WaterBodySourceParsers.parseINaturalistObservations(from: data)
        else {
            return .failed
        }
        return .success(parsed)
    }

    private func fetchUSGSGauge(
        around coordinate: CatchCoordinate
    ) async -> SourceOutcome<RiverGaugeReading?> {
        guard let request = WaterBodySourceRequests.usgsGauge(around: coordinate),
              let data = await performRequest(request),
              let parsed = try? WaterBodySourceParsers.parseUSGSGaugeReading(from: data, near: coordinate)
        else {
            return .failed
        }
        return .success(parsed)
    }

    private func performRequest(_ request: URLRequest) async -> Data? {
        if case let .success(data) = await performDetailedRequest(request) {
            return data
        }
        return nil
    }

    private func performDetailedRequest(_ request: URLRequest) async -> HTTPResult {
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

    private static func reverseGeocodeRegion(at coordinate: CatchCoordinate) async -> String? {
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

private enum HTTPResult {
    case success(Data)
    case notFound
    case failed
}

private enum SourceOutcome<Value: Sendable>: Sendable {
    case success(Value)
    case failed
    case skipped

    var didSucceed: Bool {
        if case .success = self {
            return true
        }
        return false
    }

    var value: Value? {
        if case let .success(val) = self {
            return val
        }
        return nil
    }
}
