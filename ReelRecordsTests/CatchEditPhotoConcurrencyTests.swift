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
}
