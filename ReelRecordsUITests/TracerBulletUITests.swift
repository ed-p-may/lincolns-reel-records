import XCTest

@MainActor
final class TracerBulletUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCatchCanBeCreatedEditedAndDeleted() {
        let app = launchLogbook()

        let addFromEmptyState = app.buttons["log.empty.add"]
        XCTAssertTrue(addFromEmptyState.waitForExistence(timeout: 5))
        addFromEmptyState.tap()

        let species = app.buttons["add.species.Largemouth Bass"]
        XCTAssertTrue(species.waitForExistence(timeout: 3))
        species.tap()

        app.textFields["add.weight"].tap()
        app.textFields["add.weight"].typeText("4.25")
        app.textFields["add.length"].tap()
        app.textFields["add.length"].typeText("20.5")

        let form = app.scrollViews.firstMatch
        form.swipeUp()

        let location = app.textFields["add.location"]
        XCTAssertTrue(location.waitForExistence(timeout: 3))
        location.tap()
        location.typeText("Stockbridge Bowl")
        app.textFields["add.lure"].tap()
        app.textFields["add.lure"].typeText("Green pumpkin jig")
        form.swipeUp()
        app.buttons["Kept"].tap()

        let save = app.buttons["add.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        let rowSpecies = app.staticTexts["Largemouth Bass"]
        XCTAssertTrue(rowSpecies.waitForExistence(timeout: 5))
        rowSpecies.tap()

        XCTAssertTrue(app.staticTexts["4.2 lb"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["20.5 in"].exists)
        XCTAssertTrue(app.staticTexts["Stockbridge Bowl"].exists)
        XCTAssertTrue(app.staticTexts["Green pumpkin jig"].exists)
        XCTAssertTrue(app.staticTexts["Kept"].exists)

        let edit = app.buttons["detail.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()
        let customSpecies = app.textFields["add.species.custom"]
        XCTAssertTrue(customSpecies.waitForExistence(timeout: 3))
        customSpecies.tap()
        customSpecies.typeText("Yellow Perch")
        app.buttons["add.save"].tap()

        XCTAssertTrue(app.navigationBars["Yellow Perch"].waitForExistence(timeout: 5))
        let detailForm = app.scrollViews.firstMatch
        detailForm.swipeUp()
        let delete = app.buttons["detail.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        app.sheets["Delete this catch?"].buttons["Delete Catch"].tap()

        XCTAssertTrue(app.buttons["log.empty.add"].waitForExistence(timeout: 5))
    }

    func testLogDiscoveryControlsComposeAndSurviveDetail() {
        let app = launchLogbook(arguments: ["--ui-testing-logbook"])

        let search = app.textFields["log.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["log.result-count"].label, "2 IN YOUR RECORDS")

        app.buttons["log.sort.heaviest"].tap()
        let trout = app.staticTexts["Rainbow Trout"]
        let bass = app.staticTexts["Largemouth Bass With An Exceptionally Long Display Name"]
        XCTAssertTrue(trout.waitForExistence(timeout: 3))
        XCTAssertLessThan(trout.frame.minY, bass.frame.minY)

        search.tap()
        search.typeText("old dock")
        XCTAssertTrue(trout.waitForExistence(timeout: 3))
        XCTAssertFalse(bass.exists)
        app.buttons["log.species.Largemouth Bass With An Exceptionally Long Display Name"].tap()
        XCTAssertTrue(app.staticTexts["No matching catches"].waitForExistence(timeout: 3))
        app.buttons["log.clear-filters"].tap()

        search.tap()
        search.typeText("bowl")
        XCTAssertTrue(bass.waitForExistence(timeout: 3))
        bass.tap()
        XCTAssertTrue(app.navigationBars["Largemouth Bass With An Exceptionally Long Display Name"]
            .waitForExistence(timeout: 3))
        app.buttons["detail.done"].tap()

        XCTAssertTrue(search.waitForExistence(timeout: 3))
        XCTAssertEqual(search.value as? String, "bowl")
        XCTAssertEqual(app.buttons["log.sort.heaviest"].value as? String, "Selected")

        app.buttons["Clear search"].tap()
        search.tap()
        search.typeText("senko")
        XCTAssertTrue(bass.waitForExistence(timeout: 3))
        XCTAssertFalse(trout.exists)
    }

    func testPhotoGalleryReorderAndRemovalPersistThroughEdit() {
        let app = launchLogbook(arguments: ["--ui-testing-logbook"])

        let bass = app.staticTexts["Largemouth Bass With An Exceptionally Long Display Name"]
        XCTAssertTrue(bass.waitForExistence(timeout: 5))
        bass.tap()

        XCTAssertTrue(app.staticTexts["detail.photo-count"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["detail.photo-count"].label, "2 PHOTOS")

        app.buttons["detail.edit"].tap()
        XCTAssertTrue(app.buttons["photo.later.0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["photo.choose-library"].exists)
        XCTAssertFalse(app.buttons["photo.take-camera"].isEnabled)

        app.buttons["photo.later.0"].tap()
        app.buttons["photo.remove.1"].tap()
        app.buttons["add.save"].tap()

        XCTAssertTrue(app.staticTexts["detail.photo-count"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detail.photo-count"].label, "1 PHOTO")
    }

    func testSavedFilterBookmarkAndShareSheetCompose() {
        let app = launchLogbook(arguments: ["--ui-testing-logbook"])

        app.buttons["log.saved"].tap()
        let bass = app.staticTexts["Largemouth Bass With An Exceptionally Long Display Name"]
        XCTAssertTrue(bass.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Rainbow Trout"].exists)
        bass.tap()

        let bookmark = app.buttons["detail.bookmark"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 3))
        XCTAssertEqual(bookmark.label, "Remove from Saved")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Save catch")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Remove from Saved")

        let share = app.buttons["detail.share"]
        XCTAssertTrue(share.isHittable)
        share.tap()
        let shareSheet = app.descendants(matching: .any)["catch.share-sheet"]
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 8))
        let close = app.buttons["Close"]
        XCTAssertTrue(close.waitForExistence(timeout: 3))
        close.tap()
        XCTAssertTrue(app.buttons["detail.share"].waitForExistence(timeout: 3))
    }

    func testCatchMapSelectionAndDetailFocusRoundTrip() {
        let app = launchLogbook(arguments: ["--ui-testing-logbook"])

        let trout = app.staticTexts["Rainbow Trout"]
        XCTAssertTrue(trout.waitForExistence(timeout: 5))
        trout.tap()
        XCTAssertTrue(app.navigationBars["Rainbow Trout"].waitForExistence(timeout: 3))

        let detailScroll = app.scrollViews.firstMatch
        detailScroll.swipeUp()
        detailScroll.swipeUp()
        let showOnMap = app.buttons["detail.show-on-map"]
        XCTAssertTrue(showOnMap.waitForExistence(timeout: 3))
        showOnMap.tap()

        let counts = app.staticTexts["map.counts"]
        XCTAssertTrue(counts.waitForExistence(timeout: 5))
        XCTAssertEqual(counts.label, "2 CATCHES ACROSS 2 SPOTS")
        let selectedCatch = app.buttons["map.selected-catch"]
        XCTAssertTrue(selectedCatch.waitForExistence(timeout: 3))
        XCTAssertTrue(selectedCatch.label.contains("Rainbow Trout"))
        XCTAssertTrue(selectedCatch.label.contains("Lake Mansfield"))
        selectedCatch.tap()
        XCTAssertTrue(app.navigationBars["Rainbow Trout"].waitForExistence(timeout: 3))
    }

    func testManualPinCanBeChosenWithoutRequestingGPS() {
        let app = launchLogbook()

        XCTAssertTrue(app.buttons["log.empty.add"].waitForExistence(timeout: 5))
        app.buttons["log.empty.add"].tap()
        let addScroll = app.scrollViews.firstMatch
        addScroll.swipeUp()
        addScroll.swipeUp()

        let chooseOnMap = app.buttons["add.location.manual"]
        XCTAssertTrue(chooseOnMap.waitForExistence(timeout: 3))
        chooseOnMap.tap()

        let map = app.otherElements["manual-location.map"]
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.45)).tap()
        let usePin = app.buttons["manual-location.use"]
        XCTAssertTrue(usePin.waitForExistence(timeout: 3))
        XCTAssertTrue(usePin.isEnabled)
        usePin.tap()

        XCTAssertTrue(app.buttons["add.location.clear"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["add.save"].isEnabled)
    }

    func testManualConditionsSaveWithoutWeatherService() {
        let app = launchLogbook()

        XCTAssertTrue(app.buttons["log.empty.add"].waitForExistence(timeout: 5))
        app.buttons["log.empty.add"].tap()
        app.buttons["add.species.Smallmouth Bass"].tap()

        let form = app.scrollViews.firstMatch
        form.swipeUp()
        let airTemperature = app.textFields["add.air-temperature"]
        XCTAssertTrue(airTemperature.waitForExistence(timeout: 3))
        airTemperature.tap()
        airTemperature.typeText("72.5")
        form.swipeDown()
        let waterTemperature = app.textFields["add.water-temperature"]
        waterTemperature.tap()
        waterTemperature.typeText("64")
        form.swipeUp()

        let rain = app.buttons["add.sky.rain"]
        XCTAssertTrue(rain.waitForExistence(timeout: 3))
        rain.tap()
        let stained = app.buttons["add.clarity.stained"]
        XCTAssertTrue(stained.waitForExistence(timeout: 3))
        stained.tap()
        app.buttons["add.save"].tap()

        let species = app.staticTexts["Smallmouth Bass"]
        XCTAssertTrue(species.waitForExistence(timeout: 5))
        species.tap()
        let detail = app.scrollViews.firstMatch
        detail.swipeUp()
        XCTAssertTrue(app.staticTexts["72.5°F"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Rain"].exists)
        XCTAssertTrue(app.staticTexts["64°F"].exists)
        XCTAssertTrue(app.staticTexts["Stained"].exists)
    }

    func testLogAndDetailRemainNavigableAtLargestAccessibilityText() {
        let app = launchLogbook(arguments: [
            "--ui-testing-logbook",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        XCTAssertTrue(app.textFields["log.search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["log.sort.recent"].isHittable)
        let bass = app.staticTexts["Largemouth Bass With An Exceptionally Long Display Name"]
        XCTAssertTrue(bass.waitForExistence(timeout: 3))
        bass.tap()

        XCTAssertTrue(app.navigationBars["Largemouth Bass With An Exceptionally Long Display Name"]
            .waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2.2 lb"].exists)
        XCTAssertTrue(app.staticTexts["Field notes"].exists)
        XCTAssertTrue(app.buttons["detail.done"].isHittable)
    }

    func testDashboardSummaryDetailAndSpotNavigationUseLocalLogbook() {
        let app = launchApp(arguments: ["--ui-testing-logbook"])

        let total = app.staticTexts["dashboard.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "2")
        XCTAssertTrue(app.staticTexts["dashboard.greeting"].label.contains("Lincoln"))
        XCTAssertTrue(app.staticTexts["6.5 lb"].exists)

        let recentBass = app.buttons["dashboard.recent.0"]
        XCTAssertTrue(recentBass.waitForExistence(timeout: 3))
        recentBass.tap()
        XCTAssertTrue(app.navigationBars["Largemouth Bass With An Exceptionally Long Display Name"]
            .waitForExistence(timeout: 3))
        app.buttons["detail.done"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 3))

        let dashboard = app.scrollViews.firstMatch
        dashboard.swipeUp()
        let seeAll = app.buttons["dashboard.see-all"]
        XCTAssertTrue(seeAll.waitForExistence(timeout: 3))
        seeAll.tap()
        XCTAssertTrue(app.textFields["log.search"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Home"].tap()
        XCTAssertTrue(total.waitForExistence(timeout: 3))

        dashboard.swipeUp()
        dashboard.swipeUp()
        let favoriteSpot = app.buttons["dashboard.spot.stockbridge bowl north shore by the old stone landing"]
        XCTAssertTrue(favoriteSpot.waitForExistence(timeout: 3))
        favoriteSpot.tap()
        XCTAssertTrue(app.staticTexts["map.counts"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["map.selected-catch"].label.contains("Largemouth Bass"))
    }

    func testDashboardEmptyStateAddsCatchAndReturnsHome() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["dashboard.total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["dashboard.total"].label, "0")
        XCTAssertTrue(app.staticTexts["Your first catch will appear here"].exists)
        app.buttons["dashboard.add"].tap()
        app.buttons["add.species.Smallmouth Bass"].tap()
        app.buttons["add.save"].tap()

        XCTAssertTrue(app.staticTexts["dashboard.total"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["dashboard.total"].label, "1")
        XCTAssertTrue(app.staticTexts["Smallmouth Bass"].exists)
    }

    private func launchLogbook(arguments: [String] = []) -> XCUIApplication {
        let app = launchApp(arguments: arguments)
        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 5))
        logTab.tap()
        return app
    }

    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }
}
