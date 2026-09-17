import Foundation
import Observation
import TerminalKit

/// In-memory process ownership; workspace snapshots continue to contain metadata only.
@MainActor
@Observable
final class TerminalSessionManager {
    private(set) var sessions: [Session.ID: TerminalSession] = [:]
    private(set) var errors: [Session.ID: String] = [:]
    let allowsLaunching: Bool

    init(allowsLaunching: Bool = true) {
        self.allowsLaunching = allowsLaunching
    }

    func prepare(_ session: Session, directory: String) {
        guard allowsLaunching, session.kind == .shell,
              sessions[session.id] == nil, errors[session.id] == nil else { return }
        do {
            sessions[session.id] = try TerminalSession(workingDirectory: URL(filePath: directory))
        } catch {
            errors[session.id] = error.localizedDescription
        }
    }

    func status(for session: Session) -> String {
        if session.kind != .shell || !allowsLaunching { return "Preview" }
        if errors[session.id] != nil { return "Failed" }
        return sessions[session.id]?.status.label ?? "Not started"
    }

    func close(_ id: Session.ID) {
        sessions.removeValue(forKey: id)?.close()
        errors.removeValue(forKey: id)
    }

    func retainSessions(_ ids: Set<Session.ID>) {
        for id in Set(sessions.keys).union(errors.keys).subtracting(ids) { close(id) }
    }

    func closeAll() {
        for session in sessions.values { session.close() }
        sessions.removeAll()
        errors.removeAll()
    }
}
