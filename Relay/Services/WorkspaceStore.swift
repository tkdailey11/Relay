import Darwin
import TerminalKit
import Foundation
import Observation

@MainActor
@Observable
final class WorkspaceStore {
    var state: WorkspaceSnapshot {
        didSet {
            if state != oldValue { save() }
            reconcileTerminals()
        }
    }
    // Deliberately excluded from WorkspaceSnapshot and its on-disk representation.
    // NSHomeDirectory points at the app container when sandboxed.
    var temporaryWorkingDirectory: String {
        guard let directory = getpwuid(getuid())?.pointee.pw_dir else { return NSHomeDirectory() }
        return String(cString: directory)
    }
    let terminals: TerminalSessionManager
    var temporarySessions: [Session] = [] {
        didSet { reconcileTerminals() }
    }
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
        RelayLog.info(.workspace, "Added workspace \(workspace.name) at \(workspace.path)")
        var updated = state
        updated.workspaces.append(workspace)
        updated.selectedWorkspaceID = workspace.id
        state = updated
        showsTemporarySessions = false
    }

    /// Removing a workspace drops its persisted session metadata, which `reconcileTerminals`
    /// then turns into closed terminals. The directory itself is never touched.
    func removeWorkspace(_ id: UUID) {
        guard let index = state.workspaces.firstIndex(where: { $0.id == id }) else { return }
        RelayLog.info(.workspace, "Removed workspace \(state.workspaces[index].name) with \(state.workspaces[index].sessions.count) session(s)")
        var updated = state
        updated.workspaces.remove(at: index)
        if state.selectedWorkspaceID == id {
            // Land on whichever workspace took the removed one's place rather than jumping to
            // the top of the list. Removing the last one leaves Temporary Sessions selected.
            let neighbor = updated.workspaces.indices.contains(index)
                ? updated.workspaces[index] : updated.workspaces.last
            updated.selectedWorkspaceID = neighbor?.id
        }
        state = updated
    }

    /// True when removing this workspace would stop a process the user may not expect to lose.
    func hasRunningProcesses(in id: UUID) -> Bool {
        guard let workspace = state.workspaces.first(where: { $0.id == id }) else { return false }
        return workspace.sessions.contains { terminals.sessions[$0.id]?.requiresCloseConfirmation == true }
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

    nonisolated static var defaultFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "Relay/workspaces.json")
    }

    private static var legacyFileURL: URL {
        URL.homeDirectory.appending(path: "Library/Containers/com.tylerdailey.Relay/Data/Library/Application Support/Relay/workspaces.json")
    }

    init(fileURL: URL? = WorkspaceStore.defaultFileURL,
         terminalsEnabled: Bool = true, migrationSource: URL? = nil) {
        self.terminals = TerminalSessionManager(allowsLaunching: terminalsEnabled)
        self.fileURL = fileURL
        self.state = WorkspaceSnapshot()
        guard let fileURL else { return }
        do {
            let data: Data
            var migrated = false
            do {
                data = try Data(contentsOf: fileURL)
            } catch CocoaError.fileReadNoSuchFile {
                // The UI shell was sandboxed. Preserve its workspaces when moving to a
                // normal terminal app; leave the original snapshot untouched.
                let source = migrationSource ?? (fileURL == Self.defaultFileURL ? Self.legacyFileURL : nil)
                guard let source, FileManager.default.fileExists(atPath: source.path) else { return }
                data = try Data(contentsOf: source)
                migrated = true
            }
            var restored = try JSONDecoder().decode(WorkspaceSnapshot.self, from: data)
            guard restored.version == 1 else {
                throw CocoaError(.fileReadUnknown)
            }
            restored.normalizeSelections()
            state = restored
            if migrated { save() }
            RelayLog.info(.workspace, "Loaded \(restored.workspaces.count) workspace(s) from \(fileURL.path)\(migrated ? " (migrated from the sandboxed location)" : "")")
        } catch {
            // Never overwrite an unreadable or newer-format store with an empty one.
            canSave = false
            RelayLog.error(.workspace, "Could not load \(fileURL.path): \(error)")
            errorMessage = "Relay couldn’t load your workspaces. The saved file has been preserved. Changes won’t be saved until the storage problem is resolved and Relay is reopened. \(error.localizedDescription)"
        }
    }

    private func reconcileTerminals() {
        let ids = state.workspaces.flatMap(\.sessions).map(\.id) + temporarySessions.map(\.id)
        terminals.retainSessions(Set(ids))
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
            RelayLog.error(.workspace, "Could not save \(fileURL.path): \(error)")
            errorMessage = "Relay couldn’t save your latest changes. \(error.localizedDescription)"
        }
    }

    static func preview() -> WorkspaceStore {
        let store = WorkspaceStore(fileURL: nil, terminalsEnabled: false)
        store.state = WorkspaceSnapshot(workspaces: Workspace.samples,
                                        selectedWorkspaceID: Workspace.samples.first?.id)
        return store
    }
}
