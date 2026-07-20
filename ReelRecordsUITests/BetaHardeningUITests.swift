import XCTest

@MainActor
final class BetaHardeningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPrimarySurfacesPassAutomatedAccessibilityAudit() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()

        XCTAssertTrue(app.staticTexts["dashboard.total"].waitForExistence(timeout: 5))
        try audit(app)

        app.tabBars.buttons["Log"].tap()
        XCTAssertTrue(app.textFields["log.search"].waitForExistence(timeout: 5))
        try audit(app)

        app.tabBars.buttons["You"].tap()
        XCTAssertTrue(app.staticTexts["profile.display-name"].waitForExistence(timeout: 5))
        try audit(app)
    }

    private func audit(_ app: XCUIApplication) throws {
        try app.performAccessibilityAudit { issue in
            if issue.auditType == .dynamicType {
                return true
            }
            guard issue.auditType == .contrast || issue.auditType == .textClipped else { return false }
            guard let element = issue.element else { return true }
            if issue.auditType == .textClipped, element.elementType == .textField {
                return true
            }

            let tabBarFrame = app.tabBars.firstMatch.frame
            let tabBarOcclusionFrame = tabBarFrame.insetBy(dx: 0, dy: -24)
            return !tabBarFrame.isNull && element.frame.intersects(tabBarOcclusionFrame)
        }
    }
}
