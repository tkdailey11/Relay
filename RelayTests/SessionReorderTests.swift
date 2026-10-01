import Foundation
import Testing
@testable import Relay

@MainActor
struct SessionReorderTests {
    private func shells(_ count: Int) -> [Session] {
        (0..<count).map { _ in Session(type: .shellPreset) }
    }

    @Test func movingASessionPutsItAtTheRequestedIndex() {
        var sessions = shells(4)
        let ids = sessions.map(\.id)

        // As a drag past each neighbour in turn reports it.
        sessions.move(ids[0], to: 1)
        sessions.move(ids[0], to: 2)
        #expect(sessions.map(\.id) == [ids[1], ids[2], ids[0], ids[3]])

        sessions.move(ids[3], to: 0)
        #expect(sessions.map(\.id) == [ids[3], ids[1], ids[2], ids[0]])

        // Out-of-range targets clamp, and unknown ids or no-op moves change nothing.
        sessions.move(ids[1], to: 99)
        #expect(sessions.map(\.id).last == ids[1])
        let before = sessions
        sessions.move(UUID(), to: 0)
        sessions.move(ids[3], to: 0)
        #expect(sessions == before)
    }

    @Test func stepsStopAtEitherEnd() {
        let sessions = shells(3)
        #expect(!sessions.canMove(sessions[0].id, by: -1))
        #expect(sessions.canMove(sessions[0].id, by: 1))
        #expect(sessions.canMove(sessions[2].id, by: -1))
        #expect(!sessions.canMove(sessions[2].id, by: 1))
        #expect(!sessions.canMove(sessions[1].id, by: 0))
        #expect(!sessions.canMove(UUID(), by: 1))
    }

    @Test func reorderedSessionsPersistWithTheirWorkspace() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            .appending(path: "workspaces.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = WorkspaceStore(fileURL: url)
        store.addWorkspace(at: URL(filePath: "/tmp/project"))
        let workspaceID = try #require(store.state.workspaces.first?.id)
        for _ in 0..<3 { store.addSession(.shellPreset, to: workspaceID) }
        let ids = store.state.workspaces[0].sessions.map(\.id)
        let selected = store.state.workspaces[0].selectedSessionID

        // The shell writes through the same binding the cards use.
        store.state.workspaces[0].sessions.move(ids[2], to: 0)
        let reopened = WorkspaceStore(fileURL: url)
        #expect(reopened.state.workspaces[0].sessions.map(\.id) == [ids[2], ids[0], ids[1]])
        #expect(reopened.state.workspaces[0].selectedSessionID == selected)
    }
}
