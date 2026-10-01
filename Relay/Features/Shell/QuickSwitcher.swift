import SwiftUI

/// One place the quick switcher can jump to: a destination, or a session inside one.
struct QuickSwitcherItem: Identifiable, Equatable {
    let id: String
    let destination: SessionDestination
    /// Nil for a destination row, which keeps that destination's own selected session.
    let sessionID: UUID?
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    /// The ⌘1–⌘9 key that also reaches this session once its destination is showing.
    let shortcutNumber: Int?
    /// Matched against the query; a session carries its destination's name so "relay claude"
    /// finds the Claude session in the Relay workspace.
    let searchText: String
}

/// Builds and filters the switcher's rows. Kept free of views so ranking can be tested.
enum QuickSwitcher {
    /// Sidebar order: each workspace followed by its sessions in card order, then Temporary
    /// Sessions and its sessions, so an empty query reads like the app's own layout.
    static func items(workspaces: [Workspace], temporarySessions: [Session],
                      resolve: (Session) -> ResolvedSessionType) -> [QuickSwitcherItem] {
        var items: [QuickSwitcherItem] = []
        for workspace in workspaces {
            let destination = SessionDestination.workspace(workspace.id)
            items.append(QuickSwitcherItem(
                id: workspace.id.uuidString, destination: destination, sessionID: nil,
                title: workspace.name, subtitle: workspace.path, symbol: "folder",
                color: .secondary, shortcutNumber: nil,
                searchText: "\(workspace.name) \(workspace.path)"))
            items += sessionItems(workspace.sessions, in: destination, named: workspace.name,
                                  resolve: resolve)
        }
        let temporaryName = "Temporary Sessions"
        items.append(QuickSwitcherItem(
            id: "temporary", destination: .temporary, sessionID: nil,
            title: temporaryName, subtitle: "Cleared when Relay quits", symbol: "terminal",
            color: .secondary, shortcutNumber: nil, searchText: temporaryName))
        items += sessionItems(temporarySessions, in: .temporary, named: temporaryName,
                              resolve: resolve)
        return items
    }

    private static func sessionItems(_ sessions: [Session], in destination: SessionDestination,
                                     named name: String,
                                     resolve: (Session) -> ResolvedSessionType) -> [QuickSwitcherItem] {
        sessions.enumerated().map { index, session in
            let type = resolve(session)
            let title = session.title(type)
            return QuickSwitcherItem(
                id: session.id.uuidString, destination: destination, sessionID: session.id,
                title: title, subtitle: name, symbol: type.symbol, color: type.color,
                shortcutNumber: index < 9 ? index + 1 : nil,
                // The type stays searchable after a rename, so "claude" still finds every one.
                searchText: "\(title) \(type.name) \(name)")
        }
    }

    /// Every whitespace-separated term must match, as a word prefix, a substring, or failing
    /// those a subsequence ("tmp" finds Temporary). Better matches rise; ties keep sidebar order.
    static func filter(_ items: [QuickSwitcherItem], query: String) -> [QuickSwitcherItem] {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return items }
        let scored = items.enumerated().compactMap { offset, item -> (Int, Int, QuickSwitcherItem)? in
            let haystack = item.searchText.lowercased()
            var total = 0
            for term in terms {
                guard let score = score(term, in: haystack) else { return nil }
                total += score
            }
            return (total, offset, item)
        }
        return scored.sorted { ($0.0, -$0.1) > ($1.0, -$1.1) }.map(\.2)
    }

    private static func score(_ term: String, in haystack: String) -> Int? {
        let words = haystack.split { $0.isWhitespace || $0 == "/" || $0 == "-" || $0 == "_" }
        if words.contains(where: { $0.hasPrefix(term) }) { return 3 }
        if haystack.contains(term) { return 2 }
        var remaining = term[...]
        for character in haystack where character == remaining.first {
            remaining = remaining.dropFirst()
            if remaining.isEmpty { return 1 }
        }
        return nil
    }
}
