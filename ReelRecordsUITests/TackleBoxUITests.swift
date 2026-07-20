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
