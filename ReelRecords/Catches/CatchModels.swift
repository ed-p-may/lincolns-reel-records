import Foundation
import SwiftData

enum CatchSyncState: String, Codable, CaseIterable, Sendable {
    case pending
    case syncing
    case synced
    case failed
}

@Model
final class CatchRecord {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var species: String
    var caughtAt: Date
    var createdAt: Date
    var updatedAt: Date
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
        caughtAt: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        syncState: CatchSyncState = .pending,
        syncError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.species = species
        self.caughtAt = caughtAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        syncStateRaw = syncState.rawValue
        self.syncError = syncError
    }
}

@Model
final class OutboxOperation {
    @Attribute(.unique) var id: UUID
    var ownerID: UUID
    var catchID: UUID
    var createdAt: Date
    var lastAttemptAt: Date?
    var attemptCount: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        ownerID: UUID,
        catchID: UUID,
        createdAt: Date = .now,
        lastAttemptAt: Date? = nil,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.ownerID = ownerID
        self.catchID = catchID
        self.createdAt = createdAt
        self.lastAttemptAt = lastAttemptAt
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}

struct CatchItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let species: String
    let caughtAt: Date
    let createdAt: Date
    let updatedAt: Date
    let syncState: CatchSyncState
    let syncError: String?
}

struct NewCatch: Equatable, Sendable {
    let ownerID: UUID
    let species: String
    let caughtAt: Date
}

struct RemoteCatch: Equatable, Sendable {
    let id: UUID
    let ownerID: UUID
    let species: String
    let caughtAt: Date
    let createdAt: Date
    let updatedAt: Date
}

struct PendingCatch: Sendable {
    let operationID: UUID
    let catchItem: RemoteCatch
}

enum CatchValidationError: LocalizedError, Equatable {
    case speciesRequired

    var errorDescription: String? {
        "Choose or enter a species before saving."
    }
}

extension CatchRecord {
    var item: CatchItem {
        CatchItem(
            id: id,
            ownerID: ownerID,
            species: species,
            caughtAt: caughtAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            syncState: syncState,
            syncError: syncError
        )
    }

    var remoteValue: RemoteCatch {
        RemoteCatch(
            id: id,
            ownerID: ownerID,
            species: species,
            caughtAt: caughtAt,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
