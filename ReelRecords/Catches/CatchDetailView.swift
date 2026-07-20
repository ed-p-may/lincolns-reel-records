import MapKit
import SwiftUI

struct CatchDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(SwiftDataCatchRepository.self) private var repository
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @Environment(SwiftDataTackleRepository.self) private var tackleRepository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var catchItem: CatchItem
    @State private var photos: [CatchPhotoItem] = []
    @State private var tackleItem: TackleItem?
    @State private var isEditing = false
    @State private var isShowingTackleItem = false
    @State private var isConfirmingDelete = false
    @State private var isPreparingShare = false
    @State private var shareArtifact: ShareArtifact?
    @State private var errorMessage: String?
    private let shareStore = TemporaryShareStore()

    let onChanged: () -> Void
    let onShowOnMap: (CatchItem) -> Void

    init(
        catchItem: CatchItem,
        onChanged: @escaping () -> Void,
        onShowOnMap: @escaping (CatchItem) -> Void
    ) {
        _catchItem = State(initialValue: catchItem)
        self.onChanged = onChanged
        self.onShowOnMap = onShowOnMap
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    hero
                    measurementSummary
                    catchDetails
                    conditionsDetails
                    fieldNotes
                    locationMap
                    recordStatus
                    deleteButton
                }
                .padding(.bottom, 28)
            }
            .background(ReelTheme.background)
            .navigationTitle(catchItem.species)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sheet(isPresented: $isEditing) {
                AddCatchView(ownerID: catchItem.ownerID, editItem: catchItem) {
                    reload()
                    onChanged()
                }
            }
            .sheet(isPresented: $isShowingTackleItem) {
                if let tackleItem {
                    TackleItemEditor(ownerID: catchItem.ownerID, editItem: tackleItem) { updated in
                        self.tackleItem = updated
                        onChanged()
                    }
                }
            }
            .sheet(item: $shareArtifact, onDismiss: cleanupShareArtifact) { artifact in
                CatchActivityView(artifact: artifact, onCompletion: cleanupShareArtifact)
                    .ignoresSafeArea()
                    .accessibilityIdentifier("catch.share-sheet")
            }
            .confirmationDialog(
                "Delete this catch?",
                isPresented: $isConfirmingDelete,
                titleVisibility: .visible
            ) {
                Button("Delete Catch", role: .destructive) { deleteCatch() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("It disappears now and the deletion syncs when connected.")
            }
        }
        .alert("Catch action unavailable", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .task(id: syncCoordinator.revision) { reload() }
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            heroGallery
            LinearGradient(
                colors: [ReelTheme.page.opacity(0.05), ReelTheme.background],
                startPoint: .center,
                endPoint: .bottom
            )
            VStack(alignment: .leading, spacing: 7) {
                Text("PERSONAL LOG")
                    .font(ReelFont.metadata(.caption2, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(ReelTheme.accentHighlight)
                Text(catchItem.species)
                    .font(ReelFont.display(32, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                HStack(spacing: 12) {
                    Label(catchItem.location ?? "Spot not recorded", systemImage: "location.fill")
                    Label(
                        catchItem.caughtAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "calendar"
                    )
                }
                .font(ReelFont.body(.caption))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
            }
            .padding(20)
        }
        .frame(minHeight: 300)
        .clipped()
        .overlay(alignment: .topTrailing) {
            CatchDetailShareActions(
                isBookmarked: catchItem.bookmarked,
                isPreparingShare: isPreparingShare,
                onToggleBookmark: toggleBookmark,
                onShare: prepareShare
            )
        }
    }

    @ViewBuilder
    private var heroGallery: some View {
        if photos.isEmpty {
            CatchPhotoPlaceholder(species: catchItem.species)
        } else {
            TabView {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    LocalPhotoImage(
                        url: photoRepository.fileURL(for: photo),
                        maximumPixelSize: 1600,
                        contentMode: .fill,
                        placeholder: CatchPhotoPlaceholder(species: catchItem.species)
                    )
                    .accessibilityLabel("Photo \(index + 1) of \(photos.count) for \(catchItem.species)")
                    .accessibilityIdentifier("detail.photo.\(index)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .accessibilityIdentifier("detail.photo-gallery")
            .overlay(alignment: .topTrailing) {
                Text("\(photos.count) PHOTO\(photos.count == 1 ? "" : "S")")
                    .font(ReelFont.metadata(.caption2, weight: .bold))
                    .padding(.horizontal, 9)
                    .frame(minHeight: 28)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(14)
                    .accessibilityIdentifier("detail.photo-count")
            }
        }
    }

    private var measurementSummary: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { metricCards }
            VStack(spacing: 12) { metricCards }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var metricCards: some View {
        DetailMetricCard(
            label: "Weight",
            value: catchItem.weight.map(CatchFormatting.weight),
            systemImage: "trophy.fill",
            prominent: true
        )
        DetailMetricCard(
            label: "Length",
            value: catchItem.length.map(CatchFormatting.length),
            systemImage: "ruler",
            prominent: false
        )
    }

    private var catchDetails: some View {
        DetailSection(title: "Catch details") {
            VStack(spacing: 11) {
                if let tackleItem {
                    Button { isShowingTackleItem = true } label: {
                        TackleItemRow(item: tackleItem)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this Tackle Box item")
                    .accessibilityIdentifier("detail.tackle-item")
                } else if catchItem.tackleItemID != nil {
                    DetailTile(
                        label: "Saved tackle",
                        value: "Unavailable",
                        systemImage: "shippingbox"
                    )
                    .accessibilityIdentifier("detail.tackle-unavailable")
                }

                LazyVGrid(columns: detailColumns, spacing: 11) {
                    if catchItem.tackleItemID == nil || catchItem.lureText != nil {
                        DetailTile(
                            label: catchItem.tackleItemID == nil ? "Lure / bait" : "One-off note",
                            value: catchItem.lureText,
                            systemImage: "fish.fill"
                        )
                    }
                    DetailTile(
                        label: "Rod & reel",
                        value: catchItem.rodReel,
                        systemImage: "wrench.and.screwdriver.fill"
                    )
                    DetailTile(
                        label: "Disposition",
                        value: catchItem.released ? "Released" : "Kept",
                        systemImage: catchItem.released ? "arrow.uturn.backward" : "checkmark.circle.fill"
                    )
                    DetailTile(
                        label: "Caught",
                        value: catchItem.caughtAt.formatted(date: .long, time: .shortened),
                        systemImage: "calendar"
                    )
                }
            }
        }
    }

    private var detailColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.flexible()), GridItem(.flexible())]
    }

    private var fieldNotes: some View {
        DetailSection(title: "Field notes") {
            Text(catchItem.notes ?? "No field notes recorded.")
                .font(ReelFont.body())
                .foregroundStyle(catchItem.notes == nil ? ReelTheme.tertiaryText : ReelTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var locationMap: some View {
        DetailCatchLocationMap(catchItem: catchItem) {
            onShowOnMap(catchItem)
        }
    }

    private var recordStatus: some View {
        DetailSection(title: "Record status") {
            HStack(spacing: 10) {
                SyncBadge(state: catchItem.syncState)
                VStack(alignment: .leading, spacing: 2) {
                    Text(catchItem.syncState.label)
                        .font(ReelFont.body(.subheadline, weight: .bold))
                        .foregroundStyle(ReelTheme.primaryText)
                    if let syncError = catchItem.syncError {
                        Text(syncError)
                            .font(ReelFont.body(.caption))
                            .foregroundStyle(ReelTheme.danger)
                    }
                }
                Spacer()
                Text("v\(catchItem.remoteVersion)")
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.tertiaryText)
            }
            .padding(14)
            .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var deleteButton: some View {
        Button("Delete Catch", role: .destructive) {
            isConfirmingDelete = true
        }
        .font(ReelFont.body(.body, weight: .semibold))
        .foregroundStyle(ReelTheme.danger)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(ReelTheme.raisedSurface, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
        .accessibilityIdentifier("detail.delete")
    }
}

private extension CatchDetailView {
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
                .accessibilityIdentifier("detail.done")
        }
        ToolbarItem(placement: .primaryAction) {
            Button("Edit") { isEditing = true }
                .accessibilityIdentifier("detail.edit")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                }
            }
        )
    }

    private func reload() {
        do {
            if let updated = try repository.item(id: catchItem.id, ownerID: catchItem.ownerID) {
                catchItem = updated
            }
            reloadPhotos()
            reloadTackleItem()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteCatch() {
        do {
            try photoRepository.deleteAll(catchID: catchItem.id, ownerID: catchItem.ownerID)
            try repository.delete(id: catchItem.id, ownerID: catchItem.ownerID)
            onChanged()
            dismiss()
            Task { await syncCoordinator.sync(ownerID: catchItem.ownerID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleBookmark() {
        do {
            catchItem = try repository.setBookmarked(
                id: catchItem.id,
                ownerID: catchItem.ownerID,
                bookmarked: !catchItem.bookmarked
            )
            onChanged()
            Task { await syncCoordinator.sync(ownerID: catchItem.ownerID) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func prepareShare() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        let content = CatchShareContent(catchItem: catchItem)
        let photoURL = photos.first.flatMap(photoRepository.fileURL(for:))
        Task {
            defer { isPreparingShare = false }
            do {
                let data = try await CatchShareRenderer().render(content: content, photoURL: photoURL)
                shareArtifact = try await Task.detached(priority: .userInitiated) {
                    try shareStore.create(data: data)
                }.value
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func cleanupShareArtifact() {
        guard let artifact = shareArtifact else { return }
        shareStore.remove(artifact)
        shareArtifact = nil
    }

    private func reloadPhotos() {
        do {
            photos = try photoRepository.photos(catchID: catchItem.id, ownerID: catchItem.ownerID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func reloadTackleItem() {
        do {
            tackleItem = try catchItem.tackleItemID.flatMap {
                try tackleRepository.item(id: $0, ownerID: catchItem.ownerID)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension CatchDetailView {
    private var conditionsDetails: some View {
        DetailSection(title: "Conditions") {
            LazyVGrid(columns: detailColumns, spacing: 11) {
                DetailTile(
                    label: "Air temperature",
                    value: catchItem.conditions.airTemperatureF.map(CatchFormatting.temperature),
                    systemImage: catchItem.conditions.skyCondition?.systemImage ?? "thermometer.medium"
                )
                .accessibilityIdentifier("detail.air-temperature")
                DetailTile(
                    label: "Sky",
                    value: catchItem.conditions.skyCondition?.label,
                    systemImage: catchItem.conditions.skyCondition?.systemImage ?? "cloud"
                )
                .accessibilityIdentifier("detail.sky-condition")
                DetailTile(
                    label: "Water temperature",
                    value: catchItem.conditions.waterTemperatureF.map(CatchFormatting.temperature),
                    systemImage: "water.waves.and.thermometer"
                )
                .accessibilityIdentifier("detail.water-temperature")
                DetailTile(
                    label: "Water clarity",
                    value: catchItem.conditions.waterClarity?.label,
                    systemImage: "drop.fill"
                )
                .accessibilityIdentifier("detail.water-clarity")
            }
        }
    }
}

private struct DetailCatchLocationMap: View {
    let catchItem: CatchItem
    let onShowOnMap: () -> Void

    var body: some View {
        DetailSection(title: "Where it happened") {
            if let coordinate = catchItem.coordinate {
                ZStack(alignment: .bottom) {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: coordinate.mapCoordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
                    ))) {
                        Marker(catchItem.species, coordinate: coordinate.mapCoordinate)
                            .tint(ReelTheme.accent)
                    }
                    .mapStyle(.standard(
                        elevation: .flat,
                        emphasis: .muted,
                        pointsOfInterest: .excludingAll
                    ))
                    .allowsHitTesting(false)
                    Button(action: onShowOnMap) { mapCaption }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show \(catchItem.species) location on Catch Map")
                        .accessibilityIdentifier("detail.show-on-map")
                }
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).stroke(ReelTheme.border) }
            } else {
                Label("Location not pinned", systemImage: "mappin.slash")
                    .font(ReelFont.body(.subheadline, weight: .semibold))
                    .foregroundStyle(ReelTheme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
                    .padding(.horizontal, 16)
                    .background(ReelTheme.surface, in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityIdentifier("detail.location-missing")
            }
        }
    }

    private var mapCaption: some View {
        HStack {
            Label(catchItem.location ?? "Unnamed catch location", systemImage: "map.fill")
                .lineLimit(1)
            Spacer()
            Image(systemName: "arrow.up.right")
        }
        .font(ReelFont.body(.caption, weight: .semibold))
        .foregroundStyle(.white)
        .frame(minHeight: 52)
        .padding(12)
        .background(.ultraThinMaterial)
    }
}
