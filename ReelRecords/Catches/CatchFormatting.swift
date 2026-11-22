import Foundation

enum CatchFormatting {
    /// Parses a form field. When `text` still equals `input(original)` the user did not edit the field,
    /// so `original` is returned unrounded instead of the 2-decimal value the form displayed.
    static func parseOptionalMeasurement(
        _ text: String,
        field: MeasurementField,
        unchangedFrom original: Double? = nil
    ) throws -> Double? {
        if text == input(original) {
            return original
        }
        return try parseOptionalNumber(
            text,
            isValid: { $0 >= 0 },
            error: field == .weight ? .invalidWeight : .invalidLength
        )
    }

    static func input(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0 ... 2)))
    }

    static func parseOptionalTemperature(_ text: String, unchangedFrom original: Double? = nil) throws -> Double? {
        if text == input(original) {
            return original
        }
        return try parseOptionalNumber(text, isValid: { _ in true }, error: .invalidTemperature)
    }

    private static func parseOptionalNumber(
        _ text: String,
        isValid: (Double) -> Bool,
        error: CatchValidationError
    ) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        guard let value = formatter.number(from: trimmed)?.doubleValue,
              value.isFinite,
              isValid(value)
        else {
            throw error
        }
        return value
    }

    static func weight(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) lb"
    }

    static func length(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0 ... 1)))) in"
    }

    static func temperature(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0 ... 1))))°F"
    }

    enum MeasurementField {
        case weight
        case length
    }
}

/// The catch form's number fields as text. Edit Catch loads them with `init(loading:)` and Save Changes
/// builds its values with `parsed(unchangedFrom:)`, so an untouched field keeps its stored value unrounded.
struct CatchNumberInputs: Equatable {
    var weight: String
    var length: String
    var airTemperature: String
    var waterTemperature: String

    struct Parsed: Equatable {
        let weight: Double?
        let length: Double?
        let airTemperatureF: Double?
        let waterTemperatureF: Double?
    }

    init(weight: String, length: String, airTemperature: String, waterTemperature: String) {
        self.weight = weight
        self.length = length
        self.airTemperature = airTemperature
        self.waterTemperature = waterTemperature
    }

    init(loading values: CatchValues?) {
        self.init(
            weight: CatchFormatting.input(values?.weight),
            length: CatchFormatting.input(values?.length),
            airTemperature: CatchFormatting.input(values?.conditions.airTemperatureF),
            waterTemperature: CatchFormatting.input(values?.conditions.waterTemperatureF)
        )
    }

    func parsed(unchangedFrom initial: CatchValues?) throws -> Parsed {
        try Parsed(
            weight: CatchFormatting.parseOptionalMeasurement(weight, field: .weight, unchangedFrom: initial?.weight),
            length: CatchFormatting.parseOptionalMeasurement(length, field: .length, unchangedFrom: initial?.length),
            airTemperatureF: CatchFormatting.parseOptionalTemperature(
                airTemperature, unchangedFrom: initial?.conditions.airTemperatureF
            ),
            waterTemperatureF: CatchFormatting.parseOptionalTemperature(
                waterTemperature, unchangedFrom: initial?.conditions.waterTemperatureF
            )
        )
    }
}

extension CatchSyncState {
    var label: String {
        switch self {
        case .pending: "Pending sync"
        case .syncing: "Syncing"
        case .synced: "Synced"
        case .failed: "Sync failed"
        case .conflict: "Sync conflict"
        }
    }

    var systemImage: String {
        switch self {
        case .pending: "clock"
        case .syncing: "arrow.triangle.2.circlepath"
        case .synced: "checkmark.circle.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .conflict: "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }
}
