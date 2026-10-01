import AppKit
import TerminalKit

/// Reads the color scheme files other terminals save, so a user can bring the colors they
/// already have rather than rebuilding them by hand:
///
/// - iTerm2's `.itermcolors`, a property list of color component dictionaries.
/// - Terminal.app's `.terminal`, a property list of archived `NSColor`s.
/// - Ghostty's theme files, `key = value` text, which most published schemes are also shipped as.
///
/// The format is recognized from the contents, not the extension, since Ghostty themes have none.
/// Anything a file leaves out takes the value libghostty would use.
enum ColorSchemeImporter {
    enum ImportError: LocalizedError, Equatable {
        case unreadable(String)
        case noColors(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let file): "Relay couldn’t read “\(file)”."
            case .noColors(let file): "“\(file)” isn’t an iTerm2, Terminal or Ghostty color scheme."
            }
        }
    }

    static func load(from url: URL) throws -> TerminalColorScheme {
        // Files chosen in an open panel are only readable inside this scope when sandboxed.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportError.unreadable(url.lastPathComponent)
        }
        return try parse(data, fileName: url.lastPathComponent)
    }

    static func parse(_ data: Data, fileName: String) throws -> TerminalColorScheme {
        let name = (fileName as NSString).deletingPathExtension
        let scheme: TerminalColorScheme?
        if let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
            scheme = iTerm(plist, name: name) ?? terminal(plist, name: name)
        } else if let text = String(data: data, encoding: .utf8) {
            scheme = ghostty(text, name: name)
        } else {
            scheme = nil
        }
        guard let scheme else { throw ImportError.noColors(fileName) }
        return scheme
    }

    // MARK: - Formats

    private static let iTermPaletteKeys = (0..<TerminalColorScheme.ansiColorCount).map { "Ansi \($0) Color" }

    private static func iTerm(_ plist: [String: Any], name: String) -> TerminalColorScheme? {
        func color(_ key: String) -> TerminalColor? {
            (plist[key] as? [String: Any]).flatMap { iTermColor($0) }
        }
        return scheme(named: name,
                      background: color("Background Color"), foreground: color("Foreground Color"),
                      cursor: color("Cursor Color"), cursorText: color("Cursor Text Color"),
                      selectionBackground: color("Selection Color"),
                      selectionForeground: color("Selected Text Color"),
                      palette: iTermPaletteKeys.map(color))
    }

    /// iTerm2 writes components as reals with the space they were picked in. Files from before
    /// it recorded a space are calibrated (generic) RGB.
    private static func iTermColor(_ dictionary: [String: Any]) -> TerminalColor? {
        func component(_ key: String) -> CGFloat? {
            (dictionary[key] as? NSNumber).map { CGFloat($0.doubleValue) }
        }
        guard let red = component("Red Component"), let green = component("Green Component"),
              let blue = component("Blue Component") else { return nil }
        let color: NSColor = switch dictionary["Color Space"] as? String {
        case "sRGB": NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
        case "P3": NSColor(displayP3Red: red, green: green, blue: blue, alpha: 1)
        default: NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
        }
        return TerminalColor(color)
    }

    private static let terminalPaletteKeys: [String] = {
        let names = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]
        return names.map { "ANSI\($0)Color" } + names.map { "ANSIBright\($0)Color" }
    }()

    private static func terminal(_ plist: [String: Any], name: String) -> TerminalColorScheme? {
        func color(_ key: String) -> TerminalColor? {
            guard let data = plist[key] as? Data,
                  let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
                return nil
            }
            return TerminalColor(color)
        }
        let selection = color("SelectionColor")
        return scheme(named: plist["name"] as? String ?? name,
                      background: color("BackgroundColor"), foreground: color("TextColor"),
                      cursor: color("CursorColor"), cursorText: nil,
                      // Terminal keeps the text color over a selection.
                      selectionBackground: selection, selectionForeground: selection == nil ? nil : color("TextColor"),
                      palette: terminalPaletteKeys.map(color))
    }

    private static func ghostty(_ text: String, name: String) -> TerminalColorScheme? {
        var values: [String: TerminalColor] = [:]
        var palette = [TerminalColor?](repeating: nil, count: TerminalColorScheme.ansiColorCount)
        for line in text.split(whereSeparator: \.isNewline) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix("#"), let separator = line.firstIndex(of: "=") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces)
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            if key == "palette" {
                // `palette = 4=#81a2be`
                let parts = value.split(separator: "=", maxSplits: 1)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                guard parts.count == 2, let index = Int(parts[0]), palette.indices.contains(index) else { continue }
                palette[index] = TerminalColor(hex: parts[1])
            } else if let color = TerminalColor(hex: value) {
                values[key] = color
            }
        }
        return scheme(named: name,
                      background: values["background"], foreground: values["foreground"],
                      cursor: values["cursor-color"], cursorText: values["cursor-text"],
                      selectionBackground: values["selection-background"],
                      selectionForeground: values["selection-foreground"],
                      palette: palette)
    }

    /// nil when the file named none of the colors Relay knows, which is what tells one format
    /// from another, and a stray property list or text file from a scheme.
    private static func scheme(named name: String, background: TerminalColor?, foreground: TerminalColor?,
                               cursor: TerminalColor?, cursorText: TerminalColor?,
                               selectionBackground: TerminalColor?, selectionForeground: TerminalColor?,
                               palette: [TerminalColor?]) -> TerminalColorScheme? {
        let found = [background, foreground, cursor, cursorText, selectionBackground, selectionForeground] + palette
        guard found.contains(where: { $0 != nil }) else { return nil }
        let fallback = TerminalColorScheme.relayDark
        return TerminalColorScheme(
            name: name.isEmpty ? "Imported" : name,
            background: background ?? fallback.background, foreground: foreground ?? fallback.foreground,
            cursor: cursor, cursorText: cursorText,
            selectionBackground: selectionBackground, selectionForeground: selectionForeground,
            palette: palette.enumerated().map { $1 ?? TerminalColorScheme.defaultPalette[$0] })
    }
}

extension TerminalColor {
    /// libghostty draws in sRGB, so a color from any other space is converted first.
    init?(_ color: NSColor) {
        guard let srgb = color.usingColorSpace(.sRGB) else { return nil }
        self.init(redComponent: srgb.redComponent, greenComponent: srgb.greenComponent,
                  blueComponent: srgb.blueComponent)
    }
}
