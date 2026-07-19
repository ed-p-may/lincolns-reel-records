import Foundation

enum CatchFormatting {
    static func parseOptionalMeasurement(_ text: String, field: MeasurementField) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        guard let value = formatter.number(from: trimmed)?.doubleValue, value.isFinite, value >= 0 else {
            throw field == .weight ? CatchValidationError.invalidWeight : CatchValidationError.invalidLength
        }
        return value
    }

    static func input(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0 ... 2)))
    }

    static func weight(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) lb"
    }

    static func length(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0 ... 1)))) in"
    }

    enum MeasurementField {
        case weight
        case length
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
