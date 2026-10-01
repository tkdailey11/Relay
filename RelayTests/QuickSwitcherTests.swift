import Foundation
import Testing
@testable import Relay

@MainActor
struct QuickSwitcherTests {
    private let claude = Session(type: SessionType.presets.first { $0.id == "claude" }!)
    private let shell = Session(type: .shellPreset)

    private func items(temporary: [Session] = []) -> [QuickSwitcherItem] {
        let relay = Workspace(name: "Relay", path: "/code/Relay", sessions: [shell, claude])
        let homelab = Workspace(name: "Homelab", path: "/code/homelab")
        return QuickSwitcher.items(workspaces: [relay, homelab], temporarySessions: temporary,
                                   resolve: SessionTypeStore(defaults: UserDefaults(suiteName: "QuickSwitcherTests-\(UUID())")!).resolve)
    }

    @Test func listsEveryDestinationAndSessionInSidebarOrder() {
        let temporary = Session(type: .shellPreset)
        let titles = items(temporary: [temporary]).map(\.title)
        #expect(titles == ["Relay", "Shell", "Claude", "Homelab", "Temporary Sessions", "Shell"])
        let claudeItem = items().first { $0.sessionID == claude.id }
        #expect(claudeItem?.shortcutNumber == 2)
        #expect(claudeItem?.subtitle == "Relay")
    }

    @Test func emptyQueryKeepsEverything() {
        let all = items()
        #expect(QuickSwitcher.filter(all, query: "  ") == all)
    }

    @Test func everyTermMustMatchAndCombinesDestinationWithType() {
        let results = QuickSwitcher.filter(items(), query: "relay claude")
        #expect(results.map(\.sessionID) == [claude.id])
        #expect(QuickSwitcher.filter(items(), query: "relay zzz").isEmpty)
    }

    @Test func wordPrefixesOutrankSubsequences() {
        // "hom" starts Homelab but is only scattered through "Shell /code/Relay"-style rows.
        let results = QuickSwitcher.filter(items(), query: "hom")
        #expect(results.first?.title == "Homelab")
        // A subsequence still matches when nothing better does.
        #expect(QuickSwitcher.filter(items(), query: "tmps").first?.title == "Temporary Sessions")
    }

    @Test func selectingASessionShowsItsDestination() {
        let store = WorkspaceStore(fileURL: nil, terminalsEnabled: false)
        let relay = Workspace(name: "Relay", path: "/code/Relay", sessions: [shell, claude],
                              selectedSessionID: shell.id)
        let homelab = Workspace(name: "Homelab", path: "/code/homelab")
        store.state = WorkspaceSnapshot(workspaces: [relay, homelab], selectedWorkspaceID: homelab.id)
        store.addTemporarySession(.shellPreset)
        #expect(store.destination == .temporary)

        store.select(.workspace(relay.id), sessionID: claude.id)
        #expect(store.destination == .workspace(relay.id))
        #expect(store.state.workspaces[0].selectedSessionID == claude.id)

        // A session from somewhere else must not become this destination's selection.
        store.select(.workspace(homelab.id), sessionID: claude.id)
        #expect(store.destination == .workspace(homelab.id))
        #expect(store.state.workspaces[1].selectedSessionID == nil)

        let temporaryID = store.temporarySessions[0].id
        store.selectedTemporarySessionID = nil
        store.select(.temporary, sessionID: temporaryID)
        #expect(store.destination == .temporary)
        #expect(store.selectedTemporarySessionID == temporaryID)
    }

    @Test func steppingDestinationsWrapsThroughTheSidebar() {
        let store = WorkspaceStore(fileURL: nil, terminalsEnabled: false)
        let first = Workspace(name: "First", path: "/first")
        let second = Workspace(name: "Second", path: "/second")
        store.state = WorkspaceSnapshot(workspaces: [first, second], selectedWorkspaceID: first.id)
        store.selectAdjacentDestination(offset: 1)
        #expect(store.destination == .workspace(second.id))
        store.selectAdjacentDestination(offset: 1)
        #expect(store.destination == .temporary)
        store.selectAdjacentDestination(offset: 1)
        #expect(store.destination == .workspace(first.id))
        store.selectAdjacentDestination(offset: -1)
        #expect(store.destination == .temporary)
    }
}
