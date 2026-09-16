import Foundation
import Observation

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

@MainActor
@Observable
final class WorkspaceStore {
    var state: WorkspaceSnapshot {
        didSet { save() }
    }
    var errorMessage: String?
    private let fileURL: URL?
    private var canSave = true

    init(fileURL: URL? = URL.applicationSupportDirectory
        .appending(path: "Relay/workspaces.json")) {
        self.fileURL = fileURL
        self.state = WorkspaceSnapshot()
        guard let fileURL else { return }
        do {
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch CocoaError.fileReadNoSuchFile {
                return
            }
            var restored = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
            guard restored.version == 1 else {
                throw CocoaError(.fileReadUnknown)
            }
            restored.normalizeSelections()
            state = restored
        } catch {
            // Never overwrite an unreadable or newer-format store with an empty one.
            canSave = false
            errorMessage = "Relay couldn’t load your workspaces. The saved file has been preserved. Changes won’t be saved until the storage problem is resolved and Relay is reopened. \(error.localizedDescription)"
        }
    }

    private func save() {
        guard canSave, let fileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(state)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            errorMessage = "Relay couldn’t save your latest changes. \(error.localizedDescription)"
        }
    }

    static func preview() -> WorkspaceStore {
        let store = WorkspaceStore(fileURL: nil)
        store.state = WorkspaceSnapshot(workspaces: Workspace.samples,
                                        selectedWorkspaceID: Workspace.samples.first?.id)
        return store
    }
}
