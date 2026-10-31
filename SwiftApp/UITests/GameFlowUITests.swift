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

    /// Any element with this accessibility id, whatever its type.
    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testARightAnswerShowsACharacterForThreeSeconds() {
        let app = launch()
        let red = app.buttons["flag-red"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        let character = element(app, "character-reveal")
        XCTAssertFalse(character.exists)
        app.buttons["play-button"].tap()

        app.buttons["flag-yellow"].tap()
        XCTAssertFalse(character.exists, "a wrong answer shows no character")

        red.tap()
        XCTAssertTrue(character.waitForExistence(timeout: 2))
        XCTAssertFalse(character.label.isEmpty, "the character's name is shown")

        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: character)
        waitForExpectations(timeout: 8)
    }

    func testTheOutlineFollowsTheStreak() {
        let app = launch(["-ElisaStreak", "7"])
        let outline = element(app, "streak-outline")
        XCTAssertTrue(outline.waitForExistence(timeout: 10))
        XCTAssertEqual(value(outline), "7")
        app.buttons["play-button"].tap()

        app.buttons["flag-yellow"].tap()
        XCTAssertEqual(value(outline), "0", "a miss starts the streak over")

        app.buttons["flag-red"].tap()
        XCTAssertEqual(value(outline), "1")
    }

    func testTwentyInARowMovesToTheNextLevel() {
        let app = launch(["-ElisaStreak", "19"])
        let red = app.buttons["flag-red"]
        XCTAssertTrue(red.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["flag-blue"].exists)
        app.buttons["play-button"].tap()
        red.tap()

        // After the reveal the next level starts: its flags show, dimmed, with the play hint.
        XCTAssertTrue(app.buttons["flag-blue"].waitForExistence(timeout: 8))
        XCTAssertEqual(value(red), "dimmed")
        XCTAssertTrue(app.staticTexts["play-hint"].exists)
        XCTAssertEqual(value(element(app, "streak-outline")), "0")

        app.buttons["play-button"].tap()
        XCTAssertEqual(value(red), "")
    }
}
