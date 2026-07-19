import XCTest

@MainActor
final class TracerBulletUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAuthenticatedEmptyStateCanSaveCatch() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()

        let addFromEmptyState = app.buttons["log.empty.add"]
        XCTAssertTrue(addFromEmptyState.waitForExistence(timeout: 5))
        addFromEmptyState.tap()

        let species = app.buttons["add.species.Largemouth Bass"]
        XCTAssertTrue(species.waitForExistence(timeout: 3))
        species.tap()

        let save = app.buttons["add.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()

        XCTAssertTrue(app.staticTexts["Largemouth Bass"].waitForExistence(timeout: 5))
    }
}
