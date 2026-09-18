import Foundation
import TerminalKit

/// The text behind Help ▸ Diagnostics. It answers the questions a bug report usually leaves
/// open — which build, which macOS, whether the CLIs resolved, what each session's terminal
/// actually did — so a tester can paste one block instead of being interviewed.
@MainActor
enum DiagnosticsReport {
    static func make(store: WorkspaceStore, log: DiagnosticLog = .shared,
                     date: Date = Date()) -> String {
        var lines: [String] = []
        lines.append("# Relay Diagnostics")
        lines.append("Generated \(ISO8601DateFormatter().string(from: date))")
        lines.append("")
        lines.append(contentsOf: environment())
        lines.append("")
        lines.append(contentsOf: state(of: store))
        lines.append("")
        lines.append(contentsOf: events(log))
        return lines.joined(separator: "\n")
    }

    private static func environment() -> [String] {
        let bundle = Bundle.main.infoDictionary ?? [:]
        let version = bundle["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = bundle["CFBundleVersion"] as? String ?? "unknown"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        // The architecture Relay is actually executing as: a release running under Rosetta
        // would explain a whole class of terminal failures.
        var info = utsname()
        uname(&info)
        let machine = withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return [
            "## Environment",
            "- Relay: \(version) (\(build))",
            "- macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "- Architecture: \(machine)",
            "- Shell: \(ProcessInfo.processInfo.environment["SHELL"] ?? "unset")",
            "- Locale: \(Locale.current.identifier)"
        ]
    }

    private static func state(of store: WorkspaceStore) -> [String] {
        var lines = ["## State"]
        lines.append("- Storage: \(WorkspaceStore.defaultFileURL.path)")
        lines.append("- Destination: \(store.destination.map(describe) ?? "none")")
        if let message = store.errorMessage {
            lines.append("- Last error: \(message)")
        }
        lines.append("- Workspaces: \(store.state.workspaces.count)")
        for workspace in store.state.workspaces {
            lines.append("  - \(workspace.name) — \(workspace.path)")
            lines.append(contentsOf: sessions(workspace.sessions, in: store, indent: "    "))
        }
        lines.append("- Temporary sessions: \(store.temporarySessions.count)")
        lines.append(contentsOf: sessions(store.temporarySessions, in: store, indent: "  "))
        return lines
    }

    private static func sessions(_ sessions: [Session], in store: WorkspaceStore,
                                 indent: String) -> [String] {
        sessions.map { session in
            var line = "\(indent)- \(session.kind.rawValue): \(store.terminals.status(for: session))"
            if let terminal = store.terminals.sessions[session.id] {
                line += ", command \(terminal.command ?? "login shell")"
            }
            if let error = store.terminals.errors[session.id] {
                // Newlines would break the one-session-per-line shape.
                line += ", error: \(error.replacingOccurrences(of: "\n", with: " "))"
            }
            return line
        }
    }

    private static func describe(_ destination: SessionDestination) -> String {
        switch destination {
        case .temporary: "Temporary Sessions"
        case .workspace: "Workspace"
        }
    }

    private static func events(_ log: DiagnosticLog) -> [String] {
        let entries = log.entries
        guard !entries.isEmpty else { return ["## Events", "(none recorded)"] }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return ["## Events (\(entries.count))"] + entries.map { entry in
            "\(formatter.string(from: entry.date)) \(entry.level.rawValue) [\(entry.category.rawValue)] \(entry.message)"
        }
    }
}
