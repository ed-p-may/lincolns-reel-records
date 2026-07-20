import Foundation

@MainActor
final class SyncSuspension {
    private var ownerIDs: Set<UUID> = []
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    func contains(_ ownerID: UUID) -> Bool {
        ownerIDs.contains(ownerID)
    }

    func suspend(_ ownerID: UUID) {
        ownerIDs.insert(ownerID)
    }

    func resume(_ ownerID: UUID) {
        ownerIDs.remove(ownerID)
    }

    func appendIdleWaiter(_ continuation: CheckedContinuation<Void, Never>) {
        idleWaiters.append(continuation)
    }

    func resumeIdleWaiters() {
        idleWaiters.forEach { $0.resume() }
        idleWaiters = []
    }
}

extension SyncCoordinator {
    func suspendAndWait(ownerID: UUID) async {
        suspension.suspend(ownerID)
        guard isSyncing else { return }
        await withCheckedContinuation { suspension.appendIdleWaiter($0) }
    }

    func resume(ownerID: UUID) {
        suspension.resume(ownerID)
    }
}
