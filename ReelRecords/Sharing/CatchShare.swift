import ImageIO
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CatchShareContent: Equatable, Sendable {
    let species: String
    let weight: String?
    let length: String?
    let spot: String?
    let caughtDate: String

    init(catchItem: CatchItem, locale: Locale = .current, timeZone: TimeZone = .current) {
        species = catchItem.species
        weight = catchItem.weight.map(CatchFormatting.weight)
        length = catchItem.length.map(CatchFormatting.length)
        spot = catchItem.location

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMMM d, yyyy"
        caughtDate = formatter.string(from: catchItem.caughtAt)
    }
}

struct ShareArtifact: Identifiable, Equatable {
    let id: UUID
    let url: URL
}

enum CatchShareError: LocalizedError {
    case renderingFailed
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            "The catch image could not be rendered."
        case .encodingFailed:
            "The catch image could not be prepared for sharing."
        }
    }
}

@MainActor
struct CatchShareRenderer {
    static let pixelSize = CGSize(width: 1080, height: 1350)

    func render(content: CatchShareContent, photoURL: URL?) async throws -> Data {
        let photoImage = await Task.detached(priority: .userInitiated) {
            photoURL.flatMap { PhotoDownsampler.image(at: $0, maximumPixelSize: 1400) }
        }.value
        let photo = photoImage.map { UIImage(cgImage: $0) }
        let renderer = ImageRenderer(content: CatchShareCard(content: content, photo: photo))
        renderer.proposedSize = ProposedViewSize(Self.pixelSize)
        renderer.scale = 1
        guard let image = renderer.uiImage?.cgImage else { throw CatchShareError.renderingFailed }
        return try await Task.detached(priority: .userInitiated) {
            try ShareJPEGEncoder.encode(image)
        }.value
    }
}

private enum ShareJPEGEncoder {
    static func encode(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { throw CatchShareError.encodingFailed }
        let properties = [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        guard CGImageDestinationFinalize(destination) else { throw CatchShareError.encodingFailed }
        return data as Data
    }
}

struct TemporaryShareStore: @unchecked Sendable {
    static let maximumAge: TimeInterval = 24 * 60 * 60

    let directory: URL
    private let fileManager: FileManager

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.temporaryDirectory
            .appendingPathComponent("ReelRecords", isDirectory: true)
            .appendingPathComponent("Share", isDirectory: true)
    }

    func create(data: Data, now: Date = .now) throws -> ShareArtifact {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try pruneStaleFiles(now: now)
        let id = UUID()
        let url = directory.appendingPathComponent("catch-\(id.uuidString.lowercased()).jpg")
        try data.write(to: url, options: .atomic)
        return ShareArtifact(id: id, url: url)
    }

    func remove(_ artifact: ShareArtifact) {
        try? fileManager.removeItem(at: artifact.url)
    }

    func pruneStaleFiles(now: Date = .now) throws {
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for url in urls {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  now.timeIntervalSince(modifiedAt) > Self.maximumAge
            else { continue }
            try fileManager.removeItem(at: url)
        }
    }
}

struct CatchActivityView: UIViewControllerRepresentable {
    let artifact: ShareArtifact
    let onCompletion: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [artifact.url],
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { _, _, _, _ in
            context.coordinator.complete()
        }
        return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}

    final class Coordinator {
        private var hasCompleted = false
        private let onCompletion: () -> Void

        init(onCompletion: @escaping () -> Void) {
            self.onCompletion = onCompletion
        }

        func complete() {
            guard !hasCompleted else { return }
            hasCompleted = true
            onCompletion()
        }
    }
}

struct CatchDetailShareActions: View {
    let isBookmarked: Bool
    let isPreparingShare: Bool
    let onToggleBookmark: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onToggleBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(isBookmarked ? ReelTheme.accent : .white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
            }
            .accessibilityLabel(isBookmarked ? "Remove from Saved" : "Save catch")
            .accessibilityIdentifier("detail.bookmark")

            Button(action: onShare) {
                Group {
                    if isPreparingShare {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
            }
            .disabled(isPreparingShare)
            .accessibilityLabel("Share catch image")
            .accessibilityIdentifier("detail.share")
        }
        .padding(16)
    }
}

private struct CatchShareCard: View {
    let content: CatchShareContent
    let photo: UIImage?

    var body: some View {
        ZStack {
            ReelTheme.page
            VStack(spacing: 0) {
                hero
                    .frame(height: 810)
                    .clipped()
                metadata
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: CatchShareRenderer.pixelSize.width, height: CatchShareRenderer.pixelSize.height)
    }

    private var hero: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 20 / 255, green: 51 / 255, blue: 36 / 255), ReelTheme.page],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Image(systemName: "fish.fill")
                    .font(.system(size: 210, weight: .bold))
                    .foregroundStyle(ReelTheme.accent.opacity(0.45))
            }
            LinearGradient(
                colors: [.clear, ReelTheme.page.opacity(0.92)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 16) {
                Image(systemName: "fish.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(ReelTheme.accent)
                Text("REEL RECORDS")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .tracking(4)
                    .foregroundStyle(ReelTheme.accentHighlight)
            }

            Text(content.species)
                .font(.system(size: 76, weight: .heavy, design: .rounded))
                .tracking(-2)
                .foregroundStyle(ReelTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.62)

            HStack(spacing: 18) {
                metric(content.weight ?? "Weight not recorded", systemImage: "trophy.fill")
                metric(content.length ?? "Length not recorded", systemImage: "ruler")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 28) { contextLabels }
                VStack(alignment: .leading, spacing: 14) { contextLabels }
            }
            .font(.system(size: 26, weight: .semibold, design: .rounded))
            .foregroundStyle(ReelTheme.secondaryText)
        }
        .padding(.horizontal, 64)
        .padding(.top, 34)
        .padding(.bottom, 50)
        .background(ReelTheme.page)
    }

    private func metric(_ value: String, systemImage: String) -> some View {
        Label(value, systemImage: systemImage)
            .font(.system(size: 30, weight: .bold, design: .monospaced))
            .foregroundStyle(ReelTheme.primaryText)
            .padding(.horizontal, 24)
            .frame(minHeight: 66)
            .background(ReelTheme.surface, in: Capsule())
    }

    @ViewBuilder
    private var contextLabels: some View {
        Label(content.spot ?? "Spot not recorded", systemImage: "location.fill")
            .lineLimit(2)
        Label(content.caughtDate, systemImage: "calendar")
            .lineLimit(1)
    }
}
