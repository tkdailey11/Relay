import Foundation
import Testing
@testable import Relay

@MainActor
struct DiagnosticsTests {
    @Test func theBufferKeepsTheMostRecentEntriesAndDropsTheRest() {
        let log = DiagnosticLog(limit: 3)
        for index in 1...5 {
            log.record(category: .session, level: .info, message: "event \(index)")
        }
        #expect(log.entries.map(\.message) == ["event 3", "event 4", "event 5"])
        log.clear()
        #expect(log.entries.isEmpty)
    }

    @Test func theReportNamesTheBuildWorkspacesAndSessions() throws {
        let store = WorkspaceStore(fileURL: nil, terminalsEnabled: false)
        store.addWorkspace(at: URL(filePath: "/tmp/relay-diagnostics"))
        let workspace = try #require(store.state.workspaces.first)
        store.addSession(.claude, to: workspace.id)
        store.addTemporarySession(.shell)

        let log = DiagnosticLog()
        log.record(category: .session, level: .error, message: "Could not find `claude`")
        let report = DiagnosticsReport.make(store: store, log: log)

        #expect(report.contains("## Environment"))
        #expect(report.contains("- Relay: "))
        #expect(report.contains("- macOS: "))
        #expect(report.contains("/tmp/relay-diagnostics"))
        #expect(report.contains("Claude"))
        #expect(report.contains("Temporary sessions: 1"))
        // The events section is the half a bug report cannot reconstruct.
        #expect(report.contains("ERROR [session] Could not find `claude`"))
    }

    @Test func aReportWithNothingRecordedStillSaysSo() {
        let store = WorkspaceStore(fileURL: nil, terminalsEnabled: false)
        let report = DiagnosticsReport.make(store: store, log: DiagnosticLog())
        #expect(report.contains("(none recorded)"))
        #expect(report.contains("Workspaces: 0"))
    }

    @Test func failuresReachTheSharedLog() async throws {
        DiagnosticLog.shared.clear()
        let manager = TerminalSessionManager(resolveCommand: { _ in "/nonexistent/claude" })
        await manager.prepare(Session(kind: .claude), directory: "/nonexistent/directory")
        let messages = DiagnosticLog.shared.entries.map(\.message)
        #expect(messages.contains { $0.contains("Could not start Claude") })
        #expect(DiagnosticLog.shared.entries.contains { $0.level == .error })
    }
}
