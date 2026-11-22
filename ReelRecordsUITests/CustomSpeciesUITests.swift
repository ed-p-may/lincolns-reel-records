import XCTest

@MainActor
final class CustomSpeciesUITests: XCTestCase {
    private let customSpecies = "Largemouth Bass With An Exceptionally Long Display Name"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The logbook seed holds a catch whose species is outside the seed list, as "Other species" saves it.
    func testLoggedCustomSpeciesBecomesSelectableChip() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()
        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 5))
        logTab.tap()

        let addCatch = app.buttons["Log a catch"]
        XCTAssertTrue(addCatch.waitForExistence(timeout: 5))
        addCatch.tap()
        let newFormChip = app.buttons["add.species.\(customSpecies)"]
        XCTAssertTrue(newFormChip.waitForExistence(timeout: 3))
        XCTAssertEqual(newFormChip.value as? String, "Not selected")
        app.buttons["Cancel"].tap()

        let row = app.staticTexts[customSpecies]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let edit = app.buttons["detail.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 3))
        edit.tap()
        let editChip = app.buttons["add.species.\(customSpecies)"]
        XCTAssertTrue(editChip.waitForExistence(timeout: 3))
        XCTAssertEqual(editChip.value as? String, "Selected")
        XCTAssertEqual(app.textFields["add.species.custom"].value as? String, "Other species")
    }
}
