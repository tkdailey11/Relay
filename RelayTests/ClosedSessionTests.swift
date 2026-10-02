import Foundation
import Testing
@testable import Relay

@MainActor
struct ClosedSessionTests {
    @Test func newestClosedSessionComesFirst() {
        var closed: [ClosedSession] = []
        let first = Session(type: .shellPreset)
        let second = Session(type: .shellPreset)
        closed.remember(first, at: 0)
        closed.remember(second, at: 2)
        #expect(closed.map(\.session.id) == [second.id, first.id])
        #expect(closed[0].index == 2)
    }

    @Test func historyKeepsOnlyTheMostRecent() {
        var closed: [ClosedSession] = []
        let sessions = (0..<[ClosedSession].limit + 3).map { _ in Session(type: .shellPreset) }
        for session in sessions { closed.remember(session, at: 0) }
        #expect(closed.count == [ClosedSession].limit)
        #expect(closed.first?.session.id == sessions.last?.id)
        #expect(!closed.contains { $0.session.id == sessions[0].id })
    }

    @Test func aClosedSessionCanOnlyBeTakenOnce() throws {
        var closed: [ClosedSession] = []
        closed.remember(Session(type: .shellPreset), at: 0)
        let id = try #require(closed.first?.id)
        #expect(closed.take(id) != nil)
        #expect(closed.take(id) == nil)
        #expect(closed.isEmpty)
    }

    @Test func removingAWorkspaceForgetsItsClosedSessions() throws {
        let store = WorkspaceStore(fileURL: nil, terminalsEnabled: false)
        store.addWorkspace(at: URL(filePath: "/tmp/relay-closed"))
        let id = try #require(store.state.workspaces.first?.id)
        store.closedSessions[.workspace(id), default: []].remember(Session(type: .shellPreset), at: 0)
        store.removeWorkspace(id)
        #expect(store.closedSessions[.workspace(id)] == nil)
    }
}
