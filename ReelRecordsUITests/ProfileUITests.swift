import XCTest

@MainActor
final class ProfileUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testProfileShowsDerivedStatsHonestSettingsAndEditsIdentitySafeFields() {
        let app = launchProfile(arguments: ["--ui-testing-logbook"])

        XCTAssertTrue(app.staticTexts["profile.display-name"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["profile.display-name"].label, "Lincoln Fisher")
        let signature = "Signature species · Largemouth Bass With An Exceptionally Long Display Name"
        XCTAssertTrue(app.staticTexts[signature].exists)

        app.buttons["profile.edit"].tap()
        let homeWater = app.textFields["profile.editor.home-water"]
        XCTAssertTrue(homeWater.waitForExistence(timeout: 3))
        homeWater.tap()
        homeWater.typeText(" North Pond")
        app.buttons["profile.editor.save"].tap()

        XCTAssertTrue(app.staticTexts["Angler since 2019 · Stockbridge Bowl North Pond"].waitForExistence(timeout: 3))
        let profile = app.scrollViews.firstMatch
        profile.swipeUp()
        profile.swipeUp()
        XCTAssertTrue(app.staticTexts["lb · in"].exists)
        let comingSoon = app.staticTexts.matching(NSPredicate(format: "label == %@", "Coming Soon"))
        XCTAssertGreaterThanOrEqual(comingSoon.count, 2)
        profile.swipeUp()
        XCTAssertTrue(app.buttons["Delete Account"].exists)
    }

    func testProfileRemainsNavigableAtLargestAccessibilityText() {
        let app = launchProfile(arguments: [
            "--ui-testing-logbook",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ])

        XCTAssertTrue(app.staticTexts["profile.display-name"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["profile.edit"].isHittable)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.buttons["profile.tackle-box"].waitForExistence(timeout: 3))
    }

    private func launchProfile(arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        let profileTab = app.tabBars.buttons["You"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()
        return app
    }
}
