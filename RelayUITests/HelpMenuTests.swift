import XCTest

final class HelpMenuTests: XCTestCase {
    @MainActor
    func testRelayHelpOpensTheUsageGuide() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launch()
        defer { app.terminate() }

        let help = app.menuBarItems["Help"]
        help.click()
        help.menuItems["Relay Help"].click()

        let window = app.windows["Relay Help"]
        XCTAssertTrue(window.waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Using Relay"].waitForExistence(timeout: 5))
        XCTAssertTrue(window.staticTexts["Getting around"].exists)

        // ⌘? brings the same window forward rather than opening a second one.
        app.typeKey("/", modifierFlags: [.command, .shift])
        XCTAssertEqual(app.windows.matching(NSPredicate(format: "title == %@", "Relay Help")).count, 1)
    }
}
