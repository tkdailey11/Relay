import Foundation
import Testing
@testable import Relay

struct SessionLauncherTests {
    private func type(named name: String, command: String) -> SessionType {
        SessionType(name: name, command: command, symbol: "bolt", color: .blue)
    }

    @Test func anEmptyCommandLaunchesTheLoginShell() async throws {
        #expect(try await SessionLauncher.command(for: .shellPreset) == nil)
        #expect(try await SessionLauncher.command(for: type(named: "Bare", command: "   ")) == nil)
    }

    @Test func resolvesTheCommandToAnAbsolutePath() async throws {
        let command = try await SessionLauncher.command(for: type(named: "Echo", command: "echo"))
        let executable = try #require(command?.split(separator: " ").first.map(String.init))
        #expect(executable.hasPrefix("/"))
        #expect(FileManager.default.isExecutableFile(atPath: executable))
    }

    @Test func keepsArgumentsAfterTheExecutable() async throws {
        let command = try await SessionLauncher.command(for: type(named: "Echo", command: "echo hello there"))
        #expect(command?.hasSuffix(" hello there") == true)
    }

    @Test func anExplicitPathIsUsedAsWritten() async throws {
        #expect(try await SessionLauncher.command(for: type(named: "Echo", command: "/bin/echo")) == "/bin/echo")
    }

    @Test func aMissingExecutableIsReportedWithTheNameAndType() async {
        let missing = "relay-not-installed-\(UUID().uuidString)"
        do {
            _ = try await SessionLauncher.command(for: type(named: "Aider", command: missing))
            Issue.record("Expected a missing-executable error")
        } catch let error as SessionLauncher.LaunchError {
            #expect(error.errorDescription?.contains(missing) == true)
            // The suggestion has to say where to fix it, now that commands are user editable.
            #expect(error.recoverySuggestion?.contains("Aider") == true)
            #expect(error.recoverySuggestion?.contains("Session Types") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    /// 0.1 tried `copilot` then `gh copilot` behind the user's back. That fallback is now a
    /// catalog entry a user picks, so both spellings still have to be reachable.
    @Test func bothSpellingsOfTheCopilotCLIAreOffered() {
        let commands = SessionType.catalog.map(\.command)
        #expect(commands.contains("copilot"))
        #expect(commands.contains("gh copilot"))
    }
}
