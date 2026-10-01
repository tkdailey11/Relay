import XCTest

final class QuickSwitcherTests: XCTestCase {
    @MainActor
    func testQuickSwitcherAndWorkspaceStepping() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Switcher \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        // A shell in the workspace, then one in Temporary Sessions.
        let newShell = app.buttons["New Shell Session"]
        XCTAssertTrue(newShell.waitForExistence(timeout: 10))
        newShell.click()
        XCTAssertTrue(app.textViews["Terminal"].waitForExistence(timeout: 15))
        app.outlines.staticTexts["Temporary Sessions"].click()
        let temporaryFooter = app.staticTexts["Temporary · Cleared when Relay quits"]
        let workspaceFooter = app.staticTexts["Shell sessions run locally · Processes end when Relay quits"]
        XCTAssertTrue(temporaryFooter.waitForExistence(timeout: 10))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.textViews["Terminal"].waitForExistence(timeout: 15))

        // Esc closes the switcher without moving anywhere.
        app.typeKey("p", modifierFlags: .command)
        let field = app.textFields["Jump to a workspace or session"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "switcher did not open")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(field.waitForNonExistence(timeout: 5), "Esc did not close the switcher")
        XCTAssertTrue(temporaryFooter.exists)

        // Typing the workspace name and Return jumps to its session.
        app.typeKey("p", modifierFlags: .command)
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("switcher shell\r")
        XCTAssertTrue(workspaceFooter.waitForExistence(timeout: 10), "Return did not jump to the workspace")

        // The workspace's terminal has the keyboard, so typing goes straight to the shell.
        let terminal = app.textViews["Terminal"]
        terminal.typeText("printf 'landed:%s\\n' \"yes\"\n")
        let landed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (terminal.value as? String)?.contains("landed:yes") == true
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [landed], timeout: 15), .completed)

        // Next Workspace steps down the sidebar to Temporary Sessions, and back.
        app.typeKey(.downArrow, modifierFlags: [.command, .control])
        XCTAssertTrue(temporaryFooter.waitForExistence(timeout: 5))
        app.typeKey(.upArrow, modifierFlags: [.command, .control])
        XCTAssertTrue(workspaceFooter.waitForExistence(timeout: 5))
    }
}
