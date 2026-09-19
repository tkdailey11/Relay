import Foundation
import Testing
@testable import Relay

@MainActor
struct SessionTypeStoreTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "RelaySessionTypeTests-\(UUID().uuidString)")!
    }

    @Test func aFreshInstallStartsWithThePresets() {
        let store = SessionTypeStore(defaults: defaults())
        #expect(store.types.map(\.id) == ["claude", "copilot", "codex", "shell"])
        #expect(store.enabled.count == 4)
        #expect(store.defaultType.id == SessionType.shellID)
    }

    @Test func typesRoundTripThroughStorage() {
        let suite = defaults()
        let store = SessionTypeStore(defaults: suite)
        store.add(SessionType(id: "aider", name: "Aider", command: "aider --no-auto-commits",
                              symbol: "wand.and.stars", color: .pink))
        var claude = try! #require(store.type(id: "claude"))
        claude.command = "/opt/homebrew/bin/claude"
        claude.isEnabled = false
        store.update(claude)

        let reopened = SessionTypeStore(defaults: suite)
        #expect(reopened.type(id: "aider")?.command == "aider --no-auto-commits")
        #expect(reopened.type(id: "aider")?.color == .pink)
        #expect(reopened.type(id: "claude")?.command == "/opt/homebrew/bin/claude")
        #expect(reopened.type(id: "claude")?.isEnabled == false)
        #expect(reopened.enabled.contains { $0.id == "claude" } == false)
    }

    /// The 0.1 escape hatch, `defaults write … RelayCommand.Copilot "gh copilot"`, has to
    /// survive the move to editable types or a tester's working setup breaks on upgrade.
    @Test func legacyCommandOverridesMigrateOntoTheirPresets() {
        let suite = defaults()
        suite.set("gh copilot", forKey: SessionTypeStore.legacyCommandKey(for: "Copilot"))
        suite.set("/usr/local/bin/claude", forKey: SessionTypeStore.legacyCommandKey(for: "Claude"))

        let store = SessionTypeStore(defaults: suite)
        #expect(store.type(id: "copilot")?.command == "gh copilot")
        #expect(store.type(id: "claude")?.command == "/usr/local/bin/claude")
        #expect(store.type(id: "codex")?.command == "codex")
    }

    @Test func shellCannotBeRemovedAndIsRestoredIfMissing() {
        let suite = defaults()
        let store = SessionTypeStore(defaults: suite)
        store.remove(SessionType.shellID)
        #expect(store.type(id: SessionType.shellID) != nil)

        // Even a stored list that somehow lacks Shell gets it back, or nothing can start.
        let withoutShell = [SessionType(id: "claude", name: "Claude", command: "claude",
                                        symbol: "sparkle", color: .orange)]
        suite.set(try! JSONEncoder().encode(withoutShell), forKey: SessionTypeStore.storageKey)
        let repaired = SessionTypeStore(defaults: suite)
        #expect(repaired.type(id: SessionType.shellID) != nil)
    }

    @Test func aCorruptListFallsBackToThePresets() {
        let suite = defaults()
        suite.set(Data("not json".utf8), forKey: SessionTypeStore.storageKey)
        let store = SessionTypeStore(defaults: suite)
        #expect(store.types.map(\.id) == SessionType.presets.map(\.id))
    }

    /// Deleting a type must not disturb a session started from it.
    @Test func removingATypeLeavesItsSessionsResolvableByName() {
        let store = SessionTypeStore(defaults: defaults())
        let codex = try! #require(store.type(id: "codex"))
        let session = Session(type: codex)
        #expect(store.resolve(session).isMissing == false)

        store.remove("codex")
        let resolved = store.resolve(session)
        #expect(resolved.isMissing)
        #expect(resolved.name == "Codex")
    }

    @Test func renamingATypeUpdatesSessionsAlreadyStartedFromIt() {
        let store = SessionTypeStore(defaults: defaults())
        var claude = try! #require(store.type(id: "claude"))
        let session = Session(type: claude)
        claude.name = "Claude Code"
        store.update(claude)
        #expect(store.resolve(session).name == "Claude Code")
    }

    /// Four presets fit the sidebar grid, so nothing is hidden on a fresh install.
    @Test func everyEnabledTypeGetsALauncherWhenTheyFit() {
        let store = SessionTypeStore(defaults: defaults())
        let launchers = store.sidebarLaunchers
        #expect(launchers.pinned.map(\.id) == ["claude", "copilot", "codex", "shell"])
        #expect(launchers.overflow.isEmpty)
    }

    /// Exactly at the limit still fills the grid: the overflow menu would cost a slot to show
    /// a list of nothing.
    @Test func theLimitItselfDoesNotTriggerAnOverflowMenu() {
        let store = SessionTypeStore(defaults: defaults())
        addTypes(to: store, count: SessionTypeStore.launcherLimit - store.enabled.count)
        #expect(store.enabled.count == SessionTypeStore.launcherLimit)
        #expect(store.sidebarLaunchers.pinned.count == SessionTypeStore.launcherLimit)
        #expect(store.sidebarLaunchers.overflow.isEmpty)
    }

    /// The sidebar has no scroll of its own, so a long list has to stay a fixed height rather
    /// than squeezing the workspace list away.
    @Test func extraTypesMoveIntoTheOverflowMenuInOrder() {
        let store = SessionTypeStore(defaults: defaults())
        addTypes(to: store, count: 16)
        let launchers = store.sidebarLaunchers
        #expect(store.enabled.count == 20)
        #expect(launchers.pinned.count == SessionTypeStore.launcherLimit - 1)
        #expect(launchers.overflow.count == 20 - (SessionTypeStore.launcherLimit - 1))
        // Nothing is dropped, and the user's Settings order decides which side a type lands on.
        #expect(launchers.pinned.map(\.id) + launchers.overflow.map(\.id) == store.enabled.map(\.id))
    }

    /// Disabling a type is the direct way to promote another into the grid.
    @Test func disabledTypesDoNotConsumeLauncherSlots() {
        let store = SessionTypeStore(defaults: defaults())
        addTypes(to: store, count: 4)
        var claude = try! #require(store.type(id: "claude"))
        claude.isEnabled = false
        store.update(claude)
        #expect(store.enabled.count == 7)
        #expect(store.sidebarLaunchers.pinned.contains { $0.id == "claude" } == false)
        #expect(store.sidebarLaunchers.overflow.contains { $0.id == "claude" } == false)
    }

    private func addTypes(to store: SessionTypeStore, count: Int) {
        for index in 0..<count {
            store.add(SessionType(id: "custom-\(index)", name: "Custom \(index)",
                                  command: "custom\(index)", symbol: "bolt", color: .blue))
        }
    }

    @Test func theDefaultTypeFallsBackWhenShellIsDisabled() {
        let store = SessionTypeStore(defaults: defaults())
        var shell = try! #require(store.type(id: SessionType.shellID))
        shell.isEnabled = false
        store.update(shell)
        #expect(store.defaultType.id == "claude")
    }
}
