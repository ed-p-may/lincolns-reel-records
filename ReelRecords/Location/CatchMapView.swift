import MapKit
import SwiftUI

struct CatchMapView: View {
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var catches: [CatchItem] = []
    @State private var selectedCatchID: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var loadError: String?

    let ownerID: UUID
    let refreshToken: Int
    let focusCatchID: UUID?
    let focusSpotName: String?
    let focusRevision: Int
    let onOpenCatch: (CatchItem) -> Void

    var body: some View {
        Group {
            if pinnedCatches.isEmpty {
                emptyState
            } else {
                mapContent
            }
        }
        .background(ReelTheme.background)
        .navigationTitle("Catch Map")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: refreshToken + syncCoordinator.revision) { reload() }
        .onChange(of: focusRevision) { _, _ in focusRequestedCatch() }
        .alert("Unable to open map", isPresented: errorBinding) {
            Button("Retry") { reload() }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition, selection: $selectedCatchID) {
            ForEach(pinnedCatches) { catchItem in
                if let coordinate = catchItem.coordinate {
                    Marker(
                        catchItem.species,
                        systemImage: selectedCatchID == catchItem.id ? "fish.circle.fill" : "fish.fill",
                        coordinate: coordinate.mapCoordinate
                    )
                    .tint(selectedCatchID == catchItem.id ? ReelTheme.accentHighlight : ReelTheme.accent)
                    .tag(catchItem.id)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .safeAreaInset(edge: .top) { mapHeader }
        .safeAreaInset(edge: .bottom) { selectedCatchCard }
    }

    private var mapHeader: some View {
        let spotCount = SpotSummary.uniqueCount(in: pinnedCatches)
        return VStack(alignment: .leading, spacing: 3) {
            Text("\(pinnedCatches.count) CATCH\(pinnedCatches.count == 1 ? "" : "ES") ACROSS "
                + "\(spotCount) SPOT\(spotCount == 1 ? "" : "S")")
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(ReelTheme.primaryText)
                .accessibilityIdentifier("map.counts")
            Text(mapSubtitle)
                .font(ReelFont.body(.caption2))
                .foregroundStyle(ReelTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var selectedCatchCard: some View {
        if let selectedCatch {
            Button {
                onOpenCatch(selectedCatch)
            } label: {
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No catches pinned yet", systemImage: "map")
        } description: {
            Text(emptyDescription)
        }
        .accessibilityIdentifier("map.empty")
    }

    private var pinnedCatches: [CatchItem] {
        catches.filter { $0.coordinate != nil }
    }

    private var selectedCatch: CatchItem? {
        guard let selectedCatchID else { return nil }
        return pinnedCatches.first { $0.id == selectedCatchID }
    }

    private var unmappedFocusName: String? {
        guard let focusSpotName else { return nil }
        guard let focusCatchID, pinnedCatches.contains(where: { $0.id == focusCatchID }) else {
            return focusSpotName
        }
        return nil
    }

    private var mapSubtitle: String {
        if let unmappedFocusName {
            return "\(unmappedFocusName) has no saved pin yet; showing your other mapped catches."
        }
        return "Catch pins stay saved offline; Apple map tiles may need a connection."
    }

    private var emptyDescription: String {
        if let unmappedFocusName {
            return "\(unmappedFocusName) has no saved pin. Add GPS or a manual pin from Edit Catch."
        }
        return catches.isEmpty
            ? "Log a catch to start your private map."
            : "Your catches are safe; add a GPS or manual pin from Edit Catch."
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { loadError != nil },
            set: {
                if !$0 {
                    loadError = nil
                }
            }
        )
    }

    private func reload() {
        do {
            catches = try repository.list(ownerID: ownerID)
            loadError = nil
            if selectedCatch == nil {
                selectedCatchID = pinnedCatches.first?.id
            }
            focusRequestedCatch()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func focusRequestedCatch() {
        guard let focusCatchID,
              let catchItem = pinnedCatches.first(where: { $0.id == focusCatchID }),
              let coordinate = catchItem.coordinate
        else {
            if focusSpotName != nil {
                selectedCatchID = nil
                cameraPosition = .automatic
            }
            return
        }
        selectedCatchID = catchItem.id
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate.mapCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
        ))
    }
}
