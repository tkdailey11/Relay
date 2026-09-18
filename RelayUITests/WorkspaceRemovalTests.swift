import XCTest

final class WorkspaceRemovalTests: XCTestCase {
    @MainActor
    func testRemovingAWorkspaceStopsItsSessionsAndClearsTheSidebar() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Removal \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        // A running shell makes the removal tear down a live terminal, not just metadata.
        app.buttons["New Shell Session"].click()
        let terminal = app.textViews["Terminal"]
        XCTAssertTrue(terminal.waitForExistence(timeout: 15))

        let row = app.outlines.staticTexts[directory.lastPathComponent]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.rightClick()
        app.menuItems["Remove Workspace"].click()

        let confirm = app.sheets.buttons["Remove Workspace"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.click()

        // The only workspace is gone, so Relay falls back to an empty Temporary Sessions.
        XCTAssertTrue(app.buttons["New Shell Session"].waitForExistence(timeout: 10))
        XCTAssertFalse(terminal.exists)
        XCTAssertFalse(row.exists)
        XCTAssertTrue(app.staticTexts["Temporary Sessions"].exists)
    }

    @MainActor
    func testCancellingRemovalKeepsTheWorkspace() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Keep \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        let row = app.outlines.staticTexts[directory.lastPathComponent]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.rightClick()
        app.menuItems["Remove Workspace"].click()
        let cancel = app.sheets.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.click()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
