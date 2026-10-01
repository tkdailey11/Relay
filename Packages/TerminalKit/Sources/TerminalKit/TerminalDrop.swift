import AppKit

/// Turns dragged pasteboard content into the text a terminal receives, the way Terminal and
/// Ghostty do: files become shell-escaped paths, so CLIs such as Copilot or Claude Code can pick
/// up a dropped screenshot by path.
@MainActor
enum TerminalDrop {
    static let acceptedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL, .URL, .string, .png, .tiff] + NSFilePromiseReceiver.readableDraggedTypes.map { .init($0) }

    /// Characters a POSIX shell would otherwise interpret inside an unquoted word.
    private static let specialCharacters = Set(" \t\n\\'\"`$!&*?;|<>()[]{}#~")

    static func escape(_ path: String) -> String {
        var escaped = ""
        for character in path {
            if specialCharacters.contains(character) { escaped.append("\\") }
            escaped.append(character)
        }
        return escaped
    }

    static func text(forFiles urls: [URL]) -> String {
        urls.map { escape($0.path) }.joined(separator: " ")
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    }

    /// Image data with no backing file, such as an image dragged out of a browser, is saved so
    /// the terminal can be handed a path to it.
    static func saveImage(from pasteboard: NSPasteboard) -> URL? {
        let data: Data
        if let png = pasteboard.data(forType: .png) {
            data = png
        } else if let tiff = pasteboard.data(forType: .tiff), let image = NSBitmapImageRep(data: tiff),
                  let png = image.representation(using: .png, properties: [:]) {
            data = png
        } else {
            return nil
        }
        guard let directory = try? makeDropDirectory() else { return nil }
        let url = directory.appending(path: "Dropped Image.png")
        do {
            try data.write(to: url)
            return url
        } catch {
            TerminalDiagnostics.error("Could not save dropped image: \(error.localizedDescription)")
            return nil
        }
    }

    /// A fresh directory per drop keeps promised files with the same name from colliding.
    static func makeDropDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "Relay Drops", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
