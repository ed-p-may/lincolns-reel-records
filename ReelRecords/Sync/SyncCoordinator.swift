import Foundation
import Observation

@MainActor
@Observable
final class SyncCoordinator {
    private let repository: SwiftDataCatchRepository
    private let remoteStore: any CatchRemoteStore

    private(set) var isSyncing = false
    private(set) var revision = 0
    private(set) var statusMessage: String?

    init(repository: SwiftDataCatchRepository, remoteStore: any CatchRemoteStore) {
        self.repository = repository
        self.remoteStore = remoteStore
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
        } catch {
            statusMessage = "Sync unavailable. Your local logbook is safe."
        }
    }
}
