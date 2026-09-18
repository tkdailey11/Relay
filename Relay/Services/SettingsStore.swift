import Foundation
import Observation
import TerminalKit

/// Relay's preferences, kept in UserDefaults so they survive a relaunch and can be corrected
/// from the command line if a value ever makes the app unusable.
///
/// Session types, including the command each one runs, live in `SessionTypeStore`.
@MainActor
@Observable
final class SettingsStore {
    static let fontFamilyKey = "RelayTerminal.FontFamily"
    static let fontSizeKey = "RelayTerminal.FontSize"

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

    init(defaults: UserDefaults = .standard,
         apply: @escaping @MainActor (TerminalSettings) -> Void = { Terminal.settings = $0 }) {
        self.defaults = defaults
        self.apply = apply
        let stored = defaults.object(forKey: Self.fontSizeKey) as? Double
        self.fontSize = stored ?? TerminalSettings.default.fontSize
        self.fontFamily = defaults.string(forKey: Self.fontFamilyKey) ?? ""
        // Terminals are created from these, so they are in force before the first one starts.
        applyTerminalSettings()
    }

    var terminalSettings: TerminalSettings {
        TerminalSettings(fontFamily: fontFamily.isEmpty ? nil : fontFamily, fontSize: fontSize).sanitized
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
