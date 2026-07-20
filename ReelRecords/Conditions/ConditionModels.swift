import Foundation

enum SkyCondition: Equatable, Sendable, Codable {
    case sunny
    case partlyCloudy
    case overcast
    case rain
    case fog
    case clearNight
    case unknown(String)

    static let knownValues: [SkyCondition] = [
        .sunny, .partlyCloudy, .overcast, .rain, .fog, .clearNight
    ]

    init(storageValue: String) {
        self = switch storageValue {
        case "sunny": .sunny
        case "partly_cloudy": .partlyCloudy
        case "overcast": .overcast
        case "rain": .rain
        case "fog": .fog
        case "clear_night": .clearNight
        default: .unknown(storageValue)
        }
    }

    var storageValue: String {
        switch self {
        case .sunny: "sunny"
        case .partlyCloudy: "partly_cloudy"
        case .overcast: "overcast"
        case .rain: "rain"
        case .fog: "fog"
        case .clearNight: "clear_night"
        case let .unknown(value): value
        }
    }

    var label: String {
        switch self {
        case .sunny: "Sunny"
        case .partlyCloudy: "Partly Cloudy"
        case .overcast: "Overcast"
        case .rain: "Rain"
        case .fog: "Fog"
        case .clearNight: "Clear Night"
        case .unknown: "Other Weather"
        }
    }

    var systemImage: String {
        switch self {
        case .sunny: "sun.max.fill"
        case .partlyCloudy: "cloud.sun.fill"
        case .overcast, .unknown: "cloud.fill"
        case .rain: "cloud.rain.fill"
        case .fog: "cloud.fog.fill"
        case .clearNight: "moon.stars.fill"
        }
    }

    init(from decoder: any Decoder) throws {
        try self.init(storageValue: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }
}

enum WaterClarity: Equatable, Sendable, Codable {
    case clear
    case stained
    case muddy
    case unknown(String)

    static let knownValues: [WaterClarity] = [.clear, .stained, .muddy]

    init(storageValue: String) {
        self = switch storageValue {
        case "clear": .clear
        case "stained": .stained
        case "muddy": .muddy
        default: .unknown(storageValue)
        }
    }

    var storageValue: String {
        switch self {
        case .clear: "clear"
        case .stained: "stained"
        case .muddy: "muddy"
        case let .unknown(value): value
        }
    }

    var label: String {
        switch self {
        case .clear: "Clear"
        case .stained: "Stained"
        case .muddy: "Muddy"
        case .unknown: "Other"
        }
    }

    init(from decoder: any Decoder) throws {
        try self.init(storageValue: decoder.singleValueContainer().decode(String.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }
}

struct CatchConditions: Equatable, Sendable {
    let airTemperatureF: Double?
    let skyCondition: SkyCondition?
    let waterTemperatureF: Double?
    let waterClarity: WaterClarity?

    static let empty = CatchConditions(
        airTemperatureF: nil,
        skyCondition: nil,
        waterTemperatureF: nil,
        waterClarity: nil
    )
}

enum SuggestedConditionSource: Equatable, Sendable {
    case existing
    case suggested
    case manual
}

struct ConditionEnrichmentDraft: Equatable, Sendable {
    private(set) var airSource: SuggestedConditionSource?
    private(set) var skySource: SuggestedConditionSource?

    init(conditions: CatchConditions = .empty) {
        airSource = conditions.airTemperatureF == nil ? nil : .existing
        skySource = conditions.skyCondition == nil ? nil : .existing
    }

    mutating func markAirTemperatureManual() {
        airSource = .manual
    }

    mutating func markSkyConditionManual() {
        skySource = .manual
    }

    mutating func apply(_ suggestion: WeatherSuggestion) -> AppliedConditionSuggestion {
        var airTemperatureF: Double?
        var skyCondition: SkyCondition?
        if airSource == nil {
            airTemperatureF = suggestion.airTemperatureF
            airSource = .suggested
        }
        if skySource == nil, let suggestedSky = suggestion.skyCondition {
            skyCondition = suggestedSky
            skySource = .suggested
        }
        return AppliedConditionSuggestion(
            airTemperatureF: airTemperatureF,
            skyCondition: skyCondition
        )
    }
}

struct AppliedConditionSuggestion: Equatable, Sendable {
    let airTemperatureF: Double?
    let skyCondition: SkyCondition?
}

enum WMOConditionMapper {
    static func skyCondition(code: Int, isDay: Bool) -> SkyCondition? {
        switch code {
        case 0, 1:
            isDay ? .sunny : .clearNight
        case 2:
            .partlyCloudy
        case 3, 71, 73, 75, 77, 85, 86:
            .overcast
        case 45, 48:
            .fog
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99:
            .rain
        default:
            nil
        }
    }
}
