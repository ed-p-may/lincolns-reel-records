import Foundation
import Observation
import SwiftData

private struct PendingProfileLocalState {
    let record: ProfileRecord
    let operation: ProfileOutboxOperation
}

@MainActor
@Observable
final class SwiftDataProfileRepository {
    let fileStore: PhotoFileStore
    let modelContext: ModelContext

    init(modelContext: ModelContext, fileStore: PhotoFileStore) {
        self.modelContext = modelContext
        self.fileStore = fileStore
    }

    static func storagePath(ownerID: UUID, avatarID: UUID) -> String {
        PhotoFileStore.avatarRemoteStoragePath(ownerID: ownerID, photoID: avatarID)
    }

    func profile(account: AccountSession) throws -> UserProfile {
        if let existing = try record(ownerID: account.ownerID) {
            return existing.profile
        }
        let record = ProfileRecord(ownerID: account.ownerID, username: account.username)
        modelContext.insert(record)
        try modelContext.save()
        return record.profile
    }

    func profile(ownerID: UUID) throws -> UserProfile? {
        try record(ownerID: ownerID)?.profile
    }

    func fileURL(for profile: UserProfile) -> URL? {
        fileStore.fileURL(relativePath: profile.avatarLocalRelativePath)
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
    func update(
        ownerID: UUID,
        values proposedValues: ProfileValues,
        avatarChange: ProfileAvatarChange = .keep,
        calendar: Calendar = .current
    ) throws -> UserProfile {
        guard let record = try record(ownerID: ownerID) else {
            throw ProfileRepositoryError.missingProfile(ownerID)
        }
        let values = try validated(proposedValues, calendar: calendar)
        guard values != record.values || avatarChange != .keep else { return record.profile }

        let oldLocalPath = record.avatarLocalRelativePath
        let oldStoragePath = record.avatarStoragePath
        var committed: CommittedDraft?
        do {
            committed = try commitAvatarChange(avatarChange, ownerID: ownerID)
            apply(values, to: record)
            try applyAvatarChange(avatarChange, committed: committed, to: record)
            record.updatedAt = .now
            record.syncState = .pending
            record.syncError = nil

            let operation = try prepareOperation(
                for: record,
                avatarChange: avatarChange,
                oldStoragePath: oldStoragePath
            )
            operation.requiresUserConfirmation = false
            operation.lastError = nil
            try modelContext.save()

            if avatarChange != .keep, oldLocalPath != record.avatarLocalRelativePath {
                try? fileStore.remove(relativePath: oldLocalPath)
            }
            return record.profile
        } catch {
            if let committed {
                try? fileStore.rollback([committed])
            }
            throw error
        }
    }

    func pendingCount(ownerID: UUID) throws -> Int {
        let descriptor = FetchDescriptor<ProfileOutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetchCount(descriptor)
    }

    func pendingMutation(
        ownerID: UUID,
        confirmingConflicts: Bool = false
    ) throws -> PendingProfileMutation? {
        guard let operation = try operation(ownerID: ownerID) else { return nil }
        guard confirmingConflicts || !operation.requiresUserConfirmation else { return nil }
        guard let record = try record(ownerID: ownerID) else {
            throw ProfileRepositoryError.missingProfile(ownerID)
        }
        if operation.requiresUserConfirmation {
            operation.requiresUserConfirmation = false
            operation.lastError = nil
            record.updatedAt = .now
            record.syncState = .pending
            record.syncError = nil
            try modelContext.save()
        }
        return PendingProfileMutation(
            operationID: operation.id,
            stage: operation.stage,
            expectedVersion: operation.baseVersion,
            profile: record.remoteValue(version: operation.baseVersion + 1),
            avatarLocalRelativePath: record.avatarLocalRelativePath,
            obsoleteStoragePaths: operation.obsoleteStoragePaths
        )
    }

    func binaryDataAsync(for mutation: PendingProfileMutation) async throws -> Data {
        let store = fileStore
        return try await Task.detached(priority: .utility) {
            guard let path = mutation.avatarLocalRelativePath,
                  let avatarID = mutation.profile.avatarID
            else { throw ProfileRepositoryError.missingAvatar(mutation.profile.ownerID) }
            return try store.data(relativePath: path, photoID: avatarID)
        }.value
    }

    func markSyncing(_ mutation: PendingProfileMutation) throws {
        let state = try localState(for: mutation)
        state.record.syncState = .syncing
        state.record.syncError = nil
        state.operation.attemptCount += 1
        state.operation.lastAttemptAt = .now
        state.operation.lastError = nil
        try modelContext.save()
    }

    func markBinaryUploaded(_ mutation: PendingProfileMutation) throws {
        let state = try localState(for: mutation)
        if state.record.avatarStoragePath == mutation.profile.avatarStoragePath {
            state.operation.stage = .upsertMetadata
        } else if let uploadedPath = mutation.profile.avatarStoragePath {
            state.operation.obsoleteStoragePaths.append(uploadedPath)
        }
        state.record.syncState = .pending
        try modelContext.save()
    }

    @discardableResult
    func markMetadataApplied(_ mutation: PendingProfileMutation, remote: RemoteProfile) throws -> Bool {
        let state = try localState(for: mutation)
        state.operation.baseVersion = remote.version
        guard state.record.updatedAt == mutation.profile.updatedAt else {
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
    func markObsoleteBinariesRemoved(_ mutation: PendingProfileMutation) throws -> Bool {
        let state = try localState(for: mutation)
        guard state.record.updatedAt == mutation.profile.updatedAt,
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

    func markFailed(_ mutation: PendingProfileMutation, error: Error) throws {
        let message = error.localizedDescription
        let state = try localState(for: mutation)
        state.record.syncState = .failed
        state.record.syncError = message
        state.operation.lastError = message
        try modelContext.save()
    }

    func markConflict(_ mutation: PendingProfileMutation, remote: RemoteProfile?) throws {
        let message = "This profile changed on another device. Retry sync to keep this version."
        let state = try localState(for: mutation)
        if let remote {
            state.operation.baseVersion = remote.version
            state.record.remoteVersion = remote.version
        }
        state.operation.requiresUserConfirmation = true
        state.operation.lastError = message
        state.record.syncState = .conflict
        state.record.syncError = message
        try modelContext.save()
    }

    func merge(_ remote: RemoteProfile, ownerID: UUID) throws -> ProfileMergeResult {
        guard remote.ownerID == ownerID else {
            return ProfileMergeResult(didChange: false, missingAvatar: nil)
        }
        if let local = try record(ownerID: ownerID) {
            guard try operation(ownerID: ownerID) == nil,
                  !local.hasRemoteSnapshot || local.remoteVersion < remote.version
            else {
                return ProfileMergeResult(didChange: false, missingAvatar: missingAvatar(for: local))
            }
            let oldLocalPath = local.avatarLocalRelativePath
            let avatarChanged = local.avatarStoragePath != remote.avatarStoragePath
            apply(remote, to: local)
            if avatarChanged {
                local.avatarLocalRelativePath = nil
                try? fileStore.remove(relativePath: oldLocalPath)
            }
            local.syncState = .synced
            local.syncError = nil
            try modelContext.save()
            return ProfileMergeResult(didChange: true, missingAvatar: missingAvatar(for: local))
        }
        let record = ProfileRecord(
            ownerID: ownerID,
            username: remote.username,
            values: remote.values,
            avatarID: remote.avatarID,
            avatarStoragePath: remote.avatarStoragePath,
            createdAt: remote.createdAt,
            updatedAt: remote.updatedAt,
            remoteVersion: remote.version,
            hasRemoteSnapshot: true,
            syncState: .synced
        )
        modelContext.insert(record)
        try modelContext.save()
        return ProfileMergeResult(didChange: true, missingAvatar: missingAvatar(for: record))
    }

    func markDownloaded(_ profile: UserProfile, data: Data) async throws {
        guard let avatarID = profile.avatarID,
              let local = try record(ownerID: profile.ownerID),
              local.avatarStoragePath == profile.avatarStoragePath
        else { return }
        let store = fileStore
        let relativePath = try await Task.detached(priority: .utility) {
            try store.storeDownloadedAvatar(data, ownerID: profile.ownerID, photoID: avatarID)
        }.value
        guard let current = try record(ownerID: profile.ownerID),
              current.avatarStoragePath == profile.avatarStoragePath
        else {
            try? fileStore.remove(relativePath: relativePath)
            return
        }
        current.avatarLocalRelativePath = relativePath
        try modelContext.save()
    }

    func purgeLocalAccountData(ownerID: UUID) throws {
        try deleteRows(CatchRecord.self, predicate: #Predicate { $0.ownerID == ownerID })
        try deleteRows(OutboxOperation.self, predicate: #Predicate { $0.ownerID == ownerID })
        try deleteRows(CatchPhotoRecord.self, predicate: #Predicate { $0.ownerID == ownerID })
        try deleteRows(PhotoOutboxOperation.self, predicate: #Predicate { $0.ownerID == ownerID })
        try deleteRows(TackleItemRecord.self, predicate: #Predicate { $0.ownerID == ownerID })
        try deleteRows(TackleOutboxOperation.self, predicate: #Predicate { $0.ownerID == ownerID })
        try deleteRows(ProfileRecord.self, predicate: #Predicate { $0.ownerID == ownerID })
        try deleteRows(ProfileOutboxOperation.self, predicate: #Predicate { $0.ownerID == ownerID })
        try modelContext.save()
        try fileStore.removeAccountFiles(ownerID: ownerID)
    }
}

private extension SwiftDataProfileRepository {
    func validated(_ proposed: ProfileValues, calendar: Calendar) throws -> ProfileValues {
        let displayName = normalized(proposed.displayName)
        let homeWater = normalized(proposed.homeWater)
        guard displayName?.count ?? 0 <= 80 else { throw ProfileValidationError.displayNameTooLong }
        guard homeWater?.count ?? 0 <= 120 else { throw ProfileValidationError.homeWaterTooLong }
        let currentYear = calendar.component(.year, from: .now)
        if let year = proposed.anglerSince, !(1900 ... currentYear).contains(year) {
            throw ProfileValidationError.invalidAnglerSince(currentYear)
        }
        return ProfileValues(displayName: displayName, homeWater: homeWater, anglerSince: proposed.anglerSince)
    }

    func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    func apply(_ values: ProfileValues, to record: ProfileRecord) {
        record.displayName = values.displayName
        record.homeWater = values.homeWater
        record.anglerSince = values.anglerSince
    }

    func apply(_ remote: RemoteProfile, to record: ProfileRecord) {
        record.username = remote.username
        apply(remote.values, to: record)
        record.avatarID = remote.avatarID
        record.avatarStoragePath = remote.avatarStoragePath
        record.createdAt = remote.createdAt
        record.updatedAt = remote.updatedAt
        record.remoteVersion = remote.version
        record.hasRemoteSnapshot = true
    }

    func missingAvatar(for record: ProfileRecord) -> UserProfile? {
        guard record.avatarStoragePath != nil,
              fileStore.fileURL(relativePath: record.avatarLocalRelativePath) == nil
        else { return nil }
        return record.profile
    }

    func commitAvatarChange(_ change: ProfileAvatarChange, ownerID: UUID) throws -> CommittedDraft? {
        guard case let .replace(draft) = change else { return nil }
        return try fileStore.commitAvatar(draft, ownerID: ownerID)
    }

    func applyAvatarChange(
        _ change: ProfileAvatarChange,
        committed: CommittedDraft?,
        to record: ProfileRecord
    ) throws {
        switch change {
        case .keep:
            return
        case .remove:
            record.avatarID = nil
            record.avatarStoragePath = nil
            record.avatarLocalRelativePath = nil
        case .replace:
            guard let committed else { throw ProfileRepositoryError.missingAvatar(record.ownerID) }
            record.avatarID = committed.draft.id
            record.avatarStoragePath = Self.storagePath(ownerID: record.ownerID, avatarID: committed.draft.id)
            record.avatarLocalRelativePath = committed.relativePath
        }
    }

    func prepareOperation(
        for record: ProfileRecord,
        avatarChange: ProfileAvatarChange,
        oldStoragePath: String?
    ) throws -> ProfileOutboxOperation {
        let existing = try operation(ownerID: record.ownerID)
        let operation = existing ?? ProfileOutboxOperation(
            ownerID: record.ownerID,
            stage: .upsertMetadata,
            baseVersion: record.remoteVersion
        )
        if existing == nil {
            modelContext.insert(operation)
        }
        if let oldStoragePath, oldStoragePath != record.avatarStoragePath {
            operation.obsoleteStoragePaths.append(oldStoragePath)
        }
        switch avatarChange {
        case .replace: operation.stage = .uploadBinary
        case .remove: operation.stage = .upsertMetadata
        case .keep where operation.stage == .uploadBinary: break
        case .keep: operation.stage = .upsertMetadata
        }
        return operation
    }

    func record(ownerID: UUID) throws -> ProfileRecord? {
        let descriptor = FetchDescriptor<ProfileRecord>(predicate: #Predicate { $0.ownerID == ownerID })
        return try modelContext.fetch(descriptor).first
    }

    func operation(ownerID: UUID) throws -> ProfileOutboxOperation? {
        let descriptor = FetchDescriptor<ProfileOutboxOperation>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        return try modelContext.fetch(descriptor).first
    }

    func localState(for mutation: PendingProfileMutation) throws -> PendingProfileLocalState {
        guard let record = try record(ownerID: mutation.profile.ownerID) else {
            throw ProfileRepositoryError.missingProfile(mutation.profile.ownerID)
        }
        let operationID = mutation.operationID
        let descriptor = FetchDescriptor<ProfileOutboxOperation>(
            predicate: #Predicate { $0.id == operationID }
        )
        guard let operation = try modelContext.fetch(descriptor).first else {
            throw ProfileRepositoryError.missingOperation(mutation.operationID)
        }
        return PendingProfileLocalState(record: record, operation: operation)
    }

    func deleteRows<Model: PersistentModel>(_: Model.Type, predicate: Predicate<Model>) throws {
        let rows = try modelContext.fetch(FetchDescriptor<Model>(predicate: predicate))
        rows.forEach(modelContext.delete)
    }
}
