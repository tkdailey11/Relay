import Foundation

/// An opaque sRGB color, the form libghostty's configuration takes. Stored as `#RRGGBB` so a
/// saved scheme can be read and corrected by hand.
public struct TerminalColor: Hashable, Sendable, Codable, CustomStringConvertible {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Accepts `RRGGBB` with or without a leading `#`, as both Ghostty theme files and people
    /// write them.
    public init?(hex: String) {
        var digits = hex.trimmingCharacters(in: .whitespaces)
        if digits.hasPrefix("#") { digits.removeFirst() }
        guard digits.count == 6, digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
            return nil
        }
        self.init(red: UInt8(value >> 16 & 0xFF), green: UInt8(value >> 8 & 0xFF), blue: UInt8(value & 0xFF))
    }

    /// Components in 0...1, clamped, since color pickers and plist files can hand back values
    /// slightly outside the range.
    public init(redComponent red: Double, greenComponent green: Double, blueComponent blue: Double) {
        func byte(_ component: Double) -> UInt8 {
            guard component.isFinite else { return 0 }
            return UInt8((min(max(component, 0), 1) * 255).rounded())
        }
        self.init(red: byte(red), green: byte(green), blue: byte(blue))
    }

    public var hex: String {
        String(format: "#%02X%02X%02X", red, green, blue)
    }

    public var description: String { hex }

    /// Relative luminance, enough to tell a light background from a dark one.
    public var luminance: Double {
        func linear(_ component: UInt8) -> Double {
            let value = Double(component) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let color = TerminalColor(hex: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "\(string) is not a #RRGGBB color")
        }
        self = color
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(hex)
    }
}

/// The colors a terminal draws with: the cell background and foreground, the cursor, the
/// selection, and the sixteen ANSI colors programs address by number.
public struct TerminalColorScheme: Identifiable, Hashable, Sendable, Codable {
    public static let ansiColorCount = 16

    public var id: String
    public var name: String
    public var background: TerminalColor
    public var foreground: TerminalColor
    public var cursor: TerminalColor
    public var cursorText: TerminalColor
    public var selectionBackground: TerminalColor
    public var selectionForeground: TerminalColor
    /// Black, red, green, yellow, blue, magenta, cyan and white, then their bright variants.
    public var palette: [TerminalColor] {
        didSet { palette = Self.complete(palette) }
    }

    public init(id: String = UUID().uuidString, name: String,
                background: TerminalColor, foreground: TerminalColor,
                cursor: TerminalColor? = nil, cursorText: TerminalColor? = nil,
                selectionBackground: TerminalColor? = nil, selectionForeground: TerminalColor? = nil,
                palette: [TerminalColor] = TerminalColorScheme.defaultPalette) {
        self.id = id
        self.name = name
        self.background = background
        self.foreground = foreground
        // Without their own values these follow libghostty: a cursor in the text color, and a
        // selection that inverts the cell.
        self.cursor = cursor ?? foreground
        self.cursorText = cursorText ?? background
        self.selectionBackground = selectionBackground ?? foreground
        self.selectionForeground = selectionForeground ?? background
        self.palette = Self.complete(palette)
    }

    public var isBuiltIn: Bool {
        Self.builtIn.contains { $0.id == id }
    }

    /// Whether this scheme reads as dark, for anything drawn around the terminal.
    public var isDark: Bool {
        background.luminance < 0.4
    }

    /// A short list from a file or a hand edit would otherwise index out of range, so missing
    /// entries take libghostty's defaults and extras are dropped.
    private static func complete(_ palette: [TerminalColor]) -> [TerminalColor] {
        guard palette.count != ansiColorCount else { return palette }
        return Array((palette + defaultPalette.dropFirst(palette.count)).prefix(ansiColorCount))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: container.decode(String.self, forKey: .id),
                      name: container.decode(String.self, forKey: .name),
                      background: container.decode(TerminalColor.self, forKey: .background),
                      foreground: container.decode(TerminalColor.self, forKey: .foreground),
                      cursor: container.decodeIfPresent(TerminalColor.self, forKey: .cursor),
                      cursorText: container.decodeIfPresent(TerminalColor.self, forKey: .cursorText),
                      selectionBackground: container.decodeIfPresent(TerminalColor.self, forKey: .selectionBackground),
                      selectionForeground: container.decodeIfPresent(TerminalColor.self, forKey: .selectionForeground),
                      palette: container.decodeIfPresent([TerminalColor].self, forKey: .palette) ?? Self.defaultPalette)
    }

    /// The scheme as a Ghostty theme file.
    public var themeFileContents: String {
        var lines = [
            "background = \(background.hex)",
            "foreground = \(foreground.hex)",
            "cursor-color = \(cursor.hex)",
            "cursor-text = \(cursorText.hex)",
            "selection-background = \(selectionBackground.hex)",
            "selection-foreground = \(selectionForeground.hex)",
        ]
        for (index, color) in palette.enumerated() {
            lines.append("palette = \(index)=\(color.hex)")
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

extension TerminalColorScheme {
    /// libghostty's own ANSI colors (Tomorrow Night), which Relay's terminals have always used.
    public static let defaultPalette: [TerminalColor] = [
        "1D1F21", "CC6666", "B5BD68", "F0C674", "81A2BE", "B294BB", "8ABEB7", "C5C8C6",
        "666666", "D54E53", "B9CA4A", "E7C547", "7AA6DA", "C397D8", "70C0B1", "EAEAEA",
    ].map { TerminalColor(hex: $0)! }

    public static let relayDark = TerminalColorScheme(
        id: "relay.dark", name: "Relay Dark",
        background: TerminalColor(hex: "111827")!, foreground: TerminalColor(hex: "E5E7EB")!,
        cursor: TerminalColor(hex: "E5E7EB")!,
        selectionBackground: TerminalColor(hex: "334155")!, selectionForeground: TerminalColor(hex: "F8FAFC")!)

    public static let relayLight = TerminalColorScheme(
        id: "relay.light", name: "Relay Light",
        background: TerminalColor(hex: "F8FAFC")!, foreground: TerminalColor(hex: "111827")!,
        cursor: TerminalColor(hex: "111827")!,
        selectionBackground: TerminalColor(hex: "BFDBFE")!, selectionForeground: TerminalColor(hex: "111827")!)

    public static let builtIn: [TerminalColorScheme] = [relayLight, relayDark]
}
