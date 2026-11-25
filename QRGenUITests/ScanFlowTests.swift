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
        XCTAssertTrue(app.staticTexts["Чек QRArest"].exists)
    }

    @MainActor
    func testHoldLogoSwitchesAndRemembersAppearance() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test-scanner")
        app.launch()

        let classicOnly = app.staticTexts["Магазины"]
        if classicOnly.exists { holdAppearanceMark(in: app) }
        XCTAssertTrue(app.buttons["services.open.manual"].waitForExistence(timeout: 5))
        holdAppearanceMark(in: app)
        XCTAssertTrue(classicOnly.waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        XCTAssertTrue(classicOnly.waitForExistence(timeout: 10))
        holdAppearanceMark(in: app)
        XCTAssertTrue(app.buttons["services.open.manual"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func holdAppearanceMark(in app: XCUIApplication) {
        let mark = app.images["appearance.toggle"]
        XCTAssertTrue(mark.waitForExistence(timeout: 10))
        mark.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 1.4)
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
            XCTAssertTrue(app.buttons["services.open.manual"].exists)
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
