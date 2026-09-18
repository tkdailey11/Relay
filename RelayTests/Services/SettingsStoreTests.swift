import Foundation
import Testing
import TerminalKit
@testable import Relay

@MainActor
struct SettingsStoreTests {
    private func defaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: "RelaySettingsTests-\(UUID().uuidString)")!
        return suite
    }

    @Test func fontChangesPersistAndReachTheTerminal() {
        let suite = defaults()
        var applied: [TerminalSettings] = []
        let store = SettingsStore(defaults: suite, apply: { applied.append($0) })
        #expect(store.fontSize == TerminalSettings.default.fontSize)
        // Constructing the store puts the stored settings in force before any terminal starts.
        #expect(applied.count == 1)

        store.fontSize = 18
        store.fontFamily = "Menlo"
        #expect(applied.last?.fontSize == 18)
        #expect(applied.last?.fontFamily == "Menlo")

        let reopened = SettingsStore(defaults: suite, apply: { _ in })
        #expect(reopened.fontSize == 18)
        #expect(reopened.fontFamily == "Menlo")
    }

    @Test func fontSizeStaysWithinAUsableRange() {
        let store = SettingsStore(defaults: defaults(), apply: { _ in })
        store.fontSize = 9000
        #expect(store.terminalSettings.fontSize == TerminalSettings.maximumFontSize)
        store.fontSize = 0
        #expect(store.terminalSettings.fontSize == TerminalSettings.minimumFontSize)

        store.resetFontSize()
        store.adjustFontSize(by: -1)
        #expect(store.fontSize == TerminalSettings.default.fontSize - 1)
        // Clamping happens at the setting, so the menu cannot walk it out of range.
        for _ in 0..<200 { store.adjustFontSize(by: -1) }
        #expect(store.fontSize == TerminalSettings.minimumFontSize)
    }

    @Test func anEmptyFamilyMeansTheDefaultFace() {
        let suite = defaults()
        let store = SettingsStore(defaults: suite, apply: { _ in })
        store.fontFamily = "Menlo"
        store.fontFamily = ""
        #expect(store.terminalSettings.fontFamily == nil)
        #expect(suite.string(forKey: SettingsStore.fontFamilyKey) == nil)
    }
}
