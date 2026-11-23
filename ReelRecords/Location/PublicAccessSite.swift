import CoreLocation
import Foundation
import MapKit

enum PublicAccessFacilityType: String, Codable, CaseIterable, Hashable, Sendable {
    case generalAccess = "A"
    case fishermanAccess = "B"
    case cartopAccess = "C"
    case canoeAccess = "D"
    case fishingPier = "E"
    case shoreFishing = "F"

    var label: String {
        switch self {
        case .generalAccess:
            "General Access"
        case .fishermanAccess:
            "Fisherman Access"
        case .cartopAccess:
            "Cartop / Kayak"
        case .canoeAccess:
            "Canoe Access"
        case .fishingPier:
            "Fishing Pier"
        case .shoreFishing:
            "Shore Fishing"
        }
    }

    var isBoatLaunch: Bool {
        switch self {
        case .generalAccess, .fishermanAccess, .cartopAccess, .canoeAccess:
            true
        case .fishingPier, .shoreFishing:
            false
        }
    }

    static func parseCodes(_ raw: String?) -> [PublicAccessFacilityType] {
        guard let raw else { return [] }
        let tokens = raw.replacingOccurrences(of: ";", with: ",").split(separator: ",").map(String.init)
        return parseCodes(tokens)
    }

    static func parseCodes(_ codes: [String]) -> [PublicAccessFacilityType] {
        var seen = Set<PublicAccessFacilityType>()
        var parsed: [PublicAccessFacilityType] = []
        for token in codes {
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            if let type = PublicAccessFacilityType(rawValue: trimmed), seen.insert(type).inserted {
                parsed.append(type)
            }
        }
        return parsed
    }
}

struct PublicAccessSite: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let ofbaId: String
    let name: String
    let town: String?
    let state: String
    let facilityTypeCodes: [String]
    let rampType: String?
    let parking: String?
    let lanes: Int?
    let fee: String?
    let restricted: String?
    let barrierFree: Bool
    let comments: String?
    let maintainer: String?
    let latitude: Double
    let longitude: Double

    var facilityTypes: [PublicAccessFacilityType] {
        PublicAccessFacilityType.parseCodes(facilityTypeCodes)
    }

    var coordinate: CatchCoordinate? {
        CatchCoordinate(latitude: latitude, longitude: longitude)
    }

    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var locationSubtitle: String {
        if let town, !town.isEmpty {
            return "\(town), \(state)"
        }
        return state
    }

    var isBoatLaunch: Bool {
        facilityTypes.contains(where: \.isBoatLaunch)
    }
}

struct PublicAccessSnapshot: Codable, Sendable {
    let source: String
    let state: String
    let fetchedAt: String
    let sites: [PublicAccessSite]
}

struct PublicAccessCatalog: Sendable {
    static let shared = PublicAccessCatalog.loadBundled()

    let source: String
    let sites: [PublicAccessSite]
    private let sitesByID: [String: PublicAccessSite]

    init(source: String, sites: [PublicAccessSite]) {
        self.source = source
        self.sites = sites
        sitesByID = Dictionary(sites.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    static func decode(from data: Data) throws -> PublicAccessSnapshot {
        let snapshot = try JSONDecoder().decode(PublicAccessSnapshot.self, from: data)
        let validSites = snapshot.sites.filter { $0.coordinate != nil }
        return PublicAccessSnapshot(
            source: snapshot.source,
            state: snapshot.state,
            fetchedAt: snapshot.fetchedAt,
            sites: validSites
        )
    }

    static func loadBundled(
        bundle: Bundle = .main,
        resourceName: String = "ma-public-access"
    ) -> PublicAccessCatalog {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let snapshot = try? decode(from: data)
        else {
            return PublicAccessCatalog(source: "MassGIS OFBA", sites: [])
        }
        return PublicAccessCatalog(source: snapshot.source, sites: snapshot.sites)
    }

    func site(id: String) -> PublicAccessSite? {
        sitesByID[id]
    }

    func sites(in region: MKCoordinateRegion) -> [PublicAccessSite] {
        let halfLat = region.span.latitudeDelta / 2
        let halfLon = region.span.longitudeDelta / 2
        let minLat = region.center.latitude - halfLat
        let maxLat = region.center.latitude + halfLat
        let minLon = region.center.longitude - halfLon
        let maxLon = region.center.longitude + halfLon
        return sites.filter { site in
            site.latitude >= minLat && site.latitude <= maxLat
                && site.longitude >= minLon && site.longitude <= maxLon
        }
    }
}
