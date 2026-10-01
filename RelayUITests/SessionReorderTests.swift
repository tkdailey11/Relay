import XCTest

final class SessionReorderTests: XCTestCase {
    private var app: XCUIApplication!
    private var directory: URL!

    @MainActor
    override func setUpWithError() throws {
        continueAfterFailure = false
        directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Reorder \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launch()
    }

    @MainActor
    override func tearDownWithError() throws {
        app.terminate()
        try? FileManager.default.removeItem(at: directory)
    }

    /// Two shells, the first renamed so the cards can be told apart: "First", then "Shell".
    @MainActor
    private func makeTwoSessions() {
        app.buttons["New Shell Session"].click()
        XCTAssertTrue(app.textViews["Terminal"].waitForExistence(timeout: 15))
        let card = app.buttons["Shell session"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.doubleClick()
        let field = app.sheets.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeKey("a", modifierFlags: .command)
        field.typeText("First")
        app.sheets.buttons["Rename"].click()
        XCTAssertTrue(app.buttons["First session"].waitForExistence(timeout: 5))
        app.typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Shell session"].waitForExistence(timeout: 15))
        XCTAssertLessThan(app.buttons["First session"].frame.minX, app.buttons["Shell session"].frame.minX)
    }

    @MainActor
    func testMoveRightInTheContextMenuReordersCards() throws {
        makeTwoSessions()
        app.buttons["First session"].rightClick()
        app.menuItems["Move Right"].click()

        let first = app.buttons["First session"], shell = app.buttons["Shell session"]
        let moved = NSPredicate { _, _ in first.frame.minX > shell.frame.minX }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)

        // ⌘1 now reaches the session that was second.
        app.menuBarItems["View"].click()
        let firstItem = app.menuItems.matching(NSPredicate(format: "title IN %@", ["Shell", "First"])).firstMatch
        XCTAssertEqual(firstItem.title, "Shell")
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testDraggingACardPastItsNeighbourReordersCards() throws {
        makeTwoSessions()
        let first = app.buttons["First session"], shell = app.buttons["Shell session"]
        let start = first.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        let end = shell.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        start.press(forDuration: 0.2, thenDragTo: end)

        let moved = NSPredicate { _, _ in first.frame.minX > shell.frame.minX }
        wait(for: [XCTNSPredicateExpectation(predicate: moved, object: nil)], timeout: 5)
    }
}
