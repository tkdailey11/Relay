import Foundation
import Testing
@testable import Relay

/// Relay 0.1 shipped to testers with `kind: "Claude"` in workspaces.json. Those files must keep
/// opening, with their sessions pointing at the matching presets.
@MainActor
struct SessionMigrationTests {
    private func storageURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            .appending(path: "workspaces.json")
    }

    private let legacy = """
        {
          "version": 1,
          "selectedWorkspaceID": "11111111-1111-1111-1111-111111111111",
          "workspaces": [
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "name": "Relay",
              "path": "/tmp/relay",
              "selectedSessionID": "22222222-2222-2222-2222-222222222222",
              "sessions": [
                { "id": "22222222-2222-2222-2222-222222222222", "kind": "Claude" },
                { "id": "33333333-3333-3333-3333-333333333333", "kind": "Copilot" },
                { "id": "44444444-4444-4444-4444-444444444444", "kind": "Shell" }
              ]
            }
          ]
        }
        """

    @Test func aRelay01SnapshotOpensWithItsSessionsOnThePresets() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: url)

        let store = WorkspaceStore(fileURL: url, terminalsEnabled: false)
        #expect(store.errorMessage == nil)
        let workspace = try #require(store.state.workspaces.first)
        #expect(workspace.sessions.map(\.typeID) == ["claude", "copilot", "shell"])
        #expect(workspace.sessions.map(\.typeName) == ["Claude", "Copilot", "Shell"])
        // The migrated ids match the presets, so the sessions still resolve to a live type.
        let types = SessionTypeStore(defaults: UserDefaults(suiteName: "MigrationTest-\(UUID())")!)
        for session in workspace.sessions {
            #expect(types.resolve(session).isMissing == false)
        }
        #expect(workspace.selectedSessionID == workspace.sessions.first?.id)
    }

    @Test func aMigratedSnapshotIsRewrittenInTheNewShape() throws {
        let url = storageURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(legacy.utf8).write(to: url)

        let store = WorkspaceStore(fileURL: url, terminalsEnabled: false)
        // Touch the snapshot so it saves, then confirm the new format round trips.
        store.addWorkspace(at: URL(filePath: "/tmp/another-relay-workspace"))
        let rewritten = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        #expect(rewritten.contains("\"typeID\""))
        #expect(rewritten.contains("\"typeName\""))
        #expect(rewritten.contains("\"kind\"") == false)

        let reopened = WorkspaceStore(fileURL: url, terminalsEnabled: false)
        #expect(reopened.state.workspaces.first?.sessions.map(\.typeID) == ["claude", "copilot", "shell"])
    }

    @Test func aSessionWrittenBeforeTypeNameExistedFallsBackToItsID() throws {
        let json = """
            { "id": "55555555-5555-5555-5555-555555555555", "typeID": "aider" }
            """
        let session = try JSONDecoder().decode(Session.self, from: Data(json.utf8))
        #expect(session.typeID == "aider")
        #expect(session.typeName == "aider")
    }
}
