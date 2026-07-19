import Foundation
import Observation

struct PhotoSyncDependencies {
    let repository: SwiftDataCatchPhotoRepository
    let remoteStore: any CatchPhotoRemoteStore
}

@MainActor
@Observable
final class SyncCoordinator {
    private let repository: SwiftDataCatchRepository
    private let remoteStore: any CatchRemoteStore
    private let photoSync: PhotoSyncDependencies?

    private(set) var isSyncing = false
    private(set) var revision = 0
    private(set) var statusMessage: String?

    init(
        repository: SwiftDataCatchRepository,
        remoteStore: any CatchRemoteStore,
        photoSync: PhotoSyncDependencies? = nil
    ) {
        self.repository = repository
        self.remoteStore = remoteStore
        self.photoSync = photoSync
    }

    func sync(ownerID: UUID, confirmingConflicts: Bool = false) async {
        guard !isSyncing else { return }
        isSyncing = true
        statusMessage = nil
        var didChange = false
        defer {
            isSyncing = false
            if didChange {
                revision += 1
            }
        }

        do {
            let pendingMutations = try repository.pendingMutations(
                ownerID: ownerID,
                confirmingConflicts: confirmingConflicts
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

            let remoteCatches = try await remoteStore.fetch(ownerID: ownerID)
            didChange = try repository.merge(remoteCatches, ownerID: ownerID) || didChange
            if let photoSync {
                didChange = await syncPhotos(
                    ownerID: ownerID,
                    confirmingConflicts: confirmingConflicts,
                    dependencies: photoSync
                ) || didChange
            }
        } catch {
            statusMessage = "Sync unavailable. Your local logbook is safe."
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
