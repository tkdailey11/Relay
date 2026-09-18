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

    /// Returns false when libghostty declined the action, which is how a name that is no longer
    /// valid in a newer Ghostty shows up rather than as a menu item that quietly does nothing.
    @discardableResult
    public func perform(_ action: TerminalAction) -> Bool {
        let accepted = terminalView.perform(action)
        if !accepted {
            TerminalDiagnostics.error("libghostty rejected the binding action \(action.rawValue)")
        }
        return accepted
    }

    /// The whole screen, scrollback included. libghostty 1.2.3 exposes no search of its own and
    /// no way to select or scroll to a match, so Relay reads the text out and searches it.
    public var scrollbackText: String {
        terminalView.readText(tag: .screen)
    }

    /// Empty when nothing is selected.
    public var selectedText: String {
        terminalView.readSelection()
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
