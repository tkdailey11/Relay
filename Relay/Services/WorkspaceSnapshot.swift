import Foundation

struct WorkspaceSnapshot: Codable, Equatable {
    var version = 1
    var workspaces: [Workspace] = []
    var selectedWorkspaceID: UUID?

    mutating func normalizeSelections() {
        if !workspaces.contains(where: { $0.id == selectedWorkspaceID }) {
            selectedWorkspaceID = workspaces.first?.id
        }
        for index in workspaces.indices {
            if !workspaces[index].sessions.contains(where: { $0.id == workspaces[index].selectedSessionID }) {
                workspaces[index].selectedSessionID = workspaces[index].sessions.first?.id
            }
        }
    }
}
