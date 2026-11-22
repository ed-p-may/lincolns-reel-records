import XCTest

@MainActor
final class EditCatchWeatherUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The seeded catch has a pin and no air temperature; the fixture provider would fill 72 °F if asked.
    func testUntouchedEditOfPinnedCatchRequestsNoWeather() {
        let app = XCUIApplication()
        app.launchArguments = [
            "--ui-testing",
            "--ui-testing-last-used-defaults",
            "--ui-testing-weather-fixture"
        ]
        app.launch()
        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 5))
        logTab.tap()

        let row = app.staticTexts["Smallmouth Bass"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let edit = app.buttons["detail.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()

        let airTemperature = app.textFields["add.air-temperature"]
        XCTAssertTrue(airTemperature.waitForExistence(timeout: 3))
        let suggested = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value CONTAINS %@", "72"),
            object: airTemperature
        )
        XCTAssertEqual(XCTWaiter.wait(for: [suggested], timeout: 2), .timedOut)

        app.buttons["add.save"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()
        XCTAssertTrue(airTemperature.waitForExistence(timeout: 3))
        XCTAssertFalse((airTemperature.value as? String ?? "").contains("72"))
    }
}
