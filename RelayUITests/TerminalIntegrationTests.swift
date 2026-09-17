import XCTest
import AppKit

final class TerminalIntegrationTests: XCTestCase {
    @MainActor
    func testShellInDarkAppearance() throws { try exerciseTerminal(appearance: "Dark") }

    @MainActor
    func testShellInLightAppearance() throws { try exerciseTerminal(appearance: "Light") }

    @MainActor
    private func exerciseTerminal(appearance: String) throws {
        continueAfterFailure = false
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Terminal \(UUID().uuidString) 'quoted'")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = XCUIApplication()
        app.launchEnvironment["RELAY_UI_TESTING"] = "1"
        app.launchEnvironment["RELAY_UI_TEST_WORKSPACE"] = directory.path
        app.launchArguments = ["-AppleInterfaceStyle", appearance]
        app.launch()
        defer { app.terminate() }
        app.buttons["New Shell Session"].click()
        let terminal = app.textViews["Terminal"]
        XCTAssertTrue(terminal.waitForExistence(timeout: 15))
        terminal.click()
        terminal.typeText("printf 'directory:%s\\n' \"$PWD\"\n")
        expectOutput("directory:\(directory.resolvingSymlinksInPath().path)", in: terminal)
        terminal.typeText("RELAY_CHECK=retained\n")
        app.typeKey(.return, modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons["Collapse terminal"].waitForExistence(timeout: 5))
        // Do not click the terminal: focus must return automatically after toggling focus mode.
        app.typeText("printf 'state:%s\\n' \"$RELAY_CHECK\"\n")
        expectOutput("state:retained", in: terminal)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["Collapse terminal"].exists)
        // The escape reached the shell, where it opens a meta sequence: finish it and clear the
        // line, or the next command's first key is read as ESC-p (history-search-backward).
        app.typeKey("c", modifierFlags: .control)
        app.typeKey("c", modifierFlags: .control)

        app.menuButtons["New Session"].click()
        app.menuItems["New Shell Session"].click()
        XCTAssertTrue(terminal.waitForExistence(timeout: 5))
        app.typeText("printf 'second:%s\\n' \"shell\"\n")
        expectOutput("second:shell", in: terminal)
        app.typeKey("1", modifierFlags: .command)
        app.typeText("printf 'switch:%s\\n' \"$RELAY_CHECK\"\n")
        expectOutput("switch:retained", in: terminal)

        // Preserve all pasteboard types while verifying native copy and paste.
        let pasteboard = NSPasteboard.general
        let originalItems = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy
        }
        defer {
            pasteboard.clearContents()
            pasteboard.writeObjects(originalItems)
        }
        app.typeKey("a", modifierFlags: .command)
        app.typeKey("c", modifierFlags: .command)
        let copied = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            pasteboard.string(forType: .string)?.contains("switch:retained") == true
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [copied], timeout: 5), .completed)
        pasteboard.clearContents()
        pasteboard.setString("clipboard-works", forType: .string)
        app.typeText("printf 'paste:%s\\n' ")
        app.typeKey("v", modifierFlags: .command)
        app.typeText("\n")
        expectOutput("paste:clipboard-works", in: terminal)
        app.typeKey(.return, modifierFlags: [.command, .shift])
        XCTAssertTrue(app.buttons["Expand terminal"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Terminal \(appearance)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.typeText("exit\n")
        XCTAssertTrue(app.staticTexts["Shell exited. Create a new Shell session to continue."].waitForExistence(timeout: 10))
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
