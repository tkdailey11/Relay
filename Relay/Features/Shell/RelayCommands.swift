import SwiftUI
import TerminalKit

// Terminal focus and session switching are published by the visible workspace shell and
// consumed by the menu bar, so shortcuts stay discoverable in the View menu.
struct TerminalFocusAction: Equatable {
    let isExpanded: Bool
    let toggle: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.isExpanded == rhs.isExpanded }
}

struct SessionSwitchAction: Equatable {
    let titles: [String]
    let selectedIndex: Int?
    let select: (Int) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.titles == rhs.titles && lhs.selectedIndex == rhs.selectedIndex
    }
}

/// Published by the window that owns the store, so the Help menu reports on what is on screen.
struct DiagnosticsAction: Equatable {
    let show: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

extension FocusedValues {
    @Entry var terminalFocus: TerminalFocusAction?
    @Entry var sessionSwitch: SessionSwitchAction?
    @Entry var diagnostics: DiagnosticsAction?
}

struct RelayCommands: Commands {
    let settings: SettingsStore
    @FocusedValue(\.terminalFocus) private var terminalFocus
    @FocusedValue(\.sessionSwitch) private var sessionSwitch
    @FocusedValue(\.diagnostics) private var diagnostics

    var body: some Commands {
        // Beta testers need one place to get a report from, and Help is where macOS users
        // look for it.
        CommandGroup(after: .help) {
            Button("Diagnostics…") { diagnostics?.show() }
                .disabled(diagnostics == nil)
        }
        // Font size is a preference rather than a per-surface state, so these move the setting
        // and every open terminal follows.
        CommandGroup(after: .toolbar) {
            Button("Bigger Text", systemImage: "textformat.size.larger") {
                settings.adjustFontSize(by: 1)
            }
            .keyboardShortcut("+", modifiers: .command)
            .disabled(settings.fontSize >= TerminalSettings.maximumFontSize)
            Button("Smaller Text", systemImage: "textformat.size.smaller") {
                settings.adjustFontSize(by: -1)
            }
            .keyboardShortcut("-", modifiers: .command)
            .disabled(settings.fontSize <= TerminalSettings.minimumFontSize)
            Button("Actual Size") { settings.resetFontSize() }
                .keyboardShortcut("0", modifiers: .command)
            Divider()
        }
        CommandGroup(after: .sidebar) {
            Button(terminalFocus?.isExpanded == true ? "Exit Terminal Focus" : "Focus Terminal") {
                terminalFocus?.toggle()
            }
            .keyboardShortcut(.return, modifiers: [.command, .shift])
            .disabled(terminalFocus == nil)
            Divider()
            // Session switching stays reachable while the workspace chrome is hidden.
            ForEach(Array(sessionTitles.enumerated()), id: \.offset) { index, title in
                Button(title) { sessionSwitch?.select(index) }
                    .keyboardShortcut(shortcut(for: index), modifiers: .command)
            }
        }
    }

    private var sessionTitles: [String] {
        Array((sessionSwitch?.titles ?? []).prefix(9))
    }

    private func shortcut(for index: Int) -> KeyEquivalent {
        KeyEquivalent(Character("\(index + 1)"))
    }
}
