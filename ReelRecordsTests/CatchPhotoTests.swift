import ImageIO
@testable import LincolnReelRecords
import SwiftData
import UIKit
import UniformTypeIdentifiers
import XCTest

@MainActor
final class CatchPhotoTests: XCTestCase {
    func testNormalizerLimitsDimensionsAndStripsGPSMetadata() throws {
        let source = try jpegWithGPS(width: 3000, height: 2400)

        let normalized = try PhotoImageNormalizer.normalize(source)

        XCTAssertEqual(max(normalized.pixelWidth, normalized.pixelHeight), 2048)
        XCTAssertLessThan(normalized.data.count, source.count)
        let properties = try XCTUnwrap(imageProperties(normalized.data))
        XCTAssertNil(properties[kCGImagePropertyGPSDictionary as String])
    }

    func testDraftCommitReorderRemovalAndCancellationOwnTheirFiles() throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let ownerID = UUID()
        let catchID = UUID()
        let sessionID = UUID()
        let first = try store.repository.stage(data: jpeg(width: 60, height: 40), sessionID: sessionID)
        let second = try store.repository.stage(data: jpeg(width: 40, height: 60), sessionID: sessionID)

        try store.repository.saveOrder(
            catchID: catchID,
            ownerID: ownerID,
            orderedIDs: [second.id, first.id],
            drafts: [first, second]
        )

        var photos = try store.repository.photos(catchID: catchID, ownerID: ownerID)
        XCTAssertEqual(photos.map(\.id), [second.id, first.id])
        XCTAssertTrue(photos.allSatisfy { store.repository.fileURL(for: $0) != nil })
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 2)

        try store.repository.saveOrder(
            catchID: catchID,
            ownerID: ownerID,
            orderedIDs: [first.id],
            drafts: []
        )
        photos = try store.repository.photos(catchID: catchID, ownerID: ownerID)
        XCTAssertEqual(photos.map(\.id), [first.id])
        XCTAssertEqual(photos.first?.position, 0)
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 1)

        let cancelledSession = UUID()
        let cancelled = try store.repository.stage(
            data: jpeg(width: 30, height: 30),
            sessionID: cancelledSession
        )
        XCTAssertNotNil(store.repository.fileURL(for: cancelled))
        try store.repository.discardDrafts(sessionID: cancelledSession)
        XCTAssertNil(store.repository.fileURL(for: cancelled))
        XCTAssertNotNil(try store.repository.fileURL(for: XCTUnwrap(photos.first)))
    }

    func testDraftCommitIsRetrySafeAndBatchFailureRollsBackMoves() throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let ownerID = UUID()
        let catchID = UUID()
        let sessionID = UUID()
        let draft = try store.repository.stage(data: jpeg(width: 60, height: 40), sessionID: sessionID)

        let firstCommit = try store.repository.fileStore.commit(draft, ownerID: ownerID, catchID: catchID)
        XCTAssertTrue(firstCommit.didMove)
        try store.repository.saveOrder(
            catchID: catchID,
            ownerID: ownerID,
            orderedIDs: [draft.id],
            drafts: [draft]
        )
        XCTAssertEqual(try store.repository.photos(catchID: catchID, ownerID: ownerID).map(\.id), [draft.id])

        let rollbackSessionID = UUID()
        let rollbackDraft = try store.repository.stage(
            data: jpeg(width: 40, height: 40),
            sessionID: rollbackSessionID
        )
        let missingDraft = DraftPhoto(
            id: UUID(),
            sessionID: rollbackSessionID,
            relativePath: "Drafts/\(rollbackSessionID.uuidString.lowercased())/missing.jpg"
        )
        XCTAssertThrowsError(try store.repository.fileStore.commit(
            [rollbackDraft, missingDraft],
            ownerID: ownerID,
            catchID: UUID()
        ))
        XCTAssertNotNil(store.repository.fileURL(for: rollbackDraft))
    }

    func testInvalidPersistedOutboxStateFailsWithoutGuessingAWorkflow() throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let ownerID = UUID()
        let catchID = UUID()
        let draft = try store.repository.stage(data: jpeg(width: 40, height: 40), sessionID: UUID())
        try store.repository.saveOrder(
            catchID: catchID,
            ownerID: ownerID,
            orderedIDs: [draft.id],
            drafts: [draft]
        )
        let operation = try XCTUnwrap(store.container.mainContext.fetch(
            FetchDescriptor<PhotoOutboxOperation>()
        ).first)
        operation.stageRaw = PhotoOutboxStage.deleteBinary.rawValue
        try store.container.mainContext.save()

        XCTAssertThrowsError(try store.repository.pendingMutations(ownerID: ownerID)) { error in
            XCTAssertEqual(error as? CatchPhotoRepositoryError, .invalidOperation(operation.id))
        }
    }

    func testCreateReorderDeleteAndFreshStoreRecoveryCompleteInOneSync() async throws {
        let firstStore = try makeStore()
        defer { firstStore.cleanup() }
        let ownerID = UUID()
        let catchRemote = InMemoryCatchRemoteStore()
        let photoRemote = InMemoryCatchPhotoRemoteStore()
        let firstCoordinator = SyncCoordinator(
            repository: firstStore.catchRepository,
            remoteStore: catchRemote,
            photoSync: PhotoSyncDependencies(repository: firstStore.repository, remoteStore: photoRemote)
        )
        let fixture = try addTwoPhotos(store: firstStore, ownerID: ownerID)

        await firstCoordinator.sync(ownerID: ownerID)
        try await verifyInitialSync(
            fixture: fixture,
            store: firstStore,
            ownerID: ownerID,
            remote: photoRemote
        )
        try await reorderAndDeleteFirst(
            fixture: fixture,
            store: firstStore,
            ownerID: ownerID,
            coordinator: firstCoordinator,
            remote: photoRemote
        )
        try await verifyRecovery(
            catchID: fixture.catchItem.id,
            expectedPhotoID: fixture.second.id,
            ownerID: ownerID,
            catchRemote: catchRemote,
            photoRemote: photoRemote
        )
    }

    func testUploadFailurePreservesLocalPhotoForRetry() async throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let ownerID = UUID()
        let catchRemote = InMemoryCatchRemoteStore()
        let catchItem = try store.catchRepository.create(NewCatch(
            ownerID: ownerID,
            species: "Bluegill",
            caughtAt: .now
        ))
        let draft = try store.repository.stage(data: jpeg(width: 40, height: 40), sessionID: UUID())
        try store.repository.saveOrder(
            catchID: catchItem.id,
            ownerID: ownerID,
            orderedIDs: [draft.id],
            drafts: [draft]
        )
        let coordinator = SyncCoordinator(
            repository: store.catchRepository,
            remoteStore: catchRemote,
            photoSync: PhotoSyncDependencies(
                repository: store.repository,
                remoteStore: FailingUploadPhotoRemoteStore()
            )
        )

        await coordinator.sync(ownerID: ownerID)

        let photo = try XCTUnwrap(store.repository.photos(catchID: catchItem.id, ownerID: ownerID).first)
        XCTAssertEqual(photo.syncState, .failed)
        XCTAssertNotNil(photo.syncError)
        XCTAssertNotNil(store.repository.fileURL(for: photo))
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 1)
    }

    private func makeStore() throws -> PhotoTestStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("reel-records-photo-tests-\(UUID().uuidString)", isDirectory: true)
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            CatchPhotoRecord.self,
            PhotoOutboxOperation.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return try PhotoTestStore(container: container, rootURL: root)
    }

    private func addTwoPhotos(store: PhotoTestStore, ownerID: UUID) throws -> PhotoFixture {
        let catchItem = try store.catchRepository.create(NewCatch(
            ownerID: ownerID,
            species: "Smallmouth Bass",
            caughtAt: .now
        ))
        let sessionID = UUID()
        let first = try store.repository.stage(data: jpeg(width: 80, height: 50), sessionID: sessionID)
        let second = try store.repository.stage(data: jpeg(width: 50, height: 80), sessionID: sessionID)
        try store.repository.saveOrder(
            catchID: catchItem.id,
            ownerID: ownerID,
            orderedIDs: [first.id, second.id],
            drafts: [first, second]
        )
        return PhotoFixture(catchItem: catchItem, first: first, second: second)
    }

    private func verifyInitialSync(
        fixture: PhotoFixture,
        store: PhotoTestStore,
        ownerID: UUID,
        remote: InMemoryCatchPhotoRemoteStore
    ) async throws {
        let photos = try store.repository.photos(catchID: fixture.catchItem.id, ownerID: ownerID)
        XCTAssertEqual(photos.map(\.syncState), [.synced, .synced])
        XCTAssertEqual(try store.repository.pendingCount(ownerID: ownerID), 0)
        for photo in photos {
            let exists = await remote.containsObject(path: photo.storagePath)
            XCTAssertTrue(exists)
        }
    }

    private func reorderAndDeleteFirst(
        fixture: PhotoFixture,
        store: PhotoTestStore,
        ownerID: UUID,
        coordinator: SyncCoordinator,
        remote: InMemoryCatchPhotoRemoteStore
    ) async throws {
        try store.repository.saveOrder(
            catchID: fixture.catchItem.id,
            ownerID: ownerID,
            orderedIDs: [fixture.second.id, fixture.first.id],
            drafts: []
        )
        await coordinator.sync(ownerID: ownerID)
        let liveRemoteIDs = await remote.fetch(ownerID: ownerID)
            .filter { $0.deletedAt == nil }
            .map(\.id)
        XCTAssertEqual(liveRemoteIDs, [fixture.second.id, fixture.first.id])

        let photos = try store.repository.photos(catchID: fixture.catchItem.id, ownerID: ownerID)
        let removedPath = try XCTUnwrap(photos.first { $0.id == fixture.first.id }?.storagePath)
        try store.repository.saveOrder(
            catchID: fixture.catchItem.id,
            ownerID: ownerID,
            orderedIDs: [fixture.second.id],
            drafts: []
        )
        await coordinator.sync(ownerID: ownerID)
        let objectRemains = await remote.containsObject(path: removedPath)
        XCTAssertFalse(objectRemains)
    }

    private func verifyRecovery(
        catchID: UUID,
        expectedPhotoID: UUID,
        ownerID: UUID,
        catchRemote: InMemoryCatchRemoteStore,
        photoRemote: InMemoryCatchPhotoRemoteStore
    ) async throws {
        let store = try makeStore()
        defer { store.cleanup() }
        let coordinator = SyncCoordinator(
            repository: store.catchRepository,
            remoteStore: catchRemote,
            photoSync: PhotoSyncDependencies(repository: store.repository, remoteStore: photoRemote)
        )
        await coordinator.sync(ownerID: ownerID)
        let photos = try store.repository.photos(catchID: catchID, ownerID: ownerID)
        XCTAssertEqual(photos.map(\.id), [expectedPhotoID])
        XCTAssertNotNil(try store.repository.fileURL(for: XCTUnwrap(photos.first)))
    }

    private func jpeg(width: Int, height: Int) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { context in
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }.jpegData(compressionQuality: 0.95)!
    }

    private func jpegWithGPS(width: Int, height: Int) throws -> Data {
        let image = try XCTUnwrap(UIImage(data: jpeg(width: width, height: height))?.cgImage)
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        let properties = [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 42.0,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 73.0,
                kCGImagePropertyGPSLongitudeRef: "W"
            ]
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, properties)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func imageProperties(_ data: Data) -> [String: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
    }
}

private struct PhotoFixture {
    let catchItem: CatchItem
    let first: DraftPhoto
    let second: DraftPhoto
}

@MainActor
private final class PhotoTestStore {
    let container: ModelContainer
    let catchRepository: SwiftDataCatchRepository
    let repository: SwiftDataCatchPhotoRepository
    let rootURL: URL

    init(container: ModelContainer, rootURL: URL) throws {
        self.container = container
        self.rootURL = rootURL
        catchRepository = SwiftDataCatchRepository(modelContext: container.mainContext)
        repository = try SwiftDataCatchPhotoRepository(
            modelContext: container.mainContext,
            fileStore: PhotoFileStore(rootURL: rootURL)
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private actor FailingUploadPhotoRemoteStore: CatchPhotoRemoteStore {
    func upload(data _: Data, path _: String) throws {
        throw URLError(.notConnectedToInternet)
    }

    func apply(_ mutation: PendingPhotoMutation) -> PhotoMutationResult {
        .applied(mutation.photo)
    }

    func remove(path _: String) {}

    func download(path _: String) throws -> Data {
        throw URLError(.fileDoesNotExist)
    }

    func fetch(ownerID _: UUID) -> [RemoteCatchPhoto] {
        []
    }
}
