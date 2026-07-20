@testable import LincolnReelRecords
import SwiftData
import UIKit
import XCTest

@MainActor
final class TackleSyncRegressionTests: XCTestCase {
    func testOverlappingSyncRerunsWithoutOverwritingNewerTackleAndCatch() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let tackleRemote = BlockingFirstApplyTackleRemoteStore()
        let catchRemote = InMemoryCatchRemoteStore()
        let coordinator = coordinator(store: store, tackleRemote: tackleRemote, catchRemote: catchRemote)
        let item = try store.tackleRepository.create(NewTackleItem(
            ownerID: ownerID,
            values: values(name: "First name", type: .jig)
        ))

        let firstSync = Task { await coordinator.sync(ownerID: ownerID) }
        await tackleRemote.waitUntilApplyIsBlocked()
        _ = try store.tackleRepository.update(
            id: item.id,
            ownerID: ownerID,
            values: values(name: "Newer name", type: .jig)
        )
        let catchItem = try store.catchRepository.create(NewCatch(
            ownerID: ownerID,
            values: catchValues(species: "Bass", tackleItemID: item.id)
        ))
        await coordinator.sync(ownerID: ownerID)
        await tackleRemote.releaseApply()
        await firstSync.value

        let remoteTackleName = try await tackleRemote.fetch(ownerID: ownerID).first?.values.name
        let remoteCatchID = try await catchRemote.fetch(ownerID: ownerID).first?.id
        XCTAssertEqual(try store.tackleRepository.item(id: item.id, ownerID: ownerID)?.name, "Newer name")
        XCTAssertEqual(remoteTackleName, "Newer name")
        XCTAssertEqual(remoteCatchID, catchItem.id)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 0)
        XCTAssertEqual(try store.catchRepository.pendingCount(ownerID: ownerID), 0)
    }

    func testConfirmedCreateConflictRetriesAsUpdate() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let remote = InMemoryTackleRemoteStore()
        let coordinator = coordinator(store: store, tackleRemote: remote)
        let local = try store.tackleRepository.create(NewTackleItem(
            ownerID: ownerID,
            values: values(name: "Keep this local spoon", type: .spoon)
        ))
        await remote.seed(RemoteTackleItem(
            id: local.id,
            ownerID: ownerID,
            values: values(name: "Earlier remote spoon", type: .spoon),
            photoStoragePath: nil,
            createdAt: local.createdAt,
            updatedAt: .now,
            deletedAt: nil,
            version: 1
        ))

        await coordinator.sync(ownerID: ownerID)
        XCTAssertTrue(try store.tackleRepository.pendingCreateItemIDs(ownerID: ownerID).isEmpty)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 1)

        await coordinator.sync(ownerID: ownerID, confirmingConflicts: true)
        let remoteName = await remote.fetch(ownerID: ownerID).first?.values.name
        XCTAssertEqual(remoteName, local.name)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 0)
    }

    func testCreateCleanupFailureDoesNotBlockCatchOrRetainCreateKind() async throws {
        let store = try makeStore()
        let ownerID = UUID()
        let tackleRemote = FailFirstRemovalTackleRemoteStore()
        let catchRemote = InMemoryCatchRemoteStore()
        let coordinator = coordinator(store: store, tackleRemote: tackleRemote, catchRemote: catchRemote)
        let item = try await makeItemWithReplacedPhoto(store: store, ownerID: ownerID)
        let catchItem = try store.catchRepository.create(NewCatch(
            ownerID: ownerID,
            values: catchValues(species: "Bass", tackleItemID: item.id)
        ))

        await coordinator.sync(ownerID: ownerID)
        let remoteCatchID = try await catchRemote.fetch(ownerID: ownerID).first?.id
        XCTAssertTrue(try store.tackleRepository.pendingCreateItemIDs(ownerID: ownerID).isEmpty)
        XCTAssertEqual(remoteCatchID, catchItem.id)
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 1)

        _ = try store.tackleRepository.update(
            id: item.id,
            ownerID: ownerID,
            values: values(name: "Final jig", type: .jig)
        )
        await coordinator.sync(ownerID: ownerID)
        let remoteName = try await tackleRemote.fetch(ownerID: ownerID).first?.values.name
        XCTAssertEqual(remoteName, "Final jig")
        XCTAssertEqual(try store.tackleRepository.pendingCount(ownerID: ownerID), 0)
    }
}

private extension TackleSyncRegressionTests {
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
            .appending(path: "reel-records-tackle-sync-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileStore = try PhotoFileStore(rootURL: root)
        return TestStore(
            container: container,
            catchRepository: SwiftDataCatchRepository(modelContext: container.mainContext),
            tackleRepository: SwiftDataTackleRepository(modelContext: container.mainContext, fileStore: fileStore)
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
            tackleSync: TackleSyncDependencies(repository: store.tackleRepository, remoteStore: tackleRemote)
        )
    }

    func values(name: String, type: TackleItemType = .softPlastic) -> TackleValues {
        TackleValues(
            name: name,
            type: type,
            size: nil,
            color: nil,
            brand: nil,
            archived: false
        )
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

    func makeItemWithReplacedPhoto(store: TestStore, ownerID: UUID) async throws -> TackleItem {
        let firstPhoto = try await store.tackleRepository.stageAsync(
            data: imageData(color: .systemGreen),
            sessionID: UUID()
        )
        let item = try store.tackleRepository.create(
            NewTackleItem(ownerID: ownerID, values: values(name: "First jig", type: .jig)),
            photo: firstPhoto
        )
        let replacement = try await store.tackleRepository.stageAsync(
            data: imageData(color: .systemBlue),
            sessionID: UUID()
        )
        _ = try store.tackleRepository.update(
            id: item.id,
            ownerID: ownerID,
            values: values(name: "Replacement jig", type: .jig),
            photoChange: .replace(replacement)
        )
        return item
    }
}

private actor BlockingFirstApplyTackleRemoteStore: TackleRemoteStore {
    private let base = InMemoryTackleRemoteStore()
    private var shouldBlock = true
    private var blockedApply: CheckedContinuation<Void, Never>?
    private var blockedWaiter: CheckedContinuation<Void, Never>?

    func upload(data: Data, path: String) async throws {
        await base.upload(data: data, path: path)
    }

    func apply(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult {
        if shouldBlock {
            shouldBlock = false
            await withCheckedContinuation { continuation in
                blockedApply = continuation
                blockedWaiter?.resume()
                blockedWaiter = nil
            }
        }
        return await base.apply(mutation)
    }

    func waitUntilApplyIsBlocked() async {
        guard blockedApply == nil else { return }
        await withCheckedContinuation { blockedWaiter = $0 }
    }

    func releaseApply() {
        blockedApply?.resume()
        blockedApply = nil
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

private actor FailFirstRemovalTackleRemoteStore: TackleRemoteStore {
    private let base = InMemoryTackleRemoteStore()
    private var shouldFailRemoval = true

    func upload(data: Data, path: String) async throws {
        await base.upload(data: data, path: path)
    }

    func apply(_ mutation: PendingTackleMutation) async throws -> TackleMutationResult {
        await base.apply(mutation)
    }

    func remove(paths: [String]) async throws {
        if shouldFailRemoval, !paths.isEmpty {
            shouldFailRemoval = false
            throw URLError(.networkConnectionLost)
        }
        await base.remove(paths: paths)
    }

    func download(path: String) async throws -> Data {
        try await base.download(path: path)
    }

    func fetch(ownerID: UUID) async throws -> [RemoteTackleItem] {
        await base.fetch(ownerID: ownerID)
    }
}
