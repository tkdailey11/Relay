import TerminalKit
import Foundation
import Testing
@testable import Relay

@MainActor
struct TerminalSessionManagerTests {
    @Test func switchingReusesShellAndClosingReleasesIt() async throws {
        let manager = TerminalSessionManager()
        let first = Session(type: .shellPreset)
        let second = Session(type: .shellPreset)
        let directory = FileManager.default.temporaryDirectory.path
        await manager.prepare(first, type: .shellPreset, directory: directory)
        let original = try #require(manager.sessions[first.id])
        await manager.prepare(second, type: .shellPreset, directory: directory)
        await manager.prepare(first, type: .shellPreset, directory: directory)
        #expect(manager.sessions[first.id] === original)
        #expect(manager.sessions.count == 2)
        manager.close(first.id)
        #expect(original.status == .closed)
        #expect(manager.sessions[first.id] == nil)
        #expect(manager.sessions[second.id] != nil)
        manager.closeAll()
        #expect(manager.sessions.isEmpty)
    }

    @Test func removingAWorkspaceClosesOnlyItsTerminals() async throws {
        let store = WorkspaceStore(fileURL: nil)
        let directory = FileManager.default.temporaryDirectory
        store.addWorkspace(at: directory)
        let doomed = try #require(store.state.workspaces.first?.id)
        store.addWorkspace(at: directory.appending(path: "keep"))
        let survivor = try #require(store.state.workspaces.last?.id)
        store.addSession(.shellPreset, to: doomed)
        store.addSession(.shellPreset, to: survivor)
        let doomedSession = try #require(store.state.workspaces.first?.sessions.first)
        let survivingSession = try #require(store.state.workspaces.last?.sessions.first)
        await store.terminals.prepare(doomedSession, type: .shellPreset, directory: directory.path)
        await store.terminals.prepare(survivingSession, type: .shellPreset, directory: directory.path)
        let terminal = try #require(store.terminals.sessions[doomedSession.id])
        #expect(store.hasRunningProcesses(in: doomed) == false)

        store.removeWorkspace(doomed)
        #expect(terminal.status == .closed)
        #expect(store.terminals.sessions[doomedSession.id] == nil)
        #expect(store.terminals.sessions[survivingSession.id] != nil)
        #expect(store.hasRunningProcesses(in: doomed) == false)
        store.terminals.closeAll()
    }

    @Test func deletingMetadataClosesOnlyRemovedTerminals() async throws {
        let store = WorkspaceStore(fileURL: nil)
        store.addWorkspace(at: FileManager.default.temporaryDirectory)
        let workspaceID = try #require(store.state.workspaces.first?.id)
        store.addSession(.shellPreset, to: workspaceID)
        let workspaceSession = try #require(store.state.workspaces.first?.sessions.first)
        store.addTemporarySession(.shellPreset)
        let temporarySession = try #require(store.temporarySessions.first)
        await store.terminals.prepare(workspaceSession, type: .shellPreset, directory: FileManager.default.temporaryDirectory.path)
        await store.terminals.prepare(temporarySession, type: .shellPreset, directory: store.temporaryWorkingDirectory)
        let removed = try #require(store.terminals.sessions[workspaceSession.id])
        store.state.workspaces.removeAll()
        #expect(removed.status == .closed)
        #expect(store.terminals.sessions[temporarySession.id] != nil)
        store.temporarySessions.removeAll()
        #expect(store.terminals.sessions.isEmpty)
    }

    @Test func unavailableDirectoryReportsError() async {
        let manager = TerminalSessionManager()
        let shell = Session(type: .shellPreset)
        await manager.prepare(shell, type: .shellPreset, directory: "/nonexistent-relay-\(UUID().uuidString)")
        #expect(manager.sessions.isEmpty)
        #expect(manager.errors[shell.id] != nil)
        #expect(manager.status(for: shell) == "Failed")
        manager.close(shell.id)
        #expect(manager.errors.isEmpty)
    }

    @Test func agentSessionsLaunchTheirResolvedCommand() async throws {
        let manager = TerminalSessionManager { "/bin/echo \($0.name)" }
        for type in [SessionType.claudePreset, .copilotPreset] {
            let session = Session(type: type)
            await manager.prepare(session, type: type, directory: FileManager.default.temporaryDirectory.path)
            let terminal = try #require(manager.sessions[session.id])
            #expect(terminal.command == "/bin/echo \(type.name)")
            #expect(manager.errors[session.id] == nil)
        }
        manager.closeAll()
    }

    /// A session whose type was deleted in Settings stays on screen, but has nothing to start.
    @Test func aSessionWithNoTypeReportsThatInsteadOfLaunching() async {
        let manager = TerminalSessionManager { _ in "/bin/echo" }
        let session = Session(typeID: "removed", typeName: "Aider")
        await manager.prepare(session, type: nil, directory: FileManager.default.temporaryDirectory.path)
        #expect(manager.sessions[session.id] == nil)
        #expect(manager.errors[session.id]?.contains("Aider") == true)
        #expect(manager.status(for: session) == "Failed")
    }

    @Test func missingExecutableReportsErrorInsteadOfLaunching() async {
        struct Missing: LocalizedError {
            var errorDescription: String? { "No `copilot` here." }
            var recoverySuggestion: String? { "Install it." }
        }
        let manager = TerminalSessionManager { _ in throw Missing() }
        let session = Session(type: .copilotPreset)
        await manager.prepare(session, type: .copilotPreset, directory: FileManager.default.temporaryDirectory.path)
        #expect(manager.sessions[session.id] == nil)
        #expect(manager.status(for: session) == "Failed")
        #expect(manager.errors[session.id] == "No `copilot` here.\n\nInstall it.")
    }

    @Test func closingDuringResolutionNeverLeavesAProcessBehind() async {
        let manager = TerminalSessionManager { _ in
            try await Task.sleep(for: .milliseconds(20))
            return nil
        }
        let session = Session(type: .claudePreset)
        let prepare = Task { await manager.prepare(session, type: .claudePreset, directory: FileManager.default.temporaryDirectory.path) }
        // Close only once resolution is actually in flight, which is the race being covered.
        while manager.status(for: session) != "Starting" { await Task.yield() }
        manager.close(session.id)
        await prepare.value
        #expect(manager.sessions[session.id] == nil)
        #expect(manager.errors[session.id] == nil)
    }

    @Test func previewsNeverCreateShells() async {
        let manager = TerminalSessionManager(allowsLaunching: false)
        let shell = Session(type: .shellPreset)
        await manager.prepare(shell, type: .shellPreset, directory: FileManager.default.temporaryDirectory.path)
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
