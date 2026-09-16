import Darwin
import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceStore {
    var state: WorkspaceSnapshot {
        didSet { if state != oldValue { save() } }
    }
    // Deliberately excluded from WorkspaceSnapshot and its on-disk representation.
    // NSHomeDirectory points at the app container when sandboxed.
    var temporaryWorkingDirectory: String {
        guard let directory = getpwuid(getuid())?.pointee.pw_dir else { return NSHomeDirectory() }
        return String(cString: directory)
    }
    var temporarySessions: [Session] = []
    var selectedTemporarySessionID: UUID?
    var showsTemporarySessions = false
    var destination: SessionDestination? {
        get {
            if showsTemporarySessions || state.selectedWorkspaceID == nil { return .temporary }
            return state.selectedWorkspaceID.map(SessionDestination.workspace)
        }
        set {
            switch newValue {
            case .workspace(let id):
                guard state.workspaces.contains(where: { $0.id == id }) else { return }
                showsTemporarySessions = false
                state.selectedWorkspaceID = id
            case .temporary:
                showsTemporarySessions = true
            case nil:
                break
            }
        }
    }

    func addTemporarySession(_ kind: SessionKind) {
        let session = Session(kind: kind)
        temporarySessions.append(session)
        selectedTemporarySessionID = session.id
        showsTemporarySessions = true
    }

    func addWorkspace(at url: URL) {
        let directory = url.standardizedFileURL
        if let existing = state.workspaces.first(where: { $0.path == directory.path }) {
            destination = .workspace(existing.id)
            return
        }
        let workspace = Workspace(name: directory.lastPathComponent, path: directory.path)
        var updated = state
        updated.workspaces.append(workspace)
        updated.selectedWorkspaceID = workspace.id
        state = updated
        showsTemporarySessions = false
    }

    func addSession(_ kind: SessionKind, to workspaceID: UUID) {
        guard let index = state.workspaces.firstIndex(where: { $0.id == workspaceID }) else { return }
        let session = Session(kind: kind)
        var updated = state
        updated.workspaces[index].sessions.append(session)
        updated.workspaces[index].selectedSessionID = session.id
        state = updated
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
