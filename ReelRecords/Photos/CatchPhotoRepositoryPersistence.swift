import Foundation
import SwiftData

struct CatchPhotoOrderPlan {
    let records: [CatchPhotoRecord]
    let recordsByID: [UUID: CatchPhotoRecord]
    let committed: [CommittedDraft]
    let committedByID: [UUID: CommittedDraft]
}

extension SwiftDataCatchPhotoRepository {
    static func storagePath(ownerID: UUID, catchID: UUID, photoID: UUID) -> String {
        "\(ownerID.uuidString.lowercased())/\(catchID.uuidString.lowercased())/\(photoID.uuidString.lowercased()).jpg"
    }

    func makeOrderPlan(
        catchID: UUID,
        ownerID: UUID,
        orderedIDs: [UUID],
        drafts: [DraftPhoto]
    ) throws -> CatchPhotoOrderPlan {
        guard Set(orderedIDs).count == orderedIDs.count else {
            throw CatchPhotoRepositoryError.invalidOrder
        }
        let draftByID = Dictionary(uniqueKeysWithValues: drafts.map { ($0.id, $0) })
        let records = try photoRecords(catchID: catchID, ownerID: ownerID).filter { $0.deletedAt == nil }
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        guard orderedIDs.allSatisfy({ recordsByID[$0] != nil || draftByID[$0] != nil }) else {
            throw CatchPhotoRepositoryError.invalidOrder
        }
        let newDrafts = try orderedIDs.compactMap { id -> DraftPhoto? in
            guard recordsByID[id] == nil else { return nil }
            guard let draft = draftByID[id] else {
                throw CatchPhotoRepositoryError.missingDraft(id)
            }
            return draft
        }
        let committed = try fileStore.commit(newDrafts, ownerID: ownerID, catchID: catchID)
        return CatchPhotoOrderPlan(
            records: records,
            recordsByID: recordsByID,
            committed: committed,
            committedByID: Dictionary(uniqueKeysWithValues: committed.map { ($0.draft.id, $0) })
        )
    }

    func applyOrderPlan(
        _ plan: CatchPhotoOrderPlan,
        catchID: UUID,
        ownerID: UUID,
        orderedIDs: [UUID]
    ) throws -> [String] {
        let now = Date.now
        let removedPaths = try plan.records.compactMap { record in
            orderedIDs.contains(record.id) ? nil : try queueDelete(record, now: now)
        }
        for (position, id) in orderedIDs.enumerated() {
            if let record = plan.recordsByID[id] {
                try updatePosition(record, to: position, now: now)
            } else if let committed = plan.committedByID[id] {
                insertPhoto(
                    committed,
                    catchID: catchID,
                    ownerID: ownerID,
                    position: position,
                    now: now
                )
            } else {
                throw CatchPhotoRepositoryError.missingDraft(id)
            }
        }
        return removedPaths
    }

    private func updatePosition(_ record: CatchPhotoRecord, to position: Int, now: Date) throws {
        guard record.position != position else { return }
        record.position = position
        record.updatedAt = now
        record.syncState = .pending
        record.syncError = nil
        try queueUpsert(record)
    }

    private func insertPhoto(
        _ committed: CommittedDraft,
        catchID: UUID,
        ownerID: UUID,
        position: Int,
        now: Date
    ) {
        let id = committed.draft.id
        modelContext.insert(CatchPhotoRecord(
            id: id,
            ownerID: ownerID,
            catchID: catchID,
            storagePath: Self.storagePath(ownerID: ownerID, catchID: catchID, photoID: id),
            localRelativePath: committed.relativePath,
            position: position,
            createdAt: now,
            updatedAt: now
        ))
        modelContext.insert(PhotoOutboxOperation(
            ownerID: ownerID,
            catchID: catchID,
            photoID: id,
            mutationKind: .create,
            stage: .uploadBinary
        ))
    }

    func queueUpsert(_ record: CatchPhotoRecord) throws {
        if let operation = try operation(photoID: record.id, ownerID: record.ownerID) {
            guard operation.mutationKind != .delete else { return }
            operation.requiresUserConfirmation = false
            operation.lastError = nil
            if operation.mutationKind == .update {
                operation.stage = .upsertMetadata
            }
        } else {
            modelContext.insert(PhotoOutboxOperation(
                ownerID: record.ownerID,
                catchID: record.catchID,
                photoID: record.id,
                mutationKind: .update,
                stage: .upsertMetadata,
                baseVersion: record.remoteVersion
            ))
        }
    }

    func queueDelete(_ record: CatchPhotoRecord, now: Date) throws -> String? {
        let existing = try operation(photoID: record.id, ownerID: record.ownerID)
        if let existing, existing.mutationKind == .create {
            modelContext.delete(existing)
            modelContext.delete(record)
            return record.localRelativePath
        }

        let operation = existing ?? PhotoOutboxOperation(
            ownerID: record.ownerID,
            catchID: record.catchID,
            photoID: record.id,
            mutationKind: .delete,
            stage: .deleteMetadata,
            baseVersion: record.remoteVersion
        )
        if existing == nil {
            modelContext.insert(operation)
        }
        operation.mutationKind = .delete
        operation.stage = .deleteMetadata
        operation.requiresUserConfirmation = false
        operation.lastError = nil
        record.deletedAt = now
        record.updatedAt = now
        record.syncState = .pending
        record.syncError = nil
        return nil
    }

    func apply(_ remote: RemoteCatchPhoto, to record: CatchPhotoRecord) {
        record.catchID = remote.catchID
        record.storagePath = remote.storagePath
        record.position = remote.position
        record.createdAt = remote.createdAt
        record.updatedAt = remote.updatedAt
        record.deletedAt = remote.deletedAt
        record.remoteVersion = remote.version
    }

    func photoRecords(catchID: UUID, ownerID: UUID) throws -> [CatchPhotoRecord] {
        let descriptor = FetchDescriptor<CatchPhotoRecord>(
            predicate: #Predicate { $0.catchID == catchID && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor)
    }

    func allPhotoRecords(ownerID: UUID) throws -> [CatchPhotoRecord] {
        let descriptor = FetchDescriptor<CatchPhotoRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor)
    }

    func photoRecord(id: UUID, ownerID: UUID) throws -> CatchPhotoRecord? {
        let descriptor = FetchDescriptor<CatchPhotoRecord>(
            predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func operation(photoID: UUID, ownerID: UUID) throws -> PhotoOutboxOperation? {
        let descriptor = FetchDescriptor<PhotoOutboxOperation>(
            predicate: #Predicate { $0.photoID == photoID && $0.ownerID == ownerID }
        )
        let operation = try modelContext.fetch(descriptor).first
        if let operation {
            try validate(operation)
        }
        return operation
    }

    func operation(id: UUID, ownerID: UUID) throws -> PhotoOutboxOperation? {
        let descriptor = FetchDescriptor<PhotoOutboxOperation>(
            predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
        )
        let operation = try modelContext.fetch(descriptor).first
        if let operation {
            try validate(operation)
        }
        return operation
    }

    func outboxOperations(ownerID: UUID) throws -> [PhotoOutboxOperation] {
        let descriptor = FetchDescriptor<PhotoOutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\PhotoOutboxOperation.createdAt)]
        )
        let operations = try modelContext.fetch(descriptor)
        try operations.forEach(validate)
        return operations
    }

    func localState(for mutation: PendingPhotoMutation) throws -> PendingPhotoLocalState {
        let ownerID = mutation.photo.ownerID
        guard let record = try photoRecord(id: mutation.photo.id, ownerID: ownerID) else {
            throw CatchPhotoRepositoryError.missingPhoto(mutation.photo.id)
        }
        guard let operation = try operation(id: mutation.operationID, ownerID: ownerID) else {
            throw CatchPhotoRepositoryError.missingOperation(mutation.operationID)
        }
        return PendingPhotoLocalState(record: record, operation: operation)
    }

    func validate(_ operation: PhotoOutboxOperation) throws {
        guard let kind = PhotoMutationKind(rawValue: operation.mutationKindRaw),
              let stage = PhotoOutboxStage(rawValue: operation.stageRaw)
        else {
            throw CatchPhotoRepositoryError.invalidOperation(operation.id)
        }
        let isValid = switch kind {
        case .create:
            stage == .uploadBinary || stage == .upsertMetadata
        case .update:
            stage == .upsertMetadata
        case .delete:
            stage == .deleteMetadata || stage == .deleteBinary
        }
        guard isValid else {
            throw CatchPhotoRepositoryError.invalidOperation(operation.id)
        }
    }
}
