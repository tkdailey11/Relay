import Foundation
import Observation
import TerminalKit

/// Relay's preferences, kept in UserDefaults so they survive a relaunch and can be corrected
/// from the command line if a value ever makes the app unusable. Color schemes are JSON under
/// `RelayTerminal.ColorSchemes`.
///
/// Session types, including the command each one runs, live in `SessionTypeStore`.
@MainActor
@Observable
final class SettingsStore {
    static let fontFamilyKey = "RelayTerminal.FontFamily"
    static let fontSizeKey = "RelayTerminal.FontSize"
    static let colorSchemesKey = "RelayTerminal.ColorSchemes"
    static let lightColorSchemeKey = "RelayTerminal.LightColorScheme"
    static let darkColorSchemeKey = "RelayTerminal.DarkColorScheme"

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

    /// Schemes the user imported or made. The built-in ones are not stored, so they can never be
    /// lost or edited out from under the default.
    private(set) var customColorSchemes: [TerminalColorScheme] {
        didSet {
            guard customColorSchemes != oldValue else { return }
            saveColorSchemes()
            applyTerminalSettings()
        }
    }

    /// Which scheme terminals use in each system appearance. An ID that names no scheme, such
    /// as one left behind by a deleted scheme, falls back to Relay's own.
    var lightColorSchemeID: String {
        didSet {
            guard lightColorSchemeID != oldValue else { return }
            defaults.set(lightColorSchemeID, forKey: Self.lightColorSchemeKey)
            applyTerminalSettings()
        }
    }

    var darkColorSchemeID: String {
        didSet {
            guard darkColorSchemeID != oldValue else { return }
            defaults.set(darkColorSchemeID, forKey: Self.darkColorSchemeKey)
            applyTerminalSettings()
        }
    }

    var errorMessage: String?

    init(defaults: UserDefaults = .standard,
         apply: @escaping @MainActor (TerminalSettings) -> Void = { Terminal.settings = $0 }) {
        self.defaults = defaults
        self.apply = apply
        let stored = defaults.object(forKey: Self.fontSizeKey) as? Double
        self.fontSize = stored ?? TerminalSettings.default.fontSize
        self.fontFamily = defaults.string(forKey: Self.fontFamilyKey) ?? ""
        self.customColorSchemes = Self.storedColorSchemes(in: defaults)
        self.lightColorSchemeID = defaults.string(forKey: Self.lightColorSchemeKey) ?? TerminalColorScheme.relayLight.id
        self.darkColorSchemeID = defaults.string(forKey: Self.darkColorSchemeKey) ?? TerminalColorScheme.relayDark.id
        // Terminals are created from these, so they are in force before the first one starts.
        applyTerminalSettings()
    }

    var terminalSettings: TerminalSettings {
        TerminalSettings(fontFamily: fontFamily.isEmpty ? nil : fontFamily, fontSize: fontSize,
                         lightColors: lightColors, darkColors: darkColors).sanitized
    }

    // MARK: - Color schemes

    var colorSchemes: [TerminalColorScheme] {
        TerminalColorScheme.builtIn + customColorSchemes
    }

    func colorScheme(id: String) -> TerminalColorScheme? {
        colorSchemes.first { $0.id == id }
    }

    var lightColors: TerminalColorScheme {
        colorScheme(id: lightColorSchemeID) ?? .relayLight
    }

    var darkColors: TerminalColorScheme {
        colorScheme(id: darkColorSchemeID) ?? .relayDark
    }

    /// The colors terminals are drawing with in the given appearance.
    func colors(isDark: Bool) -> TerminalColorScheme {
        isDark ? darkColors : lightColors
    }

    func addColorScheme(_ scheme: TerminalColorScheme) {
        var scheme = scheme
        if colorScheme(id: scheme.id) != nil { scheme.id = UUID().uuidString }
        customColorSchemes.append(scheme)
        RelayLog.info(.app, "Added color scheme \(scheme.name)")
    }

    /// Built-in schemes are fixed; a user changes a copy of one instead.
    func updateColorScheme(_ scheme: TerminalColorScheme) {
        guard let index = customColorSchemes.firstIndex(where: { $0.id == scheme.id }) else { return }
        customColorSchemes[index] = scheme
    }

    func removeColorScheme(id: String) {
        guard let scheme = customColorSchemes.first(where: { $0.id == id }) else { return }
        customColorSchemes.removeAll { $0.id == id }
        if lightColorSchemeID == id { lightColorSchemeID = TerminalColorScheme.relayLight.id }
        if darkColorSchemeID == id { darkColorSchemeID = TerminalColorScheme.relayDark.id }
        RelayLog.info(.app, "Removed color scheme \(scheme.name)")
    }

    /// A new, editable scheme with the same colors.
    func duplicateColorScheme(_ scheme: TerminalColorScheme) -> TerminalColorScheme {
        var copy = scheme
        copy.id = UUID().uuidString
        copy.name = "\(scheme.name) Copy"
        addColorScheme(copy)
        return copy
    }

    /// Imports every file it can and reports the ones it couldn't together, so one bad file in
    /// a multiple selection doesn't cost the rest.
    @discardableResult
    func importColorSchemes(from urls: [URL]) -> [TerminalColorScheme] {
        var imported: [TerminalColorScheme] = []
        var failures: [String] = []
        for url in urls {
            do {
                let scheme = try ColorSchemeImporter.load(from: url)
                addColorScheme(scheme)
                imported.append(scheme)
            } catch {
                RelayLog.error(.app, "Could not import color scheme \(url.lastPathComponent): \(error)")
                failures.append(error.localizedDescription)
            }
        }
        errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
        return imported
    }

    func restoreDefaultColorSchemes() {
        lightColorSchemeID = TerminalColorScheme.relayLight.id
        darkColorSchemeID = TerminalColorScheme.relayDark.id
    }

    private static func storedColorSchemes(in defaults: UserDefaults) -> [TerminalColorScheme] {
        guard let data = defaults.data(forKey: colorSchemesKey) else { return [] }
        do {
            return try JSONDecoder().decode([TerminalColorScheme].self, from: data)
        } catch {
            // Terminals still need colors; Relay's own are always there to fall back on.
            RelayLog.error(.app, "Could not decode color schemes, ignoring them: \(error)")
            return []
        }
    }

    private func saveColorSchemes() {
        do {
            defaults.set(try JSONEncoder().encode(customColorSchemes), forKey: Self.colorSchemesKey)
        } catch {
            RelayLog.error(.app, "Could not save color schemes: \(error)")
            errorMessage = "Relay couldn’t save your color schemes. \(error.localizedDescription)"
        }
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
        RelayLog.info(.app, "Terminal settings: \(fontFamily.isEmpty ? "default font" : fontFamily) at \(Int(terminalSettings.fontSize))pt, colors \(lightColors.name) / \(darkColors.name)")
    }
}
