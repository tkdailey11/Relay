import AppKit
import Foundation
import Testing
import TerminalKit
@testable import Relay

@MainActor
struct ColorSchemeImporterTests {
    private func iTermColor(_ red: Double, _ green: Double, _ blue: Double, space: String? = "sRGB") -> [String: Any] {
        var color: [String: Any] = ["Red Component": red, "Green Component": green,
                                    "Blue Component": blue, "Alpha Component": 1.0]
        color["Color Space"] = space
        return color
    }

    @Test func importsAnITermColorsFile() throws {
        let plist: [String: Any] = [
            "Background Color": iTermColor(0, 0, 0),
            "Foreground Color": iTermColor(1, 1, 1),
            "Selection Color": iTermColor(0, 0, 1),
            "Ansi 1 Color": iTermColor(1, 0, 0),
            // Older files carry no color space; they must still import, converted to sRGB.
            "Ansi 2 Color": iTermColor(0, 1, 0, space: nil),
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let scheme = try ColorSchemeImporter.parse(data, fileName: "Midnight.itermcolors")
        #expect(scheme.name == "Midnight")
        #expect(scheme.background == TerminalColor(hex: "000000"))
        #expect(scheme.foreground == TerminalColor(hex: "FFFFFF"))
        #expect(scheme.selectionBackground == TerminalColor(hex: "0000FF"))
        #expect(scheme.palette[1] == TerminalColor(hex: "FF0000"))
        #expect(scheme.palette[2].green > 200)
        // Colors the file leaves out take libghostty's.
        #expect(scheme.palette[4] == TerminalColorScheme.defaultPalette[4])
        #expect(scheme.cursor == scheme.foreground)
    }

    @Test func importsATerminalProfile() throws {
        func archived(_ hex: String) throws -> Data {
            let color = try #require(TerminalColor(hex: hex))
            let nsColor = NSColor(srgbRed: CGFloat(color.red) / 255, green: CGFloat(color.green) / 255,
                                  blue: CGFloat(color.blue) / 255, alpha: 1)
            return try NSKeyedArchiver.archivedData(withRootObject: nsColor, requiringSecureCoding: true)
        }
        let plist: [String: Any] = [
            "name": "Homebrew",
            "type": "Window Settings",
            "BackgroundColor": try archived("000000"),
            "TextColor": try archived("28FE14"),
            "ANSIBrightBlueColor": try archived("0A0AFF"),
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let scheme = try ColorSchemeImporter.parse(data, fileName: "Homebrew copy.terminal")
        #expect(scheme.name == "Homebrew")
        #expect(scheme.foreground == TerminalColor(hex: "28FE14"))
        #expect(scheme.palette[12] == TerminalColor(hex: "0A0AFF"))
    }

    @Test func importsAGhosttyTheme() throws {
        let text = """
            # Dracula
            palette = 0=#21222c
            palette =  9 = ff6e6e
            palette = 99=#ffffff
            background = #282a36
            foreground = f8f8f2
            cursor-color = "#f8f8f2"
            selection-background = #44475a
            font-family = Menlo
            """
        let scheme = try ColorSchemeImporter.parse(Data(text.utf8), fileName: "Dracula")
        #expect(scheme.name == "Dracula")
        #expect(scheme.background == TerminalColor(hex: "282A36"))
        #expect(scheme.foreground == TerminalColor(hex: "F8F8F2"))
        #expect(scheme.cursor == TerminalColor(hex: "F8F8F2"))
        #expect(scheme.selectionBackground == TerminalColor(hex: "44475A"))
        #expect(scheme.palette[0] == TerminalColor(hex: "21222C"))
        #expect(scheme.palette[9] == TerminalColor(hex: "FF6E6E"))
        #expect(scheme.palette.count == TerminalColorScheme.ansiColorCount)
    }

    @Test func rejectsFilesThatAreNotSchemes() {
        #expect(throws: ColorSchemeImporter.ImportError.noColors("notes.txt")) {
            try ColorSchemeImporter.parse(Data("just some notes".utf8), fileName: "notes.txt")
        }
        let plist = try! PropertyListSerialization.data(fromPropertyList: ["CFBundleName": "App"],
                                                        format: .xml, options: 0)
        #expect(throws: ColorSchemeImporter.ImportError.noColors("Info.plist")) {
            try ColorSchemeImporter.parse(plist, fileName: "Info.plist")
        }
        #expect(throws: ColorSchemeImporter.ImportError.noColors("image.png")) {
            try ColorSchemeImporter.parse(Data([0x89, 0x50, 0x4E, 0x47, 0xFF, 0xFE]), fileName: "image.png")
        }
    }
}
