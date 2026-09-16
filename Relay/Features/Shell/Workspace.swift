import SwiftUI

// Persisted metadata only; sessions do not own running processes.
struct Workspace: Identifiable, Codable, Equatable {
    var id = UUID()
    let name: String
    let path: String
    var sessions: [Session] = []
    var selectedSessionID: UUID?

    static let samples: [Workspace] = {
        let sessions = SessionKind.allCases.map { Session(kind: $0) }
        return [
            Workspace(name: "Relay", path: "~/Developer/Relay", sessions: sessions,
                             selectedSessionID: sessions.first?.id),
            Workspace(name: "Aquarium Manager", path: "~/Developer/aquarium"),
            Workspace(name: "Homelab", path: "~/homelab")
        ]
    }()
}
