import XCTest

@MainActor
final class PhotoMetadataDefaultsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPhotoMetadataPrefillsCaughtTimeAndCoordinate() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-photo-metadata-defaults"]
        app.launch()

        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 5))
        logTab.tap()
        let addCatch = app.buttons["Log a catch"]
        XCTAssertTrue(addCatch.waitForExistence(timeout: 5))
        addCatch.tap()

        let form = app.scrollViews.firstMatch
        let choosePhotos = app.buttons["photo.choose-library"]
        XCTAssertTrue(choosePhotos.waitForExistence(timeout: 3))
        choosePhotos.tap()
        form.swipeUp()
        let caughtAt = app.descendants(matching: .any)["add.caught-at"]
        XCTAssertTrue(caughtAt.waitForExistence(timeout: 3))
        let capturedDate = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'Aug' AND label CONTAINS '9' AND label CONTAINS '2026'"
        )).firstMatch
        let capturedTime = app.buttons.matching(NSPredicate(format: "label CONTAINS '7:15'")).firstMatch
        XCTAssertTrue(capturedDate.exists)
        XCTAssertTrue(capturedTime.exists)
        capturedDate.tap()
        let manualCalendarDate = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'August' AND label CONTAINS '10' AND NOT label CONTAINS '2026'"
        )).firstMatch
        XCTAssertTrue(manualCalendarDate.waitForExistence(timeout: 3))
        manualCalendarDate.tap()
        app.navigationBars["Log a Catch"].tap()

        form.swipeUp()
        XCTAssertTrue(app.staticTexts["Catch pin saved"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["42.31690, -73.32260"].exists)
        let clearPin = app.buttons["add.location.clear"]
        XCTAssertTrue(clearPin.exists)
        clearPin.tap()
        XCTAssertFalse(app.staticTexts["42.31690, -73.32260"].exists)
        XCTAssertFalse(app.staticTexts["Catch pin saved"].exists)

        form.swipeDown()
        form.swipeDown()
        XCTAssertTrue(choosePhotos.waitForExistence(timeout: 3))
        choosePhotos.tap()
        form.swipeUp()
        let manualDate = app.buttons.matching(NSPredicate(
            format: "label CONTAINS[c] 'Aug' AND label CONTAINS '10' AND label CONTAINS '2026'"
        )).firstMatch
        XCTAssertTrue(manualDate.exists)
        form.swipeUp()
        XCTAssertFalse(app.staticTexts["42.31690, -73.32260"].exists)
        XCTAssertFalse(app.staticTexts["Catch pin saved"].exists)
    }
}
