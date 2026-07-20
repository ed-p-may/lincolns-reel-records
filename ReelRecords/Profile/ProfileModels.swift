import Foundation
import SwiftData

enum ProfileOutboxStage: String, Codable, Sendable {
    case uploadBinary
    case upsertMetadata
    case removeObsoleteBinaries
}

@Model
final class ProfileRecord {
    @Attribute(.unique) var ownerID: UUID
    var username: String
    var displayName: String?
    var homeWater: String?
    var avatarID: UUID?
    var avatarStoragePath: String?
    var avatarLocalRelativePath: String?
    var anglerSince: Int?
    var createdAt: Date
    var updatedAt: Date
    var remoteVersion: Int64
    var hasRemoteSnapshot: Bool
    var syncStateRaw: String
    var syncError: String?

    var syncState: CatchSyncState {
        get { CatchSyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    init(
        ownerID: UUID,
        username: String,
        values: ProfileValues = .empty,
        avatarID: UUID? = nil,
        avatarStoragePath: String? = nil,
        avatarLocalRelativePath: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        remoteVersion: Int64 = 1,
        hasRemoteSnapshot: Bool = false,
        syncState: CatchSyncState = .synced,
        syncError: String? = nil
    ) {
        self.ownerID = ownerID
        self.username = username
        displayName = values.displayName
        homeWater = values.homeWater
        self.avatarID = avatarID
        self.avatarStoragePath = avatarStoragePath
        self.avatarLocalRelativePath = avatarLocalRelativePath
        anglerSince = values.anglerSince
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.remoteVersion = remoteVersion
        self.hasRemoteSnapshot = hasRemoteSnapshot
        syncStateRaw = syncState.rawValue
        self.syncError = syncError
    }
}

@Model
final class ProfileOutboxOperation {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var stageRaw: String
    var baseVersion: Int64
    var requiresUserConfirmation: Bool
    var obsoleteStoragePathsRaw: String
    var createdAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var lastError: String?

    var stage: ProfileOutboxStage {
        get { ProfileOutboxStage(rawValue: stageRaw) ?? .upsertMetadata }
        set { stageRaw = newValue.rawValue }
    }

    var obsoleteStoragePaths: [String] {
        get { obsoleteStoragePathsRaw.split(separator: "\n").map(String.init) }
        set { obsoleteStoragePathsRaw = Array(Set(newValue)).sorted().joined(separator: "\n") }
    }

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        stage: ProfileOutboxStage,
        baseVersion: Int64,
        requiresUserConfirmation: Bool = false,
        obsoleteStoragePaths: [String] = [],
        createdAt: Date = .now,
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
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

struct ProfileValues: Equatable, Sendable {
    let displayName: String?
    let homeWater: String?
    let anglerSince: Int?

    static let empty = ProfileValues(displayName: nil, homeWater: nil, anglerSince: nil)
}

struct UserProfile: Identifiable, Equatable, Sendable {
    var id: UUID {
        ownerID
    }

    let ownerID: UUID
    let username: String
    let values: ProfileValues
    let avatarID: UUID?
    let avatarStoragePath: String?
    let avatarLocalRelativePath: String?
    let createdAt: Date
    let updatedAt: Date
    let remoteVersion: Int64
    let syncState: CatchSyncState
    let syncError: String?

    var displayName: String {
        values.displayName ?? username
    }

    var homeWater: String? {
        values.homeWater
    }

    var anglerSince: Int? {
        values.anglerSince
    }
}

enum ProfileAvatarChange: Equatable, Sendable {
    case keep
    case remove
    case replace(DraftPhoto)
}

struct RemoteProfile: Equatable, Sendable {
    let ownerID: UUID
    let username: String
    let values: ProfileValues
    let avatarStoragePath: String?
    let createdAt: Date
    let updatedAt: Date
    let version: Int64
}

struct PendingProfileMutation: Equatable, Sendable {
    let operationID: UUID
    let stage: ProfileOutboxStage
    let expectedVersion: Int64
    let profile: RemoteProfile
    let avatarLocalRelativePath: String?
    let obsoleteStoragePaths: [String]
}

struct ProfileMergeResult: Equatable, Sendable {
    let didChange: Bool
    let missingAvatar: UserProfile?
}

enum ProfileMutationResult: Equatable, Sendable {
    case applied(RemoteProfile)
    case conflict(RemoteProfile?)
}

enum ProfileValidationError: LocalizedError, Equatable {
    case displayNameTooLong
    case homeWaterTooLong
    case invalidAnglerSince(Int)

    var errorDescription: String? {
        switch self {
        case .displayNameTooLong: "Display name must be 80 characters or fewer."
        case .homeWaterTooLong: "Home water must be 120 characters or fewer."
        case let .invalidAnglerSince(year): "Enter an angler-since year from 1900 through \(year)."
        }
    }
}

enum ProfileRepositoryError: LocalizedError, Equatable {
    case missingProfile(UUID)
    case missingOperation(UUID)
    case missingAvatar(UUID)

    var errorDescription: String? {
        switch self {
        case let .missingProfile(id): "The local profile for \(id.uuidString) is missing."
        case let .missingOperation(id): "The profile queue operation \(id.uuidString) is missing."
        case let .missingAvatar(id): "The avatar for \(id.uuidString) is missing locally."
        }
    }
}

extension ProfileRecord {
    var values: ProfileValues {
        ProfileValues(displayName: displayName, homeWater: homeWater, anglerSince: anglerSince)
    }

    var profile: UserProfile {
        UserProfile(
            ownerID: ownerID,
            username: username,
            values: values,
            avatarID: avatarID,
            avatarStoragePath: avatarStoragePath,
            avatarLocalRelativePath: avatarLocalRelativePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            remoteVersion: remoteVersion,
            syncState: syncState,
            syncError: syncError
        )
    }

    func remoteValue(version: Int64) -> RemoteProfile {
        RemoteProfile(
            ownerID: ownerID,
            username: username,
            values: values,
            avatarStoragePath: avatarStoragePath,
            createdAt: createdAt,
            updatedAt: updatedAt,
            version: version
        )
    }
}

extension RemoteProfile {
    var avatarID: UUID? {
        guard let component = avatarStoragePath?.split(separator: "/").last else { return nil }
        return UUID(uuidString: component.replacingOccurrences(of: ".jpg", with: ""))
    }
}
