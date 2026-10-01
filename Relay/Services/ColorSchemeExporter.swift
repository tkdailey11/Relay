import SwiftUI
import TerminalKit
import UniformTypeIdentifiers

/// Writes a scheme in a format another terminal reads, the reverse of `ColorSchemeImporter`.
/// iTerm2's format is the one most terminals and scheme collections accept; Ghostty's is what
/// Relay's terminals themselves run on.
enum ColorSchemeExporter {
    enum Format: CaseIterable {
        case iTerm
        case ghostty

        var title: String {
            switch self {
            case .iTerm: "iTerm2 Colors"
            case .ghostty: "Ghostty Theme"
            }
        }

        var contentType: UTType {
            switch self {
            case .iTerm: UTType(filenameExtension: "itermcolors", conformingTo: .propertyList) ?? .propertyList
            // Ghostty names a theme by its file name, so the file gets no extension.
            case .ghostty: .data
            }
        }
    }

    static func data(for scheme: TerminalColorScheme, as format: Format) throws -> Data {
        switch format {
        case .iTerm:
            var plist: [String: Any] = [
                "Background Color": iTermColor(scheme.background),
                "Foreground Color": iTermColor(scheme.foreground),
                "Bold Color": iTermColor(scheme.foreground),
                "Cursor Color": iTermColor(scheme.cursor),
                "Cursor Text Color": iTermColor(scheme.cursorText),
                "Selection Color": iTermColor(scheme.selectionBackground),
                "Selected Text Color": iTermColor(scheme.selectionForeground),
            ]
            for (index, color) in scheme.palette.enumerated() {
                plist["Ansi \(index) Color"] = iTermColor(color)
            }
            return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        case .ghostty:
            return Data(scheme.themeFileContents.utf8)
        }
    }

    /// Relay's colors are sRGB, so they are written as sRGB and read back without conversion.
    private static func iTermColor(_ color: TerminalColor) -> [String: Any] {
        ["Red Component": Double(color.red) / 255, "Green Component": Double(color.green) / 255,
         "Blue Component": Double(color.blue) / 255, "Alpha Component": 1.0, "Color Space": "sRGB"]
    }
}

/// The bytes of an exported scheme, in the shape `fileExporter` takes.
struct ColorSchemeFile: FileDocument {
    static let readableContentTypes: [UTType] = [.data]
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
