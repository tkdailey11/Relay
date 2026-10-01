import AppKit
import Testing
@testable import TerminalKit

@MainActor
struct TerminalSessionTests {
    @Test func rejectsMissingDirectory() {
        let url = URL(filePath: "/nonexistent-relay-\(UUID().uuidString)")
        #expect(throws: TerminalError.invalidDirectory(url.path)) {
            try TerminalSession(workingDirectory: url)
        }
    }

    @Test func rejectsFileAsWorkingDirectory() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(throws: TerminalError.invalidDirectory(url.path)) {
            try TerminalSession(workingDirectory: url)
        }
    }

    @Test func closingBeforeAttachmentDoesNotStartAProcess() throws {
        let session = try TerminalSession(workingDirectory: FileManager.default.temporaryDirectory)
        #expect(session.status == .starting)
        #expect(session.terminalView.surface == nil)
        session.close()
        session.close()
        #expect(session.status == .closed)
        #expect(session.terminalView.surface == nil)
    }

    /// libghostty's `shell:` form launches a command through `exec -l`, whose dash-prefixed argv0
    /// a Node single-executable CLI such as Copilot rejects as a bad option.
    @Test func resolvedCommandsAreSpawnedDirectly() {
        #expect(GhosttyRuntime.commandValue(for: "/Users/me/.local/bin/copilot")
                == "direct:/Users/me/.local/bin/copilot")
        #expect(GhosttyRuntime.commandValue(for: "/opt/homebrew/bin/gh copilot")
                == "direct:/opt/homebrew/bin/gh copilot")
    }

    /// A quoted path is a command only a shell can parse, so it keeps the shell form.
    @Test func commandsNeedingAShellKeepTheShellForm() {
        #expect(GhosttyRuntime.commandValue(for: "\"/Users/me/My Tools/claude\"")
                == "shell:\"/Users/me/My Tools/claude\"")
    }
}
