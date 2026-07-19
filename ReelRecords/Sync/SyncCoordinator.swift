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

    func sync(ownerID: UUID) async {
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
            let pendingCatches = try repository.pendingCreates(ownerID: ownerID)
            if !pendingCatches.isEmpty {
                do {
                    try repository.markSyncing(pendingCatches)
                    try await remoteStore.upsert(pendingCatches.map(\.catchItem))
                    try repository.markSynced(pendingCatches)
                    didChange = true
                } catch {
                    try? repository.markFailed(pendingCatches, error: error)
                    statusMessage = "A catch is saved locally and will retry when connected."
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
