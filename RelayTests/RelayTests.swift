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

    @Test func reportsWriteFailures() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        store.state.workspaces.append(Workspace(name: "Project", path: "/tmp/project"))
        #expect(store.errorMessage != nil)
    }
}
