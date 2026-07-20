import Foundation

struct CatchCoordinate: Codable, Equatable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite,
              longitude.isFinite,
              (-90 ... 90).contains(latitude),
              (-180 ... 180).contains(longitude)
        else {
            return nil
        }
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude else { return nil }
        self.init(latitude: latitude, longitude: longitude)
    }

    var displayLabel: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }
}

struct LocationSample: Equatable, Sendable {
    let coordinate: CatchCoordinate
    let horizontalAccuracy: Double
    let timestamp: Date
}

enum LocationSampleRejection: Equatable, Sendable {
    case invalidAccuracy
    case inaccurate
    case stale
}

enum LocationFixPolicy {
    static let maximumAccuracy = 100.0
    static let maximumAge: TimeInterval = 120

    static func rejection(for sample: LocationSample, now: Date = .now) -> LocationSampleRejection? {
        guard sample.horizontalAccuracy.isFinite, sample.horizontalAccuracy > 0 else {
            return .invalidAccuracy
        }
        guard sample.horizontalAccuracy <= maximumAccuracy else {
            return .inaccurate
        }
        guard abs(now.timeIntervalSince(sample.timestamp)) <= maximumAge else {
            return .stale
        }
        return nil
    }
}

enum SpotSummary {
    static func normalizedName(_ name: String?) -> String? {
        let normalized = name?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized?.isEmpty == false ? normalized : nil
    }

    static func uniqueCount(in catches: [CatchItem]) -> Int {
        Set(catches.compactMap { normalizedName($0.location) }).count
    }
}
