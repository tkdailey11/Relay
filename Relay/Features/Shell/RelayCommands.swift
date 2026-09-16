import SwiftUI

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

extension FocusedValues {
    @Entry var terminalFocus: TerminalFocusAction?
    @Entry var sessionSwitch: SessionSwitchAction?
}

struct RelayCommands: Commands {
    @FocusedValue(\.terminalFocus) private var terminalFocus
    @FocusedValue(\.sessionSwitch) private var sessionSwitch

    var body: some Commands {
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
