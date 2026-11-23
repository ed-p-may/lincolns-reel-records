@testable import LincolnReelRecords
import SwiftData
import XCTest

final class TackleDiscoveryTests: XCTestCase {
    func testRecentlyUsedReturnsAtMostFiveDistinctSelectableItemsOrderedByCatchRecency() {
        let items = (1 ... 7).map { index in
            makeItem(name: "Lure \(index)", type: .softPlastic)
        }
        let base = Date(timeIntervalSince1970: 1_750_000_000)
        let catches = [
            makeCatch(tackleItemID: items[0].id, caughtAt: base.addingTimeInterval(100)),
            makeCatch(tackleItemID: items[1].id, caughtAt: base.addingTimeInterval(200)),
            makeCatch(tackleItemID: items[2].id, caughtAt: base.addingTimeInterval(300)),
            makeCatch(tackleItemID: items[3].id, caughtAt: base.addingTimeInterval(400)),
            makeCatch(tackleItemID: items[4].id, caughtAt: base.addingTimeInterval(500)),
            makeCatch(tackleItemID: items[5].id, caughtAt: base.addingTimeInterval(600)),
            makeCatch(tackleItemID: items[6].id, caughtAt: base.addingTimeInterval(700)),
            // Duplicate usage of items[4] at the newest timestamp promotes it to index 0 without duplicating it.
            makeCatch(tackleItemID: items[4].id, caughtAt: base.addingTimeInterval(800))
        ]

        let recent = TackleDiscovery.recentlyUsed(from: items, catches: catches)
        XCTAssertEqual(
            recent.map(\.id),
            [items[4].id, items[6].id, items[5].id, items[3].id, items[2].id]
        )
    }

    func testRecentlyUsedUsesCreatedAtAndIDAsDeterministicTieBreakers() throws {
        let firstID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let secondID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let thirdID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000003"))
        let itemA = makeItem(id: firstID, name: "Item A")
        let itemB = makeItem(id: secondID, name: "Item B")
        let itemC = makeItem(id: thirdID, name: "Item C")
        let sameCaughtAt = Date(timeIntervalSince1970: 1_750_000_000)
        let earlierCreated = Date(timeIntervalSince1970: 1_750_000_010)
        let laterCreated = Date(timeIntervalSince1970: 1_750_000_020)

        let catches = try [
            makeCatch(
                id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-00000000000B")),
                tackleItemID: itemB.id,
                caughtAt: sameCaughtAt,
                createdAt: earlierCreated
            ),
            makeCatch(
                id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-00000000000A")),
                tackleItemID: itemA.id,
                caughtAt: sameCaughtAt,
                createdAt: earlierCreated
            ),
            makeCatch(
                id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-00000000000C")),
                tackleItemID: itemC.id,
                caughtAt: sameCaughtAt,
                createdAt: laterCreated
            )
        ]

        let recent = TackleDiscovery.recentlyUsed(from: [itemA, itemB, itemC], catches: catches)
        XCTAssertEqual(recent.map(\.id), [itemC.id, itemA.id, itemB.id])
    }

    func testRecentlyUsedSkipsArchivedDeletedAndDeletedCatches() {
        let activeNewest = makeItem(name: "Active Newest")
        let archived = makeItem(name: "Archived", archived: true)
        let deletedItem = makeItem(name: "Deleted", deletedAt: .now)
        let fallback = makeItem(name: "Active Older")
        let deletedCatchOnly = makeItem(name: "Deleted Catch Lure")
        let base = Date(timeIntervalSince1970: 1_750_000_000)

        let catches = [
            makeCatch(tackleItemID: deletedCatchOnly.id, caughtAt: base.addingTimeInterval(500), deletedAt: .now),
            makeCatch(tackleItemID: archived.id, caughtAt: base.addingTimeInterval(400)),
            makeCatch(tackleItemID: deletedItem.id, caughtAt: base.addingTimeInterval(300)),
            makeCatch(tackleItemID: activeNewest.id, caughtAt: base.addingTimeInterval(200)),
            makeCatch(tackleItemID: nil, caughtAt: base.addingTimeInterval(150)),
            makeCatch(tackleItemID: fallback.id, caughtAt: base.addingTimeInterval(100))
        ]

        let recent = TackleDiscovery.recentlyUsed(
            from: [activeNewest, archived, deletedItem, fallback, deletedCatchOnly],
            catches: catches
        )
        XCTAssertEqual(recent.map(\.id), [activeNewest.id, fallback.id])
    }

    func testInlineStripItemsUsesRecentWhenAvailableAndFallsBackAlphabeticallyOnColdStart() {
        let items = [
            makeItem(name: "Zebra Popper", type: .topwater),
            makeItem(name: "Alpha Jig", type: .jig),
            makeItem(name: "Charlie Crank", type: .crankbait),
            makeItem(name: "Bravo Senko", type: .softPlastic),
            makeItem(name: "Echo Spoon", type: .spoon),
            makeItem(name: "Delta Fly", type: .fly),
            makeItem(name: "Archived Bait", type: .liveBait, archived: true)
        ]

        let coldStart = TackleDiscovery.inlineStripItems(from: items, recentItems: [])
        XCTAssertFalse(coldStart.isRecent)
        XCTAssertEqual(
            coldStart.items.map(\.name),
            ["Alpha Jig", "Bravo Senko", "Charlie Crank", "Delta Fly", "Echo Spoon"]
        )

        let warm = TackleDiscovery.inlineStripItems(from: items, recentItems: [items[0], items[3]])
        XCTAssertTrue(warm.isRecent)
        XCTAssertEqual(warm.items.map(\.name), ["Zebra Popper", "Bravo Senko"])
    }

    func testSectionsByTypeGroupsInCanonicalOrderSortsAlphabeticallyAndMatchesBrandAndColor() throws {
        let spoon = makeItem(name: "Silver Minnow", type: .spoon, color: "Silver", brand: "Johnson")
        let crankZ = makeItem(name: "Z-Crank", type: .crankbait, color: "Crème Chartreuse", brand: "Rapala")
        let crankA = makeItem(name: "Apple Shad", type: .crankbait, color: "Red Craw", brand: "Strike King")
        let soft = makeItem(name: "Senko", type: .softPlastic, color: "Green Pumpkin", brand: "Yamamoto Café")
        let items = [spoon, crankZ, crankA, soft]

        let allSections = TackleDiscovery.sectionsByType(in: items)
        XCTAssertEqual(allSections.map(\.type), [.softPlastic, .crankbait, .spoon])
        let crankSection = try XCTUnwrap(allSections.first { $0.type == .crankbait })
        XCTAssertEqual(crankSection.items.map(\.name), ["Apple Shad", "Z-Crank"])
        XCTAssertEqual(TackleDiscovery.availableTypes(in: items), [.softPlastic, .crankbait, .spoon])

        let byBrand = TackleDiscovery.sectionsByType(in: items, query: "ｃａｆｅ")
        XCTAssertEqual(byBrand.map(\.type), [.softPlastic])
        XCTAssertEqual(try XCTUnwrap(byBrand.first).items.map(\.id), [soft.id])

        let byColor = TackleDiscovery.sectionsByType(in: items, query: "ｃｒｅｍｅ")
        XCTAssertEqual(byColor.map(\.type), [.crankbait])
        XCTAssertEqual(try XCTUnwrap(byColor.first).items.map(\.id), [crankZ.id])

        let byType = TackleDiscovery.sectionsByType(in: items, type: .crankbait)
        XCTAssertEqual(byType.map(\.type), [.crankbait])
        XCTAssertEqual(try XCTUnwrap(byType.first).items.map(\.id), [crankA.id, crankZ.id])
    }

    @MainActor
    func testMetadataOnlyRemoteTackleArchiveAdvancesSyncCoordinatorRevision() async throws {
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
            .appending(path: "reel-records-tackle-rev-\(UUID().uuidString)", directoryHint: .isDirectory)
        let fileStore = try PhotoFileStore(rootURL: root)
        let catchRepo = SwiftDataCatchRepository(modelContext: container.mainContext)
        let tackleRepo = SwiftDataTackleRepository(modelContext: container.mainContext, fileStore: fileStore)
        let tackleRemote = InMemoryTackleRemoteStore()
        let coordinator = SyncCoordinator(
            repository: catchRepo,
            remoteStore: InMemoryCatchRemoteStore(),
            tackleSync: TackleSyncDependencies(repository: tackleRepo, remoteStore: tackleRemote)
        )
        let ownerID = UUID()
        let item = try tackleRepo.create(NewTackleItem(
            ownerID: ownerID,
            values: TackleValues(name: "Senko", type: .softPlastic, size: nil, color: nil, brand: nil, archived: false)
        ))
        await coordinator.sync(ownerID: ownerID)
        let revisionAfterInitialSync = coordinator.revision

        let archivedRemote = RemoteTackleItem(
            id: item.id,
            ownerID: ownerID,
            values: TackleValues(name: "Senko", type: .softPlastic, size: nil, color: nil, brand: nil, archived: true),
            photoStoragePath: nil,
            createdAt: item.createdAt,
            updatedAt: .now,
            deletedAt: nil,
            version: 2
        )
        await tackleRemote.seed(archivedRemote)
        await coordinator.sync(ownerID: ownerID)

        XCTAssertGreaterThan(coordinator.revision, revisionAfterInitialSync)
        XCTAssertEqual(try tackleRepo.item(id: item.id, ownerID: ownerID)?.isSelectable, false)
    }

    @MainActor
    func testValidateSelectableSelectionRejectsRetiredNewLinkAndPreservesHistoricalEdit() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TackleItemRecord.self,
            TackleOutboxOperation.self,
            configurations: configuration
        )
        let root = FileManager.default.temporaryDirectory
            .appending(path: "reel-records-tackle-val-\(UUID().uuidString)", directoryHint: .isDirectory)
        let repo = try SwiftDataTackleRepository(
            modelContext: container.mainContext,
            fileStore: PhotoFileStore(rootURL: root)
        )
        let ownerID = UUID()
        let item = try repo.create(NewTackleItem(
            ownerID: ownerID,
            values: TackleValues(name: "Senko", type: .softPlastic, size: nil, color: nil, brand: nil, archived: false)
        ))
        XCTAssertNoThrow(try repo.validateSelectableSelection(itemID: item.id, unchangedFrom: nil, ownerID: ownerID))

        _ = try repo.update(
            id: item.id,
            ownerID: ownerID,
            values: TackleValues(name: "Senko", type: .softPlastic, size: nil, color: nil, brand: nil, archived: true)
        )
        XCTAssertThrowsError(
            try repo.validateSelectableSelection(itemID: item.id, unchangedFrom: nil, ownerID: ownerID)
        ) { error in
            XCTAssertEqual(error as? TackleRepositoryError, .retiredSelection)
        }
        XCTAssertNoThrow(
            try repo.validateSelectableSelection(itemID: item.id, unchangedFrom: item.id, ownerID: ownerID)
        )
    }
}

private extension TackleDiscoveryTests {
    func makeItem(
        id: UUID = UUID(),
        name: String,
        type: TackleItemType = .softPlastic,
        color: String? = nil,
        brand: String? = nil,
        archived: Bool = false,
        deletedAt: Date? = nil
    ) -> TackleItem {
        TackleItem(
            id: id,
            ownerID: UUID(),
            values: TackleValues(
                name: name,
                type: type,
                size: nil,
                color: color,
                brand: brand,
                archived: archived
            ),
            photoID: nil,
            photoStoragePath: nil,
            photoLocalRelativePath: nil,
            createdAt: .now,
            updatedAt: .now,
            deletedAt: deletedAt,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
    }

    func makeCatch(
        id: UUID = UUID(),
        tackleItemID: UUID?,
        caughtAt: Date,
        createdAt: Date = Date(timeIntervalSince1970: 1_750_000_000),
        deletedAt: Date? = nil
    ) -> CatchItem {
        CatchItem(
            id: id,
            ownerID: UUID(),
            values: CatchValues(
                species: "Bass",
                weight: nil,
                length: nil,
                caughtAt: caughtAt,
                location: nil,
                tackleItemID: tackleItemID,
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: deletedAt,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
    }
}
