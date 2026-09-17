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
    /// Membership also means "still wanted": close() removes an id so a session closed while its
    /// executable was being resolved never gets a process afterwards.
    private var preparing: Set<Session.ID> = []
    private let resolveCommand: @Sendable (SessionKind) async throws -> String?

    init(allowsLaunching: Bool = true,
         resolveCommand: @escaping @Sendable (SessionKind) async throws -> String? = {
             try await SessionLauncher.command(for: $0)
         }) {
        self.allowsLaunching = allowsLaunching
        self.resolveCommand = resolveCommand
    }

    func prepare(_ session: Session, directory: String) async {
        guard allowsLaunching, sessions[session.id] == nil, errors[session.id] == nil,
              preparing.insert(session.id).inserted else { return }
        defer { preparing.remove(session.id) }
        do {
            let command = try await resolveCommand(session.kind)
            guard preparing.contains(session.id) else { return }
            sessions[session.id] = try TerminalSession(workingDirectory: URL(filePath: directory),
                                                       command: command)
        } catch {
            guard preparing.contains(session.id) else { return }
            errors[session.id] = message(for: error)
        }
    }

    func status(for session: Session) -> String {
        if !allowsLaunching { return "Preview" }
        if errors[session.id] != nil { return "Failed" }
        if preparing.contains(session.id) { return "Starting" }
        return sessions[session.id]?.status.label ?? "Not started"
    }

    func close(_ id: Session.ID) {
        preparing.remove(id)
        sessions.removeValue(forKey: id)?.close()
        errors.removeValue(forKey: id)
    }

    /// LocalizedError's recoverySuggestion is the actionable half and localizedDescription drops it.
    private func message(for error: Error) -> String {
        guard let localized = error as? LocalizedError,
              let description = localized.errorDescription else { return error.localizedDescription }
        guard let suggestion = localized.recoverySuggestion else { return description }
        return "\(description)\n\n\(suggestion)"
    }

    func retainSessions(_ ids: Set<Session.ID>) {
        for id in Set(sessions.keys).union(errors.keys).union(preparing).subtracting(ids) { close(id) }
    }

    func closeAll() {
        preparing.removeAll()
        for session in sessions.values { session.close() }
        sessions.removeAll()
        errors.removeAll()
    }
}
