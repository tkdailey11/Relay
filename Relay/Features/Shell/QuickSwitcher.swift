import SwiftUI

/// Something the palette can do other than jump somewhere. The ones that act on a session run
/// in the workspace shell, which owns the rename prompt and the close confirmation.
enum PaletteCommand: Hashable {
    case newSession(typeID: String)
    case renameSession
    case changeIcon
    case duplicateSession
    case closeSession
    case reopenClosedSession
    case addWorkspace
    case toggleTerminalFocus
    case openSettings
}

/// One row in the palette: a place to jump to, a session inside it, or a command to run.
struct QuickSwitcherItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case destination(SessionDestination)
        case session(SessionDestination, UUID)
        case command(PaletteCommand)
    }

    let id: String
    let kind: Kind
    let title: String
    let subtitle: String
    let symbol: String
    let color: Color
    /// The key that does the same thing without the palette, such as ⌘2 for a session once its
    /// destination is showing, or ⇧⌘D for Duplicate.
    let shortcut: String?
    /// True for a session whose program is waiting on the user.
    var needsAttention = false
    /// Matched against the query; a session carries its destination's name so "relay claude"
    /// finds the Claude session in the Relay workspace.
    let searchText: String

    var destination: SessionDestination? {
        switch kind {
        case .destination(let destination), .session(let destination, _): destination
        case .command: nil
        }
    }

    var sessionID: UUID? {
        if case .session(_, let id) = kind { id } else { nil }
    }

    var command: PaletteCommand? {
        if case .command(let command) = kind { command } else { nil }
    }
}

/// What the commands depend on: the destination on screen, its selected session, and what
/// could be reopened. Commands that have nothing to act on are left out rather than disabled.
struct PaletteContext {
    var sessionTypes: [SessionType]
    var defaultTypeID: String
    var destinationName: String
    var selectedSessionTitle: String?
    var closedSessionTitle: String?
    /// Nil when no workspace shell is showing; otherwise whether the terminal is expanded.
    var isTerminalFocused: Bool?
}

/// A titled group of rows. Only an empty query is grouped; a search is one ranked list.
struct QuickSwitcherSection: Identifiable, Equatable {
    let title: String?
    let items: [QuickSwitcherItem]
    /// Sessions sit under their destination only where the list reads like the sidebar.
    let indentsSessions: Bool

    var id: String { title ?? "results" }
}

/// Builds and filters the palette's rows. Kept free of views so ranking can be tested.
enum QuickSwitcher {
    /// Sidebar order: each workspace followed by its sessions in card order, then Temporary
    /// Sessions and its sessions, so an empty query reads like the app's own layout.
    static func items(workspaces: [Workspace], temporarySessions: [Session],
                      resolve: (Session) -> ResolvedSessionType,
                      state: (Session) -> SessionState = { _ in .running }) -> [QuickSwitcherItem] {
        var items: [QuickSwitcherItem] = []
        for workspace in workspaces {
            let destination = SessionDestination.workspace(workspace.id)
            var item = QuickSwitcherItem(
                id: workspace.id.uuidString, kind: .destination(destination),
                title: workspace.name, subtitle: workspace.path, symbol: "folder",
                color: .secondary, shortcut: nil,
                searchText: "\(workspace.name) \(workspace.path)")
            item.needsAttention = workspace.sessions.contains { state($0) == .needsAttention }
            items.append(item)
            items += sessionItems(workspace.sessions, in: destination, named: workspace.name,
                                  resolve: resolve, state: state)
        }
        let temporaryName = "Temporary Sessions"
        var temporary = QuickSwitcherItem(
            id: "temporary", kind: .destination(.temporary),
            title: temporaryName, subtitle: "Cleared when Relay quits", symbol: "terminal",
            color: .secondary, shortcut: nil, searchText: temporaryName)
        temporary.needsAttention = temporarySessions.contains { state($0) == .needsAttention }
        items.append(temporary)
        items += sessionItems(temporarySessions, in: .temporary, named: temporaryName,
                              resolve: resolve, state: state)
        return items
    }

    private static func sessionItems(_ sessions: [Session], in destination: SessionDestination,
                                     named name: String,
                                     resolve: (Session) -> ResolvedSessionType,
                                     state: (Session) -> SessionState) -> [QuickSwitcherItem] {
        sessions.enumerated().map { index, session in
            let type = resolve(session)
            let title = session.title(type)
            let needsAttention = state(session) == .needsAttention
            var item = QuickSwitcherItem(
                id: session.id.uuidString, kind: .session(destination, session.id),
                title: title, subtitle: name, symbol: type.symbol, color: type.color,
                shortcut: index < 9 ? "⌘\(index + 1)" : nil,
                // The type stays searchable after a rename, so "claude" still finds every one.
                // A waiting session answers to what a person would call it.
                searchText: "\(title) \(type.name) \(name)" + (needsAttention ? " needs attention waiting" : ""))
            item.needsAttention = needsAttention
            return item
        }
    }

    /// Commands follow navigation in the list, and rank below it on a tie, so typing a name
    /// still lands on the session and typing a verb lands on the action.
    static func commands(_ context: PaletteContext) -> [QuickSwitcherItem] {
        func command(_ command: PaletteCommand, _ title: String, subtitle: String = "Command",
                     symbol: String, color: Color = .secondary, shortcut: String? = nil,
                     keywords: String = "") -> QuickSwitcherItem {
            QuickSwitcherItem(id: "command:\(command)", kind: .command(command), title: title,
                              subtitle: subtitle, symbol: symbol, color: color, shortcut: shortcut,
                              // Not the subtitle: it names the session or destination the command
                              // acts on, and "claude" should find the session, not every action.
                              searchText: "\(title) \(keywords)")
        }
        var commands = context.sessionTypes.map { type in
            command(.newSession(typeID: type.id), "New \(type.name) Session",
                    subtitle: "In \(context.destinationName)", symbol: type.symbol,
                    color: type.color.color,
                    shortcut: type.id == context.defaultTypeID ? "⌘N" : nil,
                    keywords: "create start launch open")
        }
        if let session = context.selectedSessionTitle {
            commands += [
                command(.renameSession, "Rename Session…", subtitle: session, symbol: "pencil",
                        keywords: "name title"),
                command(.changeIcon, "Change Icon…", subtitle: session, symbol: "face.smiling",
                        keywords: "symbol"),
                command(.duplicateSession, "Duplicate Session", subtitle: session,
                        symbol: "plus.square.on.square", shortcut: "⇧⌘D", keywords: "copy clone"),
                command(.closeSession, "Close Session", subtitle: session, symbol: "xmark",
                        keywords: "end quit kill stop remove")
            ]
        }
        if let closed = context.closedSessionTitle {
            commands.append(command(.reopenClosedSession, "Reopen Closed Session", subtitle: closed,
                                    symbol: "arrow.uturn.backward", shortcut: "⇧⌘T",
                                    keywords: "undo restore recent"))
        }
        commands.append(command(.addWorkspace, "Add Workspace…", symbol: "folder.badge.plus",
                                shortcut: "⇧⌘O", keywords: "folder project directory"))
        if let isFocused = context.isTerminalFocused {
            commands.append(command(.toggleTerminalFocus,
                                    isFocused ? "Exit Terminal Focus" : "Focus Terminal",
                                    symbol: "arrow.up.left.and.arrow.down.right", shortcut: "⇧⌘↩",
                                    keywords: "expand fullscreen collapse"))
        }
        commands.append(command(.openSettings, "Open Settings…", symbol: "gearshape",
                                shortcut: "⌘,", keywords: "preferences fonts colors session types"))
        return commands
    }

    /// An empty query is grouped so the palette answers "what needs me, and where was I" before
    /// it lists everything. Anything typed becomes one ranked list.
    static func sections(_ items: [QuickSwitcherItem], query: String,
                         recents: [String] = []) -> [QuickSwitcherSection] {
        guard query.allSatisfy(\.isWhitespace) else {
            let results = filter(items, query: query, recents: recents)
            return results.isEmpty ? [] : [QuickSwitcherSection(title: nil, items: results,
                                                                  indentsSessions: true)]
        }
        let navigation = items.filter { $0.command == nil }
        let waiting = navigation.filter { $0.sessionID != nil && $0.needsAttention }
        let waitingIDs = Set(waiting.map(\.id))
        let recent = recents.compactMap { id in navigation.first { $0.id == id && !waitingIDs.contains(id) } }
            .prefix(5)
        let shownIDs = waitingIDs.union(recent.map(\.id))
        let rest = navigation.filter { !shownIDs.contains($0.id) }
        let sections = [
            QuickSwitcherSection(title: "Needs Attention", items: waiting, indentsSessions: false),
            QuickSwitcherSection(title: "Recent", items: Array(recent), indentsSessions: false),
            QuickSwitcherSection(title: "Workspaces & Sessions", items: rest, indentsSessions: true),
            QuickSwitcherSection(title: "Commands", items: items.filter { $0.command != nil },
                                 indentsSessions: false)
        ]
        return sections.filter { !$0.items.isEmpty }
    }

    /// Every whitespace-separated term must match, as a word prefix, a substring, or failing
    /// those a subsequence ("tmp" finds Temporary); commands skip the subsequence, which would
    /// make a short query match half of them. Better matches rise; ties go to what was used
    /// most recently, then keep list order.
    static func filter(_ items: [QuickSwitcherItem], query: String,
                       recents: [String] = []) -> [QuickSwitcherItem] {
        let terms = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return items }
        let scored = items.enumerated().compactMap { offset, item -> (Int, Int, Int, QuickSwitcherItem)? in
            let haystack = item.searchText.lowercased()
            var total = 0
            for term in terms {
                guard let score = score(term, in: haystack,
                                        allowsSubsequence: item.command == nil) else { return nil }
                total += score
            }
            let recency = recents.firstIndex(of: item.id) ?? recents.count
            return (total, recency, offset, item)
        }
        return scored.sorted { lhs, rhs in
            (lhs.0, -lhs.1, -lhs.2) > (rhs.0, -rhs.1, -rhs.2)
        }.map(\.3)
    }

    private static func score(_ term: String, in haystack: String,
                              allowsSubsequence: Bool = true) -> Int? {
        let words = haystack.split { $0.isWhitespace || $0 == "/" || $0 == "-" || $0 == "_" }
        if words.contains(where: { $0.hasPrefix(term) }) { return 3 }
        if haystack.contains(term) { return 2 }
        guard allowsSubsequence else { return nil }
        var remaining = term[...]
        for character in haystack where character == remaining.first {
            remaining = remaining.dropFirst()
            if remaining.isEmpty { return 1 }
        }
        return nil
    }
}
