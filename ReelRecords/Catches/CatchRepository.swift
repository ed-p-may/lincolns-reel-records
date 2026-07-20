import Foundation
import Observation
import SwiftData

enum CatchRepositoryError: LocalizedError, Equatable {
    case missingCatch(UUID)
    case missingOutboxOperation(UUID)
    case deletedCatch(UUID)

    var errorDescription: String? {
        switch self {
        case let .missingCatch(id):
            "The sync queue references missing catch \(id.uuidString)."
        case let .missingOutboxOperation(id):
            "The sync queue operation \(id.uuidString) is missing."
        case let .deletedCatch(id):
            "Catch \(id.uuidString) has already been deleted."
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
            predicate: #Predicate { $0.ownerID == ownerID && $0.deletedAt == nil },
            sortBy: [SortDescriptor(\CatchRecord.caughtAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(\.item)
    }

    func item(id: UUID, ownerID: UUID) throws -> CatchItem? {
        try record(id: id, ownerID: ownerID)?.item
    }

    @discardableResult
    func create(_ newCatch: NewCatch) throws -> CatchItem {
        let values = try validated(newCatch.values)
        let now = Date.now
        let record = CatchRecord(
            ownerID: newCatch.ownerID,
            species: values.species,
            weight: values.weight,
            length: values.length,
            caughtAt: values.caughtAt,
            location: values.location,
            coordinate: values.coordinate,
            conditions: values.conditions,
            tackleItemID: values.tackleItemID,
            lureText: values.lureText,
            rodReel: values.rodReel,
            notes: values.notes,
            released: values.released,
            bookmarked: values.bookmarked,
            createdAt: now,
            updatedAt: now
        )
        let operation = OutboxOperation(ownerID: newCatch.ownerID, catchID: record.id)
        modelContext.insert(record)
        modelContext.insert(operation)
        try modelContext.save()
        return record.item
    }

    @discardableResult
    func setBookmarked(id: UUID, ownerID: UUID, bookmarked: Bool) throws -> CatchItem {
        guard let record = try record(id: id, ownerID: ownerID) else {
            throw CatchRepositoryError.missingCatch(id)
        }
        var values = record.values
        values.bookmarked = bookmarked
        return try update(record: record, ownerID: ownerID, proposedValues: values)
    }

    @discardableResult
    func update(id: UUID, ownerID: UUID, values proposedValues: CatchValues) throws -> CatchItem {
        guard let record = try record(id: id, ownerID: ownerID) else {
            throw CatchRepositoryError.missingCatch(id)
        }
        return try update(record: record, ownerID: ownerID, proposedValues: proposedValues)
    }

    private func update(
        record: CatchRecord,
        ownerID: UUID,
        proposedValues: CatchValues
    ) throws -> CatchItem {
        let id = record.id
        guard record.deletedAt == nil else { throw CatchRepositoryError.deletedCatch(id) }

        let values = try validated(proposedValues)
        guard values != record.values else { return record.item }
        apply(values, to: record)
        record.updatedAt = .now
        record.syncState = .pending
        record.syncError = nil

        if let operation = try operation(catchID: id, ownerID: ownerID) {
            guard operation.mutationKind != .delete else { throw CatchRepositoryError.deletedCatch(id) }
            operation.requiresUserConfirmation = false
            operation.lastError = nil
        } else {
            modelContext.insert(OutboxOperation(
                ownerID: ownerID,
                catchID: id,
                mutationKind: .update,
                baseVersion: record.remoteVersion
            ))
        }

        try modelContext.save()
        return record.item
    }

    func delete(id: UUID, ownerID: UUID) throws {
        guard let record = try record(id: id, ownerID: ownerID) else {
            throw CatchRepositoryError.missingCatch(id)
        }
        guard record.deletedAt == nil else { return }

        let existingOperation = try operation(catchID: id, ownerID: ownerID)
        if let existingOperation, existingOperation.mutationKind == .create {
            modelContext.delete(existingOperation)
            modelContext.delete(record)
            try modelContext.save()
            return
        }

        let deleteOperation: OutboxOperation
        if let existingOperation {
            deleteOperation = existingOperation
        } else {
            deleteOperation = OutboxOperation(
                ownerID: ownerID,
                catchID: id,
                mutationKind: .delete,
                baseVersion: record.remoteVersion
            )
            modelContext.insert(deleteOperation)
        }
        deleteOperation.mutationKind = .delete
        deleteOperation.requiresUserConfirmation = false
        deleteOperation.lastError = nil
        record.deletedAt = .now
        record.updatedAt = .now
        record.syncState = .pending
        record.syncError = nil
        try modelContext.save()
    }

    func pendingCount(ownerID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func pendingMutations(
        ownerID: UUID,
        confirmingConflicts: Bool = false,
        blockedTackleItemIDs: Set<UUID> = []
    ) throws -> [PendingCatchMutation] {
        let operations = try outboxOperations(ownerID: ownerID).filter {
            confirmingConflicts || !$0.requiresUserConfirmation
        }
        guard !operations.isEmpty else { return [] }
        let recordsByID = try Dictionary(uniqueKeysWithValues: catchRecords(ownerID: ownerID).map { ($0.id, $0) })

        var didConfirmConflict = false
        var mutations: [PendingCatchMutation] = []
        for operation in operations {
            guard let record = recordsByID[operation.catchID] else {
                throw CatchRepositoryError.missingCatch(operation.catchID)
            }
            if let tackleItemID = record.tackleItemID, blockedTackleItemIDs.contains(tackleItemID) {
                continue
            }
            if operation.requiresUserConfirmation {
                operation.requiresUserConfirmation = false
                operation.lastError = nil
                record.updatedAt = .now
                record.syncState = .pending
                record.syncError = nil
                didConfirmConflict = true
            }
            let version = operation.mutationKind == .create ? 1 : operation.baseVersion + 1
            mutations.append(PendingCatchMutation(
                operationID: operation.id,
                kind: operation.mutationKind,
                expectedVersion: operation.baseVersion,
                catchItem: record.remoteValue(version: version)
            ))
        }
        if didConfirmConflict {
            try modelContext.save()
        }
        return mutations
    }

    func markSyncing(_ mutation: PendingCatchMutation) throws {
        let state = try localState(for: mutation)
        state.record.syncState = .syncing
        state.record.syncError = nil
        state.operation.attemptCount += 1
        state.operation.lastAttemptAt = .now
        state.operation.lastError = nil
        try modelContext.save()
    }

    func markApplied(_ mutation: PendingCatchMutation, remote: RemoteCatch) throws {
        let state = try localState(for: mutation)
        apply(remote, to: state.record)
        state.record.syncState = .synced
        state.record.syncError = nil
        modelContext.delete(state.operation)
        try modelContext.save()
    }

    func markFailed(_ mutation: PendingCatchMutation, error: Error) throws {
        let message = error.localizedDescription
        let state = try localState(for: mutation)
        state.record.syncState = .failed
        state.record.syncError = message
        state.operation.lastError = message
        try modelContext.save()
    }

    func markConflict(_ mutation: PendingCatchMutation, remote: RemoteCatch?) throws {
        let message = "This catch changed on another device. Retry sync to keep this device's version."
        let state = try localState(for: mutation)
        if let remote {
            state.operation.baseVersion = remote.version
        }
        state.operation.requiresUserConfirmation = true
        state.operation.lastError = message
        state.record.syncState = .conflict
        state.record.syncError = message
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
                guard !pendingIDs.contains(local.id), local.remoteVersion < remoteCatch.version else { continue }
                apply(remoteCatch, to: local)
                local.syncState = .synced
                local.syncError = nil
                didChange = true
            } else {
                let record = record(from: remoteCatch)
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
}

private extension SwiftDataCatchRepository {
    func validated(_ proposedValues: CatchValues) throws -> CatchValues {
        let species = proposedValues.species.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !species.isEmpty else { throw CatchValidationError.speciesRequired }
        if let weight = proposedValues.weight, !weight.isFinite || weight < 0 {
            throw CatchValidationError.invalidWeight
        }
        if let length = proposedValues.length, !length.isFinite || length < 0 {
            throw CatchValidationError.invalidLength
        }
        guard proposedValues.conditions.airTemperatureF?.isFinite != false,
              proposedValues.conditions.waterTemperatureF?.isFinite != false
        else { throw CatchValidationError.invalidTemperature }
        return CatchValues(
            species: species,
            weight: proposedValues.weight,
            length: proposedValues.length,
            caughtAt: proposedValues.caughtAt,
            location: normalized(proposedValues.location),
            coordinate: proposedValues.coordinate,
            conditions: proposedValues.conditions,
            tackleItemID: proposedValues.tackleItemID,
            lureText: normalized(proposedValues.lureText),
            rodReel: normalized(proposedValues.rodReel),
            notes: normalized(proposedValues.notes),
            released: proposedValues.released,
            bookmarked: proposedValues.bookmarked
        )
    }

    func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    func apply(_ values: CatchValues, to record: CatchRecord) {
        record.species = values.species
        record.weight = values.weight
        record.length = values.length
        record.caughtAt = values.caughtAt
        record.location = values.location
        record.latitude = values.coordinate?.latitude
        record.longitude = values.coordinate?.longitude
        record.airTemperatureF = values.conditions.airTemperatureF
        record.skyConditionRaw = values.conditions.skyCondition?.storageValue
        record.waterTemperatureF = values.conditions.waterTemperatureF
        record.waterClarityRaw = values.conditions.waterClarity?.storageValue
        record.tackleItemID = values.tackleItemID
        record.lureText = values.lureText
        record.rodReel = values.rodReel
        record.notes = values.notes
        record.released = values.released
        record.bookmarked = values.bookmarked
    }

    func apply(_ remote: RemoteCatch, to record: CatchRecord) {
        apply(remote.values, to: record)
        record.createdAt = remote.createdAt
        record.updatedAt = remote.updatedAt
        record.deletedAt = remote.deletedAt
        record.remoteVersion = remote.version
    }

    func record(from remote: RemoteCatch) -> CatchRecord {
        let record = CatchRecord(
            id: remote.id,
            ownerID: remote.ownerID,
            species: remote.values.species,
            caughtAt: remote.values.caughtAt,
            bookmarked: remote.values.bookmarked,
            syncState: .synced
        )
        apply(remote, to: record)
        return record
    }

    func record(id: UUID, ownerID: UUID) throws -> CatchRecord? {
        let descriptor = FetchDescriptor<CatchRecord>(
            predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func operation(catchID: UUID, ownerID: UUID) throws -> OutboxOperation? {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.catchID == catchID && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func operation(id: UUID, ownerID: UUID) throws -> OutboxOperation? {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func catchRecords(ownerID: UUID) throws -> [CatchRecord] {
        let descriptor = FetchDescriptor<CatchRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor)
    }

    func outboxOperations(ownerID: UUID) throws -> [OutboxOperation] {
        let descriptor = FetchDescriptor<OutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\OutboxOperation.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    func localState(for mutation: PendingCatchMutation) throws -> PendingLocalState {
        let ownerID = mutation.catchItem.ownerID
        guard let record = try record(id: mutation.catchItem.id, ownerID: ownerID) else {
            throw CatchRepositoryError.missingCatch(mutation.catchItem.id)
        }
        guard let operation = try operation(id: mutation.operationID, ownerID: ownerID) else {
            throw CatchRepositoryError.missingOutboxOperation(mutation.operationID)
        }
        return PendingLocalState(record: record, operation: operation)
    }
}
