import XCTest

final class TerminalCommandsTests: XCTestCase {
    @MainActor
    func testTerminalMenuActionsAndScrollbackSearch() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Commands \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        // ⌘N replaces New Window, so it is what starts the session. The File menu is built
        // from the focused window's session types, so wait for the window before pressing it.
        XCTAssertTrue(app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'New ' AND label ENDSWITH ' Session'")
        ).firstMatch.waitForExistence(timeout: 10), "empty state never appeared")
        app.typeKey("n", modifierFlags: .command)
        let terminal = app.textViews["Terminal"]
        XCTAssertTrue(terminal.waitForExistence(timeout: 15))
        terminal.click()
        terminal.typeText("printf 'needle:%s\\n' \"findme\"\n")
        expectOutput("needle:findme", in: terminal)

        // Every one of these is a libghostty binding action; a name the library rejects is
        // logged as an error, so the diagnostics report would name it.
        for item in ["Jump to Previous Prompt", "Jump to Next Prompt", "Page Up", "Page Down",
                     "Scroll to Top", "Scroll to Bottom"] {
            selectTerminalMenuItem(item, in: app)
        }

        // Search finds the line that is now in the scrollback.
        selectTerminalMenuItem("Search Scrollback…", in: app)
        let field = app.textFields.element(boundBy: 0)
        XCTAssertTrue(field.waitForExistence(timeout: 5), "search field did not appear")
        field.click()
        field.typeText("needle")
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "value CONTAINS 'needle:findme' OR label CONTAINS 'needle:findme'")
        ).firstMatch.waitForExistence(timeout: 5), "search did not find the line")
        app.buttons["Done"].click()

        // Clear Screen empties the viewport while leaving the session running.
        terminal.click()
        selectTerminalMenuItem("Clear Screen", in: app)
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (terminal.value as? String)?.contains("needle:findme") == false
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 10), .completed,
                       "Clear Screen left the old output in the viewport")
        terminal.typeText("printf 'alive:%s\\n' \"yes\"\n")
        expectOutput("alive:yes", in: terminal)
    }

    @MainActor
    private func selectTerminalMenuItem(_ title: String, in app: XCUIApplication) {
        app.menuBarItems["Terminal"].click()
        let item = app.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "missing Terminal menu item: \(title)")
        XCTAssertTrue(item.isEnabled, "disabled Terminal menu item: \(title)")
        item.click()
    }

    @MainActor
    private func expectOutput(_ value: String, in terminal: XCUIElement,
                              file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate { _, _ in (terminal.value as? String)?.contains(value) == true }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed,
                       "Expected terminal output: \(value)", file: file, line: line)
    }
}
