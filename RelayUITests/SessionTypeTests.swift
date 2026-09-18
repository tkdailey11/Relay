import XCTest

final class SessionTypeTests: XCTestCase {
    @MainActor
    func testAddingACustomTypeMakesItStartable() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Types \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        openSessionTypes(in: app)

        // A custom type pointed at a real command, so it can actually be started.
        app.menuButtons["Add"].click()
        app.menuItems["Custom Session Type…"].click()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5), "editor did not open")
        name.click()
        name.typeText("Echoer")
        let command = app.textFields["Command"]
        command.click()
        command.typeText("/bin/echo relay-custom-type")
        app.buttons["Add"].click()

        XCTAssertTrue(app.descendants(matching: .any)["Echoer session type"].waitForExistence(timeout: 5),
                      "the new type is not in the list")
        app.typeKey("w", modifierFlags: .command)

        // It reaches the launchers. The File menu is used here because the pane's own New
        // Session menu offers an item of the same name.
        app.menuBarItems["File"].click()
        let item = app.menuItems["New Echoer Session"].firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5), "the custom type is not in the File menu")
        item.click()

        let terminal = app.textViews["Terminal"]
        XCTAssertTrue(terminal.waitForExistence(timeout: 15), "the custom type did not start a terminal")
        let ran = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            (terminal.value as? String)?.contains("relay-custom-type") == true
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ran], timeout: 15), .completed,
                       "the custom type's command did not run")
    }

    /// Deleting a type must not disturb a session already started from it.
    @MainActor
    func testRemovingATypeLeavesItsRunningSessionAlone() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Remove Type \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        // Codex is a preset with no CLI installed here, but its session card still appears.
        app.menuBarItems["File"].click()
        app.menuItems["New Codex Session"].click()
        XCTAssertTrue(app.descendants(matching: .any)["Codex session"].waitForExistence(timeout: 10),
                      "the Codex session card never appeared")

        openSessionTypes(in: app)
        app.descendants(matching: .any)["Codex session type"].click()
        app.buttons["Remove"].click()
        XCTAssertFalse(app.descendants(matching: .any)["Codex session type"].exists,
                       "Codex was not removed")

        // Shell is the one type Relay refuses to remove.
        app.descendants(matching: .any)["Shell session type"].click()
        XCTAssertFalse(app.buttons["Remove"].isEnabled, "Shell should not be removable")
        app.typeKey("w", modifierFlags: .command)

        // The session survives its type's removal, keeping the name it was started under.
        XCTAssertTrue(app.descendants(matching: .any)["Codex session"].waitForExistence(timeout: 5),
                      "removing the type took its session with it")
    }

    @MainActor
    private func openSessionTypes(in app: XCUIApplication) {
        app.menuBarItems["Relay"].click()
        let settings = app.menuItems.containing(
            NSPredicate(format: "title BEGINSWITH 'Settings'")).firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.click()
        let window = app.windows["com_apple_SwiftUI_Settings_window"]
        XCTAssertTrue(window.waitForExistence(timeout: 10), "Settings did not open")
        window.toolbars.buttons["Session Types"].click()
    }
}
