@testable import LincolnReelRecords
import SwiftData
import UIKit
import XCTest

@MainActor
final class CatchEditConcurrencyTests: XCTestCase {
    func testUntouchedSaveDoesNotOverwriteConcurrentlySyncedCatch() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(notes: "v1", airTemperatureF: nil)
        ))
        await env.coordinator.sync(ownerID: env.ownerID)
        let openingCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        let snapshot = CatchEditSnapshot(catchItem: openingCatch, photos: [])

        try await env.seedRemoteCatchUpdate(
            from: openingCatch,
            values: ConcurrencyTestEnvironment.makeValues(
                notes: "v2 from other device",
                airTemperatureF: 72,
                bookmarked: true
            )
        )
        await env.coordinator.sync(ownerID: env.ownerID)

        let result = try env.persist(snapshot: snapshot, submittedValues: openingCatch.values)
        XCTAssertFalse(result.didMutate)
        await env.coordinator.sync(ownerID: env.ownerID)

        let afterSave = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        XCTAssertEqual(afterSave.notes, "v2 from other device")
        XCTAssertEqual(afterSave.conditions.airTemperatureF, 72)
        XCTAssertTrue(afterSave.bookmarked)
        XCTAssertEqual(afterSave.remoteVersion, 2)
        XCTAssertEqual(afterSave.syncState, .synced)
        XCTAssertEqual(try env.catchRepository.pendingCount(ownerID: env.ownerID), 0)
        let remoteCatches = try await env.catchRemote.fetch(ownerID: env.ownerID)
        let remote = try XCTUnwrap(remoteCatches.first)
        XCTAssertEqual(remote.version, 2)
        XCTAssertEqual(remote.values.notes, "v2 from other device")
    }

    func testEditedCatchRejectsOverwriteWhenConcurrentlySynced() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(notes: "v1")
        ))
        await env.coordinator.sync(ownerID: env.ownerID)
        let openingCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        let snapshot = CatchEditSnapshot(catchItem: openingCatch, photos: [])

        try await env.seedRemoteCatchUpdate(
            from: openingCatch,
            values: ConcurrencyTestEnvironment.makeValues(notes: "v2 from other device", airTemperatureF: 72)
        )
        await env.coordinator.sync(ownerID: env.ownerID)

        XCTAssertThrowsError(try env.persist(
            snapshot: snapshot,
            submittedValues: ConcurrencyTestEnvironment.makeValues(notes: "local edit")
        )) { error in
            XCTAssertEqual(error as? CatchRepositoryError, .concurrentChange(created.id))
        }

        let live = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        XCTAssertEqual(live.notes, "v2 from other device")
        XCTAssertEqual(live.conditions.airTemperatureF, 72)
        XCTAssertEqual(live.remoteVersion, 2)
        XCTAssertEqual(try env.catchRepository.pendingCount(ownerID: env.ownerID), 0)
    }

    func testEditingBothCatchAndPhotosDoesNotPartiallySaveOnPhotoConflict() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(notes: "v1")
        ))
        await env.coordinator.sync(ownerID: env.ownerID)
        let openingCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        let snapshot = CatchEditSnapshot(catchItem: openingCatch, photos: [])

        let syncedPhotoID = try await env.seedRemotePhoto(catchID: created.id, position: 0)
        await env.coordinator.sync(ownerID: env.ownerID)

        let sessionID = UUID()
        let draft = try env.photoRepository.stage(data: ConcurrencyTestEnvironment.jpeg(), sessionID: sessionID)

        XCTAssertThrowsError(try env.persist(
            snapshot: snapshot,
            submittedValues: ConcurrencyTestEnvironment.makeValues(notes: "local edit"),
            orderedPhotoIDs: [draft.id],
            draftPhotos: [draft],
            photoSessionID: sessionID
        )) { error in
            XCTAssertEqual(error as? CatchPhotoRepositoryError, .concurrentChange(created.id))
        }

        let liveCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        XCTAssertEqual(liveCatch.notes, "v1")
        XCTAssertEqual(try env.catchRepository.pendingCount(ownerID: env.ownerID), 0)
        XCTAssertEqual(
            try env.photoRepository.photos(catchID: created.id, ownerID: env.ownerID).map(\.id),
            [syncedPhotoID]
        )
        XCTAssertEqual(try env.photoRepository.pendingCount(ownerID: env.ownerID), 0)
    }

    func testEditingCatchOnlyPreservesConcurrentlySyncedPhoto() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(notes: "v1")
        ))
        await env.coordinator.sync(ownerID: env.ownerID)
        let openingCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        let snapshot = CatchEditSnapshot(catchItem: openingCatch, photos: [])

        let syncedPhotoID = try await env.seedRemotePhoto(catchID: created.id, position: 0)
        await env.coordinator.sync(ownerID: env.ownerID)

        let result = try env.persist(
            snapshot: snapshot,
            submittedValues: ConcurrencyTestEnvironment.makeValues(notes: "updated notes")
        )
        XCTAssertTrue(result.didMutate)

        let liveCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        XCTAssertEqual(liveCatch.notes, "updated notes")
        XCTAssertEqual(
            try env.photoRepository.photos(catchID: created.id, ownerID: env.ownerID).map(\.id),
            [syncedPhotoID]
        )
        XCTAssertEqual(try env.photoRepository.pendingCount(ownerID: env.ownerID), 0)
    }

    func testEditingPhotosOnlyPreservesConcurrentlySyncedCatch() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(notes: "v1")
        ))
        await env.coordinator.sync(ownerID: env.ownerID)
        let openingCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        let snapshot = CatchEditSnapshot(catchItem: openingCatch, photos: [])

        try await env.seedRemoteCatchUpdate(
            from: openingCatch,
            values: ConcurrencyTestEnvironment.makeValues(notes: "v2 from other device", airTemperatureF: 72)
        )
        await env.coordinator.sync(ownerID: env.ownerID)

        let sessionID = UUID()
        let draft = try env.photoRepository.stage(data: ConcurrencyTestEnvironment.jpeg(), sessionID: sessionID)
        let result = try env.persist(
            snapshot: snapshot,
            submittedValues: openingCatch.values,
            orderedPhotoIDs: [draft.id],
            draftPhotos: [draft],
            photoSessionID: sessionID
        )
        XCTAssertTrue(result.didMutate)

        let liveCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        XCTAssertEqual(liveCatch.notes, "v2 from other device")
        XCTAssertEqual(liveCatch.conditions.airTemperatureF, 72)
        XCTAssertEqual(try env.catchRepository.pendingCount(ownerID: env.ownerID), 0)
        XCTAssertEqual(
            try env.photoRepository.photos(catchID: created.id, ownerID: env.ownerID).map(\.id),
            [draft.id]
        )
    }

    func testOwnOfflineCreateWithTimestampPrecisionShiftDoesNotBlockSubsequentEdit() throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let localCaughtAt = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let serverCaughtAt = localCaughtAt.addingTimeInterval(0.005)
        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(caughtAt: localCaughtAt, notes: "offline draft")
        ))
        let snapshot = CatchEditSnapshot(catchItem: created, photos: [])

        // Simulate server ack returning a 5 ms precision-shifted caughtAt timestamp.
        let mutation = try XCTUnwrap(env.catchRepository.pendingMutations(ownerID: env.ownerID).first)
        let acked = RemoteCatch(
            id: created.id,
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(caughtAt: serverCaughtAt, notes: "offline draft"),
            createdAt: mutation.catchItem.createdAt,
            updatedAt: mutation.catchItem.updatedAt,
            deletedAt: nil,
            version: 1
        )
        try env.catchRepository.markApplied(mutation, remote: acked)

        let result = try env.persist(
            snapshot: snapshot,
            submittedValues: ConcurrencyTestEnvironment.makeValues(
                caughtAt: localCaughtAt,
                notes: "edited after upload"
            )
        )
        XCTAssertTrue(result.didMutate)
        let live = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        XCTAssertEqual(live.notes, "edited after upload")
        XCTAssertEqual(live.caughtAt, serverCaughtAt)
    }
}

@MainActor
struct ConcurrencyTestEnvironment {
    let root: URL
    let container: ModelContainer
    let ownerID: UUID
    let catchRepository: SwiftDataCatchRepository
    let photoRepository: SwiftDataCatchPhotoRepository
    let tackleRepository: SwiftDataTackleRepository
    let catchRemote: InMemoryCatchRemoteStore
    let photoRemote: InMemoryCatchPhotoRemoteStore
    let coordinator: SyncCoordinator

    static func make() throws -> ConcurrencyTestEnvironment {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "reel-records-edit-concurrency-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            CatchPhotoRecord.self,
            PhotoOutboxOperation.self,
            TackleItemRecord.self,
            TackleOutboxOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let catchRepository = SwiftDataCatchRepository(modelContext: container.mainContext)
        let photoRepository = try SwiftDataCatchPhotoRepository(
            modelContext: container.mainContext,
            fileStore: PhotoFileStore(rootURL: root)
        )
        let tackleRepository = try SwiftDataTackleRepository(
            modelContext: container.mainContext,
            fileStore: PhotoFileStore(rootURL: root.appending(path: "Tackle", directoryHint: .isDirectory))
        )
        let catchRemote = InMemoryCatchRemoteStore()
        let photoRemote = InMemoryCatchPhotoRemoteStore()
        let coordinator = SyncCoordinator(
            repository: catchRepository,
            remoteStore: catchRemote,
            photoSync: PhotoSyncDependencies(repository: photoRepository, remoteStore: photoRemote)
        )
        return ConcurrencyTestEnvironment(
            root: root,
            container: container,
            ownerID: UUID(),
            catchRepository: catchRepository,
            photoRepository: photoRepository,
            tackleRepository: tackleRepository,
            catchRemote: catchRemote,
            photoRemote: photoRemote,
            coordinator: coordinator
        )
    }

    static func makeValues(
        species: String = "Bass",
        caughtAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        notes: String? = nil,
        airTemperatureF: Double? = nil,
        tackleItemID: UUID? = nil,
        bookmarked: Bool = false
    ) -> CatchValues {
        CatchValues(
            species: species,
            weight: 3.5,
            length: 17,
            caughtAt: caughtAt,
            location: "Lake Mansfield",
            coordinate: nil,
            conditions: CatchConditions(
                airTemperatureF: airTemperatureF,
                skyCondition: nil,
                waterTemperatureF: nil,
                waterClarity: nil
            ),
            tackleItemID: tackleItemID,
            lureText: nil,
            rodReel: nil,
            notes: notes,
            released: true,
            bookmarked: bookmarked
        )
    }

    static func jpeg(width: Int = 40, height: Int = 40) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        let image = renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }

    func createSyncedCatchWithPhotos(count: Int) async throws -> (CatchItem, [CatchPhotoItem]) {
        let created = try catchRepository.create(NewCatch(
            ownerID: ownerID,
            values: Self.makeValues(notes: "with photos")
        ))
        let drafts = try (0 ..< count).map { _ in
            try photoRepository.stage(data: Self.jpeg(), sessionID: UUID())
        }
        try photoRepository.saveOrder(
            catchID: created.id,
            ownerID: ownerID,
            orderedIDs: drafts.map(\.id),
            drafts: drafts
        )
        await coordinator.sync(ownerID: ownerID)
        let catchItem = try XCTUnwrap(catchRepository.item(id: created.id, ownerID: ownerID))
        let photos = try photoRepository.photos(catchID: created.id, ownerID: ownerID)
        return (catchItem, photos)
    }

    func persist(
        snapshot: CatchEditSnapshot?,
        submittedValues: CatchValues,
        orderedPhotoIDs: [UUID] = [],
        draftPhotos: [DraftPhoto] = [],
        photoSessionID: UUID = UUID()
    ) throws -> CatchEditSaveResult {
        try CatchEditSave.persist(CatchEditSaveRequest(
            ownerID: ownerID,
            snapshot: snapshot,
            submittedValues: submittedValues,
            orderedPhotoIDs: orderedPhotoIDs,
            draftPhotos: draftPhotos,
            photoSessionID: photoSessionID,
            catchRepository: catchRepository,
            photoRepository: photoRepository,
            tackleRepository: tackleRepository
        ))
    }

    func seedRemoteCatchUpdate(from current: CatchItem, values: CatchValues) async throws {
        await catchRemote.seed(RemoteCatch(
            id: current.id,
            ownerID: ownerID,
            values: values,
            createdAt: current.createdAt,
            updatedAt: current.updatedAt.addingTimeInterval(60),
            deletedAt: nil,
            version: current.remoteVersion + 1
        ))
    }

    func seedRemotePhoto(catchID: UUID, position: Int) async throws -> UUID {
        let photoID = UUID()
        let path = SwiftDataCatchPhotoRepository.storagePath(
            ownerID: ownerID,
            catchID: catchID,
            photoID: photoID
        )
        try await photoRemote.upload(data: Self.jpeg(width: 30, height: 30), path: path)
        let now = Date.now
        let remote = RemoteCatchPhoto(
            id: photoID,
            ownerID: ownerID,
            catchID: catchID,
            storagePath: path,
            position: position,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            version: 1
        )
        _ = try await photoRemote.apply(PendingPhotoMutation(
            operationID: UUID(),
            kind: .create,
            stage: .upsertMetadata,
            expectedVersion: 0,
            photo: remote,
            localRelativePath: nil
        ))
        return photoID
    }

    func reorderRemotePhoto(_ photo: CatchPhotoItem, to position: Int) async throws {
        let updated = RemoteCatchPhoto(
            id: photo.id,
            ownerID: ownerID,
            catchID: photo.catchID,
            storagePath: photo.storagePath,
            position: position,
            createdAt: photo.createdAt,
            updatedAt: photo.updatedAt.addingTimeInterval(30),
            deletedAt: nil,
            version: photo.remoteVersion + 1
        )
        _ = try await photoRemote.apply(PendingPhotoMutation(
            operationID: UUID(),
            kind: .update,
            stage: .upsertMetadata,
            expectedVersion: photo.remoteVersion,
            photo: updated,
            localRelativePath: nil
        ))
    }

    func deleteRemotePhoto(_ photo: CatchPhotoItem) async throws {
        let deleted = RemoteCatchPhoto(
            id: photo.id,
            ownerID: ownerID,
            catchID: photo.catchID,
            storagePath: photo.storagePath,
            position: photo.position,
            createdAt: photo.createdAt,
            updatedAt: photo.updatedAt.addingTimeInterval(30),
            deletedAt: Date.now,
            version: photo.remoteVersion + 1
        )
        _ = try await photoRemote.apply(PendingPhotoMutation(
            operationID: UUID(),
            kind: .delete,
            stage: .deleteMetadata,
            expectedVersion: photo.remoteVersion,
            photo: deleted,
            localRelativePath: nil
        ))
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
