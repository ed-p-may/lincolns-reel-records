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

    func testSyncedCatchRejectsConcurrentSubsecondTimestampShift() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let initialCaughtAt = Date(timeIntervalSince1970: 1_700_000_000.100)
        let created = try env.catchRepository.create(NewCatch(
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(caughtAt: initialCaughtAt, notes: "v1")
        ))
        await env.coordinator.sync(ownerID: env.ownerID)
        let openingCatch = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        let snapshot = CatchEditSnapshot(catchItem: openingCatch, photos: [])

        // Another device shifts caughtAt by 5 ms on an already-synced catch.
        let shiftedCaughtAt = initialCaughtAt.addingTimeInterval(0.005)
        try await env.seedRemoteCatchUpdate(
            from: openingCatch,
            values: ConcurrencyTestEnvironment.makeValues(caughtAt: shiftedCaughtAt, notes: "v1")
        )
        await env.coordinator.sync(ownerID: env.ownerID)

        XCTAssertThrowsError(try env.persist(
            snapshot: snapshot,
            submittedValues: ConcurrencyTestEnvironment.makeValues(
                caughtAt: initialCaughtAt.addingTimeInterval(600),
                notes: "v1"
            )
        )) { error in
            XCTAssertEqual(error as? CatchRepositoryError, .concurrentChange(created.id))
        }

        let live = try XCTUnwrap(env.catchRepository.item(id: created.id, ownerID: env.ownerID))
        XCTAssertEqual(live.caughtAt, shiftedCaughtAt)
        XCTAssertEqual(try env.catchRepository.pendingCount(ownerID: env.ownerID), 0)
    }

    func testSyncedCatchWithTrailingNewlineAllowsSubsequentEdit() async throws {
        let env = try ConcurrencyTestEnvironment.make()
        defer { env.cleanup() }

        let catchID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        await env.catchRemote.seed(RemoteCatch(
            id: catchID,
            ownerID: env.ownerID,
            values: ConcurrencyTestEnvironment.makeValues(notes: "Synced note with newline\n"),
            createdAt: now,
            updatedAt: now,
            deletedAt: nil,
            version: 1
        ))
        await env.coordinator.sync(ownerID: env.ownerID)
        let openingCatch = try XCTUnwrap(env.catchRepository.item(id: catchID, ownerID: env.ownerID))
        let snapshot = CatchEditSnapshot(catchItem: openingCatch, photos: [])

        let result = try env.persist(
            snapshot: snapshot,
            submittedValues: CatchValues(
                species: openingCatch.species,
                weight: 4.5,
                length: openingCatch.length,
                caughtAt: openingCatch.caughtAt,
                location: openingCatch.location,
                coordinate: openingCatch.coordinate,
                conditions: openingCatch.conditions,
                tackleItemID: openingCatch.tackleItemID,
                lureText: openingCatch.lureText,
                rodReel: openingCatch.rodReel,
                notes: openingCatch.notes,
                released: openingCatch.released,
                bookmarked: openingCatch.bookmarked
            )
        )
        XCTAssertTrue(result.didMutate)
        XCTAssertEqual(try env.catchRepository.item(id: catchID, ownerID: env.ownerID)?.weight, 4.5)
    }
}
