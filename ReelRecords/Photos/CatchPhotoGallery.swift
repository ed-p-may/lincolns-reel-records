import SwiftUI

struct CatchPhotoGalleryItem: Identifiable, Equatable {
    let photo: CatchPhotoItem
    let catchItem: CatchItem

    var id: UUID {
        photo.id
    }

    static func ordered(
        catches: [CatchItem],
        photosByCatch: [UUID: [CatchPhotoItem]]
    ) -> [CatchPhotoGalleryItem] {
        catches
            .sorted(by: CatchDiscovery.recentPrecedes)
            .flatMap { catchItem in
                photosByCatch[catchItem.id, default: []]
                    .filter { $0.ownerID == catchItem.ownerID }
                    .sorted(by: photoOrder)
                    .map { CatchPhotoGalleryItem(photo: $0, catchItem: catchItem) }
            }
    }

    private static func photoOrder(_ lhs: CatchPhotoItem, _ rhs: CatchPhotoItem) -> Bool {
        if lhs.position != rhs.position {
            return lhs.position < rhs.position
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt < rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

struct CatchPhotoViewerSelection: Identifiable {
    let selectedPhotoID: UUID
    let items: [CatchPhotoGalleryItem]

    var id: UUID {
        selectedPhotoID
    }
}

struct CatchDetailPhotoGallery: View {
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository

    let photos: [CatchPhotoItem]
    let catchItem: CatchItem
    let onOpenPhoto: (UUID) -> Void

    var body: some View {
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
                    .contentShape(Rectangle())
                    .simultaneousGesture(TapGesture().onEnded { onOpenPhoto(photo.id) })
                    .accessibilityLabel("Photo \(index + 1) of \(photos.count) for \(catchItem.species)")
                    .accessibilityHint("Opens full-screen photo viewer")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onOpenPhoto(photo.id) }
                    .accessibilityIdentifier("detail.photo.\(index)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .automatic : .never))
            .accessibilityIdentifier("detail.photo-gallery")
            .overlay(alignment: .topTrailing) { photoCount }
        }
    }

    private var photoCount: some View {
        Text("\(photos.count) PHOTO\(photos.count == 1 ? "" : "S")")
            .font(ReelFont.metadata(.caption2, weight: .bold))
            .padding(.horizontal, 9)
            .frame(minHeight: 28)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(14)
            .accessibilityIdentifier("detail.photo-count")
    }
}

struct CatchPhotoGalleryView: View {
    @Environment(SwiftDataCatchRepository.self) private var catchRepository
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @State private var items: [CatchPhotoGalleryItem] = []
    @State private var viewerSelection: CatchPhotoViewerSelection?
    @State private var loadError: String?

    let ownerID: UUID
    let refreshToken: Int

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 80), spacing: 2),
        count: 3
    )

    var body: some View {
        Group {
            if items.isEmpty, loadError == nil {
                emptyGallery
            } else {
                photoGrid
            }
        }
        .background(ReelTheme.background)
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.large)
        .task(id: refreshToken + syncCoordinator.revision) { reload() }
        .fullScreenCover(item: $viewerSelection) { selection in
            CatchPhotoViewer(selection: selection)
        }
        .alert("Unable to open photos", isPresented: errorBinding) {
            Button("Retry") { reload() }
        } message: {
            Text(loadError ?? "")
        }
    }

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(items.count) PHOTO\(items.count == 1 ? "" : "S")")
                .font(ReelFont.metadata(.caption2, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(ReelTheme.secondaryText)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .accessibilityIdentifier("gallery.count")

            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            viewerSelection = CatchPhotoViewerSelection(
                                selectedPhotoID: item.id,
                                items: items
                            )
                        } label: {
                            CatchPhotoGalleryTile(item: item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.accessibilityLabel)
                        .accessibilityHint("Opens full-screen photo viewer")
                        .accessibilityIdentifier("gallery.photo.\(index)")
                    }
                }
            }
            .accessibilityIdentifier("gallery.grid")
        }
    }

    private var emptyGallery: some View {
        ContentUnavailableView {
            Label("No catch photos yet", systemImage: "photo.on.rectangle.angled")
        } description: {
            Text("Photos added to your catches will appear here.")
        }
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
            items = try CatchPhotoGalleryItem.ordered(
                catches: catchRepository.list(ownerID: ownerID),
                photosByCatch: photoRepository.photosByCatch(ownerID: ownerID)
            )
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

struct CatchPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository
    @State private var selectedPhotoID: UUID

    let items: [CatchPhotoGalleryItem]

    init(selection: CatchPhotoViewerSelection) {
        items = selection.items
        _selectedPhotoID = State(initialValue: selection.selectedPhotoID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selectedPhotoID) {
                ForEach(items) { item in
                    LocalPhotoImage(
                        url: photoRepository.fileURL(for: item.photo),
                        maximumPixelSize: 2400,
                        contentMode: .fit,
                        placeholder: CatchPhotoPlaceholder(species: item.catchItem.species)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(item.accessibilityLabel)
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            viewerChrome
        }
        .statusBarHidden()
    }

    private var viewerChrome: some View {
        VStack {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.bold())
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .foregroundStyle(.white)
                .accessibilityLabel("Close photo viewer")
                .accessibilityIdentifier("photo.viewer.close")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            if let selectedItem {
                VStack(spacing: 5) {
                    Text(selectedItem.catchItem.species)
                        .font(ReelFont.body(.headline, weight: .bold))
                    Text(selectedItem.catchItem.caughtAt.formatted(date: .long, time: .omitted))
                        .font(ReelFont.body(.caption))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(positionLabel)
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                        .tracking(0.8)
                        .accessibilityIdentifier("photo.viewer.position")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }
        }
    }

    private var selectedItem: CatchPhotoGalleryItem? {
        items.first { $0.id == selectedPhotoID }
    }

    private var positionLabel: String {
        guard let index = items.firstIndex(where: { $0.id == selectedPhotoID }) else { return "" }
        return "\(index + 1) OF \(items.count)"
    }
}

private struct CatchPhotoGalleryTile: View {
    @Environment(SwiftDataCatchPhotoRepository.self) private var photoRepository

    let item: CatchPhotoGalleryItem

    var body: some View {
        GeometryReader { proxy in
            LocalPhotoImage(
                url: photoRepository.fileURL(for: item.photo),
                maximumPixelSize: 480,
                contentMode: .fill,
                placeholder: CatchPhotoPlaceholder(species: item.catchItem.species)
            )
            .frame(width: proxy.size.width, height: proxy.size.width)
            .clipped()
            .contentShape(Rectangle())
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

private extension CatchPhotoGalleryItem {
    var accessibilityLabel: String {
        let catchPhotoCount = "Photo \(photo.position + 1)"
        return "\(catchPhotoCount) for \(catchItem.species), "
            + catchItem.caughtAt.formatted(date: .long, time: .omitted)
    }
}
