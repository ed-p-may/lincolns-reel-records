import Foundation
import SwiftData

enum PhotoMutationKind: String, Codable, Sendable {
    case create
    case update
    case delete
}

enum PhotoOutboxStage: String, Codable, Sendable {
    case uploadBinary
    case upsertMetadata
    case deleteMetadata
    case deleteBinary
}

@Model
final class CatchPhotoRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var catchID: UUID
    var storagePath: String
    var localRelativePath: String?
    var position: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var remoteVersion: Int64
    var syncStateRaw: String
    var syncError: String?

    var syncState: CatchSyncState {
        get { CatchSyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        catchID: UUID,
        storagePath: String,
        localRelativePath: String? = nil,
        position: Int,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        remoteVersion: Int64 = 0,
        syncState: CatchSyncState = .pending,
        syncError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.catchID = catchID
        self.storagePath = storagePath
        self.localRelativePath = localRelativePath
        self.position = position
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.remoteVersion = remoteVersion
        syncStateRaw = syncState.rawValue
        self.syncError = syncError
    }
}

@Model
final class PhotoOutboxOperation {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var catchID: UUID
    var photoID: UUID
    var mutationKindRaw: String
    var stageRaw: String
    var baseVersion: Int64
    var requiresUserConfirmation: Bool
    var createdAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var lastError: String?

    var mutationKind: PhotoMutationKind {
        get { PhotoMutationKind(rawValue: mutationKindRaw) ?? .create }
        set { mutationKindRaw = newValue.rawValue }
    }

    var stage: PhotoOutboxStage {
        get { PhotoOutboxStage(rawValue: stageRaw) ?? .uploadBinary }
        set { stageRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        catchID: UUID,
        photoID: UUID,
        mutationKind: PhotoMutationKind,
        stage: PhotoOutboxStage,
        baseVersion: Int64 = 0,
        requiresUserConfirmation: Bool = false,
        createdAt: Date = .now,
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.catchID = catchID
        self.photoID = photoID
        mutationKindRaw = mutationKind.rawValue
        stageRaw = stage.rawValue
        self.baseVersion = baseVersion
        self.requiresUserConfirmation = requiresUserConfirmation
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}

struct CatchPhotoItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let catchID: UUID
    let storagePath: String
    let localRelativePath: String?
    let position: Int
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let remoteVersion: Int64
    let syncState: CatchSyncState
    let syncError: String?
}

struct DraftPhoto: Identifiable, Equatable, Sendable {
    let id: UUID
    let sessionID: UUID
    let relativePath: String
}

struct RemoteCatchPhoto: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let catchID: UUID
    let storagePath: String
    let position: Int
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64
}

struct PendingPhotoMutation: Equatable, Sendable {
    let operationID: UUID
    let kind: PhotoMutationKind
    let stage: PhotoOutboxStage
    let expectedVersion: Int64
    let photo: RemoteCatchPhoto
    let localRelativePath: String?
}

enum PhotoMutationResult: Equatable, Sendable {
    case applied(RemoteCatchPhoto)
    case conflict(RemoteCatchPhoto?)
}

extension CatchPhotoRecord {
    var item: CatchPhotoItem {
        CatchPhotoItem(
            id: id,
            ownerID: ownerID,
            catchID: catchID,
            storagePath: storagePath,
            localRelativePath: localRelativePath,
            position: position,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            remoteVersion: remoteVersion,
            syncState: syncState,
            syncError: syncError
        )
    }

    func remoteValue(version: Int64) -> RemoteCatchPhoto {
        RemoteCatchPhoto(
            id: id,
            ownerID: ownerID,
            catchID: catchID,
            storagePath: storagePath,
            position: position,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            version: version
        )
    }
}
