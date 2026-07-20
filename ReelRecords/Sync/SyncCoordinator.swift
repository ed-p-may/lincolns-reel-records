import Foundation
import Observation

struct PhotoSyncDependencies {
    let repository: SwiftDataCatchPhotoRepository
    let remoteStore: any CatchPhotoRemoteStore
}

struct TackleSyncDependencies {
    let repository: SwiftDataTackleRepository
    let remoteStore: any TackleRemoteStore
}

struct ProfileSyncDependencies {
    let repository: SwiftDataProfileRepository
    let remoteStore: any ProfileRemoteStore
}

@MainActor
@Observable
final class SyncCoordinator {
    private struct SyncRequest {
        let ownerID: UUID
        let confirmingConflicts: Bool
    }

    private let repository: SwiftDataCatchRepository
    private let remoteStore: any CatchRemoteStore
    private let photoSync: PhotoSyncDependencies?
    private let tackleSync: TackleSyncDependencies?
    let profileSync: ProfileSyncDependencies?
    @ObservationIgnored private var pendingSyncRequest: SyncRequest?
    @ObservationIgnored let suspension = SyncSuspension()

    private(set) var isSyncing = false
    private(set) var revision = 0
    var statusMessage: String?

    init(
        repository: SwiftDataCatchRepository,
        remoteStore: any CatchRemoteStore,
        photoSync: PhotoSyncDependencies? = nil,
        tackleSync: TackleSyncDependencies? = nil,
        profileSync: ProfileSyncDependencies? = nil
    ) {
        self.repository = repository
        self.remoteStore = remoteStore
        self.photoSync = photoSync
        self.tackleSync = tackleSync
        self.profileSync = profileSync
    }

    func sync(ownerID: UUID, confirmingConflicts: Bool = false) async {
        guard !suspension.contains(ownerID) else { return }
        guard !isSyncing else {
            queueFollowUp(ownerID: ownerID, confirmingConflicts: confirmingConflicts)
            return
        }
        isSyncing = true
        statusMessage = nil
        var didChange = false
        defer {
            isSyncing = false
            suspension.resumeIdleWaiters()
            if didChange {
                revision += 1
            }
        }

        var request = SyncRequest(ownerID: ownerID, confirmingConflicts: confirmingConflicts)
        while true {
            pendingSyncRequest = nil
            didChange = await performSync(request) || didChange
            guard let followUp = pendingSyncRequest else { break }
            request = followUp
        }
    }

    private func performSync(_ request: SyncRequest) async -> Bool {
        var didChange = false
        do {
            didChange = await performProfileSync(request) || didChange
            var blockedTackleItemIDs: Set<UUID> = []
            if let tackleSync {
                didChange = await syncTackle(
                    ownerID: request.ownerID,
                    confirmingConflicts: request.confirmingConflicts,
                    dependencies: tackleSync
                ) || didChange
                blockedTackleItemIDs = try tackleSync.repository.pendingCreateItemIDs(ownerID: request.ownerID)
            }
            let pendingMutations = try repository.pendingMutations(
                ownerID: request.ownerID,
                confirmingConflicts: request.confirmingConflicts,
                blockedTackleItemIDs: blockedTackleItemIDs
            )
            for mutation in pendingMutations {
                do {
                    try repository.markSyncing(mutation)
                    switch try await remoteStore.apply(mutation) {
                    case let .applied(remote):
                        try repository.markApplied(mutation, remote: remote)
                    case let .conflict(remote):
                        try repository.markConflict(mutation, remote: remote)
                        statusMessage = "A catch changed elsewhere. Retry sync to keep this version."
                    }
                    didChange = true
                } catch {
                    try? repository.markFailed(mutation, error: error)
                    statusMessage = "A local change is safe and will retry when connected."
                    didChange = true
                }
            }

            let remoteCatches = try await remoteStore.fetch(ownerID: request.ownerID)
            didChange = try repository.merge(remoteCatches, ownerID: request.ownerID) || didChange
            if let photoSync {
                didChange = await syncPhotos(
                    ownerID: request.ownerID,
                    confirmingConflicts: request.confirmingConflicts,
                    dependencies: photoSync
                ) || didChange
            }
        } catch {
            statusMessage = "Sync unavailable. Your local logbook is safe."
        }
        return didChange
    }

    private func performProfileSync(_ request: SyncRequest) async -> Bool {
        guard let profileSync else { return false }
        return await syncProfile(
            ownerID: request.ownerID,
            confirmingConflicts: request.confirmingConflicts,
            dependencies: profileSync
        )
    }

    private func queueFollowUp(ownerID: UUID, confirmingConflicts: Bool) {
        if let pendingSyncRequest, pendingSyncRequest.ownerID == ownerID {
            self.pendingSyncRequest = SyncRequest(
                ownerID: ownerID,
                confirmingConflicts: pendingSyncRequest.confirmingConflicts || confirmingConflicts
            )
        } else {
            pendingSyncRequest = SyncRequest(ownerID: ownerID, confirmingConflicts: confirmingConflicts)
        }
    }

    private func syncTackle(
        ownerID: UUID,
        confirmingConflicts: Bool,
        dependencies: TackleSyncDependencies
    ) async -> Bool {
        let repository = dependencies.repository
        let remoteStore = dependencies.remoteStore
        var didChange = false
        do {
            let pending = try repository.pendingMutations(
                ownerID: ownerID,
                confirmingConflicts: confirmingConflicts
            )
            for mutation in pending {
                do {
                    try await processTackleMutation(
                        mutation,
                        repository: repository,
                        remoteStore: remoteStore
                    )
                    didChange = true
                } catch {
                    try? repository.markFailed(mutation, error: error)
                    statusMessage = "A tackle change is safe on this device and will retry when connected."
                    didChange = true
                }
            }

            let remoteItems = try await remoteStore.fetch(ownerID: ownerID)
            let missingPhotos = try repository.merge(remoteItems, ownerID: ownerID)
            for item in missingPhotos {
                guard let path = item.photoStoragePath else { continue }
                do {
                    let data = try await remoteStore.download(path: path)
                    try await repository.markDownloaded(item, data: data)
                    didChange = true
                } catch {
                    statusMessage = "A tackle photo will download when the connection is available."
                }
            }
        } catch {
            statusMessage = "Tackle Box sync unavailable. Local items are safe."
        }
        return didChange
    }

    private func processTackleMutation(
        _ mutation: PendingTackleMutation,
        repository: SwiftDataTackleRepository,
        remoteStore: any TackleRemoteStore
    ) async throws {
        try repository.markSyncing(mutation)
        switch mutation.stage {
        case .uploadBinary:
            guard let path = mutation.item.photoStoragePath else {
                throw TackleRepositoryError.missingPhoto(mutation.item.id)
            }
            let data = try await repository.binaryDataAsync(for: mutation)
            try await remoteStore.upload(data: data, path: path)
            try repository.markBinaryUploaded(mutation)
            try await applyTackleMetadata(mutation, repository: repository, remoteStore: remoteStore)
        case .upsertMetadata:
            try await applyTackleMetadata(mutation, repository: repository, remoteStore: remoteStore)
        case .removeObsoleteBinaries:
            try await remoteStore.remove(paths: mutation.obsoleteStoragePaths)
            try repository.markObsoleteBinariesRemoved(mutation)
        }
    }

    private func applyTackleMetadata(
        _ mutation: PendingTackleMutation,
        repository: SwiftDataTackleRepository,
        remoteStore: any TackleRemoteStore
    ) async throws {
        switch try await remoteStore.apply(mutation) {
        case let .applied(remote):
            let appliedCurrentMutation = try repository.markMetadataApplied(mutation, remote: remote)
            if appliedCurrentMutation, !mutation.obsoleteStoragePaths.isEmpty {
                try await remoteStore.remove(paths: mutation.obsoleteStoragePaths)
                try repository.markObsoleteBinariesRemoved(mutation)
            }
        case let .conflict(remote):
            try repository.markConflict(mutation, remote: remote)
            statusMessage = "A tackle item changed elsewhere. Retry sync to keep this version."
        }
    }

    private func syncPhotos(
        ownerID: UUID,
        confirmingConflicts: Bool,
        dependencies: PhotoSyncDependencies
    ) async -> Bool {
        let repository = dependencies.repository
        let remoteStore = dependencies.remoteStore
        var didChange = false
        do {
            let pending = try repository.pendingMutations(
                ownerID: ownerID,
                confirmingConflicts: confirmingConflicts
            )
            for mutation in pending {
                do {
                    try await processPhotoMutation(mutation, repository: repository, remoteStore: remoteStore)
                    didChange = true
                } catch {
                    try? repository.markFailed(mutation, error: error)
                    statusMessage = "A photo is safe on this device and will retry when connected."
                    didChange = true
                }
            }

            let remotePhotos = try await remoteStore.fetch(ownerID: ownerID)
            let missingPhotos = try repository.merge(remotePhotos, ownerID: ownerID)
            for photo in missingPhotos {
                do {
                    let data = try await remoteStore.download(path: photo.storagePath)
                    try await repository.markDownloaded(photo, data: data)
                    didChange = true
                } catch {
                    statusMessage = "A remote photo will download when the connection is available."
                }
            }
        } catch {
            statusMessage = "Photo sync unavailable. Local photos are safe."
        }
        return didChange
    }

    private func processPhotoMutation(
        _ mutation: PendingPhotoMutation,
        repository: SwiftDataCatchPhotoRepository,
        remoteStore: any CatchPhotoRemoteStore
    ) async throws {
        try repository.markSyncing(mutation)
        switch mutation.stage {
        case .uploadBinary:
            let data = try await repository.binaryDataAsync(for: mutation)
            try await remoteStore.upload(
                data: data,
                path: mutation.photo.storagePath
            )
            try repository.markBinaryUploaded(mutation)
            let metadataApplied = try await applyPhotoMetadata(
                mutation,
                repository: repository,
                remoteStore: remoteStore
            )
            if metadataApplied, mutation.kind == .delete {
                try await removePhotoBinary(mutation, repository: repository, remoteStore: remoteStore)
            }
        case .upsertMetadata, .deleteMetadata:
            let metadataApplied = try await applyPhotoMetadata(
                mutation,
                repository: repository,
                remoteStore: remoteStore
            )
            if metadataApplied, mutation.kind == .delete {
                try await removePhotoBinary(mutation, repository: repository, remoteStore: remoteStore)
            }
        case .deleteBinary:
            try await removePhotoBinary(mutation, repository: repository, remoteStore: remoteStore)
        }
    }

    private func applyPhotoMetadata(
        _ mutation: PendingPhotoMutation,
        repository: SwiftDataCatchPhotoRepository,
        remoteStore: any CatchPhotoRemoteStore
    ) async throws -> Bool {
        switch try await remoteStore.apply(mutation) {
        case let .applied(remote):
            try repository.markMetadataApplied(mutation, remote: remote)
            return true
        case let .conflict(remote):
            try repository.markConflict(mutation, remote: remote)
            statusMessage = "Photo order changed elsewhere. Retry sync to keep this order."
            return false
        }
    }

    private func removePhotoBinary(
        _ mutation: PendingPhotoMutation,
        repository: SwiftDataCatchPhotoRepository,
        remoteStore: any CatchPhotoRemoteStore
    ) async throws {
        try await remoteStore.remove(path: mutation.photo.storagePath)
        try repository.markBinaryDeleted(mutation)
    }
}
