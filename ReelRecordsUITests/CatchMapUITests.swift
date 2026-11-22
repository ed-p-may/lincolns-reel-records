import XCTest

@MainActor
final class CatchMapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSpeciesFilterUpdatesMapCountsAndSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let counts = app.staticTexts["map.counts"]
        XCTAssertTrue(counts.waitForExistence(timeout: 5))
        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")

        let allChip = app.buttons["map.species.All"]
        XCTAssertTrue(allChip.waitForExistence(timeout: 3))
        XCTAssertEqual(allChip.value as? String, "Selected")

        let troutChip = app.buttons["map.species.Rainbow Trout"]
        XCTAssertTrue(troutChip.waitForExistence(timeout: 3))
        troutChip.tap()

        XCTAssertEqual(counts.label, "1 OF 2 CATCHES ACROSS 1 SPOT")
        let selectedCatch = app.buttons["map.selected-catch"]
        XCTAssertTrue(selectedCatch.waitForExistence(timeout: 3))
        XCTAssertTrue(selectedCatch.label.contains("Rainbow Trout"))

        allChip.tap()
        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")
    }

    func testMapStylePersistsAcrossRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let styleButton = app.buttons["map.style.button"]
        XCTAssertTrue(styleButton.waitForExistence(timeout: 5))
        styleButton.tap()

        let hybridOption = app.buttons["map.style.hybrid"]
        XCTAssertTrue(hybridOption.waitForExistence(timeout: 3))
        hybridOption.tap()
        app.buttons["map.layers.done"].tap()
        XCTAssertEqual(styleButton.value as? String, "Hybrid")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Map"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Map"].tap()

        let persistedStyleButton = app.buttons["map.style.button"]
        XCTAssertTrue(persistedStyleButton.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedStyleButton.value as? String, "Hybrid")

        persistedStyleButton.tap()
        let standardOption = app.buttons["map.style.standard"]
        XCTAssertTrue(standardOption.waitForExistence(timeout: 3))
        standardOption.tap()
        app.buttons["map.layers.done"].tap()
        XCTAssertEqual(persistedStyleButton.value as? String, "Standard")
    }
}
