import Foundation
import Observation
import SwiftData

enum TackleRepositoryError: LocalizedError, Equatable {
    case missingItem(UUID)
    case missingOperation(UUID)
    case deletedItem(UUID)
    case missingPhoto(UUID)

    var errorDescription: String? {
        switch self {
        case let .missingItem(id): "The tackle queue references missing item \(id.uuidString)."
        case let .missingOperation(id): "The tackle queue operation \(id.uuidString) is missing."
        case let .deletedItem(id): "Tackle item \(id.uuidString) is no longer available."
        case let .missingPhoto(id): "The photo for tackle item \(id.uuidString) is missing locally."
        }
    }
}

struct PendingTackleLocalState {
    let record: TackleItemRecord
    let operation: TackleOutboxOperation
}

@MainActor
@Observable
final class SwiftDataTackleRepository {
    let fileStore: PhotoFileStore
    let modelContext: ModelContext

    init(modelContext: ModelContext, fileStore: PhotoFileStore) {
        self.modelContext = modelContext
        self.fileStore = fileStore
    }

    static func storagePath(ownerID: UUID, itemID: UUID, photoID: UUID) -> String {
        PhotoFileStore.remoteStoragePath(ownerID: ownerID, parentID: itemID, photoID: photoID)
    }

    func items(ownerID: UUID, archived: Bool = false) throws -> [TackleItem] {
        try records(ownerID: ownerID)
            .filter { $0.deletedAt == nil && $0.archived == archived }
            .map(\.item)
            .sorted(by: TackleDiscovery.alphabeticallyPrecedes)
    }

    func item(id: UUID, ownerID: UUID) throws -> TackleItem? {
        try record(id: id, ownerID: ownerID)?.item
    }

    func itemNames(ownerID: UUID, referencedIDs: Set<UUID>) throws -> [UUID: String] {
        guard !referencedIDs.isEmpty else { return [:] }
        return try Dictionary(uniqueKeysWithValues: records(ownerID: ownerID)
            .filter { referencedIDs.contains($0.id) }
            .map { ($0.id, $0.name) })
    }

    func fileURL(for item: TackleItem) -> URL? {
        fileStore.fileURL(relativePath: item.photoLocalRelativePath)
    }

    func fileURL(for draft: DraftPhoto) -> URL? {
        fileStore.fileURL(relativePath: draft.relativePath)
    }

    func stageAsync(data: Data, sessionID: UUID) async throws -> DraftPhoto {
        try await fileStore.stageNormalizedAsync(data: data, sessionID: sessionID)
    }

    func discardDrafts(sessionID: UUID) throws {
        try fileStore.discardDraftSession(sessionID)
    }

    @discardableResult
    func create(_ newItem: NewTackleItem, photo: DraftPhoto? = nil) throws -> TackleItem {
        let values = try validated(newItem.values)
        let id = UUID()
        let now = Date.now
        var committed: CommittedDraft?
        do {
            if let photo {
                committed = try fileStore.commitTackle(photo, ownerID: newItem.ownerID, itemID: id)
            }
            let photoID = committed?.draft.id
            let record = TackleItemRecord(
                id: id,
                ownerID: newItem.ownerID,
                values: values,
                photoID: photoID,
                photoStoragePath: photoID.map {
                    Self.storagePath(ownerID: newItem.ownerID, itemID: id, photoID: $0)
                },
                photoLocalRelativePath: committed?.relativePath,
                createdAt: now,
                updatedAt: now
            )
            modelContext.insert(record)
            modelContext.insert(TackleOutboxOperation(
                ownerID: newItem.ownerID,
                itemID: id,
                mutationKind: .create,
                stage: photoID == nil ? .upsertMetadata : .uploadBinary
            ))
            try modelContext.save()
            return record.item
        } catch {
            if let committed {
                try? fileStore.rollback([committed])
            }
            throw error
        }
    }

    @discardableResult
    func update(
        id: UUID,
        ownerID: UUID,
        values proposedValues: TackleValues,
        photoChange: TacklePhotoChange = .keep
    ) throws -> TackleItem {
        guard let record = try record(id: id, ownerID: ownerID) else {
            throw TackleRepositoryError.missingItem(id)
        }
        guard record.deletedAt == nil else { throw TackleRepositoryError.deletedItem(id) }
        let values = try validated(proposedValues)
        guard values != record.values || photoChange != .keep else { return record.item }

        let oldLocalPath = record.photoLocalRelativePath
        let oldStoragePath = record.photoStoragePath
        var committed: CommittedDraft?
        do {
            committed = try commitPhotoChange(photoChange, ownerID: ownerID, itemID: id)
            apply(values, to: record)
            try applyPhotoChange(photoChange, committed: committed, to: record)
            record.updatedAt = .now
            record.syncState = .pending
            record.syncError = nil

            let operation = try prepareUpdateOperation(
                for: record,
                photoChange: photoChange,
                oldStoragePath: oldStoragePath
            )
            operation.requiresUserConfirmation = false
            operation.lastError = nil
            try modelContext.save()

            if photoChange != .keep, oldLocalPath != record.photoLocalRelativePath {
                try? fileStore.remove(relativePath: oldLocalPath)
            }
            return record.item
        } catch {
            if let committed {
                try? fileStore.rollback([committed])
            }
            throw error
        }
    }
}

extension SwiftDataTackleRepository {
    func pendingCount(ownerID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<TackleOutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func pendingCreateItemIDs(ownerID: UUID) throws -> Set<UUID> {
        try Set(operations(ownerID: ownerID).filter { $0.mutationKind == .create }.map(\.itemID))
    }

    func pendingMutations(
        ownerID: UUID,
        confirmingConflicts: Bool = false
    ) throws -> [PendingTackleMutation] {
        let queued = try operations(ownerID: ownerID).filter {
            confirmingConflicts || !$0.requiresUserConfirmation
        }
        let recordsByID = try Dictionary(uniqueKeysWithValues: records(ownerID: ownerID).map { ($0.id, $0) })
        var confirmedConflict = false
        let mutations = try queued.map { operation in
            guard let record = recordsByID[operation.itemID] else {
                throw TackleRepositoryError.missingItem(operation.itemID)
            }
            if operation.requiresUserConfirmation {
                operation.requiresUserConfirmation = false
                operation.lastError = nil
                record.updatedAt = .now
                record.syncState = .pending
                record.syncError = nil
                confirmedConflict = true
            }
            let version = operation.mutationKind == .create ? 1 : operation.baseVersion + 1
            return PendingTackleMutation(
                operationID: operation.id,
                kind: operation.mutationKind,
                stage: operation.stage,
                expectedVersion: operation.baseVersion,
                item: record.remoteValue(version: version),
                photoLocalRelativePath: record.photoLocalRelativePath,
                obsoleteStoragePaths: operation.obsoleteStoragePaths
            )
        }
        if confirmedConflict {
            try modelContext.save()
        }
        return mutations
    }

    func binaryDataAsync(for mutation: PendingTackleMutation) async throws -> Data {
        let store = fileStore
        return try await Task.detached(priority: .utility) {
            guard let path = mutation.photoLocalRelativePath, let photoID = mutation.item.photoID else {
                throw TackleRepositoryError.missingPhoto(mutation.item.id)
            }
            return try store.data(relativePath: path, photoID: photoID)
        }.value
    }

    func markSyncing(_ mutation: PendingTackleMutation) throws {
        let state = try localState(for: mutation)
        state.record.syncState = .syncing
        state.record.syncError = nil
        state.operation.attemptCount += 1
        state.operation.lastAttemptAt = .now
        state.operation.lastError = nil
        try modelContext.save()
    }

    func markBinaryUploaded(_ mutation: PendingTackleMutation) throws {
        let state = try localState(for: mutation)
        if state.record.photoStoragePath == mutation.item.photoStoragePath {
            state.operation.stage = .upsertMetadata
        } else if let uploadedPath = mutation.item.photoStoragePath {
            state.operation.obsoleteStoragePaths.append(uploadedPath)
        }
        state.record.syncState = .pending
        try modelContext.save()
    }

    @discardableResult
    func markMetadataApplied(_ mutation: PendingTackleMutation, remote: RemoteTackleItem) throws -> Bool {
        let state = try localState(for: mutation)
        state.operation.baseVersion = remote.version
        if mutation.kind == .create {
            state.operation.mutationKind = .update
        }
        guard state.record.updatedAt == mutation.item.updatedAt else {
            state.record.remoteVersion = remote.version
            state.record.syncState = .pending
            state.record.syncError = nil
            try modelContext.save()
            return false
        }

        apply(remote, to: state.record)
        if state.operation.obsoleteStoragePaths.isEmpty {
            state.record.syncState = .synced
            state.record.syncError = nil
            modelContext.delete(state.operation)
        } else {
            state.operation.stage = .removeObsoleteBinaries
            state.record.syncState = .pending
        }
        try modelContext.save()
        return true
    }

    @discardableResult
    func markObsoleteBinariesRemoved(_ mutation: PendingTackleMutation) throws -> Bool {
        let state = try localState(for: mutation)
        guard state.record.updatedAt == mutation.item.updatedAt,
              state.operation.stage == .removeObsoleteBinaries,
              Set(state.operation.obsoleteStoragePaths) == Set(mutation.obsoleteStoragePaths)
        else { return false }
        state.operation.obsoleteStoragePaths = []
        state.record.syncState = .synced
        state.record.syncError = nil
        modelContext.delete(state.operation)
        try modelContext.save()
        return true
    }

    func markFailed(_ mutation: PendingTackleMutation, error: Error) throws {
        let message = error.localizedDescription
        let state = try localState(for: mutation)
        state.record.syncState = .failed
        state.record.syncError = message
        state.operation.lastError = message
        try modelContext.save()
    }

    func markConflict(_ mutation: PendingTackleMutation, remote: RemoteTackleItem?) throws {
        let message = "This tackle item changed on another device. Retry sync to keep this version."
        let state = try localState(for: mutation)
        if let remote {
            state.operation.baseVersion = remote.version
            state.record.remoteVersion = remote.version
            if mutation.kind == .create {
                state.operation.mutationKind = .update
            }
        }
        state.operation.requiresUserConfirmation = true
        state.operation.lastError = message
        state.record.syncState = .conflict
        state.record.syncError = message
        try modelContext.save()
    }

    func merge(_ remoteItems: [RemoteTackleItem], ownerID: UUID) throws -> [TackleItem] {
        let localRecords = try records(ownerID: ownerID)
        var recordsByID = Dictionary(uniqueKeysWithValues: localRecords.map { ($0.id, $0) })
        let pendingIDs = try Set(operations(ownerID: ownerID).map(\.itemID))
        var changed = false

        for remote in remoteItems where remote.ownerID == ownerID {
            if let local = recordsByID[remote.id] {
                guard !pendingIDs.contains(local.id), local.remoteVersion < remote.version else { continue }
                let oldLocalPath = local.photoLocalRelativePath
                let photoChanged = local.photoStoragePath != remote.photoStoragePath
                apply(remote, to: local)
                if photoChanged {
                    local.photoLocalRelativePath = nil
                    try? fileStore.remove(relativePath: oldLocalPath)
                }
                local.syncState = .synced
                local.syncError = nil
                changed = true
            } else {
                let record = TackleItemRecord(
                    id: remote.id,
                    ownerID: remote.ownerID,
                    values: remote.values,
                    photoID: remote.photoID,
                    photoStoragePath: remote.photoStoragePath,
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
            .filter { $0.photoStoragePath != nil && $0.photoLocalRelativePath == nil }
            .map(\.item)
    }

    func markDownloaded(_ item: TackleItem, data: Data) async throws {
        guard let photoID = item.photoID,
              let localRecord = try record(id: item.id, ownerID: item.ownerID),
              localRecord.photoStoragePath == item.photoStoragePath
        else { return }
        let store = fileStore
        let relativePath = try await Task.detached(priority: .utility) {
            try store.storeDownloadedTackle(
                data,
                ownerID: item.ownerID,
                itemID: item.id,
                photoID: photoID
            )
        }.value
        guard let current = try record(id: item.id, ownerID: item.ownerID),
              current.photoStoragePath == item.photoStoragePath
        else {
            try? fileStore.remove(relativePath: relativePath)
            return
        }
        current.photoLocalRelativePath = relativePath
        try modelContext.save()
    }
}

enum TackleDiscovery {
    static func results(
        in items: [TackleItem],
        query: String,
        type: TackleItemType?
    ) -> [TackleItem] {
        let query = CatchDiscovery.normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        return items.filter { item in
            (type == nil || item.type == type)
                && (query.isEmpty || CatchDiscovery.normalized(item.name).contains(query))
        }
        .sorted(by: alphabeticallyPrecedes)
    }

    static func alphabeticallyPrecedes(_ first: TackleItem, _ second: TackleItem) -> Bool {
        if CatchDiscovery.normalized(first.name) != CatchDiscovery.normalized(second.name) {
            return CatchDiscovery.alphabeticallyPrecedes(first.name, second.name)
        }
        return first.id.uuidString < second.id.uuidString
    }
}
