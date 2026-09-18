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

/// The terminal the menus act on. Nil while no session has a running terminal, which is what
/// disables the Terminal menu rather than letting it act on nothing.
struct ActiveTerminalAction: Equatable {
    let sessionName: String
    let perform: (TerminalAction) -> Void
    let scrollback: () -> String

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.sessionName == rhs.sessionName }
}

/// Relay is a single-window app, so ⌘N makes a session rather than a window.
struct NewSessionAction: Equatable {
    let destinationName: String
    let add: (SessionKind) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.destinationName == rhs.destinationName }
}

struct ScrollbackSearchAction: Equatable {
    let show: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool { true }
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
    @Entry var activeTerminal: ActiveTerminalAction?
    @Entry var newSession: NewSessionAction?
    @Entry var scrollbackSearch: ScrollbackSearchAction?
}

struct RelayCommands: Commands {
    let settings: SettingsStore
    @FocusedValue(\.terminalFocus) private var terminalFocus
    @FocusedValue(\.sessionSwitch) private var sessionSwitch
    @FocusedValue(\.diagnostics) private var diagnostics
    @FocusedValue(\.activeTerminal) private var activeTerminal
    @FocusedValue(\.newSession) private var newSession
    @FocusedValue(\.scrollbackSearch) private var scrollbackSearch

    var body: some Commands {
        // Relay has one window, so the File menu's New Window is replaced by the thing a user
        // actually wants a shortcut for.
        CommandGroup(replacing: .newItem) {
            ForEach(SessionKind.allCases) { kind in
                Button("New \(kind.rawValue) Session", systemImage: kind.symbol) {
                    newSession?.add(kind)
                }
                .keyboardShortcut(shortcut(for: kind))
                .disabled(newSession == nil)
            }
        }
        // relay.conf clears libghostty's own keybindings so the menu bar owns every Command
        // key; these are the ones worth having back, as discoverable menu items. Each is
        // disabled individually because Commands has no .disabled of its own.
        CommandMenu("Terminal") {
            Button("Clear Screen", systemImage: "eraser") { activeTerminal?.perform(.clearScreen) }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(activeTerminal == nil)
            Button("Search Scrollback…", systemImage: "magnifyingglass") { scrollbackSearch?.show() }
                .keyboardShortcut("f", modifiers: .command)
                .disabled(scrollbackSearch == nil)
            Divider()
            terminalButton("Jump to Previous Prompt", .jumpToPreviousPrompt, .upArrow)
            terminalButton("Jump to Next Prompt", .jumpToNextPrompt, .downArrow)
            Divider()
            terminalButton("Page Up", .scrollPageUp, .pageUp)
            terminalButton("Page Down", .scrollPageDown, .pageDown)
            terminalButton("Scroll to Top", .scrollToTop, .home)
            terminalButton("Scroll to Bottom", .scrollToBottom, .end)
        }
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

    private func terminalButton(_ title: String, _ action: TerminalAction,
                                _ key: KeyEquivalent) -> some View {
        Button(title) { activeTerminal?.perform(action) }
            .keyboardShortcut(key, modifiers: .command)
            .disabled(activeTerminal == nil)
    }

    /// ⌘N is the one a user expects; the other kinds stay in the menu without a shortcut.
    /// The optional-shortcut overload is what allows that, rather than a second Button branch.
    private func shortcut(for kind: SessionKind) -> KeyboardShortcut? {
        kind == .shell ? KeyboardShortcut("n", modifiers: .command) : nil
    }

    private var sessionTitles: [String] {
        Array((sessionSwitch?.titles ?? []).prefix(9))
    }

    private func shortcut(for index: Int) -> KeyEquivalent {
        KeyEquivalent(Character("\(index + 1)"))
    }
}
