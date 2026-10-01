import Foundation
import GhosttyKit
import Testing
@testable import TerminalKit

@MainActor
struct TerminalColorSchemeTests {
    @Test func hexRoundTripsAndRejectsGarbage() throws {
        let color = try #require(TerminalColor(hex: "#1a2B3c"))
        #expect(color == TerminalColor(red: 0x1A, green: 0x2B, blue: 0x3C))
        #expect(color.hex == "#1A2B3C")
        #expect(TerminalColor(hex: "1A2B3C") == color)
        #expect(TerminalColor(hex: "#12345") == nil)
        #expect(TerminalColor(hex: "zzzzzz") == nil)
        #expect(TerminalColor(redComponent: 2.0, greenComponent: -1, blueComponent: .nan) == TerminalColor(red: 255, green: 0, blue: 0))
    }

    @Test func aShortPaletteIsCompletedFromTheDefaults() throws {
        var scheme = TerminalColorScheme(name: "Short", background: .init(red: 0, green: 0, blue: 0),
                                         foreground: .init(red: 255, green: 255, blue: 255),
                                         palette: [.init(red: 1, green: 2, blue: 3)])
        #expect(scheme.palette.count == TerminalColorScheme.ansiColorCount)
        #expect(scheme.palette[0] == .init(red: 1, green: 2, blue: 3))
        #expect(scheme.palette[1] == TerminalColorScheme.defaultPalette[1])
        scheme.palette = []
        #expect(scheme.palette == TerminalColorScheme.defaultPalette)

        // A hand-edited file missing optional keys still decodes.
        let json = ##"{"id":"x","name":"Hand","background":"#000000","foreground":"#FFFFFF"}"##
        let decoded = try JSONDecoder().decode(TerminalColorScheme.self, from: Data(json.utf8))
        #expect(decoded.cursor == decoded.foreground)
        #expect(decoded.palette == TerminalColorScheme.defaultPalette)
        let reencoded = try JSONDecoder().decode(TerminalColorScheme.self, from: JSONEncoder().encode(decoded))
        #expect(reencoded == decoded)
    }

    /// The scheme has to survive libghostty's own parser, not just Relay's, or the terminal
    /// silently keeps its previous colors.
    @Test func libghosttyLoadsTheSchemeRelayWrites() throws {
        _ = ghostty_init(0, nil)
        var palette = TerminalColorScheme.defaultPalette
        palette[1] = TerminalColor(hex: "FF0000")!
        palette[15] = TerminalColor(hex: "ABCDEF")!
        let scheme = TerminalColorScheme(name: "Test", background: TerminalColor(hex: "102030")!,
                                         foreground: TerminalColor(hex: "C0D0E0")!, palette: palette)
        let config = try GhosttyRuntime.makeConfig(
            settings: TerminalSettings(lightColors: scheme, darkColors: scheme), command: nil)
        defer { ghostty_config_free(config) }

        var background = ghostty_config_color_s()
        #expect(ghostty_config_get(config, &background, "background", UInt("background".utf8.count)))
        #expect(TerminalColor(red: background.r, green: background.g, blue: background.b) == scheme.background)

        var loaded = ghostty_config_palette_s()
        #expect(ghostty_config_get(config, &loaded, "palette", UInt("palette".utf8.count)))
        let colors = withUnsafeBytes(of: loaded.colors) { raw in
            raw.bindMemory(to: ghostty_config_color_s.self).prefix(16).map {
                TerminalColor(red: $0.r, green: $0.g, blue: $0.b)
            }
        }
        #expect(colors == palette)
    }
}

@MainActor
struct TerminalColorSchemeCatalogTests {
    /// IDs are what preferences store, so a duplicate would make one scheme unselectable.
    @Test func builtInIDsAndNamesAreUnique() {
        let schemes = TerminalColorScheme.builtIn
        #expect(Set(schemes.map(\.id)).count == schemes.count)
        #expect(Set(schemes.map(\.name)).count == schemes.count)
        #expect(schemes.allSatisfy { $0.isBuiltIn })
    }

    @Test(arguments: TerminalColorScheme.catalog)
    func catalogSchemeLoadsInLibghostty(scheme: TerminalColorScheme) throws {
        _ = ghostty_init(0, nil)
        let config = try GhosttyRuntime.makeConfig(
            settings: TerminalSettings(lightColors: scheme, darkColors: scheme), command: nil)
        defer { ghostty_config_free(config) }
        var background = ghostty_config_color_s()
        #expect(ghostty_config_get(config, &background, "background", UInt("background".utf8.count)))
        #expect(TerminalColor(red: background.r, green: background.g, blue: background.b) == scheme.background)
    }
}
