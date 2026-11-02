import XCTest

/// Screenshots to compare with SwiftApp/Reference Material/screenshots/. Skipped unless the
/// test runner has ELISA_SCREENSHOTS=1 (pass TEST_RUNNER_ELISA_SCREENSHOTS=1 to xcodebuild).
final class ScreenshotTests: XCTestCase {
    static let levels = ["yellow", "blue", "black", "green", "orange", "purple", "pink", "brown",
                         "gray", "tan", "lightgreen", "lightpurple", "skyblue"]

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["ELISA_SCREENSHOTS"] == "1",
                          "set TEST_RUNNER_ELISA_SCREENSHOTS=1 to take screenshots")
    }

    private var orientation: UIDeviceOrientation = .portrait

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ElisaFreshState", "YES"] + arguments
        app.launch()
        // Rotate after launch and let the window settle, or the capture shows a half-turned frame.
        XCUIDevice.shared.orientation = orientation
        if orientation.isLandscape {
            let window = app.windows.firstMatch
            let settled = NSPredicate { _, _ in window.frame.width > window.frame.height }
            wait(for: [XCTNSPredicateExpectation(predicate: settled, object: nil)], timeout: 5)
        }
        Thread.sleep(forTimeInterval: 0.6)
        return app
    }

    private func keep(_ app: XCUIApplication, _ name: String, settle: TimeInterval = 0.5) {
        Thread.sleep(forTimeInterval: settle) // let any animation finish before the capture
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testLevels() {
        let orientations: [(String, UIDeviceOrientation)] = UIDevice.current.userInterfaceIdiom == .pad
            ? [("portrait", .portrait), ("landscape", .landscapeLeft)]
            : [("portrait", .portrait)]
        for (name, orientation) in orientations {
            self.orientation = orientation
            XCUIDevice.shared.orientation = orientation
            for level in Self.levels {
                let app = launch(["-ElisaLevel", level])
                _ = app.buttons["flag-\(level)"].waitForExistence(timeout: 10)
                keep(app, "level-\(level)-\(name)")
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testAnswerStates() {
        XCUIDevice.shared.orientation = .portrait
        let app = launch(["-ElisaAnswer", "red"])
        let red = app.buttons["flag-red"]
        _ = red.waitForExistence(timeout: 10)
        keep(app, "state-01-first-run-play-hint")
        app.buttons["play-button"].tap()
        keep(app, "state-02-chord-playing")
        app.waitForTheChord()
        app.buttons["flag-yellow"].tap()
        keep(app, "state-03-wrong-answer")
        red.tap()
        keep(app, "state-04-correct")
        expectation(for: NSPredicate(format: "value == 'dimmed'"), evaluatedWith: red)
        waitForExpectations(timeout: 8)
        keep(app, "state-05-awaiting-play")
    }

    func testRewardStates() {
        XCUIDevice.shared.orientation = .portrait
        for streak in [5, 10, 15, 19] {
            let app = launch(["-ElisaStreak", "\(streak)"])
            _ = app.buttons["flag-red"].waitForExistence(timeout: 10)
            keep(app, String(format: "state-06-streak-%02d-of-20", streak), settle: 1.5)
        }
        let app = launch(["-ElisaAnswer", "red", "-ElisaStreak", "19"])
        let red = app.buttons["flag-red"]
        _ = red.waitForExistence(timeout: 10)
        app.playAndListen()
        red.tap()
        _ = app.buttons["flag-blue"].waitForExistence(timeout: 8)
        keep(app, "state-07-after-level-up")
    }

    func testMenus() {
        let orientations: [(String, UIDeviceOrientation)] = UIDevice.current.userInterfaceIdiom == .pad
            ? [("portrait", .portrait), ("landscape", .landscapeLeft)]
            : [("portrait", .portrait)]
        for (name, orientation) in orientations {
            self.orientation = orientation
            XCUIDevice.shared.orientation = orientation
            let app = launch(["-ElisaAnswer", "red"])
            _ = app.buttons["menu-gear"].waitForExistence(timeout: 10)
            // One filed session for the history: answer at yellow, then move to blue.
            app.playAndListen()
            app.buttons["flag-red"].tap()
            app.buttons["menu-gear"].tap()
            app.buttons["menu-profile"].tap()
            app.buttons["profile-level"].tap()
            app.buttons["Nivel 2: Azul (Si Re Sol)"].tap()
            app.buttons["menu-home"].tap()
            keep(app, "menu-01-gear-open-\(name)")
            app.buttons["menu-trainer"].tap()
            keep(app, "menu-02-piano-trainer-\(name)")
            app.buttons["menu-info"].tap()
            keep(app, "menu-03-info-\(name)")
            app.buttons["menu-history"].tap()
            keep(app, "menu-04-stats-history-\(name)")
            app.buttons["menu-profile"].tap()
            keep(app, "menu-05-profile-settings-\(name)")
            app.swipeUp()
            keep(app, "menu-06-profile-settings-scrolled-\(name)")
            app.buttons["profile-guided-access"].tap()
            keep(app, "menu-07-guided-access-\(name)")
        }
        XCUIDevice.shared.orientation = .portrait
    }
}
