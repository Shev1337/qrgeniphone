import XCTest

final class ScanFlowTests: XCTestCase {
    @MainActor
    func testFirstScanShowsCompleteReviewAndCreatesReceipt() {
        let app = launchScanner()
        readQRCode(in: app)
        verifyReview(in: app, scan: 1, number: "721BG04")

        app.buttons["scan.review.confirm"].tap()
        XCTAssertTrue(app.images["ticket.qr"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRescanReplacesTheEntireReview() {
        let app = launchScanner()
        readQRCode(in: app)
        verifyReview(in: app, scan: 1, number: "721BG04")

        let rescan = app.buttons["scan.review.rescan"]
        if !rescan.isHittable { app.scrollViews.firstMatch.swipeUp() }
        rescan.tap()
        readQRCode(in: app)
        verifyReview(in: app, scan: 2, number: "837AY04")
    }

    @MainActor
    private func launchScanner() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-scanner")
        app.launch()
        let scanner = app.buttons["scan.open"]
        XCTAssertTrue(scanner.waitForExistence(timeout: 10))
        scanner.tap()
        return app
    }

    @MainActor
    private func readQRCode(in app: XCUIApplication) {
        let read = app.buttons["scan.fixture.read"]
        XCTAssertTrue(read.waitForExistence(timeout: 5))
        read.tap()
    }

    @MainActor
    private func verifyReview(in app: XCUIApplication, scan: Int, number: String) {
        let expected = "https://example.com/scan/\(scan)?ticket=123"
        let payload = app.staticTexts["scan.review.payload"]
        XCTAssertTrue(payload.waitForExistence(timeout: 5))
        XCTAssertEqual(payload.label, expected)
        XCTAssertTrue(app.images["scan.review.preview"].exists)
        XCTAssertEqual(app.textFields["scan.review.number"].value as? String, number)
        XCTAssertTrue(app.buttons["scan.review.confirm"].isEnabled)
    }
}
