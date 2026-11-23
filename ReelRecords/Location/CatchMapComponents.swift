import SwiftUI

struct MapSpeciesFilterBar: View {
    let availableSpecies: [String]
    let selectedSpecies: String?
    let onSelect: (String?) -> Void

    var body: some View {
        let resetTitle = CatchMapFilter.resetChipTitle(availableSpecies: availableSpecies)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                SelectionChip(title: resetTitle, isSelected: selectedSpecies == nil, sizing: .compact) {
                    onSelect(nil)
                }
                .accessibilityLabel("Show all catches")
                .accessibilityIdentifier("map.species.All")

                ForEach(availableSpecies, id: \.self) { species in
                    SelectionChip(title: species, isSelected: selectedSpecies == species, sizing: .compact) {
                        onSelect(species)
                    }
                    .accessibilityLabel(
                        CatchDiscovery.normalized(species) == "all" ? "Species \(species)" : species
                    )
                    .accessibilityIdentifier(CatchMapFilter.speciesChipIdentifier(for: species))
                }
            }
        }
        .accessibilityLabel("Filter map by species")
    }
}

struct SelectedCatchCard: View {
    let selectedCatch: CatchItem
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                Image(systemName: "fish.fill")
                    .font(.title2)
                    .foregroundStyle(ReelTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(ReelTheme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(selectedCatch.species)
                        .reelDisplayFont(17)
                        .foregroundStyle(ReelTheme.primaryText)
                        .lineLimit(1)
                    Text(selectedCatch.location ?? "Named spot not recorded")
                        .font(ReelFont.body(.caption))
                        .foregroundStyle(ReelTheme.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                if let weight = selectedCatch.weight {
                    Text(CatchFormatting.weight(weight))
                        .font(ReelFont.metadata(.caption, weight: .bold))
                        .foregroundStyle(ReelTheme.accentHighlight)
                }
                Image(systemName: "chevron.right")
                    .foregroundStyle(ReelTheme.tertiaryText)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(12)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(selectedCatch.species) from \(selectedCatch.location ?? "unnamed spot")")
        .accessibilityIdentifier("map.selected-catch")
    }
}

struct WaterLookupNoticeBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "drop.triangle")
                .foregroundStyle(ReelTheme.secondaryText)
            Text(message)
                .font(ReelFont.body(.caption, weight: .semibold))
                .foregroundStyle(ReelTheme.primaryText)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(ReelTheme.secondaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map.water-notice")
    }
}
