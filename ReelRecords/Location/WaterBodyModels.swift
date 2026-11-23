import CoreLocation
import Foundation

enum WaterBodyType: String, Codable, Hashable, Sendable {
    case lake
    case pond
    case river
    case stream
    case reservoir
    case bay
    case water

    var displayTitle: String {
        switch self {
        case .lake: "Lake"
        case .pond: "Pond"
        case .river: "River"
        case .stream: "Stream"
        case .reservoir: "Reservoir"
        case .bay: "Bay"
        case .water: "Water"
        }
    }

    var systemImage: String {
        switch self {
        case .river, .stream:
            "water.waves"
        case .lake, .pond, .reservoir, .bay, .water:
            "drop.fill"
        }
    }

    var supportsLiveRiverGauge: Bool {
        self == .river || self == .stream
    }
}

struct WaterBodySelection: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let waterType: WaterBodyType
    let coordinate: CatchCoordinate
    let regionSubtitle: String?
    let wikipediaTag: String?

    var subtitle: String {
        if let regionSubtitle, !regionSubtitle.isEmpty {
            return "\(waterType.displayTitle) · \(regionSubtitle)"
        }
        return waterType.displayTitle
    }

    static func canonicalID(name: String, coordinate: CatchCoordinate) -> String {
        let slug = CatchDiscovery.normalized(name)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let latBucket = Int((coordinate.latitude * 100).rounded())
        let lonBucket = Int((coordinate.longitude * 100).rounded())
        return "water-\(slug.isEmpty ? "unnamed" : slug)-\(latBucket)-\(lonBucket)"
    }
}

struct WaterBodySpecies: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let commonName: String
    let scientificName: String?
    let observationCount: Int
    let source: String
}

struct WaterBodyPhoto: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let thumbnailURL: URL
    let fullURL: URL?
    let attribution: String
    let license: String?
    let source: String

    var caption: String {
        if let license, !license.isEmpty {
            return "\(attribution) · \(license)"
        }
        return attribution
    }
}

struct WaterBodyAccessPoint: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let kind: String
    let coordinate: CatchCoordinate
}

struct RiverGaugeReading: Codable, Hashable, Sendable {
    let siteCode: String
    let siteName: String
    let dischargeCFS: Double?
    let gaugeHeightFT: Double?
    let waterTemperatureF: Double?
    let observedAt: Date?

    var compactFlowLabel: String? {
        guard let dischargeCFS, dischargeCFS.isFinite else { return nil }
        let formatted = dischargeCFS.formatted(.number.precision(.fractionLength(0)))
        return "\(formatted) cfs"
    }

    var gaugeHeightLabel: String? {
        guard let gaugeHeightFT, gaugeHeightFT.isFinite else { return nil }
        let formatted = gaugeHeightFT.formatted(.number.precision(.fractionLength(0 ... 2)))
        return "\(formatted) ft"
    }

    var waterTemperatureLabel: String? {
        guard let waterTemperatureF, waterTemperatureF.isFinite else { return nil }
        return CatchFormatting.temperature(waterTemperatureF)
    }

    var hasAnyMeasurement: Bool {
        dischargeCFS != nil || gaugeHeightFT != nil || waterTemperatureF != nil
    }
}

struct WaterBodyQuickLink: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let url: URL
    let systemImage: String

    static func defaultLinks(for selection: WaterBodySelection) -> [WaterBodyQuickLink] {
        let queryPrefix = [selection.name, selection.regionSubtitle]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        var links: [WaterBodyQuickLink] = []
        if let reportURL = googleSearchURL(query: "\(queryPrefix) fishing report") {
            links.append(WaterBodyQuickLink(
                id: "reports-\(selection.id)",
                title: "Public Fishing Reports",
                subtitle: "Search recent reports & forums for \(selection.name)",
                url: reportURL,
                systemImage: "doc.text.magnifyingglass"
            ))
        }
        if let tipsURL = googleSearchURL(query: "\(queryPrefix) best lures fish species") {
            links.append(WaterBodyQuickLink(
                id: "lures-\(selection.id)",
                title: "Lures & Species Guides",
                subtitle: "Search tactics, structure, and local articles",
                url: tipsURL,
                systemImage: "safari"
            ))
        }
        if let agencyURL = googleSearchURL(query: "\(queryPrefix) state fishing regulations boat ramp") {
            links.append(WaterBodyQuickLink(
                id: "agency-\(selection.id)",
                title: "State Access & Regulations",
                subtitle: "Check official agency access and rules",
                url: agencyURL,
                systemImage: "building.columns"
            ))
        }
        return links
    }

    private static func googleSearchURL(query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url
    }
}

struct WaterBodyInfo: Codable, Hashable, Sendable {
    let waterID: String
    let name: String
    let waterType: WaterBodyType
    let regionSubtitle: String?
    let coordinate: CatchCoordinate
    let overview: String?
    let wikipediaURL: URL?
    let accessPoints: [WaterBodyAccessPoint]
    let species: [WaterBodySpecies]
    let photos: [WaterBodyPhoto]
    let riverGauge: RiverGaugeReading?
    let fetchedAt: Date
    let gaugeFetchedAt: Date?
    var isFromOfflineCache: Bool
    var isRiverGaugeStale: Bool

    init(
        waterID: String,
        name: String,
        waterType: WaterBodyType,
        regionSubtitle: String?,
        coordinate: CatchCoordinate,
        overview: String?,
        wikipediaURL: URL?,
        accessPoints: [WaterBodyAccessPoint],
        species: [WaterBodySpecies],
        photos: [WaterBodyPhoto],
        riverGauge: RiverGaugeReading?,
        fetchedAt: Date,
        gaugeFetchedAt: Date?,
        isFromOfflineCache: Bool = false,
        isRiverGaugeStale: Bool = false
    ) {
        self.waterID = waterID
        self.name = name
        self.waterType = waterType
        self.regionSubtitle = regionSubtitle
        self.coordinate = coordinate
        self.overview = overview
        self.wikipediaURL = wikipediaURL
        self.accessPoints = accessPoints
        self.species = species
        self.photos = photos
        self.riverGauge = riverGauge
        self.fetchedAt = fetchedAt
        self.gaugeFetchedAt = gaugeFetchedAt
        self.isFromOfflineCache = isFromOfflineCache
        self.isRiverGaugeStale = isRiverGaugeStale
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        waterID = try container.decode(String.self, forKey: .waterID)
        name = try container.decode(String.self, forKey: .name)
        waterType = try container.decode(WaterBodyType.self, forKey: .waterType)
        regionSubtitle = try container.decodeIfPresent(String.self, forKey: .regionSubtitle)
        coordinate = try container.decode(CatchCoordinate.self, forKey: .coordinate)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        wikipediaURL = try container.decodeIfPresent(URL.self, forKey: .wikipediaURL)
        accessPoints = try container.decode([WaterBodyAccessPoint].self, forKey: .accessPoints)
        species = try container.decode([WaterBodySpecies].self, forKey: .species)
        photos = try container.decode([WaterBodyPhoto].self, forKey: .photos)
        riverGauge = try container.decodeIfPresent(RiverGaugeReading.self, forKey: .riverGauge)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        gaugeFetchedAt = try container.decodeIfPresent(Date.self, forKey: .gaugeFetchedAt)
        isFromOfflineCache = try container.decodeIfPresent(Bool.self, forKey: .isFromOfflineCache) ?? false
        isRiverGaugeStale = try container.decodeIfPresent(Bool.self, forKey: .isRiverGaugeStale) ?? false
    }

    var hasPublicContent: Bool {
        let hasOverview = overview.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? false
        return hasOverview
            || !accessPoints.isEmpty
            || !species.isEmpty
            || !photos.isEmpty
            || (riverGauge?.hasAnyMeasurement == true)
    }

    var heroThumbnailURL: URL? {
        photos.first?.thumbnailURL
    }
}

struct LocalWaterHistory: Equatable, Sendable {
    static let defaultProximityMeters: CLLocationDistance = 1000

    let catchCount: Int
    let personalBestWeight: Double?
    let personalBestLength: Double?
    let topSpecies: [String]
    let topLures: [String]
    let recentCatches: [CatchItem]

    static let empty = LocalWaterHistory(
        catchCount: 0,
        personalBestWeight: nil,
        personalBestLength: nil,
        topSpecies: [],
        topLures: [],
        recentCatches: []
    )

    static func summarize(
        catches: [CatchItem],
        tackleNames: [UUID: String] = [:],
        for selection: WaterBodySelection,
        proximityMeters: CLLocationDistance = defaultProximityMeters
    ) -> LocalWaterHistory {
        let normalizedWater = CatchDiscovery.normalized(selection.name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let targetLocation = CLLocation(
            latitude: selection.coordinate.latitude,
            longitude: selection.coordinate.longitude
        )

        let matched = catches.filter { catchItem in
            matches(
                catchItem,
                normalizedWaterName: normalizedWater,
                targetLocation: targetLocation,
                proximityMeters: proximityMeters
            )
        }

        guard !matched.isEmpty else { return .empty }

        let sortedRecent = matched.sorted(by: CatchDiscovery.recentPrecedes)
        let bestWeight = matched.compactMap(\.weight).max()
        let bestLength = matched.compactMap(\.length).max()
        let topSpecies = rankedLabels(matched.map(\.species), limit: 4)
        let lureLabels = matched.compactMap { catchItem -> String? in
            if let tackleID = catchItem.tackleItemID {
                let name = tackleNames[tackleID]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !name.isEmpty {
                    return name
                }
            }
            let trimmed = catchItem.lureText?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed?.isEmpty == false ? trimmed : nil
        }
        let topLures = rankedLabels(lureLabels, limit: 3)

        return LocalWaterHistory(
            catchCount: matched.count,
            personalBestWeight: bestWeight,
            personalBestLength: bestLength,
            topSpecies: topSpecies,
            topLures: topLures,
            recentCatches: Array(sortedRecent.prefix(5))
        )
    }

    private static let conflictingCoordinateMeters: CLLocationDistance = 5000

    private static func matches(
        _ catchItem: CatchItem,
        normalizedWaterName: String,
        targetLocation: CLLocation,
        proximityMeters: CLLocationDistance
    ) -> Bool {
        let trimmedLocation = catchItem.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedCatch = CatchDiscovery.normalized(trimmedLocation)
        let matchesByName = normalizedWaterName.count >= 3
            && !trimmedLocation.isEmpty
            && matchesWaterName(normalizedCatch, waterName: normalizedWaterName)
        let isConflictingNamedWater = !trimmedLocation.isEmpty
            && !matchesByName
            && WaterBodyNameClassifier.isDistinctNamedWaterBody(trimmedLocation)

        if let coordinate = catchItem.coordinate {
            let catchLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = catchLocation.distance(from: targetLocation)
            if distance <= proximityMeters {
                return !isConflictingNamedWater
            }
            if distance > conflictingCoordinateMeters {
                return false
            }
        }
        return matchesByName
    }

    private static func matchesWaterName(_ catchLocation: String, waterName: String) -> Bool {
        if catchLocation == waterName {
            return true
        }
        let separators = [" ", ",", "-", "(", "/"]
        for sep in separators where catchLocation.hasPrefix(waterName + sep) {
            return true
        }
        return false
    }

    private static func rankedLabels(_ values: [String], limit: Int) -> [String] {
        var counts: [String: (display: String, count: Int)] = [:]
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = CatchDiscovery.normalized(trimmed)
            if let existing = counts[key] {
                counts[key] = (min(existing.display, trimmed), existing.count + 1)
            } else {
                counts[key] = (trimmed, 1)
            }
        }
        return counts.values
            .sorted { first, second in
                if first.count != second.count {
                    return first.count > second.count
                }
                return CatchDiscovery.alphabeticallyPrecedes(first.display, second.display)
            }
            .prefix(limit)
            .map(\.display)
    }
}

enum WaterBodyNameClassifier {
    private static let nonWaterKeywords = [
        "mountain", "mount ", "mt ", "mt.", "peak", "hill", "ridge", "valley", "summit",
        "forest", "state park", "national park", "trail", "pass", "gorge", "canyon", "island",
        "knob", "ledge", "cliff", "meadow", "woods", "reservation"
    ]

    private static let waterKeywords: [(keyword: String, type: WaterBodyType)] = [
        ("reservoir", .reservoir),
        ("lake", .lake),
        ("pond", .pond),
        ("bowl", .lake),
        ("river", .river),
        ("stream", .stream),
        ("brook", .stream),
        ("creek", .stream),
        ("run", .stream),
        ("bay", .bay),
        ("cove", .bay),
        ("harbor", .bay),
        ("sound", .bay),
        ("lagoon", .lake),
        ("canal", .river),
        ("flowage", .reservoir),
        ("impoundment", .reservoir)
    ]

    static func classify(name: String, osmWaterTag: String? = nil, osmWaterwayTag: String? = nil) -> WaterBodyType {
        if let osmWaterwayTag {
            let lowered = osmWaterwayTag.lowercased()
            if lowered == "river" || lowered == "canal" {
                return .river
            }
            if lowered == "stream" || lowered == "brook" || lowered == "creek" {
                return .stream
            }
        }
        if let osmWaterTag {
            let lowered = osmWaterTag.lowercased()
            if lowered == "reservoir" {
                return .reservoir
            }
            if lowered == "pond" {
                return .pond
            }
            if lowered == "lake" || lowered == "oxbow" {
                return .lake
            }
            if lowered == "river" {
                return .river
            }
            if lowered == "bay" || lowered == "lagoon" {
                return .bay
            }
        }
        let loweredName = " \(CatchDiscovery.normalized(name)) "
        for entry in waterKeywords where loweredName.contains(" \(entry.keyword) ") {
            return entry.type
        }
        return .water
    }

    static func looksLikeWaterName(_ name: String) -> Bool {
        let normalized = CatchDiscovery.normalized(name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let padded = " \(normalized) "
        if nonWaterKeywords.contains(where: { padded.contains(" \($0)") || normalized.hasPrefix($0) }) {
            return false
        }
        return waterKeywords.contains { entry in
            padded.contains(" \(entry.keyword) ")
        }
    }

    static func isGenericWaterTerm(_ normalizedValue: String) -> Bool {
        let trimmed = normalizedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "water"
            || waterKeywords.contains { $0.keyword == trimmed }
    }

    /// True when a location string explicitly names a primary water body (e.g. "Goose Pond", "Lake Buel")
    /// rather than a shore/cove spot descriptor like "Unnamed Cove" or "North Shore".
    static func isDistinctNamedWaterBody(_ name: String) -> Bool {
        let normalized = CatchDiscovery.normalized(name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, !isGenericWaterTerm(normalized) else { return false }
        let padded = " \(normalized) "
        if nonWaterKeywords.contains(where: { padded.contains(" \($0)") || normalized.hasPrefix($0) }) {
            return false
        }
        let primaryKeywords = ["lake", "pond", "river", "stream", "brook", "creek", "reservoir", "bowl"]
        return primaryKeywords.contains { padded.contains(" \($0) ") }
    }
}
