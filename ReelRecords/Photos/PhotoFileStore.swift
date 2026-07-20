import Foundation
import ImageIO
import UniformTypeIdentifiers

enum PhotoFileStoreError: LocalizedError, Equatable {
    case invalidImage
    case encodingFailed
    case missingDraft(UUID)
    case missingCommittedFile(UUID)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "That image could not be opened. Choose another photo."
        case .encodingFailed:
            "The photo could not be prepared for offline storage."
        case let .missingDraft(id):
            "Draft photo \(id.uuidString) is no longer available."
        case let .missingCommittedFile(id):
            "Local photo \(id.uuidString) is missing and must be downloaded again."
        }
    }
}

struct NormalizedPhoto: Equatable, Sendable {
    let data: Data
    let pixelWidth: Int
    let pixelHeight: Int
}

enum PhotoImageNormalizer {
    static let maximumDimension = 2048
    static let jpegQuality = 0.82

    static func normalize(_ sourceData: Data) throws -> NormalizedPhoto {
        guard let source = CGImageSourceCreateWithData(sourceData as CFData, nil) else {
            throw PhotoFileStoreError.invalidImage
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            throw PhotoFileStoreError.invalidImage
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw PhotoFileStoreError.encodingFailed
        }
        let outputProperties = [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary
        CGImageDestinationAddImage(destination, image, outputProperties)
        guard CGImageDestinationFinalize(destination) else {
            throw PhotoFileStoreError.encodingFailed
        }
        return NormalizedPhoto(
            data: data as Data,
            pixelWidth: image.width,
            pixelHeight: image.height
        )
    }
}

struct CommittedDraft: Sendable {
    let draft: DraftPhoto
    let relativePath: String
    let didMove: Bool
}

final class PhotoFileStore: @unchecked Sendable {
    let rootURL: URL
    private let fileManager: FileManager

    init(rootURL: URL? = nil, fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let applicationSupport = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            self.rootURL = applicationSupport
                .appendingPathComponent("ReelRecords", isDirectory: true)
                .appendingPathComponent("Photos", isDirectory: true)
        }
        try fileManager.createDirectory(at: self.rootURL, withIntermediateDirectories: true)
    }

    static func remoteStoragePath(ownerID: UUID, parentID: UUID, photoID: UUID) -> String {
        "\(ownerID.uuidString.lowercased())/\(parentID.uuidString.lowercased())/\(photoID.uuidString.lowercased()).jpg"
    }

    func stageNormalizedAsync(data: Data, sessionID: UUID) async throws -> DraftPhoto {
        try await Task.detached(priority: .userInitiated) { [self] in
            let normalized = try PhotoImageNormalizer.normalize(data)
            return try stage(normalized.data, sessionID: sessionID)
        }.value
    }

    func stage(_ data: Data, sessionID: UUID, photoID: UUID = UUID()) throws -> DraftPhoto {
        let relativePath = "Drafts/\(sessionID.uuidString.lowercased())/\(photoID.uuidString.lowercased()).jpg"
        let destination = url(for: relativePath)
        try ensureParentDirectory(for: destination)
        try data.write(to: destination, options: .atomic)
        return DraftPhoto(id: photoID, sessionID: sessionID, relativePath: relativePath)
    }

    func commit(_ draft: DraftPhoto, ownerID: UUID, catchID: UUID) throws -> CommittedDraft {
        let relativePath = committedRelativePath(ownerID: ownerID, catchID: catchID, photoID: draft.id)
        return try commit(draft, to: relativePath)
    }

    func commitTackle(_ draft: DraftPhoto, ownerID: UUID, itemID: UUID) throws -> CommittedDraft {
        let relativePath = tackleRelativePath(ownerID: ownerID, itemID: itemID, photoID: draft.id)
        return try commit(draft, to: relativePath)
    }

    private func commit(_ draft: DraftPhoto, to relativePath: String) throws -> CommittedDraft {
        let source = url(for: draft.relativePath)
        let destination = url(for: relativePath)
        if fileManager.fileExists(atPath: source.path) {
            try ensureParentDirectory(for: destination)
            if fileManager.fileExists(atPath: destination.path) {
                return CommittedDraft(draft: draft, relativePath: relativePath, didMove: false)
            }
            try fileManager.moveItem(at: source, to: destination)
            return CommittedDraft(draft: draft, relativePath: relativePath, didMove: true)
        }
        guard fileManager.fileExists(atPath: destination.path) else {
            throw PhotoFileStoreError.missingDraft(draft.id)
        }
        return CommittedDraft(draft: draft, relativePath: relativePath, didMove: false)
    }

    func commit(
        _ drafts: [DraftPhoto],
        ownerID: UUID,
        catchID: UUID
    ) throws -> [CommittedDraft] {
        var committed: [CommittedDraft] = []
        do {
            for draft in drafts {
                try committed.append(commit(draft, ownerID: ownerID, catchID: catchID))
            }
            return committed
        } catch {
            try? rollback(committed)
            throw error
        }
    }

    func rollback(_ committed: [CommittedDraft]) throws {
        for item in committed.reversed() where item.didMove {
            let source = url(for: item.relativePath)
            let destination = url(for: item.draft.relativePath)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            try ensureParentDirectory(for: destination)
            try fileManager.moveItem(at: source, to: destination)
        }
    }

    func storeDownloaded(_ data: Data, ownerID: UUID, catchID: UUID, photoID: UUID) throws -> String {
        let relativePath = committedRelativePath(ownerID: ownerID, catchID: catchID, photoID: photoID)
        return try storeDownloaded(data, relativePath: relativePath)
    }

    func storeDownloadedTackle(_ data: Data, ownerID: UUID, itemID: UUID, photoID: UUID) throws -> String {
        let relativePath = tackleRelativePath(ownerID: ownerID, itemID: itemID, photoID: photoID)
        return try storeDownloaded(data, relativePath: relativePath)
    }

    private func storeDownloaded(_ data: Data, relativePath: String) throws -> String {
        let destination = url(for: relativePath)
        try ensureParentDirectory(for: destination)
        try data.write(to: destination, options: .atomic)
        return relativePath
    }

    func data(relativePath: String, photoID: UUID) throws -> Data {
        let source = url(for: relativePath)
        guard fileManager.fileExists(atPath: source.path) else {
            throw PhotoFileStoreError.missingCommittedFile(photoID)
        }
        return try Data(contentsOf: source, options: .mappedIfSafe)
    }

    func fileURL(relativePath: String?) -> URL? {
        guard let relativePath else { return nil }
        let candidate = url(for: relativePath)
        return fileManager.fileExists(atPath: candidate.path) ? candidate : nil
    }

    func remove(relativePath: String?) throws {
        guard let relativePath else { return }
        let target = url(for: relativePath)
        guard fileManager.fileExists(atPath: target.path) else { return }
        try fileManager.removeItem(at: target)
    }

    func discardDraftSession(_ sessionID: UUID) throws {
        let directory = rootURL
            .appendingPathComponent("Drafts", isDirectory: true)
            .appendingPathComponent(sessionID.uuidString.lowercased(), isDirectory: true)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }

    private func committedRelativePath(ownerID: UUID, catchID: UUID, photoID: UUID) -> String {
        let owner = ownerID.uuidString.lowercased()
        let catchComponent = catchID.uuidString.lowercased()
        let photo = photoID.uuidString.lowercased()
        return "Accounts/\(owner)/Catches/\(catchComponent)/\(photo).jpg"
    }

    private func tackleRelativePath(ownerID: UUID, itemID: UUID, photoID: UUID) -> String {
        let owner = ownerID.uuidString.lowercased()
        let item = itemID.uuidString.lowercased()
        let photo = photoID.uuidString.lowercased()
        return "Accounts/\(owner)/Tackle/\(item)/\(photo).jpg"
    }

    private func url(for relativePath: String) -> URL {
        rootURL.appending(path: relativePath)
    }

    private func ensureParentDirectory(for destination: URL) throws {
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }
}
