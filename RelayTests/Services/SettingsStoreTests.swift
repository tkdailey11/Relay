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

    private func scheme(named name: String, background: String) -> TerminalColorScheme {
        TerminalColorScheme(name: name, background: TerminalColor(hex: background)!,
                            foreground: TerminalColor(hex: "FFFFFF")!)
    }

    @Test func chosenColorSchemesPersistAndReachTheTerminal() {
        let suite = defaults()
        var applied: [TerminalSettings] = []
        let store = SettingsStore(defaults: suite, apply: { applied.append($0) })
        #expect(store.terminalSettings.lightColors == .relayLight)
        #expect(store.terminalSettings.darkColors == .relayDark)

        let midnight = scheme(named: "Midnight", background: "000033")
        store.addColorScheme(midnight)
        store.darkColorSchemeID = midnight.id
        #expect(applied.last?.darkColors == midnight)
        #expect(applied.last?.lightColors == .relayLight)

        var edited = midnight
        edited.palette[1] = TerminalColor(hex: "FF0000")!
        store.updateColorScheme(edited)
        #expect(applied.last?.darkColors.palette[1] == TerminalColor(hex: "FF0000"))

        let reopened = SettingsStore(defaults: suite, apply: { _ in })
        #expect(reopened.customColorSchemes == [edited])
        #expect(reopened.darkColors == edited)
    }

    @Test func removingAChosenSchemeFallsBackToRelays() {
        let store = SettingsStore(defaults: defaults(), apply: { _ in })
        let paper = scheme(named: "Paper", background: "FFFFF0")
        store.addColorScheme(paper)
        store.lightColorSchemeID = paper.id
        store.darkColorSchemeID = paper.id
        store.removeColorScheme(id: paper.id)
        #expect(store.lightColors == .relayLight)
        #expect(store.darkColors == .relayDark)
        #expect(store.customColorSchemes.isEmpty)
    }

    @Test func builtInSchemesCannotBeChangedOrRemoved() {
        let store = SettingsStore(defaults: defaults(), apply: { _ in })
        var changed = TerminalColorScheme.relayDark
        changed.background = TerminalColor(hex: "FF00FF")!
        store.updateColorScheme(changed)
        store.removeColorScheme(id: TerminalColorScheme.relayDark.id)
        #expect(store.darkColors == .relayDark)
        #expect(store.colorSchemes.contains(.relayDark))

        // Editing one goes through a copy, which is a scheme of its own.
        let copy = store.duplicateColorScheme(.relayDark)
        #expect(copy.id != TerminalColorScheme.relayDark.id)
        #expect(copy.name == "Relay Dark Copy")
        #expect(store.customColorSchemes == [copy])
    }

    @Test func aStaleOrCorruptSelectionStillGivesTerminalsColors() {
        let suite = defaults()
        suite.set(Data("not json".utf8), forKey: SettingsStore.colorSchemesKey)
        suite.set("deleted-elsewhere", forKey: SettingsStore.darkColorSchemeKey)
        let store = SettingsStore(defaults: suite, apply: { _ in })
        #expect(store.customColorSchemes.isEmpty)
        #expect(store.darkColors == .relayDark)
    }

    @Test func importingKeepsTheGoodFilesAndReportsTheRest() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "RelayImport-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let good = directory.appending(path: "Nord")
        try "background = #2e3440\nforeground = #d8dee9\n".write(to: good, atomically: true, encoding: .utf8)
        let bad = directory.appending(path: "readme.txt")
        try "hello".write(to: bad, atomically: true, encoding: .utf8)

        let store = SettingsStore(defaults: defaults(), apply: { _ in })
        let imported = store.importColorSchemes(from: [good, bad])
        #expect(imported.map(\.name) == ["Nord"])
        #expect(store.customColorSchemes.map(\.name) == ["Nord"])
        #expect(store.errorMessage?.contains("readme.txt") == true)
    }
}
