import MapKit
import SwiftUI

struct CatchMapView: View {
    private static let defaultMassachusettsRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 42.3169, longitude: -73.25),
        span: MKCoordinateSpan(latitudeDelta: 0.75, longitudeDelta: 0.95)
    )

    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SwiftDataTackleRepository.self) private var tackleRepository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Environment(\.waterBodyInfoProvider) private var waterBodyInfoProvider
    @AppStorage(CatchMapStyle.storageKey) private var mapStyle: CatchMapStyle = .standard
    @AppStorage(CatchMapLayerSettings.showPublicAccessKey) private var showPublicAccess = false
    @AppStorage(CatchMapLayerSettings.showLakeDepthsKey) private var showLakeDepths = false
    @State private var catches: [CatchItem] = []
    @State private var tackleNames: [UUID: String] = [:]
    @State private var selectedSpecies: String?
    @State private var selection: CatchMapSelection?
    @State private var selectedWaterBody: WaterBodySelection?
    @State private var waterBodyInfo: WaterBodyInfo?
    @State private var isLoadingWaterInfo = false
    @State private var isWaterInfoOffline = false
    @State private var waterLookupNotice: String?
    @State private var waterResolveTask: Task<Void, Never>?
    @State private var waterFetchTask: Task<Void, Never>?
    @State private var noticeDismissTask: Task<Void, Never>?
    @State private var handledFocusRevision: Int?
    @State private var hasLoadedCatches = false
    @State private var usingEmptyFallbackCamera = false
    @State private var targetRegion: MKCoordinateRegion?
    @State private var cameraRevision = 0
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
                    showLakeDepths: $showLakeDepths,
                    publicAccessSiteCount: accessCatalog.sites.count
                )
            }
            .sheet(item: $selectedWaterBody, onDismiss: clearWaterBodyState) { water in
                WaterBodyInfoSheet(
                    selection: water,
                    localHistory: LocalWaterHistory.summarize(
                        catches: catches.filter { $0.ownerID == ownerID },
                        tackleNames: tackleNames,
                        for: water
                    ),
                    info: waterBodyInfo,
                    isLoading: isLoadingWaterInfo,
                    isOfflineUnavailable: isWaterInfoOffline,
                    onRefresh: { loadWaterBodyInfo(for: water, forceRefresh: true) },
                    onOpenCatch: { catchItem in
                        selectedWaterBody = nil
                        onOpenCatch(catchItem)
                    },
                    onDismiss: { selectedWaterBody = nil }
                )
            }
            .task(id: MapReloadKey(ownerID: ownerID, revision: refreshToken + syncCoordinator.revision)) { reload() }
            .onChange(of: ownerID) { _, _ in
                resetForOwnerChange()
            }
            .onChange(of: focusRevision) { _, _ in reload() }
            .onChange(of: selection) { _, newValue in
                if newValue != nil {
                    waterResolveTask?.cancel()
                    selectedWaterBody = nil
                    waterLookupNotice = nil
                }
            }
            .onChange(of: showPublicAccess) { _, isVisible in
                if !isVisible, selection?.accessSiteID != nil {
                    selection = nil
                }
            }
            .onDisappear {
                waterResolveTask?.cancel()
                waterFetchTask?.cancel()
                noticeDismissTask?.cancel()
            }
            .alert("Unable to open map", isPresented: errorBinding) {
                Button("Retry") { reload() }
            } message: {
                Text(loadError ?? "")
            }
    }

    private var mapContent: some View {
        CatchMKMapView(
            catches: filteredCatches,
            accessSites: accessCatalog.sites,
            showPublicAccess: showPublicAccess,
            showLakeDepths: showLakeDepths,
            mapStyle: mapStyle,
            targetRegion: targetRegion,
            cameraRevision: cameraRevision,
            selection: $selection,
            onSelectMapFeature: { title, coordinate in
                inspectWaterBody(at: coordinate, hintName: title, showNotFoundNotice: false)
            },
            onLongPressCoordinate: { coordinate in
                inspectWaterBody(at: coordinate, hintName: nil, showNotFoundNotice: true)
            }
        )
        .ignoresSafeArea(edges: .bottom)
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

    private var bottomDetailCard: some View {
        VStack(spacing: 0) {
            if let waterLookupNotice {
                WaterLookupNoticeBanner(message: waterLookupNotice) {
                    self.waterLookupNotice = nil
                }
            }
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

    private func setCamera(to region: MKCoordinateRegion) {
        targetRegion = region
        cameraRevision += 1
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
            setCamera(to: region)
        }
    }
}

private extension CatchMapView {
    func reload() {
        do {
            let wasFirstLoad = !hasLoadedCatches
            catches = try repository.list(ownerID: ownerID)
            let referencedIDs = Set(catches.compactMap(\.tackleItemID))
            tackleNames = (try? tackleRepository.itemNames(ownerID: ownerID, referencedIDs: referencedIDs)) ?? [:]
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
                    setCamera(to: Self.defaultMassachusettsRegion)
                    usingEmptyFallbackCamera = true
                }
            } else if wasFirstLoad || usingEmptyFallbackCamera {
                usingEmptyFallbackCamera = false
                if let region = CatchMapFilter.fittingRegion(for: filteredCatches) {
                    setCamera(to: region)
                }
            }
            applyPendingFocusIfNeeded()
        } catch {
            loadError = error.localizedDescription
        }
    }

    func applyPendingFocusIfNeeded() {
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

    func focusRequestedCatch() {
        guard let focusCatchID,
              let catchItem = pinnedCatches.first(where: { $0.id == focusCatchID }),
              let coordinate = catchItem.coordinate
        else {
            if focusSpotName != nil {
                selection = nil
                if let region = CatchMapFilter.fittingRegion(for: filteredCatches) {
                    usingEmptyFallbackCamera = false
                    setCamera(to: region)
                } else {
                    usingEmptyFallbackCamera = true
                    setCamera(to: Self.defaultMassachusettsRegion)
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
        setCamera(to: MKCoordinateRegion(
            center: coordinate.mapCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
        ))
    }

    func inspectWaterBody(
        at coordinate: CatchCoordinate,
        hintName: String?,
        showNotFoundNotice: Bool
    ) {
        waterResolveTask?.cancel()
        noticeDismissTask?.cancel()
        waterLookupNotice = nil

        // Show local history & cached guide immediately for known/recognizable waters.
        let instantSelection: WaterBodySelection? = if let cached = waterBodyInfoProvider.cachedSelection(
            near: coordinate,
            hintName: hintName
        ) {
            cached
        } else if let hintName, WaterBodyNameClassifier.looksLikeWaterName(hintName) {
            WaterBodySelection(
                id: WaterBodySelection.canonicalID(name: hintName, coordinate: coordinate),
                name: hintName,
                waterType: WaterBodyNameClassifier.classify(name: hintName),
                coordinate: coordinate,
                regionSubtitle: nil,
                wikipediaTag: nil
            )
        } else {
            nil
        }

        if let instantSelection {
            selection = nil
            selectedWaterBody = instantSelection
            waterBodyInfo = waterBodyInfoProvider.cachedInfo(for: instantSelection)
            isLoadingWaterInfo = true
            isWaterInfoOffline = false
        }

        waterResolveTask = Task { @MainActor in
            let resolved = try? await waterBodyInfoProvider.resolveWaterBody(
                at: coordinate,
                hintName: hintName
            )
            guard !Task.isCancelled else { return }

            guard let resolved else {
                if instantSelection != nil {
                    selectedWaterBody = nil
                    clearWaterBodyState()
                }
                if showNotFoundNotice {
                    showTemporaryWaterNotice("No named body of water found here")
                }
                return
            }

            selection = nil
            selectedWaterBody = resolved
            loadWaterBodyInfo(for: resolved, forceRefresh: false)
        }
    }

    func loadWaterBodyInfo(for selection: WaterBodySelection, forceRefresh: Bool) {
        waterFetchTask?.cancel()
        if !forceRefresh {
            waterBodyInfo = waterBodyInfoProvider.cachedInfo(for: selection)
        }
        isLoadingWaterInfo = true
        isWaterInfoOffline = false

        waterFetchTask = Task { @MainActor in
            do {
                let fetched = try await waterBodyInfoProvider.fetchInfo(
                    for: selection,
                    forceRefresh: forceRefresh
                )
                guard !Task.isCancelled, selectedWaterBody?.id == selection.id else { return }
                waterBodyInfo = fetched
                isLoadingWaterInfo = false
                isWaterInfoOffline = false
            } catch {
                guard !Task.isCancelled, selectedWaterBody?.id == selection.id else { return }
                isLoadingWaterInfo = false
                if waterBodyInfo == nil {
                    isWaterInfoOffline = true
                }
            }
        }
    }

    func showTemporaryWaterNotice(_ message: String) {
        waterLookupNotice = message
        noticeDismissTask?.cancel()
        noticeDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            waterLookupNotice = nil
        }
    }

    func clearWaterBodyState() {
        waterFetchTask?.cancel()
        waterBodyInfo = nil
        isLoadingWaterInfo = false
        isWaterInfoOffline = false
    }

    func resetForOwnerChange() {
        waterResolveTask?.cancel()
        waterFetchTask?.cancel()
        noticeDismissTask?.cancel()
        catches = []
        tackleNames = [:]
        selection = nil
        selectedSpecies = nil
        selectedWaterBody = nil
        waterBodyInfo = nil
        isLoadingWaterInfo = false
        isWaterInfoOffline = false
        waterLookupNotice = nil
        hasLoadedCatches = false
    }
}

private struct MapReloadKey: Equatable {
    let ownerID: UUID
    let revision: Int
}
