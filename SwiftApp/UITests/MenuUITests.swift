import XCTest

/// The gear menu and its panels, on a throwaway progress file with red always the answer.
final class MenuUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ElisaFreshState", "YES", "-ElisaAnswer", "red"] + extra
        app.launch()
        XCTAssertTrue(app.buttons["menu-gear"].waitForExistence(timeout: 10))
        return app
    }

    /// Taps a menu item, opening the menu first if needed.
    private func open(_ app: XCUIApplication, _ item: String) {
        if !app.buttons["menu-home"].exists { app.buttons["menu-gear"].tap() }
        app.buttons[item].tap()
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    /// Picks an option of a menu-style picker.
    private func choose(_ app: XCUIApplication, _ picker: String, _ option: String) {
        app.buttons[picker].tap()
        XCTAssertTrue(app.buttons[option].waitForExistence(timeout: 2), "no option \(option)")
        app.buttons[option].tap()
    }

    private func waitGone(_ element: XCUIElement) {
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: element)
        waitForExpectations(timeout: 5)
    }

    func testTheGearOpensTheMenuAndHomeGoesBackToTheGame() {
        let app = launch()
        XCTAssertFalse(app.buttons["menu-home"].exists)
        app.buttons["menu-gear"].tap()
        XCTAssertEqual(app.buttons["menu-home"].value as? String, "active")

        app.buttons["menu-info"].tap()
        XCTAssertTrue(element(app, "info-panel").exists)
        XCTAssertEqual(app.buttons["menu-info"].value as? String, "active")
        XCTAssertFalse(app.buttons["flag-red"].exists)
        XCTAssertFalse(app.buttons["play-button"].exists)

        app.buttons["menu-home"].tap()
        XCTAssertTrue(app.buttons["flag-red"].exists)

        app.buttons["menu-info"].tap()
        app.buttons["menu-gear"].tap()
        XCTAssertFalse(app.buttons["menu-home"].exists)
        XCTAssertTrue(app.buttons["flag-red"].exists, "hiding the menu closes the panel")
    }

    func testTheTrainerHasEveryChordAndCountsNothing() {
        let app = launch(["-ElisaStreak", "3"])
        open(app, "menu-trainer")
        let flags = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'trainer-'"))
        XCTAssertEqual(flags.count, 14)
        app.buttons["trainer-blue"].tap()
        app.buttons["trainer-red"].tap()
        open(app, "menu-home")
        XCTAssertEqual(element(app, "streak-outline").value as? String, "3")
    }

    func testChangingTheLevelShowsItsFlags() {
        let app = launch()
        open(app, "menu-profile")
        choose(app, "profile-level", "Nivel 2: Azul (Si Re Sol)")
        open(app, "menu-home")
        XCTAssertTrue(app.buttons["flag-blue"].exists)
    }

    func testTheHistoryListsASessionOnceItIsFiled() {
        let app = launch()
        open(app, "menu-history")
        XCTAssertTrue(element(app, "history-empty").exists)

        open(app, "menu-home")
        app.playAndListen()
        app.buttons["flag-red"].tap()
        // A level change files the session at yellow.
        open(app, "menu-profile")
        choose(app, "profile-level", "Nivel 2: Azul (Si Re Sol)")
        open(app, "menu-history")
        let row = element(app, "history-row")
        XCTAssertTrue(row.waitForExistence(timeout: 2))
        XCTAssertTrue(row.label.contains("1 / 1 (100%)"), row.label)
    }

    func testAddingAProfilePlaysAsItAndDeletingGoesBackToElisa() {
        let app = launch()
        open(app, "menu-profile")
        XCTAssertFalse(app.buttons["profile-delete"].isEnabled, "the guest can't be deleted")

        app.buttons["profile-add"].tap()
        let name = app.textFields["profile-name"]
        name.tap()
        name.typeText("Papa\n")
        app.buttons["icon-fa-truck"].tap()
        app.buttons["profile-submit-add"].tap()
        XCTAssertTrue(app.buttons["flag-red"].waitForExistence(timeout: 3), "adding closes the panel")
        XCTAssertTrue(app.buttons["menu-profile"].label.contains("Papa"), app.buttons["menu-profile"].label)

        open(app, "menu-profile")
        XCTAssertTrue(app.buttons["switcher-101"].exists)
        XCTAssertTrue(app.buttons["profile-delete"].isEnabled)
        app.buttons["profile-delete"].tap()
        app.alerts.buttons["Borrar"].tap()
        XCTAssertTrue(app.buttons["flag-red"].waitForExistence(timeout: 3), "deleting closes the panel")
        XCTAssertTrue(app.buttons["menu-profile"].label.contains("Elisa"), app.buttons["menu-profile"].label)
    }

    func testANameThatIsTakenIsRefused() {
        let app = launch()
        open(app, "menu-profile")
        app.buttons["profile-add"].tap()
        let name = app.textFields["profile-name"]
        name.tap()
        name.typeText("elisa\n")
        app.buttons["profile-submit-add"].tap()
        XCTAssertTrue(app.alerts.staticTexts["Ya existe un perfil llamado elisa."].waitForExistence(timeout: 2))
        app.alerts.buttons["OK"].tap()
    }

    func testSavingTurnsTheHintOff() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["play-hint"].exists)
        open(app, "menu-profile")
        // On recent iOS the Toggle's tappable part is a switch inside the identified one.
        let toggle = app.switches["profile-hints"]
        let inner = toggle.switches.firstMatch
        (inner.exists ? inner : toggle).tap()
        app.buttons["profile-save"].tap()
        XCTAssertTrue(app.buttons["flag-red"].waitForExistence(timeout: 3), "saving closes the panel")
        XCTAssertFalse(app.staticTexts["play-hint"].exists)
    }

    func testTheGuidedAccessInstructions() {
        let app = launch()
        open(app, "menu-profile")
        app.buttons["profile-guided-access"].tap()
        let info = element(app, "guided-access-info")
        XCTAssertTrue(info.waitForExistence(timeout: 3))
        app.buttons["guided-access-ok"].tap()
        waitGone(info)
    }
}
