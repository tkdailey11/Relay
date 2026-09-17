import TerminalKit
import Foundation
import Testing
@testable import Relay

@MainActor
struct TerminalSessionManagerTests {
    @Test func switchingReusesShellAndClosingReleasesIt() async throws {
        let manager = TerminalSessionManager()
        let first = Session(kind: .shell)
        let second = Session(kind: .shell)
        let directory = FileManager.default.temporaryDirectory.path
        await manager.prepare(first, directory: directory)
        let original = try #require(manager.sessions[first.id])
        await manager.prepare(second, directory: directory)
        await manager.prepare(first, directory: directory)
        #expect(manager.sessions[first.id] === original)
        #expect(manager.sessions.count == 2)
        manager.close(first.id)
        #expect(original.status == .closed)
        #expect(manager.sessions[first.id] == nil)
        #expect(manager.sessions[second.id] != nil)
        manager.closeAll()
        #expect(manager.sessions.isEmpty)
    }

    @Test func deletingMetadataClosesOnlyRemovedTerminals() async throws {
        let store = WorkspaceStore(fileURL: nil)
        store.addWorkspace(at: FileManager.default.temporaryDirectory)
        let workspaceID = try #require(store.state.workspaces.first?.id)
        store.addSession(.shell, to: workspaceID)
        let workspaceSession = try #require(store.state.workspaces.first?.sessions.first)
        store.addTemporarySession(.shell)
        let temporarySession = try #require(store.temporarySessions.first)
        await store.terminals.prepare(workspaceSession, directory: FileManager.default.temporaryDirectory.path)
        await store.terminals.prepare(temporarySession, directory: store.temporaryWorkingDirectory)
        let removed = try #require(store.terminals.sessions[workspaceSession.id])
        store.state.workspaces.removeAll()
        #expect(removed.status == .closed)
        #expect(store.terminals.sessions[temporarySession.id] != nil)
        store.temporarySessions.removeAll()
        #expect(store.terminals.sessions.isEmpty)
    }

    @Test func unavailableDirectoryReportsError() async {
        let manager = TerminalSessionManager()
        let shell = Session(kind: .shell)
        await manager.prepare(shell, directory: "/nonexistent-relay-\(UUID().uuidString)")
        #expect(manager.sessions.isEmpty)
        #expect(manager.errors[shell.id] != nil)
        #expect(manager.status(for: shell) == "Failed")
        manager.close(shell.id)
        #expect(manager.errors.isEmpty)
    }

    @Test func agentSessionsLaunchTheirResolvedCommand() async throws {
        let manager = TerminalSessionManager { "/bin/echo \($0.rawValue)" }
        for kind in [SessionKind.claude, .copilot] {
            let session = Session(kind: kind)
            await manager.prepare(session, directory: FileManager.default.temporaryDirectory.path)
            let terminal = try #require(manager.sessions[session.id])
            #expect(terminal.command == "/bin/echo \(kind.rawValue)")
            #expect(manager.errors[session.id] == nil)
        }
        manager.closeAll()
    }

    @Test func missingExecutableReportsErrorInsteadOfLaunching() async {
        struct Missing: LocalizedError {
            var errorDescription: String? { "No `copilot` here." }
            var recoverySuggestion: String? { "Install it." }
        }
        let manager = TerminalSessionManager { _ in throw Missing() }
        let session = Session(kind: .copilot)
        await manager.prepare(session, directory: FileManager.default.temporaryDirectory.path)
        #expect(manager.sessions[session.id] == nil)
        #expect(manager.status(for: session) == "Failed")
        #expect(manager.errors[session.id] == "No `copilot` here.\n\nInstall it.")
    }

    @Test func closingDuringResolutionNeverLeavesAProcessBehind() async {
        let manager = TerminalSessionManager { _ in
            try await Task.sleep(for: .milliseconds(20))
            return nil
        }
        let session = Session(kind: .claude)
        let prepare = Task { await manager.prepare(session, directory: FileManager.default.temporaryDirectory.path) }
        // Close only once resolution is actually in flight, which is the race being covered.
        while manager.status(for: session) != "Starting" { await Task.yield() }
        manager.close(session.id)
        await prepare.value
        #expect(manager.sessions[session.id] == nil)
        #expect(manager.errors[session.id] == nil)
    }

    @Test func previewsNeverCreateShells() async {
        let manager = TerminalSessionManager(allowsLaunching: false)
        let shell = Session(kind: .shell)
        await manager.prepare(shell, directory: FileManager.default.temporaryDirectory.path)
        #expect(manager.sessions.isEmpty)
        #expect(manager.status(for: shell) == "Preview")
    }

    @Test func migratesSandboxSnapshotWithoutChangingOriginal() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let oldURL = root.appending(path: "sandbox/workspaces.json")
        let newURL = root.appending(path: "application-support/workspaces.json")
        let oldStore = WorkspaceStore(fileURL: oldURL)
        oldStore.addWorkspace(at: root)
        let original = try Data(contentsOf: oldURL)
        let migrated = WorkspaceStore(fileURL: newURL, migrationSource: oldURL)
        #expect(migrated.state == oldStore.state)
        #expect(try Data(contentsOf: oldURL) == original)
        #expect(WorkspaceStore(fileURL: newURL).state == oldStore.state)
        migrated.state.workspaces.removeAll()
        #expect(WorkspaceStore(fileURL: newURL, migrationSource: oldURL).state.workspaces.isEmpty)
    }
}
