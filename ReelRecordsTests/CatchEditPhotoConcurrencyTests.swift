@testable import LincolnReelRecords
import SwiftData
import UIKit
import XCTest

@MainActor
final class CatchEditPhotoConcurrencyTests: XCTestCase {
    func testUntouchedSaveDoesNotDeleteConcurrentlySyncedPhoto() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let (openingCatch, openingPhotos) = try await env.createSyncedCatchWithPhotos(count: 1)
        let photoAID = try XCTUnwrap(openingPhotos.first?.id)
        let snapshot = CatchEditSnapshot(
            catchItem: openingCatch,
            photos: openingPhotos.map(CatchPhotoSnapshot.init)
        )

        let photoBID = try await env.seedRemotePhoto(catchID: openingCatch.id, position: 1)
        await env.coordinator.sync(ownerID: env.ownerID)

        let result = try env.persist(
            snapshot: snapshot,
            submittedValues: openingCatch.values,
            orderedPhotoIDs: openingPhotos.map(\.id)
        )
        XCTAssertFalse(result.didMutate)
        XCTAssertEqual(try env.photoRepository.pendingCount(ownerID: env.ownerID), 0)
        await env.coordinator.sync(ownerID: env.ownerID)

        let afterSave = try env.photoRepository.photos(catchID: openingCatch.id, ownerID: env.ownerID)
        XCTAssertEqual(afterSave.map(\.id), [photoAID, photoBID])
        let remoteActive = try await env.photoRemote.fetch(ownerID: env.ownerID).filter { $0.deletedAt == nil }
        XCTAssertEqual(Set(remoteActive.map(\.id)), Set([photoAID, photoBID]))
    }

    func testUntouchedSavePreservesConcurrentlyDeletedAndReorderedPhotos() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let (openingCatch, openingPhotos) = try await env.createSyncedCatchWithPhotos(count: 3)
        let snapshot = CatchEditSnapshot(
            catchItem: openingCatch,
            photos: openingPhotos.map(CatchPhotoSnapshot.init)
        )

        // Remote deletes photo 0 and swaps photos 2 and 1.
        try await env.deleteRemotePhoto(openingPhotos[0])
        try await env.reorderRemotePhoto(openingPhotos[2], to: 0)
        try await env.reorderRemotePhoto(openingPhotos[1], to: 1)
        await env.coordinator.sync(ownerID: env.ownerID)

        let result = try env.persist(
            snapshot: snapshot,
            submittedValues: openingCatch.values,
            orderedPhotoIDs: openingPhotos.map(\.id)
        )
        XCTAssertFalse(result.didMutate)
        XCTAssertEqual(try env.photoRepository.pendingCount(ownerID: env.ownerID), 0)
        await env.coordinator.sync(ownerID: env.ownerID)

        let expectedIDs = [openingPhotos[2].id, openingPhotos[1].id]
        XCTAssertEqual(
            try env.photoRepository.photos(catchID: openingCatch.id, ownerID: env.ownerID).map(\.id),
            expectedIDs
        )
        let remotePhotos = try await env.photoRemote.fetch(ownerID: env.ownerID)
        XCTAssertNotNil(remotePhotos.first { $0.id == openingPhotos[0].id }?.deletedAt)
        let remoteOrdered = remotePhotos
            .filter { $0.deletedAt == nil }
            .sorted { $0.position < $1.position }
            .map(\.id)
        XCTAssertEqual(remoteOrdered, expectedIDs)
    }

    func testEditedPhotosRejectOverwriteWhenConcurrentlySynced() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let (openingCatch, openingPhotos) = try await env.createSyncedCatchWithPhotos(count: 1)
        let photoAID = try XCTUnwrap(openingPhotos.first?.id)
        let snapshot = CatchEditSnapshot(
            catchItem: openingCatch,
            photos: openingPhotos.map(CatchPhotoSnapshot.init)
        )

        let photoBID = try await env.seedRemotePhoto(catchID: openingCatch.id, position: 1)
        await env.coordinator.sync(ownerID: env.ownerID)

        let sessionID = UUID()
        let draftC = try env.photoRepository.stage(data: ConcurrencyTestEnvironment.jpeg(), sessionID: sessionID)

        XCTAssertThrowsError(try env.persist(
            snapshot: snapshot,
            submittedValues: openingCatch.values,
            orderedPhotoIDs: [photoAID, draftC.id],
            draftPhotos: [draftC],
            photoSessionID: sessionID
        )) { error in
            XCTAssertEqual(error as? CatchPhotoRepositoryError, .concurrentChange(openingCatch.id))
        }

        let livePhotos = try env.photoRepository.photos(catchID: openingCatch.id, ownerID: env.ownerID)
        XCTAssertEqual(livePhotos.map(\.id), [photoAID, photoBID])
        XCTAssertEqual(try env.photoRepository.pendingCount(ownerID: env.ownerID), 0)
        XCTAssertNotNil(env.photoRepository.fileURL(for: draftC))
    }

    func testEditedPhotosRejectOverwriteAfterConcurrentReorderWithSameIDs() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let (openingCatch, openingPhotos) = try await env.createSyncedCatchWithPhotos(count: 2)
        let snapshot = CatchEditSnapshot(
            catchItem: openingCatch,
            photos: openingPhotos.map(CatchPhotoSnapshot.init)
        )

        try await env.reorderRemotePhoto(openingPhotos[1], to: 0)
        try await env.reorderRemotePhoto(openingPhotos[0], to: 1)
        await env.coordinator.sync(ownerID: env.ownerID)

        let sessionID = UUID()
        let draftC = try env.photoRepository.stage(data: ConcurrencyTestEnvironment.jpeg(), sessionID: sessionID)

        XCTAssertThrowsError(try env.persist(
            snapshot: snapshot,
            submittedValues: openingCatch.values,
            orderedPhotoIDs: [openingPhotos[0].id, openingPhotos[1].id, draftC.id],
            draftPhotos: [draftC],
            photoSessionID: sessionID
        )) { error in
            XCTAssertEqual(error as? CatchPhotoRepositoryError, .concurrentChange(openingCatch.id))
        }

        XCTAssertEqual(try env.photoRepository.pendingCount(ownerID: env.ownerID), 0)
        XCTAssertEqual(
            try env.photoRepository.photos(catchID: openingCatch.id, ownerID: env.ownerID).map(\.id),
            [openingPhotos[1].id, openingPhotos[0].id]
        )
    }

    func testOwnOfflinePhotoUploadCompletingSyncDoesNotBlockSubsequentPhotoEdit() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(notes: "offline photo")
        ))
        let photoA = try env.photoRepository.stage(data: ConcurrencyTestEnvironment.jpeg(), sessionID: UUID())
        try env.photoRepository.saveOrder(
            catchID: created.id,
            ownerID: env.ownerID,
            orderedIDs: [photoA.id],
            drafts: [photoA]
        )
        let openingPhotos = try env.photoRepository.photos(catchID: created.id, ownerID: env.ownerID)
        let snapshot = CatchEditSnapshot(
            catchItem: created,
            photos: openingPhotos.map(CatchPhotoSnapshot.init)
        )

        // Background sync uploads this device's own offline catch and photo (v0 -> v1).
        await env.coordinator.sync(ownerID: env.ownerID)
        XCTAssertEqual(
            try env.photoRepository.photos(catchID: created.id, ownerID: env.ownerID).first?.remoteVersion,
            1
        )

        let sessionID = UUID()
        let photoB = try env.photoRepository.stage(data: ConcurrencyTestEnvironment.jpeg(), sessionID: sessionID)
        let result = try env.persist(
            snapshot: snapshot,
            submittedValues: created.values,
            orderedPhotoIDs: [photoA.id, photoB.id],
            draftPhotos: [photoB],
            photoSessionID: sessionID
        )
        XCTAssertTrue(result.didMutate)
        XCTAssertEqual(
            try env.photoRepository.photos(catchID: created.id, ownerID: env.ownerID).map(\.id),
            [photoA.id, photoB.id]
        )
    }

    func testRetryingAfterPhotoFailureAndTimestampNormalizationIsNoOpWhenRebased() throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let localCaughtAt = Date(timeIntervalSince1970: 1_700_000_000.123456)
        let serverCaughtAt = localCaughtAt.addingTimeInterval(0.005)
        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(caughtAt: localCaughtAt, notes: "offline draft")
        ))
        let snapshot = CatchEditSnapshot(catchItem: created, photos: [])
        let mutation = try XCTUnwrap(env.catchRepository.pendingMutations(ownerID: env.ownerID).first)
        try env.catchRepository.markApplied(mutation, remote: RemoteCatch(
            id: created.id,
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(caughtAt: serverCaughtAt, notes: "offline draft"),
            createdAt: mutation.catchItem.createdAt,
            updatedAt: mutation.catchItem.updatedAt,
            deletedAt: nil,
            version: 1
        ))

        let sessionID = UUID()
        let missingDraft = DraftPhoto(
            id: UUID(),
            sessionID: sessionID,
            relativePath: "Drafts/\(sessionID.uuidString.lowercased())/missing.jpg"
        )
        var rebasedCatch: CatchItem?
        do {
            _ = try env.persist(
                snapshot: snapshot,
                submittedValues: ConcurrencyTestEnvironment.makeValues(caughtAt: localCaughtAt, notes: "edited"),
                orderedPhotoIDs: [missingDraft.id],
                draftPhotos: [missingDraft],
                photoSessionID: sessionID
            )
            XCTFail("Expected photosFailed error")
        } catch let CatchEditSaveError.photosFailed(savedCatch, _) {
            rebasedCatch = savedCatch
        }

        let committed = try XCTUnwrap(rebasedCatch)
        XCTAssertEqual(committed.caughtAt, serverCaughtAt)
        let retry = try env.persist(
            snapshot: CatchEditSnapshot(catchItem: committed, photos: []),
            submittedValues: ConcurrencyTestEnvironment.makeValues(caughtAt: committed.caughtAt, notes: "edited")
        )
        XCTAssertFalse(retry.didMutate)
        XCTAssertEqual(try env.catchRepository.item(id: created.id, ownerID: env.ownerID)?.caughtAt, serverCaughtAt)
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
