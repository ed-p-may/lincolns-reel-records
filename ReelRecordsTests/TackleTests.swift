@testable import LincolnReelRecords
import SwiftData
import UIKit
import XCTest

@MainActor
final class TackleTests: XCTestCase {
    func testCreateEditArchiveRestoreAndDiscoveryStayOwnerScoped() throws {
        let store = try makeStore()
        let ownerID = UUID()
        let otherOwnerID = UUID()
        let created = try store.tackleRepository.create(NewTackleItem(
            ownerID: ownerID,
            values: values(name: "  Green Pumpkin Senko  ", size: " 5\" ", color: " Green Pumpkin ")
        ))
        _ = try store.tackleRepository.create(NewTackleItem(
            ownerID: otherOwnerID,
            values: values(name: "Other owner's jig", type: .jig)
        ))

        XCTAssertEqual(created.name, "Green Pumpkin Senko")
        XCTAssertEqual(created.size, "5\"")
        XCTAssertEqual(created.color, "Green Pumpkin")
        XCTAssertEqual(try store.tackleRepository.items(ownerID: ownerID).map(\.id), [created.id])
        XCTAssertEqual(
            try TackleDiscovery.results(
                in: store.tackleRepository.items(ownerID: ownerID),
                query: "pumpkin",
                type: .softPlastic
            ).map(\.id),
            [created.id]
        )

        let archived = try store.tackleRepository.update(
            id: created.id,
            ownerID: ownerID,
            values: values(name: created.name, archived: true)
        )
        XCTAssertTrue(archived.archived)
        XCTAssertTrue(try store.tackleRepository.items(ownerID: ownerID).isEmpty)
        XCTAssertEqual(try store.tackleRepository.items(ownerID: ownerID, archived: true).map(\.id), [created.id])

        _ = try store.tackleRepository.update(
            id: created.id,
            ownerID: ownerID,
            values: values(name: created.name)
        )
        XCTAssertEqual(try store.tackleRepository.items(ownerID: ownerID).map(\.id), [created.id])
    }

    func testPhotoCreateReplaceAndRemoveCleanObsoleteObjects() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remote = InMemoryTackleRemoteStore()
        let coordinator = coordinator(store: store, tackleRemote: remote)
        let firstDraft = try await store.tackleRepository.stageAsync(
            data: imageData(color: .systemGreen),
            sessionID: UUID()
        )
        let created = try store.tackleRepository.create(
            NewTackleItem(ownerID: ownerID, values: values(name: "Senko")),
            photo: firstDraft
        )
        let firstPath = try XCTUnwrap(created.photoStoragePath)

        await coordinator.sync(ownerID: ownerID)
        let hasFirstObject = await remote.containsObject(path: firstPath)
        XCTAssertTrue(hasFirstObject)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 0)

        let replacement = try await store.tackleRepository.stageAsync(
            data: imageData(color: .systemBlue),
            sessionID: UUID()
        )
        let replaced = try store.tackleRepository.update(
            id: created.id,
            ownerID: ownerID,
            values: created.values,
            photoChange: .replace(replacement)
        )
        let replacementPath = try XCTUnwrap(replaced.photoStoragePath)
        XCTAssertNotEqual(firstPath, replacementPath)

        await coordinator.sync(ownerID: ownerID)
        let hasOldObject = await remote.containsObject(path: firstPath)
        let hasReplacementObject = await remote.containsObject(path: replacementPath)
        XCTAssertFalse(hasOldObject)
        XCTAssertTrue(hasReplacementObject)

        _ = try store.tackleRepository.update(
            id: created.id,
            ownerID: ownerID,
            values: created.values,
            photoChange: .remove
        )
        await coordinator.sync(ownerID: ownerID)
        let hasRemovedObject = await remote.containsObject(path: replacementPath)
        XCTAssertFalse(hasRemovedObject)
        XCTAssertNil(try store.tackleRepository.item(id: created.id, ownerID: ownerID)?.photoStoragePath)
    }

    func testPhotoUploadDoesNotRepeatWhenMetadataRetryIsNeeded() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remote = FailFirstMetadataTackleRemoteStore()
        let coordinator = coordinator(store: store, tackleRemote: remote)
        let photo = try await store.tackleRepository.stageAsync(
            data: imageData(color: .systemYellow),
            sessionID: UUID()
        )
        let item = try store.tackleRepository.create(
            NewTackleItem(ownerID: ownerID, values: values(name: "Retry spoon", type: .spoon)),
            photo: photo
        )

        await coordinator.sync(ownerID: ownerID)
        let firstUploadCount = await remote.uploadCount
        XCTAssertEqual(firstUploadCount, 1)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 1)

        await coordinator.sync(ownerID: ownerID)
        let finalUploadCount = await remote.uploadCount
        let finalApplyCount = await remote.applyCount
        XCTAssertEqual(finalUploadCount, 1)
        XCTAssertEqual(finalApplyCount, 2)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 0)
        let remoteItemID = try await remote.fetch(ownerID: ownerID).first?.id
        XCTAssertEqual(remoteItemID, item.id)
    }

    func testMetadataEditBeforeFirstSyncPreservesPendingPhotoUpload() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remote = InMemoryTackleRemoteStore()
        let coordinator = coordinator(store: store, tackleRemote: remote)
        let photo = try await store.tackleRepository.stageAsync(
            data: imageData(color: .systemGreen),
            sessionID: UUID()
        )
        let created = try store.tackleRepository.create(
            NewTackleItem(ownerID: ownerID, values: values(name: "Original Senko")),
            photo: photo
        )
        _ = try store.tackleRepository.update(
            id: created.id,
            ownerID: ownerID,
            values: values(name: "Edited Senko")
        )

        XCTAssertEqual(try store.tackleRepository.pendingMutations(ownerID: ownerID).first?.stage, .uploadBinary)
        await coordinator.sync(ownerID: ownerID)

        let path = try XCTUnwrap(created.photoStoragePath)
        let containsPhoto = await remote.containsObject(path: path)
        let remoteName = await remote.fetch(ownerID: ownerID).first?.values.name
        XCTAssertTrue(containsPhoto)
        XCTAssertEqual(remoteName, "Edited Senko")
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 0)
    }

    func testNewCatchWaitsForFailedTackleCreateThenSyncsInOrder() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let tackleRemote = FailFirstTackleRemoteStore()
        let catchRemote = InMemoryCatchRemoteStore()
        let coordinator = coordinator(store: store, tackleRemote: tackleRemote, catchRemote: catchRemote)
        let tackleItem = try store.tackleRepository.create(NewTackleItem(
            ownerID: ownerID,
            values: values(name: "Inline jig", type: .jig)
        ))
        let catchItem = try store.catchRepository.create(NewCatch(
            ownerID: ownerID,
            values: catchValues(species: "Bass", tackleItemID: tackleItem.id)
        ))

        await coordinator.sync(ownerID: ownerID)
        let initiallyRemoteCatches = try await catchRemote.fetch(ownerID: ownerID)
        XCTAssertTrue(initiallyRemoteCatches.isEmpty)
        XCTAssertEqual(try store.catchRepository.pendingCount(ownerID: ownerID), 1)
        XCTAssertEqual(try store.tackleRepository.pendingCreateItemIDs(ownerID: ownerID), Set([tackleItem.id]))

        await coordinator.sync(ownerID: ownerID)
        let finalRemoteCatches = try await catchRemote.fetch(ownerID: ownerID)
        let remoteCatch = try XCTUnwrap(finalRemoteCatches.first)
        XCTAssertEqual(remoteCatch.id, catchItem.id)
        XCTAssertEqual(remoteCatch.values.tackleItemID, tackleItem.id)
        XCTAssertEqual(try store.catchRepository.pendingCount(ownerID: ownerID), 0)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 0)
    }

    func testRemoteItemAndPhotoRecoverAndArchiveWithoutLosingHistory() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let itemID = UUID()
        let photoID = UUID()
        let path = SwiftDataTackleRepository.storagePath(ownerID: ownerID, itemID: itemID, photoID: photoID)
        let remote = InMemoryTackleRemoteStore()
        let first = RemoteTackleItem(
            id: itemID,
            ownerID: ownerID,
            values: values(name: "Recovered spoon", type: .spoon),
            photoStoragePath: path,
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            version: 1
        )
        await remote.seed(first, data: imageData(color: .systemOrange))
        let coordinator = coordinator(store: store, tackleRemote: remote)

        await coordinator.sync(ownerID: ownerID)
        let recovered = try XCTUnwrap(store.tackleRepository.item(id: itemID, ownerID: ownerID))
        XCTAssertNotNil(store.tackleRepository.fileURL(for: recovered))

        let archived = RemoteTackleItem(
            id: itemID,
            ownerID: ownerID,
            values: values(name: "Recovered spoon", type: .spoon, archived: true),
            photoStoragePath: path,
            createdAt: first.createdAt,
            updatedAt: .now,
            deletedAt: nil,
            version: 2
        )
        await remote.seed(archived)
        await coordinator.sync(ownerID: ownerID)

        XCTAssertTrue(try store.tackleRepository.items(ownerID: ownerID).isEmpty)
        let historical = try XCTUnwrap(store.tackleRepository.item(id: itemID, ownerID: ownerID))
        XCTAssertTrue(historical.archived)
        XCTAssertNotNil(store.tackleRepository.fileURL(for: historical))
    }

    func testValidationAndEveryFixedTypeRoundTrip() throws {
        let store = try makeStore()
        let ownerID = UUID()
        XCTAssertThrowsError(try store.tackleRepository.create(NewTackleItem(
            ownerID: ownerID,
            values: values(name: "   ")
        ))) { error in
            XCTAssertEqual(error as? TackleValidationError, .nameRequired)
        }

        for type in TackleItemType.allCases {
            let item = try store.tackleRepository.create(NewTackleItem(
                ownerID: ownerID,
                values: values(name: type.label, type: type)
            ))
            XCTAssertEqual(item.type, type)
        }
        XCTAssertEqual(try store.tackleRepository.items(ownerID: ownerID).count, TackleItemType.allCases.count)
    }

    func testCatchDiscoveryMatchesLinkedTackleNameAndFreeText() {
        let ownerID = UUID()
        let tackleItemID = UUID()
        let (linkedCatch, freeTextCatch) = discoveryCatches(ownerID: ownerID, tackleItemID: tackleItemID)

        XCTAssertEqual(
            CatchDiscovery.results(
                in: [linkedCatch, freeTextCatch],
                query: "senko",
                species: nil,
                sort: .recent,
                tackleItemNames: [tackleItemID: "Green Pumpkin Senko"]
            ).map(\.id),
            [linkedCatch.id]
        )
        XCTAssertEqual(
            CatchDiscovery.results(
                in: [linkedCatch, freeTextCatch],
                query: "cafe",
                species: nil,
                sort: .recent,
                tackleItemNames: [tackleItemID: "Green Pumpkin Senko"]
            ).map(\.id),
            [freeTextCatch.id]
        )
    }
}

private extension TackleTests {
    struct TestStore {
        let container: ModelContainer
        let catchRepository: SwiftDataCatchRepository
        let tackleRepository: SwiftDataTackleRepository
    }

    func makeStore() throws -> TestStore {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: CatchRecord.self,
            OutboxOperation.self,
            CatchPhotoRecord.self,
            PhotoOutboxOperation.self,
            TackleItemRecord.self,
            TackleOutboxOperation.self,
            configurations: configuration
        )
        let root = FileManager.default.temporaryDirectory
            .appending(path: "reel-records-tackle-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileStore = try PhotoFileStore(rootURL: root)
        return TestStore(
            container: container,
            catchRepository: SwiftDataCatchRepository(modelContext: container.mainContext),
            tackleRepository: SwiftDataTackleRepository(
                modelContext: container.mainContext,
                fileStore: fileStore
            )
        )
    }

    func coordinator(
        store: TestStore,
        tackleRemote: any TackleRemoteStore,
        catchRemote: any CatchRemoteStore = InMemoryCatchRemoteStore()
    ) -> SyncCoordinator {
        SyncCoordinator(
            repository: store.catchRepository,
            remoteStore: catchRemote,
            tackleSync: TackleSyncDependencies(
                repository: store.tackleRepository,
                remoteStore: tackleRemote
            )
        )
    }

    func values(
        name: String,
        type: TackleItemType = .softPlastic,
        size: String? = nil,
        color: String? = nil,
        brand: String? = nil,
        archived: Bool = false
    ) -> TackleValues {
        TackleValues(name: name, type: type, size: size, color: color, brand: brand, archived: archived)
    }

    func catchValues(species: String, tackleItemID: UUID?) -> CatchValues {
        CatchValues(
            species: species,
            weight: nil,
            length: nil,
            caughtAt: .now,
            location: nil,
            tackleItemID: tackleItemID,
            lureText: nil,
            rodReel: nil,
            notes: nil,
            released: true
        )
    }

    func imageData(color: UIColor) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 220))
        return renderer.image { context in
            color.setFill()
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 300, height: 220))
        }.jpegData(compressionQuality: 0.9)!
    }

    func discoveryCatches(ownerID: UUID, tackleItemID: UUID) -> (CatchItem, CatchItem) {
        let linked = CatchItem(
            id: UUID(),
            ownerID: ownerID,
            values: catchValues(species: "Bass", tackleItemID: tackleItemID),
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
        let freeText = CatchItem(
            id: UUID(),
            ownerID: ownerID,
            values: CatchValues(
                species: "Trout",
                weight: nil,
                length: nil,
                caughtAt: .now,
                location: nil,
                lureText: "Café spoon",
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: .now,
            updatedAt: .now,
            deletedAt: nil,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
        return (linked, freeText)
    }
}

private actor FailFirstTackleRemoteStore: TackleRemoteStore {
    private let base = InMemoryTackleRemoteStore()
    private var shouldFail = true

    func upload(data: Data, path: String) async throws {
        await base.upload(data: data, path: path)
    }

    func apply(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult {
        if shouldFail {
            shouldFail = false
            throw URLError(.notConnectedToInternet)
        }
        return await base.apply(mutation)
    }

    func remove(paths: [String]) async throws {
        await base.remove(paths: paths)
    }

    func download(path: String) async throws -> Data {
        try await base.download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> [RemoteTackleItem] {
        await base.fetch(ownerID: ownerID)
    }
}

private actor FailFirstMetadataTackleRemoteStore: TackleRemoteStore {
    private let base = InMemoryTackleRemoteStore()
    private var shouldFailApply = true
    private(set) var uploadCount = 0
    private(set) var applyCount = 0

    func upload(data: Data, path: String) async throws {
        uploadCount += 1
        await base.upload(data: data, path: path)
    }

    func apply(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult {
        applyCount += 1
        if shouldFailApply {
            shouldFailApply = false
            throw URLError(.networkConnectionLost)
        }
        return await base.apply(mutation)
    }

    func remove(paths: [String]) async throws {
        await base.remove(paths: paths)
    }

    func download(path: String) async throws -> Data {
        try await base.download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> [RemoteTackleItem] {
        await base.fetch(ownerID: ownerID)
    }
}
