import XCTest

@MainActor
final class TracerBulletUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testCatchCanBeCreatedEditedAndDeleted() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

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
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()

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
    }

    func testLogAndDetailRemainNavigableAtLargestAccessibilityText() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-logbook",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

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
}
