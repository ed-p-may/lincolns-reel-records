import Foundation

extension SyncCoordinator {
    func syncProfile(
        ownerID: UUID,
        confirmingConflicts: Bool,
        dependencies: ProfileSyncDependencies
    ) async -> Bool {
        let repository = dependencies.repository
        let remoteStore = dependencies.remoteStore
        var didChange = false
        do {
            if let mutation = try repository.pendingMutation(
                ownerID: ownerID,
                confirmingConflicts: confirmingConflicts
            ) {
                do {
                    try await processProfileMutation(
                        mutation,
                        repository: repository,
                        remoteStore: remoteStore
                    )
                    didChange = true
                } catch {
                    try? repository.markFailed(mutation, error: error)
                    statusMessage = "A profile change is safe on this device and will retry when connected."
                    didChange = true
                }
            }

            if let remote = try await remoteStore.fetch(ownerID: ownerID) {
                let mergeResult = try repository.merge(remote, ownerID: ownerID)
                didChange = mergeResult.didChange || didChange
                if let missingAvatar = mergeResult.missingAvatar {
                    didChange = await downloadAvatar(
                        missingAvatar,
                        repository: repository,
                        remoteStore: remoteStore
                    ) || didChange
                }
            }
        } catch {
            statusMessage = "Profile sync unavailable. Local profile changes are safe."
        }
        return didChange
    }

    private func downloadAvatar(
        _ profile: UserProfile,
        repository: SwiftDataProfileRepository,
        remoteStore: any ProfileRemoteStore
    ) async -> Bool {
        guard let path = profile.avatarStoragePath else { return false }
        do {
            let data = try await remoteStore.download(path: path)
            try await repository.markDownloaded(profile, data: data)
            return true
        } catch {
            statusMessage = "Your avatar will download when the connection is available."
            return false
        }
    }

    private func processProfileMutation(
        _ mutation: PendingProfileMutation,
        repository: SwiftDataProfileRepository,
        remoteStore: any ProfileRemoteStore
    ) async throws {
        try repository.markSyncing(mutation)
        switch mutation.stage {
        case .uploadBinary:
            guard let path = mutation.profile.avatarStoragePath else {
                throw ProfileRepositoryError.missingAvatar(mutation.profile.ownerID)
            }
            let data = try await repository.binaryDataAsync(for: mutation)
            try await remoteStore.upload(data: data, path: path)
            try repository.markBinaryUploaded(mutation)
            try await applyProfileMetadata(mutation, repository: repository, remoteStore: remoteStore)
        case .upsertMetadata:
            try await applyProfileMetadata(mutation, repository: repository, remoteStore: remoteStore)
        case .removeObsoleteBinaries:
            try await remoteStore.remove(paths: mutation.obsoleteStoragePaths)
            try repository.markObsoleteBinariesRemoved(mutation)
        }
    }

    private func applyProfileMetadata(
        _ mutation: PendingProfileMutation,
        repository: SwiftDataProfileRepository,
        remoteStore: any ProfileRemoteStore
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
            statusMessage = "Your profile changed elsewhere. Retry sync to keep this version."
        }
    }
}
