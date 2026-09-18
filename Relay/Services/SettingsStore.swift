import Foundation
import Observation
import TerminalKit

/// Relay's preferences, kept in UserDefaults so they survive a relaunch and can be corrected
/// from the command line if a value ever makes the app unusable.
///
/// The command overrides deliberately read and write the same `RelayCommand.<Kind>` keys
/// `SessionLauncher` already consults, so Settings is a front end for a mechanism that exists
/// rather than a second one beside it.
@MainActor
@Observable
final class SettingsStore {
    static let fontFamilyKey = "RelayTerminal.FontFamily"
    static let fontSizeKey = "RelayTerminal.FontSize"

    static func commandKey(for kind: SessionKind) -> String { "RelayCommand.\(kind.rawValue)" }

    private let defaults: UserDefaults
    /// Applying settings touches libghostty, which the preview and test stores must not do.
    private let apply: @MainActor (TerminalSettings) -> Void

    var fontSize: Double {
        didSet {
            guard fontSize != oldValue else { return }
            defaults.set(fontSize, forKey: Self.fontSizeKey)
            applyTerminalSettings()
        }
    }

    /// An empty string means libghostty's default face.
    var fontFamily: String {
        didSet {
            guard fontFamily != oldValue else { return }
            if fontFamily.isEmpty {
                defaults.removeObject(forKey: Self.fontFamilyKey)
            } else {
                defaults.set(fontFamily, forKey: Self.fontFamilyKey)
            }
            applyTerminalSettings()
        }
    }

    var commands: [SessionKind: String] {
        didSet {
            guard commands != oldValue else { return }
            for kind in SessionKind.allCases {
                let value = commands[kind]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                // Absent and empty mean different things: absent restores Relay's own default,
                // empty means "launch the login shell".
                if value == Self.unset {
                    defaults.removeObject(forKey: Self.commandKey(for: kind))
                } else {
                    defaults.set(value, forKey: Self.commandKey(for: kind))
                }
            }
        }
    }

    /// Distinguishes "no override" from an override of the empty string, which is meaningful.
    static let unset = "\u{0}unset"

    init(defaults: UserDefaults = .standard,
         apply: @escaping @MainActor (TerminalSettings) -> Void = { Terminal.settings = $0 }) {
        self.defaults = defaults
        self.apply = apply
        let stored = defaults.object(forKey: Self.fontSizeKey) as? Double
        self.fontSize = stored ?? TerminalSettings.default.fontSize
        self.fontFamily = defaults.string(forKey: Self.fontFamilyKey) ?? ""
        self.commands = Dictionary(uniqueKeysWithValues: SessionKind.allCases.map { kind in
            (kind, defaults.string(forKey: Self.commandKey(for: kind)) ?? Self.unset)
        })
        // Terminals are created from these, so they are in force before the first one starts.
        applyTerminalSettings()
    }

    var terminalSettings: TerminalSettings {
        TerminalSettings(fontFamily: fontFamily.isEmpty ? nil : fontFamily, fontSize: fontSize).sanitized
    }

    func command(for kind: SessionKind) -> String {
        commands[kind] == Self.unset ? "" : (commands[kind] ?? "")
    }

    func setCommand(_ value: String, for kind: SessionKind) {
        commands[kind] = value
    }

    func hasOverride(for kind: SessionKind) -> Bool {
        commands[kind] != Self.unset
    }

    func clearOverride(for kind: SessionKind) {
        commands[kind] = Self.unset
    }

    /// ⌘+ and ⌘− move the preference rather than libghostty's own per-surface size, so every
    /// terminal agrees with Settings and the change outlives the session.
    func adjustFontSize(by delta: Double) {
        fontSize = TerminalSettings(fontSize: fontSize + delta).sanitized.fontSize
    }

    func resetFontSize() {
        fontSize = TerminalSettings.default.fontSize
    }

    private func applyTerminalSettings() {
        apply(terminalSettings)
        RelayLog.info(.app, "Terminal settings: \(fontFamily.isEmpty ? "default font" : fontFamily) at \(Int(terminalSettings.fontSize))pt")
    }
}
