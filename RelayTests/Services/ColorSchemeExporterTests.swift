import Foundation
import Testing
import TerminalKit
@testable import Relay

@MainActor
struct ColorSchemeExporterTests {
    private var scheme: TerminalColorScheme {
        var palette = TerminalColorScheme.defaultPalette
        palette[1] = TerminalColor(hex: "FF5555")!
        palette[14] = TerminalColor(hex: "8BE9FD")!
        return TerminalColorScheme(name: "Dracula", background: TerminalColor(hex: "282A36")!,
                                   foreground: TerminalColor(hex: "F8F8F2")!,
                                   cursor: TerminalColor(hex: "FF79C6")!, cursorText: TerminalColor(hex: "000000")!,
                                   selectionBackground: TerminalColor(hex: "44475A")!,
                                   selectionForeground: TerminalColor(hex: "FFFFFF")!, palette: palette)
    }

    /// An exported file is only useful if it reads back as the same colors, in Relay or elsewhere.
    @Test(arguments: ColorSchemeExporter.Format.allCases)
    func exportedSchemesImportUnchanged(format: ColorSchemeExporter.Format) throws {
        let original = scheme
        let data = try ColorSchemeExporter.data(for: original, as: format)
        var imported = try ColorSchemeImporter.parse(data, fileName: "Dracula.itermcolors")
        imported.id = original.id
        #expect(imported == original)
    }

    @Test func iTermExportUsesITermsKeys() throws {
        let data = try ColorSchemeExporter.data(for: scheme, as: .iTerm)
        let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let red = try #require(plist["Ansi 1 Color"] as? [String: Any])
        #expect(red["Color Space"] as? String == "sRGB")
        #expect(red["Red Component"] as? Double == 1.0)
        #expect(plist["Background Color"] != nil)
        #expect(plist["Ansi 15 Color"] != nil)
    }
}
