import MapKit
import SwiftUI

enum CatchMapStyle: String, CaseIterable, Identifiable, Sendable {
    static let storageKey = "reelrecords.map.style"

    case standard
    case hybrid
    case satellite

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .standard:
            "Standard"
        case .hybrid:
            "Hybrid"
        case .satellite:
            "Satellite"
        }
    }

    var subtitle: String {
        switch self {
        case .standard:
            "Dark muted map"
        case .hybrid:
            "Satellite imagery with labels"
        case .satellite:
            "Pure satellite imagery"
        }
    }

    var systemImage: String {
        switch self {
        case .standard:
            "map"
        case .hybrid:
            "globe.americas"
        case .satellite:
            "photo"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            .standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll)
        case .hybrid:
            .hybrid(elevation: .flat, pointsOfInterest: .excludingAll)
        case .satellite:
            .imagery(elevation: .flat)
        }
    }
}

enum CatchMapFilter {
    static func reconciledSpecies(_ selectedSpecies: String?, availableSpecies: [String]) -> String? {
        guard availableSpecies.count > 1, let selectedSpecies else {
            return nil
        }
        let target = CatchDiscovery.normalized(selectedSpecies)
        return availableSpecies.first { CatchDiscovery.normalized($0) == target }
    }

    static func reconciledSelection(_ selectedCatchID: UUID?, in filteredCatches: [CatchItem]) -> UUID? {
        if let selectedCatchID, filteredCatches.contains(where: { $0.id == selectedCatchID }) {
            return selectedCatchID
        }
        return filteredCatches.first?.id
    }

    static func speciesForFocus(
        catchID: UUID?,
        selectedSpecies: String?,
        in pinnedCatches: [CatchItem]
    ) -> String? {
        guard let catchID,
              let selectedSpecies,
              let target = pinnedCatches.first(where: { $0.id == catchID })
        else {
            return selectedSpecies
        }
        let matchesSelected = CatchDiscovery.normalized(target.species)
            == CatchDiscovery.normalized(selectedSpecies)
        return matchesSelected ? selectedSpecies : nil
    }

    static func countSummary(
        filteredCount: Int,
        totalCount: Int,
        spotCount: Int,
        isFiltered: Bool
    ) -> String {
        let catchWord = totalCount == 1 ? "CATCH" : "CATCHES"
        let spotWord = spotCount == 1 ? "SPOT" : "SPOTS"
        if isFiltered {
            return "\(filteredCount) OF \(totalCount) \(catchWord) ACROSS \(spotCount) \(spotWord)"
        }
        return "\(totalCount) \(catchWord) ACROSS \(spotCount) \(spotWord)"
    }
}

struct CatchMapLayersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var mapStyle: CatchMapStyle

    var body: some View {
        NavigationStack {
            List {
                Section("Map Style") {
                    ForEach(CatchMapStyle.allCases) { style in
                        Button {
                            mapStyle = style
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: style.systemImage)
                                    .font(.body)
                                    .foregroundStyle(
                                        mapStyle == style ? ReelTheme.accent : ReelTheme.secondaryText
                                    )
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(style.title)
                                        .font(ReelFont.body(.body, weight: .semibold))
                                        .foregroundStyle(ReelTheme.primaryText)
                                    Text(style.subtitle)
                                        .font(ReelFont.body(.caption))
                                        .foregroundStyle(ReelTheme.secondaryText)
                                }
                                Spacer()
                                if mapStyle == style {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(ReelTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(mapStyle == style ? .isSelected : [])
                        .accessibilityValue(mapStyle == style ? "Selected" : "Not selected")
                        .accessibilityIdentifier("map.style.\(style.rawValue)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ReelTheme.background)
            .navigationTitle("Map Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("map.layers.done")
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
