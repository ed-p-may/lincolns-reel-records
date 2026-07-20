@testable import LincolnReelRecords
import XCTest

final class CatchDiscoveryTests: XCTestCase {
    func testSearchMatchesEveryPhaseTwoTextFieldAsUserTypes() {
        let catches = [
            catchItem(species: "Smallmouth Bass", location: "Stockbridge Bowl"),
            catchItem(species: "Rainbow Trout", lure: "Café spoon"),
            catchItem(species: "Walleye", notes: "Caught beside the old dock")
        ]

        XCTAssertEqual(results(catches, query: "small").map(\.species), ["Smallmouth Bass"])
        XCTAssertEqual(results(catches, query: "BOWL").map(\.species), ["Smallmouth Bass"])
        XCTAssertEqual(results(catches, query: "cafe").map(\.species), ["Rainbow Trout"])
        XCTAssertEqual(results(catches, query: "old dock").map(\.species), ["Walleye"])
    }

    func testSpeciesOptionsAreDistinctCaseInsensitiveAndAlphabetical() {
        let catches = [
            catchItem(species: "walleye"),
            catchItem(species: "Bass"),
            catchItem(species: "bass"),
            catchItem(species: "Bluegill")
        ]

        XCTAssertEqual(CatchDiscovery.species(in: catches), ["Bass", "Bluegill", "walleye"])
    }

    func testSearchSpeciesAndSortCompose() {
        let catches = [
            catchItem(species: "Bass", weight: 2, location: "Bowl", caughtAt: date(1)),
            catchItem(species: "Bass", weight: 5, notes: "Bowl shoreline", caughtAt: date(2)),
            catchItem(species: "Perch", weight: 7, location: "Bowl", caughtAt: date(3))
        ]

        let filtered = CatchDiscovery.results(
            in: catches,
            query: "bowl",
            species: "bass",
            sort: .heaviest
        )

        XCTAssertEqual(filtered.map(\.weight), [5, 2])
    }

    func testSavedSearchSpeciesAndSortCompose() {
        let catches = [
            catchItem(species: "Bass", weight: 2, location: "Bowl", bookmarked: true),
            catchItem(species: "Bass", weight: 6, location: "Bowl", bookmarked: false),
            catchItem(species: "Perch", weight: 8, location: "Bowl", bookmarked: true)
        ]

        let filtered = CatchDiscovery.results(
            in: catches,
            query: "bowl",
            species: "bass",
            savedOnly: true,
            sort: .heaviest
        )

        XCTAssertEqual(filtered.map(\.weight), [2])
    }

    func testMeasurementSortsPutMissingValuesLastThenUseRecentTieBreaks() {
        let olderHeavy = catchItem(id: 1, species: "Older", weight: 4, length: 20, caughtAt: date(1))
        let newerHeavy = catchItem(id: 2, species: "Newer", weight: 4, length: 19, caughtAt: date(2))
        let light = catchItem(id: 3, species: "Light", weight: 2, length: 20, caughtAt: date(3))
        let unmeasured = catchItem(id: 4, species: "Unmeasured", caughtAt: date(4))
        let catches = [unmeasured, olderHeavy, light, newerHeavy]

        XCTAssertEqual(
            results(catches, sort: .heaviest).map(\.species),
            ["Newer", "Older", "Light", "Unmeasured"]
        )
        XCTAssertEqual(
            results(catches, sort: .longest).map(\.species),
            ["Light", "Older", "Newer", "Unmeasured"]
        )
    }

    func testRecentSortHasDeterministicCreatedAtAndIDTieBreaks() {
        let firstID = catchItem(id: 1, species: "First", caughtAt: date(2), createdAt: date(3))
        let secondID = catchItem(id: 2, species: "Second", caughtAt: date(2), createdAt: date(3))
        let laterCreated = catchItem(id: 3, species: "Later", caughtAt: date(2), createdAt: date(4))

        XCTAssertEqual(
            results([secondID, firstID, laterCreated]).map(\.species),
            ["Later", "First", "Second"]
        )
    }

    func testRepresentativeLocalCollectionRemainsPractical() {
        let catches = (0 ..< 1000).map { index in
            catchItem(
                id: index + 1,
                species: index.isMultiple(of: 2) ? "Bass" : "Perch",
                weight: Double(index % 12),
                location: "Lake \(index % 20)",
                notes: index.isMultiple(of: 10) ? "windy shoreline" : nil,
                caughtAt: date(index)
            )
        }

        measure {
            let filtered = CatchDiscovery.results(
                in: catches,
                query: "windy",
                species: "Bass",
                sort: .heaviest
            )
            XCTAssertEqual(filtered.count, 100)
        }
    }

    private func results(
        _ catches: [CatchItem],
        query: String = "",
        species: String? = nil,
        sort: CatchSort = .recent
    ) -> [CatchItem] {
        CatchDiscovery.results(in: catches, query: query, species: species, sort: sort)
    }

    private func catchItem(
        id: Int = 1,
        species: String,
        weight: Double? = nil,
        length: Double? = nil,
        location: String? = nil,
        lure: String? = nil,
        notes: String? = nil,
        bookmarked: Bool = false,
        caughtAt: Date = Date(timeIntervalSince1970: 1),
        createdAt: Date = Date(timeIntervalSince1970: 1)
    ) -> CatchItem {
        CatchItem(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            ownerID: UUID(),
            values: CatchValues(
                species: species,
                weight: weight,
                length: length,
                caughtAt: caughtAt,
                location: location,
                lureText: lure,
                rodReel: nil,
                notes: notes,
                released: true,
                bookmarked: bookmarked
            ),
            createdAt: createdAt,
            updatedAt: createdAt,
            deletedAt: nil,
            remoteVersion: 1,
            syncState: .synced,
            syncError: nil
        )
    }

    private func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(offset))
    }
}
