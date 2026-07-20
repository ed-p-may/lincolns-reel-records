import Foundation
import SwiftData

enum TackleItemType: String, Codable, CaseIterable, Identifiable, Sendable {
    case softPlastic = "soft_plastic"
    case crankbait
    case spinnerbait
    case jig
    case topwater
    case spoon
    case fly
    case liveBait = "live_bait"
    case other

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .softPlastic: "Soft Plastic"
        case .crankbait: "Crankbait"
        case .spinnerbait: "Spinnerbait"
        case .jig: "Jig"
        case .topwater: "Topwater"
        case .spoon: "Spoon"
        case .fly: "Fly"
        case .liveBait: "Live Bait"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .softPlastic, .liveBait: "water.waves"
        case .crankbait, .topwater: "fish.fill"
        case .spinnerbait: "fanblades.fill"
        case .jig: "arrow.down.to.line.compact"
        case .spoon: "oval.fill"
        case .fly: "ant.fill"
        case .other: "shippingbox.fill"
        }
    }
}

enum TackleMutationKind: String, Codable, Sendable {
    case create
    case update
    case delete
}

enum TackleOutboxStage: String, Codable, Sendable {
    case uploadBinary
    case upsertMetadata
    case removeObsoleteBinaries
}

@Model
final class TackleItemRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var name: String
    var typeRaw: String
    var size: String?
    var color: String?
    var brand: String?
    var photoID: UUID?
    var photoStoragePath: String?
    var photoLocalRelativePath: String?
    var archived: Bool = false
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var remoteVersion: Int64 = 0
    var syncStateRaw: String
    var syncError: String?

    var type: TackleItemType {
        get { TackleItemType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    var syncState: CatchSyncState {
        get { CatchSyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        values: TackleValues,
        photoID: UUID? = nil,
        photoStoragePath: String? = nil,
        photoLocalRelativePath: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        remoteVersion: Int64 = 0,
        syncState: CatchSyncState = .pending,
        syncError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        name = values.name
        typeRaw = values.type.rawValue
        size = values.size
        color = values.color
        brand = values.brand
        self.photoID = photoID
        self.photoStoragePath = photoStoragePath
        self.photoLocalRelativePath = photoLocalRelativePath
        archived = values.archived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.remoteVersion = remoteVersion
        syncStateRaw = syncState.rawValue
        self.syncError = syncError
    }
}

@Model
final class TackleOutboxOperation {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var itemID: UUID
    var mutationKindRaw: String
    var stageRaw: String
    var baseVersion: Int64
    var requiresUserConfirmation: Bool
    var obsoleteStoragePathsRaw: String
    var createdAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var lastError: String?

    var mutationKind: TackleMutationKind {
        get { TackleMutationKind(rawValue: mutationKindRaw) ?? .create }
        set { mutationKindRaw = newValue.rawValue }
    }

    var stage: TackleOutboxStage {
        get { TackleOutboxStage(rawValue: stageRaw) ?? .upsertMetadata }
        set { stageRaw = newValue.rawValue }
    }

    var obsoleteStoragePaths: [String] {
        get { obsoleteStoragePathsRaw.split(separator: "\n").map(String.init) }
        set { obsoleteStoragePathsRaw = Array(Set(newValue)).sorted().joined(separator: "\n") }
    }

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        itemID: UUID,
        mutationKind: TackleMutationKind,
        stage: TackleOutboxStage,
        baseVersion: Int64 = 0,
        requiresUserConfirmation: Bool = false,
        obsoleteStoragePaths: [String] = [],
        createdAt: Date = .now,
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.itemID = itemID
        mutationKindRaw = mutationKind.rawValue
        stageRaw = stage.rawValue
        self.baseVersion = baseVersion
        self.requiresUserConfirmation = requiresUserConfirmation
        obsoleteStoragePathsRaw = Array(Set(obsoleteStoragePaths)).sorted().joined(separator: "\n")
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}

struct TackleValues: Equatable, Sendable {
    let name: String
    let type: TackleItemType
    let size: String?
    let color: String?
    let brand: String?
    let archived: Bool
}

struct TackleItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let values: TackleValues
    let photoID: UUID?
    let photoStoragePath: String?
    let photoLocalRelativePath: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let remoteVersion: Int64
    let syncState: CatchSyncState
    let syncError: String?

    var name: String {
        values.name
    }

    var type: TackleItemType {
        values.type
    }

    var size: String? {
        values.size
    }

    var color: String? {
        values.color
    }

    var brand: String? {
        values.brand
    }

    var archived: Bool {
        values.archived
    }

    var isSelectable: Bool {
        !archived && deletedAt == nil
    }
}

struct NewTackleItem: Equatable, Sendable {
    let ownerID: UUID
    let values: TackleValues
}

enum TacklePhotoChange: Equatable, Sendable {
    case keep
    case remove
    case replace(DraftPhoto)
}

struct RemoteTackleItem: Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let values: TackleValues
    let photoStoragePath: String?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64
}

struct PendingTackleMutation: Equatable, Sendable {
    let operationID: UUID
    let kind: TackleMutationKind
    let stage: TackleOutboxStage
    let expectedVersion: Int64
    let item: RemoteTackleItem
    let photoLocalRelativePath: String?
    let obsoleteStoragePaths: [String]
}

enum TackleMutationResult: Equatable, Sendable {
    case applied(RemoteTackleItem)
    case conflict(RemoteTackleItem?)
}

enum TackleValidationError: LocalizedError, Equatable {
    case nameRequired

    var errorDescription: String? {
        switch self {
        case .nameRequired: "Enter a name before saving this tackle item."
        }
    }
}

extension TackleItemRecord {
    var values: TackleValues {
        TackleValues(name: name, type: type, size: size, color: color, brand: brand, archived: archived)
    }

    var item: TackleItem {
        TackleItem(
            id: id,
            ownerID: ownerID,
            values: values,
            photoID: photoID,
            photoStoragePath: photoStoragePath,
            photoLocalRelativePath: photoLocalRelativePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            remoteVersion: remoteVersion,
            syncState: syncState,
            syncError: syncError
        )
    }

    func remoteValue(version: Int64) -> RemoteTackleItem {
        RemoteTackleItem(
            id: id,
            ownerID: ownerID,
            values: values,
            photoStoragePath: photoStoragePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            version: version
        )
    }
}

extension RemoteTackleItem {
    var photoID: UUID? {
        guard let component = photoStoragePath?.split(separator: "/").last else { return nil }
        return UUID(uuidString: component.replacingOccurrences(of: ".jpg", with: ""))
    }
}
