@testable import LincolnReelRecords
import XCTest

@MainActor
final class CatchPhotoGalleryTests: XCTestCase {
    func testItemsUseNewestCatchAndSavedPhotoOrder() {
        let ownerID = UUID()
        let older = catchItem(ownerID: ownerID, species: "Rainbow Trout", caughtAt: date(100))
        let newer = catchItem(ownerID: ownerID, species: "Smallmouth Bass", caughtAt: date(200))
        let olderPhoto = photo(ownerID: ownerID, catchID: older.id, position: 0)
        let newerFirst = photo(ownerID: ownerID, catchID: newer.id, position: 1)
        let newerSecond = photo(ownerID: ownerID, catchID: newer.id, position: 0)
        let orphan = photo(ownerID: ownerID, catchID: UUID(), position: 0)

        let items = CatchPhotoGalleryItem.ordered(
            catches: [older, newer],
            photosByCatch: [
                older.id: [olderPhoto],
                newer.id: [newerFirst, newerSecond],
                orphan.catchID: [orphan]
            ]
        )

        XCTAssertEqual(items.map(\.id), [newerSecond.id, newerFirst.id, olderPhoto.id])
        XCTAssertEqual(items.map(\.catchItem.id), [newer.id, newer.id, older.id])
    }

    private func catchItem(ownerID: UUID, species: String, caughtAt: Date) -> CatchItem {
        CatchItem(
            id: UUID(),
            ownerID: ownerID,
            values: CatchValues(
                species: species,
                weight: nil,
                length: nil,
                caughtAt: caughtAt,
                location: nil,
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: caughtAt,
            updatedAt: caughtAt,
            deletedAt: nil,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
    }

    private func photo(ownerID: UUID, catchID: UUID, position: Int) -> CatchPhotoItem {
        CatchPhotoItem(
            id: UUID(),
            ownerID: ownerID,
            catchID: catchID,
            storagePath: "catches/\(catchID.uuidString)/\(UUID().uuidString).jpg",
            localRelativePath: nil,
            position: position,
            createdAt: date(position),
            updatedAt: date(position),
            deletedAt: nil,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
    }

    private func date(_ seconds: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(seconds))
    }
}
