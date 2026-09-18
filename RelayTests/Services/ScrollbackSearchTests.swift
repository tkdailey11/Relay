import Foundation
import Testing
@testable import Relay

struct ScrollbackSearchTests {
    private let scrollback = """
        relay $ swift build
        error: cannot find 'foo' in scope
        relay $ swift test
        Executed 3 tests, with 0 failures
        relay $ echo DONE
        DONE
        """

    @Test func matchesCarryTheirLineNumberAndAreTrimmed() {
        let matches = ScrollbackSearch.matches(for: "error", in: scrollback)
        #expect(matches.count == 1)
        #expect(matches[0].lineNumber == 2)
        #expect(matches[0].text == "error: cannot find 'foo' in scope")
    }

    @Test func searchIgnoresCase() {
        #expect(ScrollbackSearch.matches(for: "ERROR", in: scrollback).count == 1)
        #expect(ScrollbackSearch.matches(for: "done", in: scrollback).count == 2)
    }

    @Test func anEmptyQueryMatchesNothingRatherThanEverything() {
        #expect(ScrollbackSearch.matches(for: "", in: scrollback).isEmpty)
        #expect(ScrollbackSearch.matches(for: "   ", in: scrollback).isEmpty)
        #expect(ScrollbackSearch.matches(for: "swift", in: "").isEmpty)
    }

    /// Line numbers must count blank lines, or they would not point at the real scrollback line.
    @Test func blankLinesStillAdvanceTheLineNumber() {
        let matches = ScrollbackSearch.matches(for: "target", in: "one\n\n\ntarget")
        #expect(matches.map(\.lineNumber) == [4])
    }

    @Test func aFloodOfMatchesIsCapped() {
        let flood = Array(repeating: "match", count: ScrollbackSearch.matchLimit + 250).joined(separator: "\n")
        #expect(ScrollbackSearch.matches(for: "match", in: flood).count == ScrollbackSearch.matchLimit)
    }
}
