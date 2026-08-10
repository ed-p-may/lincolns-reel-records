import XCTest

@MainActor
final class LastUsedDefaultsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testNewCatchUsesSameDayDefaultsWithoutReusingPin() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-last-used-defaults"]
        app.launch()
        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 5))
        logTab.tap()

        let addCatch = app.buttons["Log a catch"]
        XCTAssertTrue(addCatch.waitForExistence(timeout: 5))
        addCatch.tap()

        let form = app.scrollViews.firstMatch
        form.swipeUp()
        let location = app.textFields["add.location"]
        XCTAssertTrue(location.waitForExistence(timeout: 3))
        let locationLoaded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Last Used Cove"),
            object: location
        )
        XCTAssertEqual(XCTWaiter.wait(for: [locationLoaded], timeout: 3), .completed)
        XCTAssertTrue(app.staticTexts["No coordinate pin"].exists)
        XCTAssertFalse(app.buttons["add.location.clear"].exists)
        XCTAssertEqual(app.buttons["add.sky.overcast"].value as? String, "Selected")
        XCTAssertEqual(app.buttons["add.clarity.muddy"].value as? String, "Selected")

        form.swipeUp()
        let selectedTackle = app.buttons["add.tackle.selected"]
        XCTAssertTrue(selectedTackle.waitForExistence(timeout: 3))
        XCTAssertTrue(selectedTackle.label.contains("Green Pumpkin Senko"))
        XCTAssertEqual(app.textFields["add.lure"].value as? String, "Black trailer")
    }
}
