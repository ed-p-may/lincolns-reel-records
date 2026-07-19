import Foundation
import Observation
import SwiftData

enum CatchPhotoRepositoryError: LocalizedError, Equatable {
    case missingPhoto(UUID)
    case missingOperation(UUID)
    case missingDraft(UUID)
    case invalidOperation(UUID)
    case invalidOrder

    var errorDescription: String? {
        switch self {
        case let .missingPhoto(id):
            "The photo queue references missing photo \(id.uuidString)."
        case let .missingOperation(id):
            "The photo queue operation \(id.uuidString) is missing."
        case let .missingDraft(id):
            "Draft photo \(id.uuidString) is missing from this edit."
        case let .invalidOperation(id):
            "Photo queue operation \(id.uuidString) has an invalid persisted state."
        case .invalidOrder:
            "The photo order contains duplicate or unknown items."
        }
    }
}

struct PendingPhotoLocalState {
    let record: CatchPhotoRecord
    let operation: PhotoOutboxOperation
}

@MainActor
@Observable
final class SwiftDataCatchPhotoRepository {
    let fileStore: PhotoFileStore
    let modelContext: ModelContext

    init(modelContext: ModelContext, fileStore: PhotoFileStore) {
        self.modelContext = modelContext
        self.fileStore = fileStore
    }

    func stage(data: Data, sessionID: UUID) throws -> DraftPhoto {
        let normalized = try PhotoImageNormalizer.normalize(data)
        return try fileStore.stage(normalized.data, sessionID: sessionID)
    }

    func stageAsync(data: Data, sessionID: UUID) async throws -> DraftPhoto {
        let store = fileStore
        return try await Task.detached(priority: .userInitiated) {
            let normalized = try PhotoImageNormalizer.normalize(data)
            return try store.stage(normalized.data, sessionID: sessionID)
        }.value
    }

    func discardDrafts(sessionID: UUID) throws {
        try fileStore.discardDraftSession(sessionID)
    }

    func photos(catchID: UUID, ownerID: UUID) throws -> [CatchPhotoItem] {
        let descriptor = FetchDescriptor<CatchPhotoRecord>(
            predicate: #Predicate {
                $0.catchID == catchID && $0.ownerID == ownerID && $0.deletedAt == nil
            },
            sortBy: [
                SortDescriptor(\CatchPhotoRecord.position),
                SortDescriptor(\CatchPhotoRecord.createdAt),
                SortDescriptor(\CatchPhotoRecord.id)
            ]
        )
        return try modelContext.fetch(descriptor).map(\.item)
    }

    func photosByCatch(ownerID: UUID) throws -> [UUID: [CatchPhotoItem]] {
        let descriptor = FetchDescriptor<CatchPhotoRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.deletedAt == nil },
            sortBy: [
                SortDescriptor(\CatchPhotoRecord.position),
                SortDescriptor(\CatchPhotoRecord.createdAt),
                SortDescriptor(\CatchPhotoRecord.id)
            ]
        )
        return try Dictionary(grouping: modelContext.fetch(descriptor).map(\.item), by: \.catchID)
    }

    func fileURL(for photo: CatchPhotoItem) -> URL? {
        fileStore.fileURL(relativePath: photo.localRelativePath)
    }

    func fileURL(for draft: DraftPhoto) -> URL? {
        fileStore.fileURL(relativePath: draft.relativePath)
    }

    func saveOrder(
        catchID: UUID,
        ownerID: UUID,
        orderedIDs: [UUID],
        drafts: [DraftPhoto]
    ) throws {
        let plan = try makeOrderPlan(
            catchID: catchID,
            ownerID: ownerID,
            orderedIDs: orderedIDs,
            drafts: drafts
        )
        let localFilesToRemove: [String]
        do {
            localFilesToRemove = try applyOrderPlan(
                plan,
                catchID: catchID,
                ownerID: ownerID,
                orderedIDs: orderedIDs
            )
            try modelContext.save()
        } catch {
            modelContext.rollback()
            try? fileStore.rollback(plan.committed)
            throw error
        }
        for path in localFilesToRemove {
            try fileStore.remove(relativePath: path)
        }
    }

    func deleteAll(catchID: UUID, ownerID: UUID) throws {
        let now = Date.now
        var localFilesToRemove: [String] = []
        for record in try photoRecords(catchID: catchID, ownerID: ownerID) where record.deletedAt == nil {
            if let path = try queueDelete(record, now: now) {
                localFilesToRemove.append(path)
            }
        }
        try modelContext.save()
        for path in localFilesToRemove {
            try fileStore.remove(relativePath: path)
        }
    }

    func pendingCount(ownerID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<PhotoOutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func pendingMutations(ownerID: UUID, confirmingConflicts: Bool = false) throws -> [PendingPhotoMutation] {
        let operations = try outboxOperations(ownerID: ownerID).filter {
            confirmingConflicts || !$0.requiresUserConfirmation
        }
        let recordsByID = try Dictionary(uniqueKeysWithValues: allPhotoRecords(ownerID: ownerID).map { ($0.id, $0) })
        var changed = false
        let mutations = try operations.map { operation in
            guard let record = recordsByID[operation.photoID] else {
                throw CatchPhotoRepositoryError.missingPhoto(operation.photoID)
            }
            if operation.requiresUserConfirmation {
                operation.requiresUserConfirmation = false
                operation.lastError = nil
                record.syncState = .pending
                record.syncError = nil
                changed = true
            }
            let version = operation.mutationKind == .create ? 1 : operation.baseVersion + 1
            return PendingPhotoMutation(
                operationID: operation.id,
                kind: operation.mutationKind,
                stage: operation.stage,
                expectedVersion: operation.baseVersion,
                photo: record.remoteValue(version: version),
                localRelativePath: record.localRelativePath
            )
        }
        if changed {
            try modelContext.save()
        }
        return mutations
    }

    func binaryDataAsync(for mutation: PendingPhotoMutation) async throws -> Data {
        let store = fileStore
        return try await Task.detached(priority: .utility) {
            guard let path = mutation.localRelativePath else {
                throw PhotoFileStoreError.missingCommittedFile(mutation.photo.id)
            }
            return try store.data(relativePath: path, photoID: mutation.photo.id)
        }.value
    }

    func markSyncing(_ mutation: PendingPhotoMutation) throws {
        let state = try localState(for: mutation)
        state.record.syncState = .syncing
        state.record.syncError = nil
        state.operation.attemptCount += 1
        state.operation.lastAttemptAt = .now
        state.operation.lastError = nil
        try modelContext.save()
    }

    func markBinaryUploaded(_ mutation: PendingPhotoMutation) throws {
        let state = try localState(for: mutation)
        state.operation.stage = .upsertMetadata
        state.record.syncState = .pending
        try modelContext.save()
    }

    func markMetadataApplied(_ mutation: PendingPhotoMutation, remote: RemoteCatchPhoto) throws {
        let state = try localState(for: mutation)
        apply(remote, to: state.record)
        if mutation.kind == .delete {
            state.operation.stage = .deleteBinary
            state.operation.baseVersion = remote.version
            state.record.syncState = .pending
        } else {
            state.record.syncState = .synced
            state.record.syncError = nil
            modelContext.delete(state.operation)
        }
        try modelContext.save()
    }

    func markBinaryDeleted(_ mutation: PendingPhotoMutation) throws {
        let state = try localState(for: mutation)
        try fileStore.remove(relativePath: state.record.localRelativePath)
        state.record.localRelativePath = nil
        state.record.syncState = .synced
        state.record.syncError = nil
        modelContext.delete(state.operation)
        try modelContext.save()
    }

    func markFailed(_ mutation: PendingPhotoMutation, error: Error) throws {
        let message = error.localizedDescription
        let state = try localState(for: mutation)
        state.record.syncState = .failed
        state.record.syncError = message
        state.operation.lastError = message
        try modelContext.save()
    }

    func markConflict(_ mutation: PendingPhotoMutation, remote: RemoteCatchPhoto?) throws {
        let message = "Photo order changed on another device. Retry sync to keep this order."
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

    func merge(_ remotePhotos: [RemoteCatchPhoto], ownerID: UUID) throws -> [CatchPhotoItem] {
        let localRecords = try allPhotoRecords(ownerID: ownerID)
        var recordsByID = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.id, $0) })
        let pendingIDs = try Set(outboxOperations(ownerID: ownerID).map(\.photoID))
        var changed = false

        for remote in remotePhotos where remote.ownerID == ownerID {
            if let local = recordsByID[remote.id] {
                guard !pendingIDs.contains(local.id), local.remoteVersion < remote.version else { continue }
                apply(remote, to: local)
                local.syncState = .synced
                local.syncError = nil
                if remote.deletedAt != nil {
                    try fileStore.remove(relativePath: local.localRelativePath)
                    local.localRelativePath = nil
                }
                changed = true
            } else {
                let record = CatchPhotoRecord(
                    id: remote.id,
                    ownerID: remote.ownerID,
                    catchID: remote.catchID,
                    storagePath: remote.storagePath,
                    position: remote.position,
                    createdAt: remote.createdAt,
                    updatedAt: remote.updatedAt,
                    deletedAt: remote.deletedAt,
                    remoteVersion: remote.version,
                    syncState: .synced
                )
                modelContext.insert(record)
                recordsByID[record.id] = record
                changed = true
            }
        }
        if changed {
            try modelContext.save()
        }
        return recordsByID.values
            .filter { $0.deletedAt == nil && $0.localRelativePath == nil }
            .map(\.item)
    }

    func markDownloaded(_ photo: CatchPhotoItem, data: Data) async throws {
        guard let record = try photoRecord(id: photo.id, ownerID: photo.ownerID), record.deletedAt == nil else {
            return
        }
        let store = fileStore
        let relativePath = try await Task.detached(priority: .utility) {
            try store.storeDownloaded(
                data,
                ownerID: photo.ownerID,
                catchID: photo.catchID,
                photoID: photo.id
            )
        }.value
        guard let currentRecord = try photoRecord(id: photo.id, ownerID: photo.ownerID),
              currentRecord.deletedAt == nil
        else {
            try? fileStore.remove(relativePath: relativePath)
            return
        }
        currentRecord.localRelativePath = relativePath
        try modelContext.save()
    }
}
