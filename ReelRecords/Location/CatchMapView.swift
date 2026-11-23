import MapKit
import SwiftUI

struct CatchMapView: View {
    private static let defaultMassachusettsRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3169, longitude: -73.25),
        span: MKCoordinateSpan(latitudeDelta: 0.75, longitudeDelta: 0.95)
    )

    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @AppStorage(CatchMapStyle.storageKey) private var mapStyle: CatchMapStyle = .standard
    @AppStorage(CatchMapLayerSettings.showPublicAccessKey) private var showPublicAccess = false
    @State private var catches: [CatchItem] = []
    @State private var selectedSpecies: String?
    @State private var selection: CatchMapSelection?
    @State private var handledFocusRevision: Int?
    @State private var hasLoadedCatches = false
    @State private var usingEmptyFallbackCamera = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showingLayersSheet = false
    @State private var loadError: String?

    let ownerID: UUID
    let refreshToken: Int
    let focusCatchID: UUID?
    let focusSpotName: String?
    let focusRevision: Int
    let onOpenCatch: (CatchItem) -> Void
    var accessCatalog: PublicAccessCatalog = .shared

    var body: some View {
        mapContent
            .background(ReelTheme.background)
            .navigationTitle("Catch Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingLayersSheet = true
                    } label: {
                        Image(systemName: "square.3.layers.3d")
                    }
                    .accessibilityLabel("Map Layers")
                    .accessibilityValue(mapStyle.title)
                    .accessibilityIdentifier("map.style.button")
                }
            }
            .sheet(isPresented: $showingLayersSheet) {
                CatchMapLayersSheet(
                    mapStyle: $mapStyle,
                    showPublicAccess: $showPublicAccess,
                    publicAccessSiteCount: accessCatalog.sites.count
                )
            }
            .task(id: refreshToken + syncCoordinator.revision) { reload() }
            .onChange(of: focusRevision) { _, _ in reload() }
            .onChange(of: showPublicAccess) { _, isVisible in
                if !isVisible, selection?.accessSiteID != nil {
                    selection = nil
                }
            }
            .alert("Unable to open map", isPresented: errorBinding) {
                Button("Retry") { reload() }
            } message: {
                Text(loadError ?? "")
            }
    }

    private var mapContent: some View {
        Map(position: $cameraPosition, selection: $selection) {
            ForEach(filteredCatches) { catchItem in
                if let coordinate = catchItem.coordinate {
                    let isSelected = selection == .catchPin(catchItem.id)
                    Marker(
                        catchItem.species,
                        systemImage: isSelected ? "fish.circle.fill" : "fish.fill",
                        coordinate: coordinate.mapCoordinate
                    )
                    .tint(isSelected ? ReelTheme.accentHighlight : ReelTheme.accent)
                    .tag(CatchMapSelection.catchPin(catchItem.id))
                }
            }

            if showPublicAccess {
                ForEach(accessCatalog.sites) { site in
                    Annotation(site.name, coordinate: site.mapCoordinate, anchor: .center) {
                        PublicAccessPinView(site: site, isSelected: selection == .accessSite(site.id)) {
                            selection = .accessSite(site.id)
                        }
                    }
                    .tag(CatchMapSelection.accessSite(site.id))
                }
            }
        }
        .mapStyle(mapStyle.mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .safeAreaInset(edge: .top) { mapHeader }
        .safeAreaInset(edge: .bottom) { bottomDetailCard }
    }

    private var mapHeader: some View {
        let spotCount = SpotSummary.uniqueCount(in: filteredCatches)
        let summary = CatchMapFilter.countSummary(
            filteredCount: filteredCatches.count,
            totalCount: pinnedCatches.count,
            spotCount: spotCount,
            isFiltered: selectedSpecies != nil
        )
        return VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                if pinnedCatches.isEmpty {
                    Text("NO CATCHES PINNED YET")
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(ReelTheme.primaryText)
                        .accessibilityIdentifier("map.empty")
                    Text(emptyDescription)
                        .font(ReelFont.body(.caption2))
                        .foregroundStyle(ReelTheme.secondaryText)
                } else {
                    Text(summary)
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .tracking(0.7)
                        .foregroundStyle(ReelTheme.primaryText)
                        .accessibilityIdentifier("map.counts")
                    Text(mapSubtitle)
                        .font(ReelFont.body(.caption2))
                        .foregroundStyle(ReelTheme.secondaryText)
                }
            }
            if availableSpecies.count > 1 {
                MapSpeciesFilterBar(
                    availableSpecies: availableSpecies,
                    selectedSpecies: selectedSpecies,
                    onSelect: selectSpecies
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var bottomDetailCard: some View {
        if let selectedCatch {
            SelectedCatchCard(selectedCatch: selectedCatch) {
                onOpenCatch(selectedCatch)
            }
        } else if let selectedAccessSite {
            PublicAccessSiteCard(site: selectedAccessSite) {
                selection = nil
            }
        }
    }

    private var pinnedCatches: [CatchItem] {
        CatchDiscovery.pinnedCatches(catches)
    }

    private var availableSpecies: [String] {
        CatchDiscovery.species(in: pinnedCatches)
    }

    private var filteredCatches: [CatchItem] {
        CatchDiscovery.pinnedCatches(catches, species: selectedSpecies)
    }

    private var selectedCatch: CatchItem? {
        guard let catchID = selection?.catchID else { return nil }
        return filteredCatches.first { $0.id == catchID }
    }

    private var selectedAccessSite: PublicAccessSite? {
        guard showPublicAccess, let siteID = selection?.accessSiteID else { return nil }
        return accessCatalog.site(id: siteID)
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
            ? "Log a catch to start your private map, or enable MA public access in Map Layers."
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

    private func selectSpecies(_ species: String?) {
        selectedSpecies = species
        if let nextID = CatchMapFilter.reconciledSelection(selection?.catchID, in: filteredCatches) {
            selection = .catchPin(nextID)
        } else {
            selection = nil
        }
        usingEmptyFallbackCamera = false
        if let region = CatchMapFilter.fittingRegion(for: filteredCatches) {
            cameraPosition = .region(region)
        } else {
            cameraPosition = .automatic
        }
    }

    private func reload() {
        do {
            let wasFirstLoad = !hasLoadedCatches
            catches = try repository.list(ownerID: ownerID)
            hasLoadedCatches = true
            loadError = nil
            selectedSpecies = CatchMapFilter.reconciledSpecies(
                selectedSpecies,
                availableSpecies: availableSpecies
            )
            if selection?.accessSiteID == nil {
                selection = CatchMapFilter.reconciledSelection(
                    selection?.catchID,
                    in: filteredCatches
                ).map(CatchMapSelection.catchPin)
            }
            if pinnedCatches.isEmpty {
                if wasFirstLoad || !usingEmptyFallbackCamera {
                    cameraPosition = .region(Self.defaultMassachusettsRegion)
                    usingEmptyFallbackCamera = true
                }
            } else if wasFirstLoad || usingEmptyFallbackCamera {
                usingEmptyFallbackCamera = false
                if let region = CatchMapFilter.fittingRegion(for: filteredCatches) {
                    cameraPosition = .region(region)
                }
            }
            applyPendingFocusIfNeeded()
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func applyPendingFocusIfNeeded() {
        guard hasLoadedCatches else { return }
        let hasFocusTarget = focusCatchID != nil || focusSpotName != nil
        guard CatchMapFilter.shouldApplyFocus(
            focusRevision: focusRevision,
            handledFocusRevision: handledFocusRevision,
            hasFocusTarget: hasFocusTarget
        ) else {
            return
        }
        handledFocusRevision = focusRevision
        focusRequestedCatch()
    }

    private func focusRequestedCatch() {
        guard let focusCatchID,
              let catchItem = pinnedCatches.first(where: { $0.id == focusCatchID }),
              let coordinate = catchItem.coordinate
        else {
            if focusSpotName != nil {
                selection = nil
                if let region = CatchMapFilter.fittingRegion(for: filteredCatches) {
                    usingEmptyFallbackCamera = false
                    cameraPosition = .region(region)
                } else {
                    usingEmptyFallbackCamera = true
                    cameraPosition = .region(Self.defaultMassachusettsRegion)
                }
            }
            return
        }
        usingEmptyFallbackCamera = false
        selectedSpecies = CatchMapFilter.speciesForFocus(
            catchID: catchItem.id,
            selectedSpecies: selectedSpecies,
            in: pinnedCatches
        )
        selection = .catchPin(catchItem.id)
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate.mapCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
        ))
    }
}

private struct MapSpeciesFilterBar: View {
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

private struct SelectedCatchCard: View {
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
