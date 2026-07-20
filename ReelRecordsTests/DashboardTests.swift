@testable import LincolnReelRecords
import XCTest

final class DashboardTests: XCTestCase {
    func testCalendarPeriodsUseCaughtAtThroughNowAndRespectTimeZone() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        let now = try date("2026-07-15T16:00:00Z")
        let catches = try [
            catchItem(id: 1, species: "Bass", caughtAt: date("2026-07-13T04:00:00Z")),
            catchItem(id: 2, species: "Trout", caughtAt: date("2026-07-13T03:59:59Z")),
            catchItem(id: 3, species: "Perch", caughtAt: date("2026-07-15T17:00:00Z")),
            catchItem(id: 4, species: "Pike", caughtAt: date("2025-12-31T17:00:00Z"))
        ]

        let result = DashboardDerivation.insights(from: catches, now: now, calendar: calendar)

        XCTAssertEqual(result.totalCatches, 4)
        XCTAssertEqual(result.catchesThisWeek, 1)
        XCTAssertEqual(result.speciesThisYear, 2)

        let boundaryCatch = try catchItem(
            id: 5,
            species: "Walleye",
            caughtAt: date("2026-01-01T02:00:00Z")
        )
        let boundaryNow = try date("2026-01-02T12:00:00Z")
        var tokyo = calendar
        tokyo.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))

        XCTAssertEqual(
            DashboardDerivation.insights(from: [boundaryCatch], now: boundaryNow, calendar: calendar)
                .speciesThisYear,
            0
        )
        XCTAssertEqual(
            DashboardDerivation.insights(from: [boundaryCatch], now: boundaryNow, calendar: tokyo)
                .speciesThisYear,
            1
        )
    }

    func testRankingsNormalizeLabelsAndResolveTiesByRecency() {
        let olderBass = catchItem(id: 1, species: " Bass ", weight: 5, location: " Bowl ", caughtAt: date(1))
        let newerBass = catchItem(id: 2, species: "bass", weight: 5, location: "bowl", caughtAt: date(4))
        let olderTrout = catchItem(id: 3, species: "Trout", weight: 7, location: "River", caughtAt: date(2))
        let newerTrout = catchItem(id: 4, species: "TROUT", location: "River", caughtAt: date(3))

        let result = DashboardDerivation.insights(
            from: [olderBass, newerBass, olderTrout, newerTrout],
            now: date(10)
        )

        XCTAssertEqual(result.biggestCatch?.id, olderTrout.id)
        XCTAssertEqual(result.topSpecies, DashboardLabelStat(label: "bass", count: 2))
        XCTAssertEqual(result.favoriteSpot?.name, "bowl")
        XCTAssertEqual(result.favoriteSpot?.count, 2)
        XCTAssertEqual(result.favoriteSpot?.bestCatch?.id, newerBass.id)
        XCTAssertEqual(result.favoriteSpot?.mapFocusCatchID, nil)
    }

    func testSpotBestFallsBackToLengthAndFocusUsesMostRecentPinnedCatch() {
        let olderPinned = catchItem(
            id: 1,
            species: "Bass",
            length: 19,
            location: "Cedar Cove",
            coordinate: CatchCoordinate(latitude: 42.1, longitude: -73.2),
            caughtAt: date(1)
        )
        let longerUnpinned = catchItem(
            id: 2,
            species: "Pike",
            length: 28,
            location: "cedar cove",
            caughtAt: date(2)
        )
        let newerPinned = catchItem(
            id: 3,
            species: "Perch",
            location: "CEDAR COVE",
            coordinate: CatchCoordinate(latitude: 42.2, longitude: -73.3),
            caughtAt: date(3)
        )

        let spot = DashboardDerivation.insights(
            from: [olderPinned, longerUnpinned, newerPinned],
            now: date(10)
        ).favoriteSpot

        XCTAssertEqual(spot?.bestCatch?.id, longerUnpinned.id)
        XCTAssertEqual(spot?.mapFocusCatchID, newerPinned.id)
    }

    func testEmptyMissingDeletedAndRecentStatesRemainHonest() {
        let deleted = catchItem(id: 1, species: "Deleted", weight: 20, caughtAt: date(5), deletedAt: date(6))
        let older = catchItem(id: 2, species: "Older", caughtAt: date(2), createdAt: date(4))
        let sameDateLaterCreated = catchItem(id: 3, species: "Later", caughtAt: date(2), createdAt: date(5))

        let empty = DashboardDerivation.insights(from: [], now: date(10))
        let result = DashboardDerivation.insights(from: [deleted, older, sameDateLaterCreated], now: date(10))

        XCTAssertEqual(empty.totalCatches, 0)
        XCTAssertNil(empty.biggestCatch)
        XCTAssertNil(empty.favoriteSpot)
        XCTAssertEqual(result.totalCatches, 2)
        XCTAssertNil(result.biggestCatch)
        XCTAssertEqual(result.recentCatches.map(\.id), [sameDateLaterCreated.id, older.id])
    }

    func testRepresentativeDashboardDerivationRemainsPractical() {
        let catches = (0 ..< 1000).map { index in
            catchItem(
                id: index + 1,
                species: index.isMultiple(of: 2) ? "Bass" : "Trout",
                weight: index.isMultiple(of: 3) ? Double(index % 20) : nil,
                length: Double(index % 35),
                location: "Lake \(index % 20)",
                caughtAt: date(index)
            )
        }

        measure {
            let result = DashboardDerivation.insights(from: catches, now: date(2000))
            XCTAssertEqual(result.totalCatches, 1000)
            XCTAssertEqual(result.favoriteSpots.count, 20)
        }
    }

    @MainActor
    func testDirectMapTabSelectionClearsDashboardRouteFocus() {
        let router = AppRouter()
        let focusID = UUID()
        router.showSpotOnMap(DashboardSpot(
            id: "cedar cove",
            name: "Cedar Cove",
            count: 1,
            bestCatch: nil,
            mapFocusCatchID: focusID
        ))

        XCTAssertEqual(router.selectedTab, .map)
        XCTAssertEqual(router.mapFocusCatchID, focusID)
        XCTAssertEqual(router.mapFocusSpotName, "Cedar Cove")

        router.select(.home)
        router.select(.map)

        XCTAssertNil(router.mapFocusCatchID)
        XCTAssertNil(router.mapFocusSpotName)
    }
}

private extension DashboardTests {
    func catchItem(
        id: Int,
        species: String,
        weight: Double? = nil,
        length: Double? = nil,
        location: String? = nil,
        coordinate: CatchCoordinate? = nil,
        caughtAt: Date,
        createdAt: Date? = nil,
        deletedAt: Date? = nil
    ) -> CatchItem {
        CatchItem(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            ownerID: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            values: CatchValues(
                species: species,
                weight: weight,
                length: length,
                caughtAt: caughtAt,
                location: location,
                coordinate: coordinate,
                lureText: nil,
                rodReel: nil,
                notes: nil,
                released: true
            ),
            createdAt: createdAt ?? caughtAt,
            updatedAt: createdAt ?? caughtAt,
            deletedAt: deletedAt,
            remoteVersion: 1,
            syncState: .synced,
            syncError: nil
        )
    }

    func date(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: TimeInterval(offset))
    }

    func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}
