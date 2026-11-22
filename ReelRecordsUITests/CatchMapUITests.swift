import XCTest

@MainActor
final class CatchMapUITests: XCTestCase {
    private let seededBass = "Largemouth Bass With An Exceptionally Long Display Name"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSpeciesFilterUpdatesMapMarkersCountsAndSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let counts = app.staticTexts["map.counts"]
        XCTAssertTrue(counts.waitForExistence(timeout: 5))
        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")

        let map = app.maps.firstMatch
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        let bassMarker = map.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", seededBass))
            .firstMatch
        let troutMarker = map.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Rainbow Trout"))
            .firstMatch
        XCTAssertTrue(bassMarker.waitForExistence(timeout: 5))
        XCTAssertTrue(troutMarker.waitForExistence(timeout: 5))

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
        XCTAssertTrue(troutMarker.waitForExistence(timeout: 3))
        XCTAssertFalse(bassMarker.exists)

        allChip.tap()
        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")
        XCTAssertTrue(bassMarker.waitForExistence(timeout: 5))

        troutChip.tap()
        XCTAssertEqual(counts.label, "1 OF 2 CATCHES ACROSS 1 SPOT")

        app.tabBars.buttons["Home"].tap()
        let dashboard = app.scrollViews.firstMatch
        XCTAssertTrue(dashboard.waitForExistence(timeout: 5))
        dashboard.swipeUp()
        dashboard.swipeUp()
        let favoriteSpot = app.buttons["dashboard.spot.stockbridge bowl north shore by the old stone landing"]
        XCTAssertTrue(favoriteSpot.waitForExistence(timeout: 3))
        favoriteSpot.tap()

        XCTAssertTrue(counts.waitForExistence(timeout: 5))
        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")
        XCTAssertEqual(app.buttons["map.species.All"].value as? String, "Selected")
        XCTAssertTrue(app.buttons["map.selected-catch"].label.contains("Largemouth Bass"))
    }

    func testMapStyleSharesWithManualPickerAndPersistsSatelliteAcrossRelaunch() {
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

        app.tabBars.buttons["Log"].tap()
        let addCatch = app.buttons["Log a catch"]
        XCTAssertTrue(addCatch.waitForExistence(timeout: 5))
        addCatch.tap()
        let addScroll = app.scrollViews.firstMatch
        addScroll.swipeUp()
        addScroll.swipeUp()
        let chooseOnMap = app.buttons["add.location.manual"]
        XCTAssertTrue(chooseOnMap.waitForExistence(timeout: 3))
        chooseOnMap.tap()

        let pickerStyleButton = app.buttons["manual-location.style.button"]
        XCTAssertTrue(pickerStyleButton.waitForExistence(timeout: 5))
        XCTAssertEqual(pickerStyleButton.value as? String, "Hybrid")
        pickerStyleButton.tap()
        let satelliteChoice = app.buttons["manual-location.style.satellite"]
        XCTAssertTrue(satelliteChoice.waitForExistence(timeout: 3))
        satelliteChoice.tap()
        XCTAssertEqual(pickerStyleButton.value as? String, "Satellite")

        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Map"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Map"].tap()

        let persistedStyleButton = app.buttons["map.style.button"]
        XCTAssertTrue(persistedStyleButton.waitForExistence(timeout: 5))
        XCTAssertEqual(persistedStyleButton.value as? String, "Satellite")

        persistedStyleButton.tap()
        let standardOption = app.buttons["map.style.standard"]
        XCTAssertTrue(standardOption.waitForExistence(timeout: 3))
        standardOption.tap()
        app.buttons["map.layers.done"].tap()
        XCTAssertEqual(persistedStyleButton.value as? String, "Standard")
    }

    func testPublicAccessLayerTogglesWithoutChangingCatchCounts() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        let counts = app.staticTexts["map.counts"]
        XCTAssertTrue(counts.waitForExistence(timeout: 5))
        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")

        let layersButton = app.buttons["map.style.button"]
        XCTAssertTrue(layersButton.waitForExistence(timeout: 5))
        layersButton.tap()

        let accessToggle = app.switches["map.layer.public-access"]
        XCTAssertTrue(accessToggle.waitForExistence(timeout: 3))
        XCTAssertEqual(accessToggle.value as? String, "0")
        accessToggle.switches.firstMatch.tap()
        app.buttons["map.layers.done"].tap()

        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")

        layersButton.tap()
        XCTAssertTrue(accessToggle.waitForExistence(timeout: 3))
        XCTAssertEqual(accessToggle.value as? String, "1")
        accessToggle.switches.firstMatch.tap()
        app.buttons["map.layers.done"].tap()
    }

    func testZeroCatchMapShowsLiveMapCanvasWithCompactHeader() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let mapTab = app.tabBars.buttons["Map"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        XCTAssertTrue(app.staticTexts["map.empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["map.style.button"].waitForExistence(timeout: 3))
    }
}
