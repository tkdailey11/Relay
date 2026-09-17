import AppKit
import GhosttyKit
import Observation

/// Owns a terminal independently of SwiftUI view lifetime. All C API details stay in TerminalKit.
@MainActor
@Observable
public final class TerminalSession {
    public private(set) var status: TerminalStatus = .starting
    public let workingDirectory: URL
    /// nil launches the user's login shell.
    public let command: String?
    @ObservationIgnored let terminalView: GhosttySurfaceView

    public init(workingDirectory: URL, command: String? = nil) throws {
        let directory = workingDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard directory.isFileURL,
              FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              FileManager.default.isReadableFile(atPath: directory.path) else {
            throw TerminalError.invalidDirectory(directory.path)
        }
        self.workingDirectory = directory
        self.command = command
        terminalView = GhosttySurfaceView(workingDirectory: directory, command: command)
        terminalView.session = self
    }

    public var requiresCloseConfirmation: Bool {
        guard let surface = terminalView.surface else { return false }
        return ghostty_surface_needs_confirm_quit(surface)
    }

    public func focus() {
        terminalView.window?.makeFirstResponder(terminalView)
    }

    /// Closing is explicit; navigating away only detaches the view, leaving its process alive.
    public func close() {
        terminalView.close()
        status = .closed
    }

    func updateStatus(_ status: TerminalStatus) {
        guard self.status != .closed else { return }
        self.status = status
    }

    isolated deinit {
        terminalView.close()
    }
}
