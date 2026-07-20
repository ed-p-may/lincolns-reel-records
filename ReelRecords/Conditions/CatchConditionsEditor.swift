import SwiftUI

struct CatchConditionsEditor: View {
    @Binding var airTemperature: String
    @Binding var skyCondition: SkyCondition?
    @Binding var waterTemperature: String
    @Binding var waterClarity: WaterClarity?
    let airIsSuggested: Bool
    let skyIsSuggested: Bool
    let isFetching: Bool
    let message: String?
    let onAirEdited: () -> Void
    let onSkyEdited: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel
            Text("Weather may be suggested from the catch pin and time. Every value stays optional and editable.")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
            temperatureInputs
            skyPicker
            clarityPicker
            requestStatus
        }
    }

    private var sectionLabel: some View {
        Text("CONDITIONS")
            .font(ReelFont.metadata(.caption2, weight: .bold))
            .tracking(1)
            .foregroundStyle(ReelTheme.tertiaryText)
    }

    private var temperatureInputs: some View {
        HStack(spacing: 12) {
            temperatureInput(
                "Air",
                text: Binding(
                    get: { airTemperature },
                    set: {
                        airTemperature = $0
                        onAirEdited()
                    }
                ),
                isSuggested: airIsSuggested,
                identifier: "add.air-temperature"
            )
            temperatureInput(
                "Water",
                text: $waterTemperature,
                isSuggested: false,
                identifier: "add.water-temperature"
            )
        }
    }

    private var skyPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            conditionLabel("Sky", isSuggested: skyIsSuggested)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104))], spacing: 9) {
                ForEach(SkyCondition.knownValues, id: \.storageValue) { condition in
                    SelectionChip(
                        title: condition.label,
                        isSelected: skyCondition == condition,
                        sizing: .fillWidth
                    ) {
                        skyCondition = skyCondition == condition ? nil : condition
                        onSkyEdited()
                    }
                    .accessibilityIdentifier("add.sky.\(condition.storageValue)")
                }
            }
        }
    }

    private var clarityPicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            conditionLabel("Water clarity", isSuggested: false)
            HStack(spacing: 9) {
                ForEach(WaterClarity.knownValues, id: \.storageValue) { clarity in
                    SelectionChip(
                        title: clarity.label,
                        isSelected: waterClarity == clarity,
                        sizing: .fillWidth
                    ) {
                        waterClarity = waterClarity == clarity ? nil : clarity
                    }
                    .accessibilityIdentifier("add.clarity.\(clarity.storageValue)")
                }
            }
        }
    }

    @ViewBuilder
    private var requestStatus: some View {
        if isFetching {
            Label("Checking weather…", systemImage: "cloud.sun")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
        } else if let message {
            Label(message, systemImage: "cloud.slash")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
        }
    }

    private func temperatureInput(
        _ title: String,
        text: Binding<String>,
        isSuggested: Bool,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            conditionLabel(title, isSuggested: isSuggested)
            UnitInput(
                title,
                unit: "°F",
                text: text,
                keyboardType: .numbersAndPunctuation,
                identifier: identifier
            )
        }
    }

    private func conditionLabel(_ text: String, isSuggested: Bool) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(ReelFont.body(.caption, weight: .semibold))
                .foregroundStyle(ReelTheme.secondaryText)
            if isSuggested {
                Text("SUGGESTED")
                    .font(ReelFont.metadata(.caption2, weight: .bold))
                    .foregroundStyle(ReelTheme.accentHighlight)
                    .accessibilityLabel("Suggested by weather service")
            }
        }
    }
}
