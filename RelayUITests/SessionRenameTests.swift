import XCTest

final class SessionRenameTests: XCTestCase {
    @MainActor
    func testDoubleClickingATabRenamesItsSession() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Rename \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        app.buttons["New Shell Session"].click()
        XCTAssertTrue(app.textViews["Terminal"].waitForExistence(timeout: 15))
        app.buttons["Expand terminal"].click()

        // Cards are hidden while the terminal is expanded, so this is the tab.
        let tab = app.buttons["Shell session"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5))
        tab.doubleClick()

        let field = app.sheets.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Shell")
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Build")
        app.sheets.buttons["Rename"].click()

        XCTAssertTrue(app.buttons["Build session"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Shell session"].exists)
    }

    @MainActor
    func testDoubleClickingACardRenamesItsSession() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Rename Card \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        app.buttons["New Shell Session"].click()
        XCTAssertTrue(app.textViews["Terminal"].waitForExistence(timeout: 15))

        // Tabs only exist while the terminal is expanded, so this is the card.
        let card = app.buttons["Shell session"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.doubleClick()

        let field = app.sheets.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeKey("a", modifierFlags: .command)
        field.typeText("Deploy")
        app.sheets.buttons["Rename"].click()

        XCTAssertTrue(app.buttons["Deploy session"].waitForExistence(timeout: 5))
        XCTAssertFalse(card.exists)
    }
}
