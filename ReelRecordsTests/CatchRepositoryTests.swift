@testable import LincolnReelRecords
import SwiftData
import XCTest

@MainActor
final class CatchRepositoryTests: XCTestCase {
    func testCreateCommitsCatchAndOutboxLocally() throws {
        let store = try makeStore()
        let repository = store.repository
        let ownerID = UUID()
        let caughtAt = Date(timeIntervalSince1970: 1_700_000_000)

        let created = try repository.create(NewCatch(
            ownerID: ownerID,
            species: "  Smallmouth Bass  ",
            caughtAt: caughtAt
        ))

        XCTAssertEqual(created.species, "Smallmouth Bass")
        XCTAssertEqual(created.caughtAt, caughtAt)
        XCTAssertEqual(created.syncState, .pending)
        XCTAssertEqual(try repository.pendingCount(ownerID: ownerID), 1)
        XCTAssertEqual(try repository.list(ownerID: ownerID).map(\.id), [created.id])
    }

    func testListIsOwnerScopedAndNewestFirst() throws {
        let store = try makeStore()
        let repository = store.repository
        let ownerID = UUID()
        let otherOwnerID = UUID()
        let older = try repository.create(NewCatch(
            ownerID: ownerID,
            species: "Bluegill",
            caughtAt: Date(timeIntervalSince1970: 100)
        ))
        let newer = try repository.create(NewCatch(
            ownerID: ownerID,
            species: "Walleye",
            caughtAt: Date(timeIntervalSince1970: 200)
        ))
        _ = try repository.create(NewCatch(
            ownerID: otherOwnerID,
            species: "Northern Pike",
            caughtAt: Date(timeIntervalSince1970: 300)
        ))

        XCTAssertEqual(try repository.list(ownerID: ownerID).map(\.id), [newer.id, older.id])
    }

    func testSpeciesIsRequired() throws {
        let store = try makeStore()
        let repository = store.repository
        XCTAssertThrowsError(try repository.create(NewCatch(
            ownerID: UUID(),
            species: "   ",
            caughtAt: .now
        ))) { error in
            XCTAssertEqual(error as? CatchValidationError, .speciesRequired)
        }
    }

    func testSyncPushesPendingCatchAndClearsOutbox() async throws {
        let store = try makeStore()
        let repository = store.repository
        let ownerID = UUID()
        let created = try repository.create(NewCatch(
            ownerID: ownerID,
            species: "Rainbow Trout",
            caughtAt: .now
        ))
        let remoteStore = InMemoryCatchRemoteStore()
        let coordinator = SyncCoordinator(repository: repository, remoteStore: remoteStore)

        await coordinator.sync(ownerID: ownerID)

        XCTAssertEqual(try repository.pendingCount(ownerID: ownerID), 0)
        XCTAssertEqual(try repository.list(ownerID: ownerID).first?.syncState, .synced)
        let remoteIDs = try await remoteStore.fetch(ownerID: ownerID).map(\.id)
        XCTAssertEqual(remoteIDs, [created.id])
    }

    func testOrphanedOutboxOperationFailsExplicitly() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let missingCatchID = UUID()
        store.container.mainContext.insert(OutboxOperation(ownerID: ownerID, catchID: missingCatchID))
        try store.container.mainContext.save()

        XCTAssertThrowsError(try store.repository.pendingCreates(ownerID: ownerID)) { error in
            XCTAssertEqual(error as? CatchRepositoryError, .missingCatch(missingCatchID))
        }
    }

    func testMergeSkipsIdenticalRemoteCatch() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remoteCatch = RemoteCatch(
            id: UUID(),
            ownerID: ownerID,
            species: "Bluegill",
            caughtAt: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 90),
            updatedAt: Date(timeIntervalSince1970: 90)
        )

        XCTAssertTrue(try store.repository.merge([remoteCatch], ownerID: ownerID))
        XCTAssertFalse(try store.repository.merge([remoteCatch], ownerID: ownerID))
    }

    private func makeStore() throws -> TestStore {
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return TestStore(container: container)
    }
}

@MainActor
private final class TestStore {
    let container: ModelContainer
    let repository: SwiftDataCatchRepository

    init(container: ModelContainer) {
        self.container = container
        repository = SwiftDataCatchRepository(modelContext: container.mainContext)
    }
}
