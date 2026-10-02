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
        #expect(claudeItem?.shortcut == "⌘2")
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

    // MARK: Commands

    private func context(selected: String? = "Claude", closed: String? = nil,
                         focused: Bool? = false) -> PaletteContext {
        PaletteContext(sessionTypes: Array(SessionType.presets.prefix(2)), defaultTypeID: "claude",
                       destinationName: "Relay", selectedSessionTitle: selected,
                       closedSessionTitle: closed, isTerminalFocused: focused)
    }

    private func palette(_ context: PaletteContext) -> [QuickSwitcherItem] {
        items() + QuickSwitcher.commands(context)
    }

    @Test func commandsActOnlyOnWhatExists() {
        let titles = QuickSwitcher.commands(context(selected: nil, focused: nil)).map(\.title)
        #expect(titles.contains("New Claude Session"))
        #expect(titles.contains("Add Workspace…"))
        #expect(!titles.contains("Rename Session…"))
        #expect(!titles.contains("Reopen Closed Session"))
        #expect(!titles.contains("Focus Terminal"))

        let full = QuickSwitcher.commands(context(closed: "Shell", focused: true)).map(\.title)
        #expect(full.contains("Duplicate Session"))
        #expect(full.contains("Reopen Closed Session"))
        #expect(full.contains("Exit Terminal Focus"))
    }

    @Test func aVerbFindsItsCommand() {
        let results = QuickSwitcher.filter(palette(context()), query: "dup")
        #expect(results.first?.command == .duplicateSession)
        #expect(results.first?.shortcut == "⇧⌘D")
        // Words that are not in the title still find it.
        #expect(QuickSwitcher.filter(palette(context()), query: "clone").first?.command == .duplicateSession)
        #expect(QuickSwitcher.filter(palette(context()), query: "new copilot").first?.command
                == .newSession(typeID: "copilot"))
    }

    @Test func aNameFindsTheSessionBeforeAnyCommand() {
        let results = QuickSwitcher.filter(palette(context()), query: "claude")
        #expect(results.first?.sessionID == claude.id)
        // The session a command acts on is not a reason for the command to match its name.
        #expect(!results.contains { $0.command == .closeSession })
    }

    @Test func commandsDoNotMatchBySubsequence() {
        #expect(QuickSwitcher.filter(palette(context()), query: "cse").allSatisfy { $0.command == nil })
    }

    // MARK: Status, recents and sections

    @Test func aWaitingSessionIsFlaggedAndSearchableAsWaiting() {
        let all = QuickSwitcher.items(
            workspaces: [Workspace(name: "Relay", path: "/code/Relay", sessions: [shell, claude])],
            temporarySessions: [],
            resolve: SessionTypeStore(defaults: UserDefaults(suiteName: "QuickSwitcherTests-\(UUID())")!).resolve,
            state: { $0.id == claude.id ? .needsAttention : .running })
        #expect(all.first { $0.sessionID == claude.id }?.needsAttention == true)
        // The workspace holding it is flagged too, so it can be found from anywhere.
        #expect(all.first { $0.title == "Relay" }?.needsAttention == true)
        #expect(all.first { $0.sessionID == shell.id }?.needsAttention == false)
        #expect(QuickSwitcher.filter(all, query: "attention").map(\.sessionID) == [claude.id])
    }

    @Test func anEmptyQueryLeadsWithWaitingSessionsThenRecents() {
        var all = palette(context())
        let index = all.firstIndex { $0.sessionID == claude.id }!
        all[index].needsAttention = true
        let homelab = all.first { $0.title == "Homelab" }!

        let sections = QuickSwitcher.sections(all, query: "", recents: [homelab.id, claude.id.uuidString])
        #expect(sections.map(\.title) == ["Needs Attention", "Recent", "Workspaces & Sessions", "Commands"])
        #expect(sections[0].items.map(\.sessionID) == [claude.id])
        // A waiting session is shown once, not again under Recent.
        #expect(sections[1].items.map(\.title) == ["Homelab"])
        let everything = sections.flatMap(\.items).map(\.id)
        #expect(Set(everything).count == everything.count)
        #expect(everything.count == all.count)
    }

    @Test func searchingIsOneFlatList() {
        let sections = QuickSwitcher.sections(palette(context()), query: "relay")
        #expect(sections.count == 1)
        #expect(sections[0].title == nil)
        #expect(QuickSwitcher.sections(palette(context()), query: "zzzzzz").isEmpty)
    }

    @Test func recentChoicesWinTies() {
        let all = items()
        let shellItem = all.first { $0.sessionID == shell.id }!
        let claudeItem = all.first { $0.sessionID == claude.id }!
        // Both sessions match "relay" equally; the one chosen last comes first.
        let results = QuickSwitcher.filter(all, query: "relay", recents: [claudeItem.id, shellItem.id])
        let sessions = results.filter { $0.sessionID != nil }.map(\.sessionID)
        #expect(sessions == [claude.id, shell.id])
    }
}
