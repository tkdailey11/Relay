import XCTest

final class SettingsTests: XCTestCase {
    @MainActor
    func testChangingFontSizeKeepsARunningTerminalAlive() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Settings \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        app.buttons["New Shell Session"].click()
        let terminal = app.textViews["Terminal"]
        XCTAssertTrue(terminal.waitForExistence(timeout: 15))
        terminal.click()
        terminal.typeText("RELAY_BEFORE=alive\n")
        terminal.typeText("printf 'before:%s\\n' \"$RELAY_BEFORE\"\n")
        expectOutput("before:alive", in: terminal)

        // The surface is rebuilt against a new libghostty configuration on each of these.
        for _ in 0..<3 { selectViewMenuItem("Bigger Text", in: app) }
        selectViewMenuItem("Smaller Text", in: app)
        selectViewMenuItem("Actual Size", in: app)

        // The process behind the surface must have survived every config swap, with its shell
        // state intact.
        terminal.click()
        terminal.typeText("printf 'after:%s\\n' \"$RELAY_BEFORE\"\n")
        expectOutput("after:alive", in: terminal)
    }

    @MainActor
    func testSettingsWindowOpensWithBothTabs() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launch()
        defer { app.terminate() }

        // The menu bar rather than ⌘, : the keystroke depends on the app already being
        // frontmost, which is not guaranteed right after launch.
        app.menuBarItems["Relay"].click()
        let settingsItem = app.menuItems.containing(
            NSPredicate(format: "title BEGINSWITH 'Settings'")).firstMatch
        XCTAssertTrue(settingsItem.waitForExistence(timeout: 5), "no Settings item in the app menu")
        settingsItem.click()

        let window = app.windows["com_apple_SwiftUI_Settings_window"]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Settings did not open")

        // SwiftUI restores the last selected tab, so neither tab can be assumed.
        window.toolbars.buttons["Terminal"].click()
        XCTAssertTrue(app.buttons["Restore Defaults"].waitForExistence(timeout: 5),
                      "missing the Terminal tab's controls")

        // The Sessions tab is where a tester fixes a CLI Relay could not find.
        window.toolbars.buttons["Sessions"].click()
        XCTAssertTrue(app.textFields["Claude command"].waitForExistence(timeout: 5),
                      "missing the Claude command field")
        XCTAssertTrue(app.textFields["Shell command"].exists)
    }

    @MainActor
    private func selectViewMenuItem(_ title: String, in app: XCUIApplication) {
        app.menuBarItems["View"].click()
        let item = app.menuItems[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "missing View menu item: \(title)")
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
