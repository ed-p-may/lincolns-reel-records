import ImageIO
import PhotosUI
import SwiftUI
import UIKit

struct EditableCatchPhoto: Identifiable, Equatable {
    enum Source: Equatable {
        case existing(CatchPhotoItem)
        case draft(DraftPhoto)
    }

    let source: Source
    let fileURL: URL?

    var id: UUID {
        switch source {
        case let .existing(photo): photo.id
        case let .draft(photo): photo.id
        }
    }

    var draft: DraftPhoto? {
        guard case let .draft(photo) = source else { return nil }
        return photo
    }
}

struct CatchPhotoEditor: View {
    @Environment(SwiftDataCatchPhotoRepository.self) private var repository
    @Binding var photos: [EditableCatchPhoto]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isShowingCamera = false
    @State private var isImporting = false

    let sessionID: UUID
    let onError: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PHOTOS")
                    .font(ReelFont.metadata(.caption2, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(ReelTheme.tertiaryText)
                Spacer()
                Text("\(photos.count) selected")
                    .font(ReelFont.metadata(.caption2))
                    .foregroundStyle(ReelTheme.secondaryText)
            }

            if photos.isEmpty {
                CatchPhotoPlaceholder(species: "this catch")
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .accessibilityIdentifier("photo.editor.empty")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                            PhotoEditorTile(
                                photo: photo,
                                index: index,
                                count: photos.count,
                                moveEarlier: { move(from: index, offset: -1) },
                                moveLater: { move(from: index, offset: 1) },
                                remove: { photos.remove(at: index) }
                            )
                        }
                    }
                }
                .accessibilityIdentifier("photo.editor.list")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { acquisitionButtons }
                VStack(spacing: 10) { acquisitionButtons }
            }

            Text("The first photo is the hero. Use the arrow buttons to reorder; changes save offline.")
                .font(ReelFont.body(.caption))
                .foregroundStyle(ReelTheme.secondaryText)
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await importPickerItems(items) }
        }
        .sheet(isPresented: $isShowingCamera) {
            CameraImagePicker { data in
                isShowingCamera = false
                importCameraData(data)
            } onCancel: {
                isShowingCamera = false
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var acquisitionButtons: some View {
        PhotosPicker(
            selection: $pickerItems,
            maxSelectionCount: max(1, 8 - photos.count),
            matching: .images
        ) {
            Label("Choose Photos", systemImage: "photo.on.rectangle.angled")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(isImporting || photos.count >= 8)
        .accessibilityIdentifier("photo.choose-library")

        Button {
            isShowingCamera = true
        } label: {
            Label("Take Photo", systemImage: "camera.fill")
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.bordered)
        .tint(ReelTheme.accent)
        .disabled(!isCameraAvailable || photos.count >= 8)
        .accessibilityIdentifier("photo.take-camera")
    }

    private var isCameraAvailable: Bool {
        #if targetEnvironment(simulator)
            false
        #else
            UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    private func move(from index: Int, offset: Int) {
        let destination = index + offset
        guard photos.indices.contains(index), photos.indices.contains(destination) else { return }
        photos.swapAt(index, destination)
    }

    private func importPickerItems(_ items: [PhotosPickerItem]) async {
        isImporting = true
        defer {
            isImporting = false
            pickerItems = []
        }
        for item in items where photos.count < 8 {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw PhotoFileStoreError.invalidImage
                }
                try await append(data: data)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    private func importCameraData(_ data: Data?) {
        guard let data else { return }
        Task {
            do {
                try await append(data: data)
            } catch {
                onError(error.localizedDescription)
            }
        }
    }

    private func append(data: Data) async throws {
        let draft = try await repository.stageAsync(data: data, sessionID: sessionID)
        photos.append(EditableCatchPhoto(
            source: .draft(draft),
            fileURL: repository.fileURL(for: draft)
        ))
    }
}

struct LocalPhotoImage<Placeholder: View>: View {
    @State private var image: Image?

    let url: URL?
    let maximumPixelSize: Int
    let contentMode: ContentMode
    let placeholder: Placeholder

    var body: some View {
        Group {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: url) {
            image = nil
            guard let url else {
                return
            }
            let pixelSize = maximumPixelSize
            let decoded = await Task.detached(priority: .userInitiated) {
                PhotoDownsampler.image(at: url, maximumPixelSize: pixelSize)
            }.value
            guard !Task.isCancelled else { return }
            image = decoded.map { Image(decorative: $0, scale: 1) }
        }
    }
}

private enum PhotoDownsampler {
    private final class CachedImage: NSObject, @unchecked Sendable {
        let value: CGImage

        init(_ value: CGImage) {
            self.value = value
        }
    }

    private final class ImageCache: @unchecked Sendable {
        private let storage: NSCache<NSString, CachedImage>

        init() {
            storage = NSCache<NSString, CachedImage>()
            storage.countLimit = 80
            storage.totalCostLimit = 64 * 1024 * 1024
        }

        func image(for key: NSString) -> CGImage? {
            storage.object(forKey: key)?.value
        }

        func insert(_ image: CGImage, for key: NSString) {
            storage.setObject(CachedImage(image), forKey: key, cost: image.bytesPerRow * image.height)
        }
    }

    private static let cache = ImageCache()

    static func image(at url: URL, maximumPixelSize: Int) -> CGImage? {
        let key = "\(url.path)|\(maximumPixelSize)" as NSString
        if let cached = cache.image(for: key) {
            return cached
        }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        cache.insert(image, for: key)
        return image
    }
}

private struct PhotoEditorTile: View {
    let photo: EditableCatchPhoto
    let index: Int
    let count: Int
    let moveEarlier: () -> Void
    let moveLater: () -> Void
    let remove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LocalPhotoImage(
                url: photo.fileURL,
                maximumPixelSize: 360,
                contentMode: .fill,
                placeholder: CatchPhotoPlaceholder(species: "this catch")
            )
            .frame(width: 170, height: 150)
            .clipped()

            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .foregroundStyle(.white)
            .accessibilityLabel("Remove photo \(index + 1)")
            .accessibilityIdentifier("photo.remove.\(index)")
            .padding(7)

            VStack {
                Spacer()
                HStack {
                    Button(action: moveEarlier) {
                        Image(systemName: "arrow.left")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(index == 0)
                    .accessibilityLabel("Move photo \(index + 1) earlier")
                    .accessibilityIdentifier("photo.earlier.\(index)")
                    Spacer()
                    Text(index == 0 ? "HERO" : "\(index + 1)")
                        .font(ReelFont.metadata(.caption2, weight: .bold))
                    Spacer()
                    Button(action: moveLater) {
                        Image(systemName: "arrow.right")
                            .frame(width: 44, height: 44)
                    }
                    .disabled(index == count - 1)
                    .accessibilityLabel("Move photo \(index + 1) later")
                    .accessibilityIdentifier("photo.later.\(index)")
                }
                .foregroundStyle(.white)
                .padding(9)
                .background(.ultraThinMaterial)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(ReelTheme.border) }
    }
}

private struct CameraImagePicker: UIViewControllerRepresentable {
    let onImage: (Data?) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_: UIImagePickerController, context _: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (Data?) -> Void
        let onCancel: () -> Void

        init(onImage: @escaping (Data?) -> Void, onCancel: @escaping () -> Void) {
            self.onImage = onImage
            self.onCancel = onCancel
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let image = info[.originalImage] as? UIImage
            onImage(image?.jpegData(compressionQuality: 1))
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            onCancel()
        }
    }
}
