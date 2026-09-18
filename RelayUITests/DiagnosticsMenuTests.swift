import XCTest

final class DiagnosticsMenuTests: XCTestCase {
    @MainActor
    func testHelpMenuProducesAReportNamingTheWorkspaceAndSession() throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Diagnostics \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
        defer { app.terminate() }

        // A started session gives the report something to say beyond the environment.
        app.buttons["New Shell Session"].click()
        XCTAssertTrue(app.textViews["Terminal"].waitForExistence(timeout: 15))

        app.menuBarItems["Help"].click()
        app.menuItems["Diagnostics…"].click()

        let copy = app.buttons["Copy"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))

        // The report is rendered as one selectable block, so assert against its text.
        let report = app.staticTexts.containing(
            NSPredicate(format: "value CONTAINS %@ OR label CONTAINS %@",
                        "# Relay Diagnostics", "# Relay Diagnostics")).firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        let text = (report.value as? String) ?? report.label
        XCTAssertTrue(text.contains("## Environment"), "missing environment section")
        XCTAssertTrue(text.contains(directory.lastPathComponent), "missing the workspace")
        XCTAssertTrue(text.contains("Shell"), "missing the session")
        XCTAssertTrue(text.contains("## Events"), "missing the event log")

        app.buttons["Done"].click()
        XCTAssertFalse(copy.exists)
    }
}
