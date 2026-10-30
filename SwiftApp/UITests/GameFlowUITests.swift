import XCTest

/// The main flows, on a throwaway progress file with red always the answer.
final class GameFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ElisaFreshState", "YES", "-ElisaAnswer", "red"] + extra
        app.launch()
        return app
    }

    private func value(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    func testTheHintPointsAtPlayUntilItIsPressed() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["play-hint"].waitForExistence(timeout: 10))
        app.buttons["play-button"].tap()
        XCTAssertFalse(app.staticTexts["play-hint"].exists)
    }

    func testATapBeforePlayIsNotAnAnswer() {
        let app = launch()
        let red = app.buttons["flag-red"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        red.tap()
        XCTAssertEqual(value(red), "")
    }

    func testWrongThenRightThenTheFlagsWaitForPlay() {
        let app = launch()
        let red = app.buttons["flag-red"]
        let yellow = app.buttons["flag-yellow"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        app.buttons["play-button"].tap()

        yellow.tap()
        XCTAssertEqual(value(yellow), "", "a wrong answer isn't marked")

        red.tap()
        XCTAssertEqual(value(red), "correct")

        // After the 3 s reveal the next chord waits for play: dimmed, and a tap does nothing.
        expectation(for: NSPredicate(format: "value == 'dimmed'"), evaluatedWith: red)
        waitForExpectations(timeout: 8)
        red.tap()
        XCTAssertEqual(value(red), "dimmed")

        app.buttons["play-button"].tap()
        XCTAssertEqual(value(red), "")
        red.tap()
        XCTAssertEqual(value(red), "correct")
    }

    func testABlackKeyLevelHasTenFlags() {
        let app = launch(["-ElisaLevel", "gray"])
        XCTAssertTrue(app.buttons["flag-gray"].waitForExistence(timeout: 10))
        let flags = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flag-'"))
        XCTAssertEqual(flags.count, 10)
    }
}
