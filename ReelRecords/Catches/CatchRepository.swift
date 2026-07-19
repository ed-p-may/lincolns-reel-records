import Foundation
import Observation
import SwiftData

enum CatchRepositoryError: LocalizedError, Equatable {
    case missingCatch(UUID)
    case missingOutboxOperation(UUID)

    var errorDescription: String? {
        switch self {
        case let .missingCatch(id):
            "The sync queue references missing catch \(id.uuidString)."
        case let .missingOutboxOperation(id):
            "The sync queue operation \(id.uuidString) is missing."
        }
    }
}

private struct PendingLocalState {
    let record: CatchRecord
    let operation: OutboxOperation
}

@MainActor
@Observable
final class SwiftDataCatchRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func list(ownerID: UUID) throws -> [CatchItem] {
        let descriptor = FetchDescriptor<CatchRecord>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\CatchRecord.caughtAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.item)
    }

    @discardableResult
    func create(_ newCatch: NewCatch) throws -> CatchItem {
        let species = newCatch.species.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !species.isEmpty else { throw CatchValidationError.speciesRequired }

        let now = Date.now
        let record = CatchRecord(
            ownerID: newCatch.ownerID,
            species: species,
            caughtAt: newCatch.caughtAt,
            createdAt: now,
            updatedAt: now
        )
        let operation = OutboxOperation(ownerID: newCatch.ownerID, catchID: record.id)
        modelContext.insert(record)
        modelContext.insert(operation)
        try modelContext.save()
        return record.item
    }

    func pendingCount(ownerID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func pendingCreates(ownerID: UUID) throws -> [PendingCatch] {
        let recordsByID = try Dictionary(uniqueKeysWithValues: catchRecords(ownerID: ownerID).map { ($0.id, $0) })
        return try outboxOperations(ownerID: ownerID).map { operation in
            guard let record = recordsByID[operation.catchID] else {
                throw CatchRepositoryError.missingCatch(operation.catchID)
            }
            return PendingCatch(operationID: operation.id, catchItem: record.remoteValue)
        }
    }

    func markSyncing(_ pendingCatches: [PendingCatch]) throws {
        let localState = try localState(for: pendingCatches)
        for state in localState {
            state.record.syncState = .syncing
            state.record.syncError = nil
            state.operation.attemptCount += 1
            state.operation.lastAttemptAt = .now
            state.operation.lastError = nil
        }
        try modelContext.save()
    }

    func markSynced(_ pendingCatches: [PendingCatch]) throws {
        let localState = try localState(for: pendingCatches)
        for state in localState {
            state.record.syncState = .synced
            state.record.syncError = nil
            modelContext.delete(state.operation)
        }
        try modelContext.save()
    }

    func markFailed(_ pendingCatches: [PendingCatch], error: Error) throws {
        let message = error.localizedDescription
        let localState = try localState(for: pendingCatches)
        for state in localState {
            state.record.syncState = .failed
            state.record.syncError = message
            state.operation.lastError = message
        }
        try modelContext.save()
    }

    @discardableResult
    func merge(_ remoteCatches: [RemoteCatch], ownerID: UUID) throws -> Bool {
        let localRecords = try catchRecords(ownerID: ownerID)
        var recordsByID = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.id, $0) })
        let pendingIDs = try Set(outboxOperations(ownerID: ownerID).map(\.catchID))
        if let missingID = pendingIDs.first(where: { recordsByID[$0] == nil }) {
            throw CatchRepositoryError.missingCatch(missingID)
        }

        var didChange = false
        for remoteCatch in remoteCatches where remoteCatch.ownerID == ownerID {
            if let local = recordsByID[remoteCatch.id] {
                guard !pendingIDs.contains(local.id) else { continue }
                guard
                    local.species != remoteCatch.species
                    || local.caughtAt != remoteCatch.caughtAt
                    || local.createdAt != remoteCatch.createdAt
                    || local.updatedAt != remoteCatch.updatedAt
                    || local.syncState != .synced
                    || local.syncError != nil
                else { continue }

                local.species = remoteCatch.species
                local.caughtAt = remoteCatch.caughtAt
                local.createdAt = remoteCatch.createdAt
                local.updatedAt = remoteCatch.updatedAt
                local.syncState = .synced
                local.syncError = nil
                didChange = true
            } else {
                let record = CatchRecord(
                    id: remoteCatch.id,
                    ownerID: remoteCatch.ownerID,
                    species: remoteCatch.species,
                    caughtAt: remoteCatch.caughtAt,
                    createdAt: remoteCatch.createdAt,
                    updatedAt: remoteCatch.updatedAt,
                    syncState: .synced
                )
                modelContext.insert(record)
                recordsByID[record.id] = record
                didChange = true
            }
        }

        if didChange {
            try modelContext.save()
        }
        return didChange
    }

    private func catchRecords(ownerID: UUID) throws -> [CatchRecord] {
        let descriptor = FetchDescriptor<CatchRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor)
    }

    private func outboxOperations(ownerID: UUID) throws -> [OutboxOperation] {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\OutboxOperation.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    private func localState(
        for pendingCatches: [PendingCatch]
    ) throws -> [PendingLocalState] {
        guard let ownerID = pendingCatches.first?.catchItem.ownerID else { return [] }

        let recordsByID = try Dictionary(uniqueKeysWithValues: catchRecords(ownerID: ownerID).map { ($0.id, $0) })
        let operationsByID = try Dictionary(
            uniqueKeysWithValues: outboxOperations(ownerID: ownerID).map { ($0.id, $0) }
        )

        return try pendingCatches.map { pendingCatch in
            guard let record = recordsByID[pendingCatch.catchItem.id] else {
                throw CatchRepositoryError.missingCatch(pendingCatch.catchItem.id)
            }
            guard let operation = operationsByID[pendingCatch.operationID] else {
                throw CatchRepositoryError.missingOutboxOperation(pendingCatch.operationID)
            }
            return PendingLocalState(record: record, operation: operation)
        }
    }
}
