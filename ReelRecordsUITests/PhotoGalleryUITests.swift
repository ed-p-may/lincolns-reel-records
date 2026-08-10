import XCTest

@MainActor
final class PhotoGalleryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGridAndCatchDetailOpenFullScreenViewer() {
        let app = launchLogbook()

        let gallery = app.buttons["log.photo-gallery"]
        XCTAssertTrue(gallery.waitForExistence(timeout: 5))
        gallery.tap()
        XCTAssertTrue(app.navigationBars["Photos"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["gallery.count"].label, "2 PHOTOS")

        let firstPhoto = app.buttons["gallery.photo.0"]
        XCTAssertTrue(firstPhoto.waitForExistence(timeout: 3))
        firstPhoto.tap()
        XCTAssertTrue(app.buttons["photo.viewer.close"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["photo.viewer.position"].label, "1 OF 2")
        app.swipeLeft()
        XCTAssertTrue(app.staticTexts["2 OF 2"].waitForExistence(timeout: 3))
        app.buttons["photo.viewer.close"].tap()

        app.navigationBars["Photos"].buttons["Fishing Log"].tap()
        let bass = app.staticTexts["Largemouth Bass With An Exceptionally Long Display Name"]
        XCTAssertTrue(bass.waitForExistence(timeout: 3))
        bass.tap()

        let detailPhoto = app.buttons["detail.photo.0"]
        XCTAssertTrue(detailPhoto.waitForExistence(timeout: 3))
        detailPhoto.tap()
        XCTAssertTrue(app.buttons["photo.viewer.close"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["photo.viewer.position"].label, "1 OF 2")
        app.buttons["photo.viewer.close"].tap()
        XCTAssertTrue(app.buttons["detail.done"].waitForExistence(timeout: 3))
    }

    private func launchLogbook() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-logbook"]
        app.launch()
        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 5))
        logTab.tap()
        return app
    }
}
