import Foundation
import Testing
@testable import TerminalKit

@MainActor
struct TerminalDropTests {
    @Test func plainPathsAreUnchanged() {
        #expect(TerminalDrop.escape("/Users/me/Desktop/shot.png") == "/Users/me/Desktop/shot.png")
    }

    @Test func shellSpecialCharactersAreEscaped() {
        #expect(TerminalDrop.escape("/tmp/Screenshot 2026-10-01 at 9.41.00 AM.png")
                == #"/tmp/Screenshot\ 2026-10-01\ at\ 9.41.00\ AM.png"#)
        #expect(TerminalDrop.escape(#"/tmp/it's $(x) & "y".txt"#)
                == #"/tmp/it\'s\ \$\(x\)\ \&\ \"y\".txt"#)
    }

    @Test func multipleFilesAreSeparatedBySpaces() {
        let urls = [URL(filePath: "/tmp/a b.png"), URL(filePath: "/tmp/c.png")]
        #expect(TerminalDrop.text(forFiles: urls) == #"/tmp/a\ b.png /tmp/c.png"#)
    }
}
