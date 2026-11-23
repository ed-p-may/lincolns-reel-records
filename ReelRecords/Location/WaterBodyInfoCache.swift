import Foundation

struct WaterBodyInfoCache: Sendable {
    static let staticInfoTTL: TimeInterval = 14 * 24 * 60 * 60
    static let riverGaugeTTL: TimeInterval = 15 * 60

    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.directoryURL = caches.appendingPathComponent("WaterBodyInfo", isDirectory: true)
        }
    }

    func load(waterID: String) -> WaterBodyInfo? {
        let fileURL = cacheFileURL(for: waterID)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WaterBodyInfo.self, from: data)
    }

    func save(_ info: WaterBodyInfo) {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var sanitized = info
        sanitized.isFromOfflineCache = false
        guard let data = try? encoder.encode(sanitized) else { return }
        try? data.write(to: cacheFileURL(for: info.waterID), options: [.atomic])
    }

    func isStaticFresh(_ info: WaterBodyInfo, now: Date) -> Bool {
        let age = now.timeIntervalSince(info.fetchedAt)
        return age >= 0 && age < Self.staticInfoTTL
    }

    func isGaugeFresh(_ info: WaterBodyInfo, now: Date) -> Bool {
        guard let gaugeFetchedAt = info.gaugeFetchedAt else { return false }
        let age = now.timeIntervalSince(gaugeFetchedAt)
        return age >= 0 && age < Self.riverGaugeTTL
    }

    private func cacheFileURL(for waterID: String) -> URL {
        let safeName = waterID
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9_-]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        let filename = (safeName.isEmpty ? "water" : String(safeName.prefix(80))) + ".json"
        return directoryURL.appendingPathComponent(filename, isDirectory: false)
    }
}

struct UnavailableWaterBodyInfoProvider: WaterBodyInfoProviding {
    func resolveWaterBody(
        at _: CatchCoordinate,
        hintName _: String?
    ) async throws -> WaterBodySelection? {
        nil
    }

    func cachedInfo(for _: WaterBodySelection) -> WaterBodyInfo? {
        nil
    }

    func fetchInfo(
        for _: WaterBodySelection,
        forceRefresh _: Bool
    ) async throws -> WaterBodyInfo {
        throw WaterBodyInfoError.offlineOrUnavailable
    }
}

/// Deterministic fixture provider used by UI tests (`--ui-testing-water-info-*`).
struct FixtureWaterBodyInfoProvider: WaterBodyInfoProviding {
    enum Mode: Sendable {
        case rich
        case sparse
        case empty
    }

    let mode: Mode

    func resolveWaterBody(
        at coordinate: CatchCoordinate,
        hintName _: String?
    ) async throws -> WaterBodySelection? {
        switch mode {
        case .rich:
            WaterBodySelection(
                id: "fixture-stockbridge-bowl",
                name: "Stockbridge Bowl",
                waterType: .lake,
                coordinate: CatchCoordinate(latitude: 42.3169, longitude: -73.3226) ?? coordinate,
                regionSubtitle: "Stockbridge, MA",
                wikipediaTag: "en:Stockbridge Bowl"
            )
        case .sparse:
            WaterBodySelection(
                id: "fixture-hidden-pond",
                name: "Hidden Meadow Pond",
                waterType: .pond,
                coordinate: coordinate,
                regionSubtitle: "Sheffield, MA",
                wikipediaTag: nil
            )
        case .empty:
            nil
        }
    }

    func cachedInfo(for _: WaterBodySelection) -> WaterBodyInfo? {
        nil
    }

    func fetchInfo(
        for selection: WaterBodySelection,
        forceRefresh _: Bool
    ) async throws -> WaterBodyInfo {
        let now = Date(timeIntervalSince1970: 1_753_000_000)
        switch mode {
        case .rich:
            return Self.richFixture(for: selection, now: now)
        case .sparse:
            return WaterBodyInfo(
                waterID: selection.id,
                name: selection.name,
                waterType: selection.waterType,
                regionSubtitle: selection.regionSubtitle,
                coordinate: selection.coordinate,
                overview: nil,
                wikipediaURL: nil,
                accessPoints: [],
                species: [],
                photos: [],
                riverGauge: nil,
                fetchedAt: now,
                gaugeFetchedAt: nil
            )
        case .empty:
            throw WaterBodyInfoError.offlineOrUnavailable
        }
    }

    private static let fixtureSpecies: [WaterBodySpecies] = [
        WaterBodySpecies(
            id: "inat-1",
            commonName: "Largemouth Bass",
            scientificName: "Micropterus salmoides",
            observationCount: 14,
            source: "iNaturalist"
        ),
        WaterBodySpecies(
            id: "inat-2",
            commonName: "Smallmouth Bass",
            scientificName: "Micropterus dolomieu",
            observationCount: 9,
            source: "iNaturalist"
        ),
        WaterBodySpecies(
            id: "inat-3",
            commonName: "Rainbow Trout",
            scientificName: "Oncorhynchus mykiss",
            observationCount: 6,
            source: "iNaturalist"
        )
    ]

    private static func richFixture(for selection: WaterBodySelection, now: Date) -> WaterBodyInfo {
        WaterBodyInfo(
            waterID: selection.id,
            name: selection.name,
            waterType: selection.waterType,
            regionSubtitle: selection.regionSubtitle,
            coordinate: selection.coordinate,
            overview: "Stockbridge Bowl (Lake Mahkeenac) is a 372-acre great pond in Stockbridge, "
                + "Massachusetts, known for largemouth bass, smallmouth bass, trout, and pike.",
            wikipediaURL: URL(string: "https://en.wikipedia.org/wiki/Stockbridge_Bowl"),
            accessPoints: [
                WaterBodyAccessPoint(
                    id: "fixture-ramp-1",
                    name: "Stockbridge Bowl Boat Ramp",
                    kind: "Boat Ramp",
                    coordinate: CatchCoordinate(latitude: 42.3335, longitude: -73.3145) ?? selection.coordinate
                )
            ],
            species: fixtureSpecies,
            photos: [
                WaterBodyPhoto(
                    id: "fixture-photo-1",
                    thumbnailURL: URL(string: "https://example.com/stockbridge-bowl.jpg")!,
                    fullURL: URL(string: "https://example.com/stockbridge-bowl-full.jpg"),
                    attribution: "Wikimedia Commons / Wikipedia",
                    license: "CC BY-SA",
                    source: "Wikipedia"
                )
            ],
            riverGauge: RiverGaugeReading(
                siteCode: "01197500",
                siteName: "Housatonic River near Great Barrington, MA",
                dischargeCFS: 420,
                gaugeHeightFT: 3.45,
                waterTemperatureF: 61.5,
                observedAt: now
            ),
            fetchedAt: now,
            gaugeFetchedAt: now
        )
    }
}
