import Foundation
import SwiftData

enum CatchSyncState: String, Codable, CaseIterable, Sendable {
    case pending
    case syncing
    case synced
    case failed
    case conflict
}

enum CatchMutationKind: String, Codable, Sendable {
    case create
    case update
    case delete
}

@Model
final class CatchRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var species: String
    var weight: Double?
    var length: Double?
    var caughtAt: Date
    var location: String?
    var lureText: String?
    var rodReel: String?
    var notes: String?
    var released: Bool = true
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var remoteVersion: Int64 = 0
    var syncStateRaw: String
    var syncError: String?

    var syncState: CatchSyncState {
        get { CatchSyncState(rawValue: syncStateRaw) ?? .pending }
        set { syncStateRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        species: String,
        weight: Double? = nil,
        length: Double? = nil,
        caughtAt: Date,
        location: String? = nil,
        lureText: String? = nil,
        rodReel: String? = nil,
        notes: String? = nil,
        released: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil,
        remoteVersion: Int64 = 0,
        syncState: CatchSyncState = .pending,
        syncError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.species = species
        self.weight = weight
        self.length = length
        self.caughtAt = caughtAt
        self.location = location
        self.lureText = lureText
        self.rodReel = rodReel
        self.notes = notes
        self.released = released
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.remoteVersion = remoteVersion
        syncStateRaw = syncState.rawValue
        self.syncError = syncError
    }
}

@Model
final class OutboxOperation {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var catchID: UUID
    var mutationKindRaw: String = CatchMutationKind.create.rawValue
    var baseVersion: Int64 = 0
    var requiresUserConfirmation: Bool = false
    var createdAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var lastError: String?

    var mutationKind: CatchMutationKind {
        get { CatchMutationKind(rawValue: mutationKindRaw) ?? .create }
        set { mutationKindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        catchID: UUID,
        mutationKind: CatchMutationKind = .create,
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
        mutationKindRaw = mutationKind.rawValue
        self.baseVersion = baseVersion
        self.requiresUserConfirmation = requiresUserConfirmation
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}

struct CatchValues: Equatable, Sendable {
    let species: String
    let weight: Double?
    let length: Double?
    let caughtAt: Date
    let location: String?
    let lureText: String?
    let rodReel: String?
    let notes: String?
    let released: Bool
}

struct CatchItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let values: CatchValues
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let remoteVersion: Int64
    let syncState: CatchSyncState
    let syncError: String?

    var species: String {
        values.species
    }

    var weight: Double? {
        values.weight
    }

    var length: Double? {
        values.length
    }

    var caughtAt: Date {
        values.caughtAt
    }

    var location: String? {
        values.location
    }

    var lureText: String? {
        values.lureText
    }

    var rodReel: String? {
        values.rodReel
    }

    var notes: String? {
        values.notes
    }

    var released: Bool {
        values.released
    }
}

struct NewCatch: Equatable, Sendable {
    let ownerID: UUID
    let values: CatchValues

    init(ownerID: UUID, species: String, caughtAt: Date) {
        self.init(ownerID: ownerID, values: CatchValues(
            species: species,
            weight: nil,
            length: nil,
            caughtAt: caughtAt,
            location: nil,
            lureText: nil,
            rodReel: nil,
            notes: nil,
            released: true
        ))
    }

    init(ownerID: UUID, values: CatchValues) {
        self.ownerID = ownerID
        self.values = values
    }
}

struct RemoteCatch: Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let values: CatchValues
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    let version: Int64
}

struct PendingCatchMutation: Equatable, Sendable {
    let operationID: UUID
    let kind: CatchMutationKind
    let expectedVersion: Int64
    let catchItem: RemoteCatch
}

enum CatchMutationResult: Equatable, Sendable {
    case applied(RemoteCatch)
    case conflict(RemoteCatch?)
}

enum CatchValidationError: LocalizedError, Equatable {
    case speciesRequired
    case invalidWeight
    case invalidLength

    var errorDescription: String? {
        switch self {
        case .speciesRequired:
            "Choose or enter a species before saving."
        case .invalidWeight:
            "Enter a valid weight of zero or more pounds."
        case .invalidLength:
            "Enter a valid length of zero or more inches."
        }
    }
}

extension CatchRecord {
    var values: CatchValues {
        CatchValues(
            species: species,
            weight: weight,
            length: length,
            caughtAt: caughtAt,
            location: location,
            lureText: lureText,
            rodReel: rodReel,
            notes: notes,
            released: released
        )
    }

    var item: CatchItem {
        CatchItem(
            id: id,
            ownerID: ownerID,
            values: values,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            remoteVersion: remoteVersion,
            syncState: syncState,
            syncError: syncError
        )
    }

    func remoteValue(version: Int64) -> RemoteCatch {
        RemoteCatch(
            id: id,
            ownerID: ownerID,
            values: values,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            version: version
        )
    }
}
