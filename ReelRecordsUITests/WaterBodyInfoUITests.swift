import XCTest

@MainActor
final class WaterBodyInfoUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLongPressWaterOpensSheetWithLocalHistoryAndPublicSources() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-logbook",
            "--ui-testing-water-info-fixture"
        ]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5))

        // Verify catch-pin selection still works before opening water info.
        let troutChip = app.buttons["map.species.Rainbow Trout"]
        XCTAssertTrue(troutChip.waitForExistence(timeout: 3))
        troutChip.tap()
        let selectedCatch = app.buttons["map.selected-catch"]
        XCTAssertTrue(selectedCatch.waitForExistence(timeout: 3))

        // Long-press on the map to inspect a water body.
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.8)

        let title = app.staticTexts["water-sheet.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Stockbridge Bowl")
        XCTAssertFalse(selectedCatch.exists)

        // Expand sheet to verify full sections.
        title.swipeUp()
        XCTAssertTrue(app.otherElements["water-sheet.local-history"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["water-sheet.overview"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["water-sheet.river-gauge"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["water-sheet.access"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["water-sheet.species"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["water-sheet.explore-links"].waitForExistence(timeout: 3))

        let dismiss = app.buttons["water-sheet.dismiss"]
        XCTAssertTrue(dismiss.waitForExistence(timeout: 3))
        dismiss.tap()
        XCTAssertFalse(title.waitForExistence(timeout: 2))
    }

    func testSparseWaterOnZeroCatchMapShowsHonestSparseCard() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-water-info-sparse"
        ]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        XCTAssertTrue(app.staticTexts["map.empty"].waitForExistence(timeout: 5))
        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5))

        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.8)

        let title = app.staticTexts["water-sheet.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Hidden Meadow Pond")

        title.swipeUp()
        XCTAssertTrue(app.otherElements["water-sheet.sparse"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.otherElements["water-sheet.explore-links"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["water-sheet.overview"].exists)
        XCTAssertFalse(app.otherElements["water-sheet.species"].exists)
        XCTAssertFalse(app.otherElements["water-sheet.river-gauge"].exists)

        app.buttons["water-sheet.dismiss"].tap()
        XCTAssertFalse(title.waitForExistence(timeout: 2))
    }

    func testLongPressOnDryLandShowsNonBlockingNotice() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-water-info-empty"
        ]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.8)

        let notice = app.otherElements["map.water-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["water-sheet.title"].exists)
    }
}
