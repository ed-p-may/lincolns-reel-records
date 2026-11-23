import XCTest

@MainActor
final class TackleBoxUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTackleCatalogSearchTypeArchiveAndRestoreVisibility() {
        let app = launchApp(arguments: ["--ui-testing-logbook"])

        app.tabBars.buttons["You"].tap()
        let tackleLink = app.buttons["profile.tackle-box"]
        XCTAssertTrue(tackleLink.waitForExistence(timeout: 5))
        tackleLink.tap()

        XCTAssertTrue(app.navigationBars["Tackle Box"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["tackle.section.soft_plastic"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["tackle.section.spinnerbait"].exists)
        let spinner = app.staticTexts["Chartreuse Spinner"]
        XCTAssertTrue(spinner.waitForExistence(timeout: 3))
        let catalogScreenshot = XCTAttachment(screenshot: app.screenshot())
        catalogScreenshot.name = "Phase 08 Tackle Box catalog"
        catalogScreenshot.lifetime = .keepAlways
        add(catalogScreenshot)
        app.textFields["tackle.search"].tap()
        app.textFields["tackle.search"].typeText("spinner")
        app.buttons["tackle.type.spinnerbait"].tap()
        XCTAssertTrue(spinner.waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["tackle.section.soft_plastic"].exists)
        XCTAssertFalse(app.staticTexts["tackle.section.spinnerbait"].exists)
        XCTAssertFalse(app.staticTexts["Green Pumpkin Senko"].exists)

        spinner.tap()
        let archivedToggle = app.switches["tackle.editor.archived"]
        XCTAssertTrue(archivedToggle.waitForExistence(timeout: 3))
        archivedToggle.tap()
        app.buttons["tackle.editor.save"].tap()

        XCTAssertFalse(spinner.waitForExistence(timeout: 2))
        app.segmentedControls["tackle.archive-filter"].buttons["Archived"].tap()
        XCTAssertTrue(spinner.waitForExistence(timeout: 3))

        spinner.tap()
        XCTAssertTrue(archivedToggle.waitForExistence(timeout: 3))
        archivedToggle.tap()
        app.buttons["tackle.editor.save"].tap()
        app.segmentedControls["tackle.archive-filter"].buttons["Active"].tap()
        XCTAssertTrue(spinner.waitForExistence(timeout: 3))
    }

    func testInlineTackleCreationLinksNewCatchAndOpensFromDetail() {
        let app = launchLogbook()

        XCTAssertTrue(app.buttons["log.empty.add"].waitForExistence(timeout: 5))
        app.buttons["log.empty.add"].tap()
        app.buttons["add.species.Smallmouth Bass"].tap()
        let form = app.scrollViews.firstMatch
        for _ in 0 ..< 5 where !app.buttons["add.tackle.new"].exists {
            form.swipeUp()
        }
        let newTackle = app.buttons["add.tackle.new"]
        XCTAssertTrue(newTackle.waitForExistence(timeout: 3))
        newTackle.tap()

        let name = app.textFields["tackle.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("River Jig")
        app.buttons["tackle.editor.save"].tap()

        XCTAssertTrue(app.buttons["add.tackle.selected"].waitForExistence(timeout: 5))
        app.buttons["add.save"].tap()
        let species = app.staticTexts["Smallmouth Bass"]
        XCTAssertTrue(species.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["River Jig"].exists)
        species.tap()
        XCTAssertTrue(app.buttons["detail.tackle-item"].waitForExistence(timeout: 5))
        app.buttons["detail.tackle-item"].tap()
        XCTAssertTrue(app.navigationBars["Edit Tackle"].waitForExistence(timeout: 3))
        let archivedToggle = app.switches["tackle.editor.archived"]
        XCTAssertTrue(archivedToggle.waitForExistence(timeout: 3))
        archivedToggle.tap()
        app.buttons["tackle.editor.save"].tap()
        XCTAssertTrue(app.buttons["detail.tackle-item"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["ARCHIVED"].exists)
    }

    func testLogCatchRecentStripAndFullScreenGalleryPickerSelectAndCreate() {
        let app = launchApp(arguments: ["--ui-testing-tackle-recency"])

        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 5))
        logTab.tap()
        let addButton = app.buttons["Log a catch"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let form = app.scrollViews.firstMatch
        for _ in 0 ..< 5 where !app.buttons["add.tackle.browse"].exists {
            form.swipeUp()
        }

        assertRecentStripShowsTopFiveOnly(in: app)

        let browseButton = app.buttons["add.tackle.browse"]
        XCTAssertTrue(browseButton.waitForExistence(timeout: 3))
        browseButton.tap()

        assertGallerySearchTypeFilterAndClear(in: app)

        app.buttons["tackle.picker.type.spinnerbait"].tap()
        let spinnerTile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'tackle.picker.item.' AND label CONTAINS 'Lure Seven'")
        ).firstMatch
        XCTAssertTrue(spinnerTile.waitForExistence(timeout: 3))
        spinnerTile.tap()

        let selectedBanner = app.buttons["add.tackle.selected"]
        XCTAssertTrue(selectedBanner.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedBanner.label.contains("Lure Seven"))

        browseButton.tap()
        XCTAssertTrue(app.navigationBars["Choose Lure / Bait"].waitForExistence(timeout: 5))
        app.buttons["tackle.picker.add"].tap()
        let name = app.textFields["tackle.editor.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Inline Crank")
        app.buttons["tackle.editor.save"].tap()

        XCTAssertTrue(selectedBanner.waitForExistence(timeout: 5))
        XCTAssertTrue(selectedBanner.label.contains("Inline Crank"))
    }

    private func assertRecentStripShowsTopFiveOnly(in app: XCUIApplication) {
        let stripLabel = app.staticTexts["add.tackle.strip-label"]
        XCTAssertTrue(stripLabel.waitForExistence(timeout: 3))
        XCTAssertEqual(stripLabel.label, "RECENTLY USED")

        let expected = ["Lure Six", "Lure Five", "Lure Four", "Lure Three", "Lure Two"]
        var previousMinX: CGFloat = -.greatestFiniteMagnitude
        for name in expected {
            let button = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'add.tackle.' AND label CONTAINS %@", name)
            ).firstMatch
            XCTAssertTrue(button.waitForExistence(timeout: 3), "Expected \(name) in recent strip")
            XCTAssertGreaterThan(button.frame.minX, previousMinX)
            previousMinX = button.frame.minX
        }

        for excluded in ["Lure One", "Lure Seven"] {
            let button = app.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'add.tackle.' AND label CONTAINS %@", excluded)
            ).firstMatch
            XCTAssertFalse(button.exists)
        }
    }

    private func assertGallerySearchTypeFilterAndClear(in app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Choose Lure / Bait"].waitForExistence(timeout: 5))
        let recentHeader = app.staticTexts["tackle.picker.section.recent"]
        XCTAssertTrue(recentHeader.waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["tackle.picker.section.soft_plastic"].exists)

        let search = app.textFields["tackle.picker.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("YAMAMOTO")
        XCTAssertFalse(recentHeader.exists)
        let yamamotoTile = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'tackle.picker.item.' AND label CONTAINS 'Lure One'")
        ).firstMatch
        XCTAssertTrue(yamamotoTile.waitForExistence(timeout: 3))

        app.buttons["tackle.picker.type.spinnerbait"].tap()
        let clearFilters = app.buttons["tackle.picker.clear-filters"]
        XCTAssertTrue(clearFilters.waitForExistence(timeout: 3))
        clearFilters.tap()
        XCTAssertTrue(recentHeader.waitForExistence(timeout: 3))
    }

    private func launchLogbook() -> XCUIApplication {
        let app = launchApp()
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
