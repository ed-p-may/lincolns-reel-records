import Foundation
@testable import LincolnReelRecords
import XCTest

final class NewCatchDefaultsTests: XCTestCase {
    func testCatchSuppliesOnlyAllowedDefaults() {
        let tackleItemID = UUID()
        let latest = catchItem(
            caughtAt: date(day: 20, hour: 10),
            location: "North Cove",
            coordinate: CatchCoordinate(latitude: 42.3, longitude: -73.3),
            tackleItemID: tackleItemID,
            lureText: "Black trailer",
            skyCondition: .overcast,
            waterClarity: .stained
        )

        let defaults = NewCatchDefaults(catchItem: latest)

        XCTAssertEqual(defaults.location, "North Cove")
        XCTAssertEqual(defaults.tackleItemID, tackleItemID)
        XCTAssertEqual(defaults.lureText, "Black trailer")
        XCTAssertEqual(defaults.skyCondition, .overcast)
        XCTAssertEqual(defaults.waterClarity, .stained)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: day, hour: hour))!
    }

    private func catchItem(
        caughtAt: Date,
        location: String? = nil,
        coordinate: CatchCoordinate? = nil,
        tackleItemID: UUID? = nil,
        lureText: String? = nil,
        skyCondition: SkyCondition? = nil,
        waterClarity: WaterClarity? = nil
    ) -> CatchItem {
        CatchItem(
            id: UUID(),
            ownerID: UUID(),
            values: CatchValues(
                species: "Smallmouth Bass",
                weight: 4.5,
                length: 19,
                caughtAt: caughtAt,
                location: location,
                coordinate: coordinate,
                conditions: CatchConditions(
                    airTemperatureF: 72,
                    skyCondition: skyCondition,
                    waterTemperatureF: 64,
                    waterClarity: waterClarity
                ),
                tackleItemID: tackleItemID,
                lureText: lureText,
                rodReel: "Rod that must not carry",
                notes: "Notes that must not carry",
                released: false
            ),
            createdAt: caughtAt,
            updatedAt: caughtAt,
            deletedAt: nil,
            remoteVersion: 0,
            syncState: .synced,
            syncError: nil
        )
    }
}
