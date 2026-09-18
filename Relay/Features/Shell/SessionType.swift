import SwiftUI

/// A kind of session a user can start. Relay ships presets for the agent CLIs people actually
/// run, but the list is data rather than an enum so a tool Relay has never heard of can be added
/// without waiting for a release.
struct SessionType: Identifiable, Codable, Equatable, Hashable {
    /// Stable across renames, and what a `Session` stores. Presets use readable slugs so an
    /// older workspaces.json, which stored the display name, can be migrated onto them.
    let id: String
    var name: String
    /// An empty command launches the user's login shell.
    var command: String
    var symbol: String
    var color: SessionColor
    var isEnabled: Bool

    /// The login shell is what makes Relay a terminal, and the empty state and ⌘N both start
    /// one, so it is the single type Settings will not let a user delete.
    var isRemovable: Bool { id != Self.shellID }

    static let shellID = "shell"

    init(id: String = UUID().uuidString, name: String, command: String,
         symbol: String, color: SessionColor, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.command = command
        self.symbol = symbol
        self.color = color
        self.isEnabled = isEnabled
    }

    /// nil means "launch the login shell", which is what TerminalKit expects.
    var resolvedCommand: String? {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static let presets: [SessionType] = [
        SessionType(id: "claude", name: "Claude", command: "claude",
                    symbol: "sparkle", color: .orange),
        SessionType(id: "copilot", name: "Copilot", command: "copilot",
                    symbol: "chevron.left.forwardslash.chevron.right", color: .violet),
        SessionType(id: "codex", name: "Codex", command: "codex",
                    symbol: "square.stack.3d.up", color: .teal),
        SessionType(id: shellID, name: "Shell", command: "",
                    symbol: "terminal", color: .accent)
    ]

    /// Offered by Settings when adding a type, so the common CLIs are one click rather than
    /// something to look up. Presets already in the list are filtered out at the call site.
    static let catalog: [SessionType] = presets + [
        // Relay 0.1 tried `copilot` then `gh copilot` automatically. With commands now editable
        // per type, the alternative is a catalog entry instead of a hidden fallback.
        SessionType(id: "copilot-gh", name: "Copilot (gh)", command: "gh copilot",
                    symbol: "chevron.left.forwardslash.chevron.right", color: .violet),
        SessionType(id: "gemini", name: "Gemini", command: "gemini",
                    symbol: "diamond", color: .blue),
        SessionType(id: "aider", name: "Aider", command: "aider",
                    symbol: "wand.and.stars", color: .pink),
        SessionType(id: "cursor-agent", name: "Cursor", command: "cursor-agent",
                    symbol: "cursorarrow.rays", color: .yellow),
        SessionType(id: "opencode", name: "opencode", command: "opencode",
                    symbol: "curlybraces", color: .green)
    ]

    /// Icons offered when editing a type. A full symbol browser would be a project of its own,
    /// and these read clearly at the sizes session cards and focus tabs use.
    static let symbols = [
        "sparkle", "chevron.left.forwardslash.chevron.right", "square.stack.3d.up", "terminal",
        "diamond", "wand.and.stars", "cursorarrow.rays", "curlybraces",
        "bolt", "brain", "cube", "hammer", "gearshape", "leaf", "flame", "star",
        "circle.hexagongrid", "point.3.connected.trianglepath.dotted", "server.rack", "ant",
        "paintbrush", "book", "shippingbox", "network"
    ]
}

/// Colors are stored by name so a type survives a round trip through JSON, and so the palette
/// stays small enough that every session type is still distinguishable at a glance.
enum SessionColor: String, Codable, CaseIterable, Hashable {
    case accent, violet, orange, blue, green, teal, pink, yellow, gray

    var color: Color {
        switch self {
        case .accent: .accentColor
        case .violet: Color(.relayViolet)
        case .orange: .orange
        case .blue: .blue
        case .green: .green
        case .teal: .teal
        case .pink: .pink
        case .yellow: .yellow
        case .gray: .gray
        }
    }

    var name: String {
        switch self {
        case .accent: "Relay"
        default: rawValue.capitalized
        }
    }
}

/// What the UI draws for a session. A session outlives the type it was started from — deleting
/// a type in Settings must not close a running terminal — so this resolves to the live type when
/// it still exists and to the session's own stored name when it does not.
struct ResolvedSessionType {
    let name: String
    let symbol: String
    let color: Color
    let isMissing: Bool

    static func missing(named name: String) -> ResolvedSessionType {
        ResolvedSessionType(name: name, symbol: "questionmark.app.dashed", color: .gray, isMissing: true)
    }

    init(_ type: SessionType) {
        name = type.name
        symbol = type.symbol
        color = type.color.color
        isMissing = false
    }

    private init(name: String, symbol: String, color: Color, isMissing: Bool) {
        self.name = name
        self.symbol = symbol
        self.color = color
        self.isMissing = isMissing
    }
}
