@testable import LincolnReelRecords
import SwiftData
import XCTest

@MainActor
final class CatchSyncTests: XCTestCase {
    func testCreateUpdateDeleteSyncIsIdempotentAndRecoverable() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remoteStore = InMemoryCatchRemoteStore()
        let coordinator = SyncCoordinator(repository: store.repository, remoteStore: remoteStore)
        let coordinate = try XCTUnwrap(CatchCoordinate(latitude: 42.3169, longitude: -73.3226))
        let conditions = CatchConditions(
            airTemperatureF: 71,
            skyCondition: .sunny,
            waterTemperatureF: 64.5,
            waterClarity: .clear
        )
        let created = try store.repository.create(NewCatch(
            ownerID: ownerID,
            values: values(species: "Rainbow Trout", coordinate: coordinate, conditions: conditions)
        ))

        await coordinator.sync(ownerID: ownerID)
        await coordinator.sync(ownerID: ownerID)
        let synced = try XCTUnwrap(store.repository.item(id: created.id, ownerID: ownerID))
        XCTAssertEqual(synced.syncState, .synced)
        XCTAssertEqual(synced.coordinate, coordinate)
        XCTAssertEqual(synced.conditions, conditions)
        XCTAssertEqual(synced.remoteVersion, 1)
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 0)

        _ = try store.repository.update(
            id: created.id,
            ownerID: ownerID,
            values: values(species: "Rainbow Trout", weight: 2.4, notes: "Updated offline")
        )
        await coordinator.sync(ownerID: ownerID)
        let updated = try XCTUnwrap(store.repository.item(id: created.id, ownerID: ownerID))
        XCTAssertEqual(updated.weight, 2.4)
        XCTAssertEqual(updated.notes, "Updated offline")
        XCTAssertEqual(updated.remoteVersion, 2)

        try store.repository.delete(id: created.id, ownerID: ownerID)
        XCTAssertTrue(try store.repository.list(ownerID: ownerID).isEmpty)
        await coordinator.sync(ownerID: ownerID)
        let remoteCatches = try await remoteStore.fetch(ownerID: ownerID)
        let remote = try XCTUnwrap(remoteCatches.first)
        XCTAssertNotNil(remote.deletedAt)
        XCTAssertEqual(remote.version, 3)

        let recoveredStore = try makeStore()
        XCTAssertTrue(try recoveredStore.repository.merge([remote], ownerID: ownerID))
        XCTAssertTrue(try recoveredStore.repository.list(ownerID: ownerID).isEmpty)
    }

    func testSyncedCatchEditAndTombstoneSurviveDiskStoreRelaunch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "reel-records-phase2-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "catches.store")
        let ownerID = UUID()

        let catchID = try createSyncedCatch(storeURL: storeURL, ownerID: ownerID)
        try verifyAndEditCatch(id: catchID, storeURL: storeURL, ownerID: ownerID)
        try verifyAndDeleteCatch(id: catchID, storeURL: storeURL, ownerID: ownerID)
        try verifyTombstone(id: catchID, storeURL: storeURL, ownerID: ownerID)
    }

    func testDivergentRemoteEditRequiresExplicitKeepMineRetry() async throws {
        let ownerID = UUID()
        let remoteStore = InMemoryCatchRemoteStore()
        let firstStore = try makeStore()
        let secondStore = try makeStore()
        let firstCoordinator = SyncCoordinator(repository: firstStore.repository, remoteStore: remoteStore)
        let secondCoordinator = SyncCoordinator(repository: secondStore.repository, remoteStore: remoteStore)
        let created = try firstStore.repository.create(NewCatch(ownerID: ownerID, species: "Bass", caughtAt: .now))
        await firstCoordinator.sync(ownerID: ownerID)
        let remoteCatches = try await remoteStore.fetch(ownerID: ownerID)
        let seed = try XCTUnwrap(remoteCatches.first)
        _ = try secondStore.repository.merge([seed], ownerID: ownerID)

        _ = try firstStore.repository.update(
            id: created.id,
            ownerID: ownerID,
            values: values(species: "Bass", notes: "First device")
        )
        _ = try secondStore.repository.update(
            id: created.id,
            ownerID: ownerID,
            values: values(species: "Bass", notes: "Second device")
        )
        await firstCoordinator.sync(ownerID: ownerID)
        await secondCoordinator.sync(ownerID: ownerID)

        let conflicted = try XCTUnwrap(secondStore.repository.item(id: created.id, ownerID: ownerID))
        XCTAssertEqual(conflicted.notes, "Second device")
        XCTAssertEqual(conflicted.syncState, .conflict)
        XCTAssertTrue(try secondStore.repository.pendingMutations(ownerID: ownerID).isEmpty)
        XCTAssertEqual(try secondStore.repository.pendingCount(ownerID: ownerID), 1)

        await secondCoordinator.sync(ownerID: ownerID, confirmingConflicts: true)
        let resolved = try XCTUnwrap(secondStore.repository.item(id: created.id, ownerID: ownerID))
        XCTAssertEqual(resolved.notes, "Second device")
        XCTAssertEqual(resolved.syncState, .synced)
        XCTAssertEqual(resolved.remoteVersion, 3)
        XCTAssertEqual(try secondStore.repository.pendingCount(ownerID: ownerID), 0)
    }

    func testIdempotentCreateToleratesBackendTimestampPrecision() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let created = try store.repository.create(NewCatch(ownerID: ownerID, species: "Perch", caughtAt: .now))
        let mutation = try XCTUnwrap(store.repository.pendingMutations(ownerID: ownerID).first)
        let remoteStore = InMemoryCatchRemoteStore()
        await remoteStore.seed(RemoteCatch(
            id: created.id,
            ownerID: ownerID,
            values: CatchValues(
                species: created.species,
                weight: created.weight,
                length: created.length,
                caughtAt: created.caughtAt.addingTimeInterval(0.005),
                location: created.location,
                coordinate: created.coordinate,
                conditions: created.conditions,
                lureText: created.lureText,
                rodReel: created.rodReel,
                notes: created.notes,
                released: created.released
            ),
            createdAt: mutation.catchItem.createdAt.addingTimeInterval(10),
            updatedAt: mutation.catchItem.updatedAt.addingTimeInterval(10),
            deletedAt: nil,
            version: 1
        ))
        let coordinator = SyncCoordinator(repository: store.repository, remoteStore: remoteStore)

        await coordinator.sync(ownerID: ownerID)

        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 0)
        XCTAssertEqual(try store.repository.item(id: created.id, ownerID: ownerID)?.syncState, .synced)
    }

    func testDeletingAlreadyMissingRemoteCatchIsIdempotent() async throws {
        let ownerID = UUID()
        let deletedAt = Date.now
        let remote = RemoteCatch(
            id: UUID(),
            ownerID: ownerID,
            values: values(species: "Perch"),
            createdAt: deletedAt.addingTimeInterval(-20),
            updatedAt: deletedAt,
            deletedAt: deletedAt,
            version: 2
        )
        let mutation = PendingCatchMutation(
            operationID: UUID(),
            kind: .delete,
            expectedVersion: 1,
            catchItem: remote
        )
        let remoteStore = InMemoryCatchRemoteStore()

        let result = try await remoteStore.apply(mutation)
        XCTAssertEqual(result, .applied(remote))
    }

    private func createSyncedCatch(storeURL: URL, ownerID: UUID) throws -> UUID {
        let store = try makeDiskStore(url: storeURL)
        let created = try store.repository.create(NewCatch(
            ownerID: ownerID,
            values: values(
                species: "Pickerel",
                weight: 2.75,
                length: 19,
                location: "Lake Mansfield",
                coordinate: CatchCoordinate(latitude: 42.1965, longitude: -73.3526),
                conditions: CatchConditions(
                    airTemperatureF: 68,
                    skyCondition: .overcast,
                    waterTemperatureF: 62,
                    waterClarity: .stained
                ),
                lureText: "Spinnerbait",
                rodReel: "Medium casting",
                notes: "Initial note",
                released: true
            )
        ))
        let mutation = try XCTUnwrap(store.repository.pendingMutations(ownerID: ownerID).first)
        try store.repository.markApplied(mutation, remote: mutation.catchItem)
        return created.id
    }

    private func verifyAndEditCatch(id: UUID, storeURL: URL, ownerID: UUID) throws {
        let store = try makeDiskStore(url: storeURL)
        let reopened = try XCTUnwrap(store.repository.item(id: id, ownerID: ownerID))
        XCTAssertEqual(reopened.weight, 2.75)
        XCTAssertEqual(reopened.length, 19)
        XCTAssertEqual(reopened.location, "Lake Mansfield")
        XCTAssertEqual(reopened.coordinate, CatchCoordinate(latitude: 42.1965, longitude: -73.3526))
        XCTAssertEqual(reopened.conditions.airTemperatureF, 68)
        XCTAssertEqual(reopened.conditions.skyCondition, .overcast)
        XCTAssertEqual(reopened.conditions.waterTemperatureF, 62)
        XCTAssertEqual(reopened.conditions.waterClarity, .stained)
        XCTAssertEqual(reopened.lureText, "Spinnerbait")
        XCTAssertEqual(reopened.rodReel, "Medium casting")
        XCTAssertEqual(reopened.notes, "Initial note")
        XCTAssertTrue(reopened.released)
        XCTAssertEqual(reopened.remoteVersion, 1)
        _ = try store.repository.update(
            id: id,
            ownerID: ownerID,
            values: values(species: "Pickerel", notes: "Edited offline")
        )
    }

    private func verifyAndDeleteCatch(id: UUID, storeURL: URL, ownerID: UUID) throws {
        let store = try makeDiskStore(url: storeURL)
        let edited = try XCTUnwrap(store.repository.item(id: id, ownerID: ownerID))
        XCTAssertEqual(edited.notes, "Edited offline")
        XCTAssertEqual(edited.syncState, .pending)
        XCTAssertEqual(try store.repository.pendingMutations(ownerID: ownerID).first?.kind, .update)
        try store.repository.delete(id: id, ownerID: ownerID)
    }

    private func verifyTombstone(id: UUID, storeURL: URL, ownerID: UUID) throws {
        let store = try makeDiskStore(url: storeURL)
        XCTAssertTrue(try store.repository.list(ownerID: ownerID).isEmpty)
        XCTAssertNotNil(try store.repository.item(id: id, ownerID: ownerID)?.deletedAt)
        XCTAssertEqual(try store.repository.pendingMutations(ownerID: ownerID).first?.kind, .delete)
    }

    private func makeStore() throws -> SyncTestStore {
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return SyncTestStore(container: container)
    }

    private func makeDiskStore(url: URL) throws -> SyncTestStore {
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            configurations: ModelConfiguration(url: url)
        )
        return SyncTestStore(container: container)
    }

    private func values(
        species: String,
        weight: Double? = nil,
        length: Double? = nil,
        caughtAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        location: String? = nil,
        coordinate: CatchCoordinate? = nil,
        conditions: CatchConditions = .empty,
        lureText: String? = nil,
        rodReel: String? = nil,
        notes: String? = nil,
        released: Bool = true
    ) -> CatchValues {
        CatchValues(
            species: species,
            weight: weight,
            length: length,
            caughtAt: caughtAt,
            location: location,
            coordinate: coordinate,
            conditions: conditions,
            lureText: lureText,
            rodReel: rodReel,
            notes: notes,
            released: released
        )
    }
}

@MainActor
private final class SyncTestStore {
    let container: ModelContainer
    let repository: SwiftDataCatchRepository

    init(container: ModelContainer) {
        self.container = container
        repository = SwiftDataCatchRepository(modelContext: container.mainContext)
    }
}
