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
}
