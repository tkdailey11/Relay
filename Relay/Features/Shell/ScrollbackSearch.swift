import Foundation

/// libghostty 1.2.3 has no search of its own, and no API to select or scroll to a match, so
/// Relay cannot highlight a hit in the terminal. It reads the scrollback out instead and lists
/// the matching lines, which still answers the question this is usually asked for: what did
/// that error say, and what ran just before it.
struct ScrollbackSearch {
    struct Match: Identifiable, Equatable {
        let id: Int
        /// 1-based, counted from the top of the scrollback.
        let lineNumber: Int
        let text: String
    }

    static let matchLimit = 500

    static func matches(for query: String, in scrollback: String) -> [Match] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        var results: [Match] = []
        // Trailing blank lines are an artifact of reading the whole screen, not content.
        for (offset, line) in scrollback.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            guard line.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil else { continue }
            results.append(Match(id: results.count, lineNumber: offset + 1,
                                 text: String(line).trimmingCharacters(in: .whitespaces)))
            if results.count == matchLimit { break }
        }
        return results
    }
}
