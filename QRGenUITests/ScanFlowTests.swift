import XCTest

final class ScanFlowTests: XCTestCase {
    @MainActor
    func testFirstScanShowsCompleteReviewAndCreatesReceipt() {
        let app = launchScanner()
        readQRCode(in: app)
        verifyReview(in: app, scan: 1, number: "721BG04")

        app.buttons["receipt.review.confirm"].tap()
        XCTAssertTrue(app.images["ticket.qr"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRescanReplacesTheEntireReview() {
        let app = launchScanner(verifyServices: true)
        readQRCode(in: app)
        verifyReview(in: app, scan: 1, number: "721BG04")

        app.buttons["receipt.review.rescan"].tap()
        readQRCode(in: app)
        verifyReview(in: app, scan: 2, number: "837AY04")
    }

    @MainActor
    func testManualReceiptRequiresConfirmation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let services = app.buttons["services.open"]
        XCTAssertTrue(services.waitForExistence(timeout: 10))
        services.tap()

        let create = app.buttons["Создать QR-код"]
        XCTAssertTrue(create.waitForExistence(timeout: 5))
        if !create.isHittable { app.scrollViews.firstMatch.swipeUp() }
        create.tap()

        let confirm = app.buttons["receipt.review.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertFalse(app.images["ticket.qr"].exists)
        app.buttons["receipt.review.cancel"].tap()
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: confirm)
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        XCTAssertFalse(app.images["ticket.qr"].exists)

        create.tap()
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertTrue(app.images["ticket.qr"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func launchScanner(verifyServices: Bool = false) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-scanner")
        app.launch()
        XCTAssertTrue(app.staticTexts["QR и чеки"].waitForExistence(timeout: 10))
        if verifyServices {
            app.buttons["history.open.home"].tap()
            XCTAssertTrue(app.navigationBars["История чеков"].waitForExistence(timeout: 5))
            app.buttons["Закрыть"].tap()
            XCTAssertTrue(app.staticTexts["QR и чеки"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Магазины"].exists)
            XCTAssertFalse(app.buttons["Магазины"].exists)
            app.buttons["services.open"].tap()
            XCTAssertTrue(app.staticTexts["QR-генератор"].waitForExistence(timeout: 5))
            app.buttons["services.back"].tap()
            XCTAssertTrue(app.staticTexts["QR и чеки"].waitForExistence(timeout: 5))
        }
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
        let payload = app.staticTexts["receipt.review.payload"]
        XCTAssertTrue(payload.waitForExistence(timeout: 5))
        XCTAssertEqual(payload.label, expected)
        XCTAssertTrue(app.images["receipt.review.preview"].exists)
        XCTAssertEqual(app.textFields["receipt.review.number"].value as? String, number)
        XCTAssertTrue(app.buttons["receipt.review.confirm"].isEnabled)
    }
}
