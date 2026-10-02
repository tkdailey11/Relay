import Foundation
import Testing
@testable import Relay

@MainActor
struct UsageGuideTests {
    private func plain(_ text: AttributedString) -> String { String(text.characters) }

    @Test func splitsMarkdownIntoTheBlocksHelpDraws() throws {
        let blocks = try UsageGuide.blocks(from: """
            # Title

            Intro with `code` and **bold**.

            - First
            - Second
              - Nested

            1. Check it.
            2. Fix it.

            | Action | Shortcut |
            | --- | --- |
            | Quick Switch | ⌘P |
            | Clear | ⌘K |

            ```
            Workspace  →  Session
            ```

            ## After
            """)

        guard blocks.count == 10 else {
            Issue.record("Expected 10 blocks, got \(blocks.count): \(blocks)")
            return
        }
        #expect(blocks[0] == .heading(level: 1, text: "Title"))
        guard case .paragraph(let intro) = blocks[1] else { Issue.record("intro"); return }
        #expect(plain(intro) == "Intro with code and bold.")
        // Inline styling survives so Text can draw it.
        #expect(intro.runs.contains { $0.inlinePresentationIntent == .code })

        // Compared as plain text: Foundation also tags list text with its delimiter.
        let items = blocks[2...6].map { block -> String in
            guard case .listItem(let marker, let depth, let text) = block else { return "not a list item" }
            return "\(depth) \(marker ?? "-") \(plain(text))"
        }
        #expect(items == ["1 • First", "1 • Second", "2 • Nested", "1 1. Check it.", "1 2. Fix it."])

        guard case .table(let header, let rows) = blocks[7] else { Issue.record("table"); return }
        #expect(header.map(plain) == ["Action", "Shortcut"])
        #expect(rows.map { $0.map(plain) } == [["Quick Switch", "⌘P"], ["Clear", "⌘K"]])

        #expect(blocks[8] == .code("Workspace  →  Session"))
        #expect(blocks[9] == .heading(level: 2, text: "After"))
    }

    /// A build that drops USAGE.md from its resources, or a guide the parser can't read, would
    /// otherwise only show up when a tester opens Help.
    @Test func theBundledGuideLoadsWithItsTables() throws {
        let blocks = try UsageGuide.load()
        #expect(blocks.first == .heading(level: 1, text: "Using Relay"))
        let tables = blocks.compactMap { block -> [AttributedString]? in
            if case .table(let header, let rows) = block, !rows.isEmpty { header } else { nil }
        }
        #expect(!tables.isEmpty)
        #expect(tables.allSatisfy { $0.map(plain) == ["Action", "Shortcut"] })
    }

    /// The notices are legal text that licenses require to ship, so a build that drops the file,
    /// or a parse that mangles a license into prose, has to fail here and not in a tester's hands.
    @Test func theBundledLicenseNoticesLoadWithTheirTextIntact() throws {
        let blocks = try UsageGuide.load(resource: "THIRD-PARTY-NOTICES")
        #expect(blocks.first == .heading(level: 1, text: "Third-Party Notices"))
        let licenses = blocks.compactMap { block -> String? in
            if case .code(let text) = block { text } else { nil }
        }
        #expect(licenses.count >= 20)
        #expect(licenses.contains { $0.hasPrefix("MIT License") && $0.contains("Mitchell Hashimoto") })
        #expect(licenses.contains { $0.contains("SIL OPEN FONT LICENSE") || $0.contains("SIL Open Font License") })
    }
}
