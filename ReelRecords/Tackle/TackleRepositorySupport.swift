import Foundation
import SwiftData

extension SwiftDataTackleRepository {
    func validated(_ proposed: TackleValues) throws -> TackleValues {
        let name = proposed.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw TackleValidationError.nameRequired }
        return TackleValues(
            name: name,
            type: proposed.type,
            size: normalized(proposed.size),
            color: normalized(proposed.color),
            brand: normalized(proposed.brand),
            archived: proposed.archived
        )
    }

    func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    func apply(_ values: TackleValues, to record: TackleItemRecord) {
        record.name = values.name
        record.type = values.type
        record.size = values.size
        record.color = values.color
        record.brand = values.brand
        record.archived = values.archived
    }

    func apply(_ remote: RemoteTackleItem, to record: TackleItemRecord) {
        apply(remote.values, to: record)
        record.photoID = remote.photoID
        record.photoStoragePath = remote.photoStoragePath
        record.createdAt = remote.createdAt
        record.updatedAt = remote.updatedAt
        record.deletedAt = remote.deletedAt
        record.remoteVersion = remote.version
    }

    func commitPhotoChange(
        _ photoChange: TacklePhotoChange,
        ownerID: UUID,
        itemID: UUID
    ) throws -> CommittedDraft? {
        guard case let .replace(draft) = photoChange else { return nil }
        return try fileStore.commitTackle(draft, ownerID: ownerID, itemID: itemID)
    }

    func applyPhotoChange(
        _ photoChange: TacklePhotoChange,
        committed: CommittedDraft?,
        to record: TackleItemRecord
    ) throws {
        switch photoChange {
        case .keep:
            return
        case .remove:
            record.photoID = nil
            record.photoStoragePath = nil
            record.photoLocalRelativePath = nil
        case .replace:
            guard let committed else { throw TackleRepositoryError.missingPhoto(record.id) }
            record.photoID = committed.draft.id
            record.photoStoragePath = Self.storagePath(
                ownerID: record.ownerID,
                itemID: record.id,
                photoID: committed.draft.id
            )
            record.photoLocalRelativePath = committed.relativePath
        }
    }

    func prepareUpdateOperation(
        for record: TackleItemRecord,
        photoChange: TacklePhotoChange,
        oldStoragePath: String?
    ) throws -> TackleOutboxOperation {
        let existingOperation = try operation(itemID: record.id, ownerID: record.ownerID)
        let operation = existingOperation ?? TackleOutboxOperation(
            ownerID: record.ownerID,
            itemID: record.id,
            mutationKind: .update,
            stage: .upsertMetadata,
            baseVersion: record.remoteVersion
        )
        if existingOperation == nil {
            modelContext.insert(operation)
        }
        if let oldStoragePath, oldStoragePath != record.photoStoragePath {
            operation.obsoleteStoragePaths.append(oldStoragePath)
        }
        switch photoChange {
        case .replace:
            operation.stage = .uploadBinary
        case .remove:
            operation.stage = .upsertMetadata
        case .keep where operation.stage == .uploadBinary:
            break
        case .keep:
            operation.stage = .upsertMetadata
        }
        return operation
    }

    func records(ownerID: UUID) throws -> [TackleItemRecord] {
        let descriptor = FetchDescriptor<TackleItemRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor)
    }

    func record(id: UUID, ownerID: UUID) throws -> TackleItemRecord? {
        let descriptor = FetchDescriptor<TackleItemRecord>(
            predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func operations(ownerID: UUID) throws -> [TackleOutboxOperation] {
        let descriptor = FetchDescriptor<TackleOutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID },
            sortBy: [SortDescriptor(\TackleOutboxOperation.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    func operation(itemID: UUID, ownerID: UUID) throws -> TackleOutboxOperation? {
        let descriptor = FetchDescriptor<TackleOutboxOperation>(
            predicate: #Predicate { $0.itemID == itemID && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func operation(id: UUID, ownerID: UUID) throws -> TackleOutboxOperation? {
        let descriptor = FetchDescriptor<TackleOutboxOperation>(
            predicate: #Predicate { $0.id == id && $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func localState(for mutation: PendingTackleMutation) throws -> PendingTackleLocalState {
        let ownerID = mutation.item.ownerID
        guard let record = try record(id: mutation.item.id, ownerID: ownerID) else {
            throw TackleRepositoryError.missingItem(mutation.item.id)
        }
        guard let operation = try operation(id: mutation.operationID, ownerID: ownerID) else {
            throw TackleRepositoryError.missingOperation(mutation.operationID)
        }
        return PendingTackleLocalState(record: record, operation: operation)
    }
}
