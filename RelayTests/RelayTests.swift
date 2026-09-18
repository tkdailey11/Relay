import Foundation
import Testing
@testable import Relay

@MainActor
struct RelayTests {
    private func storageURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            .appending(path: "workspaces.json")
    }

    @Test func restoresWorkspaceOrderSessionsAndSelections() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: url)
        #expect(store.state.workspaces.isEmpty)
        #expect(store.errorMessage == nil)
        let sessions = SessionKind.allCases.map { Session(kind: $0) }
        let first = Workspace(name: "Project", path: "/tmp/project", sessions: sessions,
                              selectedSessionID: sessions[1].id)
        let second = Workspace(name: "Other", path: "/tmp/other")
        store.state = WorkspaceSnapshot(workspaces: [first, second], selectedWorkspaceID: first.id)
        let reopened = WorkspaceStore(fileURL: url)
        #expect(reopened.errorMessage == nil)
        #expect(reopened.state == store.state)

        // Nested bindings must save just as whole-snapshot replacements do.
        reopened.state.workspaces[0].sessions.removeLast()
        reopened.state.selectedWorkspaceID = second.id
        #expect(WorkspaceStore(fileURL: url).state == reopened.state)
    }

    @Test func preservesUnreadableDataInsteadOfOverwriting() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = Data("broken json".utf8)
        try original.write(to: url)
        let store = WorkspaceStore(fileURL: url)
        #expect(store.errorMessage != nil)
        store.state.workspaces.append(Workspace(name: "New", path: "/tmp/new"))
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func repairsStaleSelectionsAndPreservesUnknownVersions() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let session = Session(kind: .shell)
        let workspace = Workspace(name: "Project", path: "/missing/project", sessions: [session],
                                  selectedSessionID: UUID())
        let store = WorkspaceStore(fileURL: url)
        store.state = WorkspaceSnapshot(workspaces: [workspace], selectedWorkspaceID: UUID())
        let reopened = WorkspaceStore(fileURL: url)
        #expect(reopened.state.selectedWorkspaceID == workspace.id)
        #expect(reopened.state.workspaces[0].selectedSessionID == session.id)
        #expect(reopened.state.workspaces[0].path == "/missing/project")
        var future = store.state
        future.version = 2
        let data = try JSONEncoder().encode(future)
        try data.write(to: url)
        let unsupported = WorkspaceStore(fileURL: url)
        #expect(unsupported.errorMessage != nil)
        unsupported.state = WorkspaceSnapshot()
        #expect(try Data(contentsOf: url) == data)
    }

    @Test func temporarySessionsStaySeparateAndDoNotRestore() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: url)
        #expect(store.destination == .temporary)
        store.addTemporarySession(.shell)
        #expect(store.temporarySessions.count == 1)
        #expect(FileManager.default.fileExists(atPath: url.path) == false)

        let workspaceSession = Session(kind: .claude)
        let workspace = Workspace(name: "Project", path: "/tmp/project", sessions: [workspaceSession],
                                  selectedSessionID: workspaceSession.id)
        store.state = WorkspaceSnapshot(workspaces: [workspace], selectedWorkspaceID: workspace.id)
        store.destination = .workspace(workspace.id)
        let persistedData = try Data(contentsOf: url)
        store.addTemporarySession(.copilot)
        let temporarySelection = store.selectedTemporarySessionID
        #expect(store.destination == .temporary)
        #expect(store.state.workspaces[0].sessions == [workspaceSession])
        #expect(try Data(contentsOf: url) == persistedData)
        store.destination = .workspace(workspace.id)
        #expect(store.temporarySessions.count == 2)
        store.destination = .temporary
        #expect(store.selectedTemporarySessionID == temporarySelection)
        store.temporarySessions.removeAll { $0.id == temporarySelection }
        store.selectedTemporarySessionID = store.temporarySessions.first?.id
        #expect(store.state.workspaces[0].selectedSessionID == workspaceSession.id)

        let reopened = WorkspaceStore(fileURL: url)
        #expect(reopened.temporarySessions.isEmpty)
        #expect(reopened.selectedTemporarySessionID == nil)
        #expect(reopened.destination == .workspace(workspace.id))
        #expect(reopened.state.workspaces == [workspace])
    }

    @Test func addingWorkspaceNormalizesPathsAndReusesExistingWorkspace() throws {
        let store = WorkspaceStore(fileURL: nil)
        store.addWorkspace(at: URL(filePath: "/tmp/relay-project"))
        let workspace = try #require(store.state.workspaces.first)
        store.addTemporarySession(.shell)
        store.addWorkspace(at: URL(filePath: "/tmp/relay-project/../relay-project"))
        #expect(store.state.workspaces.count == 1)
        #expect(store.destination == .workspace(workspace.id))
        #expect(store.temporarySessions.count == 1)
    }

    @Test(arguments: SessionKind.allCases)
    func addsSessionOnlyToRequestedWorkspace(kind: SessionKind) throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: url)
        store.addWorkspace(at: URL(filePath: "/tmp/first"))
        let first = try #require(store.state.workspaces.first)
        store.addWorkspace(at: URL(filePath: "/tmp/second"))
        let second = try #require(store.state.workspaces.last)
        store.addSession(kind, to: first.id)
        let restored = WorkspaceStore(fileURL: url)
        let workspace = try #require(restored.state.workspaces.first)
        let session = try #require(workspace.sessions.first)
        #expect(session.kind == kind)
        #expect(workspace.selectedSessionID == session.id)
        #expect(restored.state.workspaces.last?.sessions.isEmpty == true)
        #expect(restored.destination == .workspace(second.id))

        let snapshot = store.state
        store.addSession(kind, to: UUID())
        store.destination = .workspace(UUID())
        #expect(store.state == snapshot)
    }

    @Test func removingWorkspaceSelectsItsNeighborAndPersists() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: url)
        for name in ["first", "second", "third"] { store.addWorkspace(at: URL(filePath: "/tmp/\(name)")) }
        let (first, second, third) = (store.state.workspaces[0], store.state.workspaces[1], store.state.workspaces[2])

        // Removing an unselected workspace leaves the selection where it was.
        store.destination = .workspace(third.id)
        store.removeWorkspace(first.id)
        #expect(store.state.workspaces.map(\.id) == [second.id, third.id])
        #expect(store.destination == .workspace(third.id))

        // Removing the selected one falls to the workspace that took its index, else the last.
        store.destination = .workspace(second.id)
        store.removeWorkspace(second.id)
        #expect(store.destination == .workspace(third.id))
        #expect(WorkspaceStore(fileURL: url).state == store.state)

        store.removeWorkspace(third.id)
        #expect(store.state.workspaces.isEmpty)
        #expect(store.destination == .temporary)
        #expect(WorkspaceStore(fileURL: url).state.workspaces.isEmpty)

        // An unknown id changes nothing.
        let snapshot = store.state
        store.removeWorkspace(UUID())
        #expect(store.state == snapshot)
    }

    @Test func removingAWorkspaceWhileViewingTemporarySessionsStaysThere() throws {
        let store = WorkspaceStore(fileURL: nil)
        store.addWorkspace(at: URL(filePath: "/tmp/first"))
        store.addWorkspace(at: URL(filePath: "/tmp/second"))
        let second = try #require(store.state.workspaces.last)
        store.addTemporarySession(.shell)
        #expect(store.destination == .temporary)
        store.removeWorkspace(second.id)
        #expect(store.destination == .temporary)
        #expect(store.temporarySessions.count == 1)
    }

    @Test func reportsWriteFailures() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        store.state.workspaces.append(Workspace(name: "Project", path: "/tmp/project"))
        #expect(store.errorMessage != nil)
    }
}
