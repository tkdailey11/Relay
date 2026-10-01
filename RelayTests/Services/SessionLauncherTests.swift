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

    /// The words after the `env PATH=…` prefix that every resolved command carries.
    private func launchedWords(_ command: String?) throws -> [String] {
        let command = try #require(command)
        let prefix = "/usr/bin/env PATH='"
        #expect(command.hasPrefix(prefix))
        // PATH directories can contain spaces, so the quoted value ends at its closing quote.
        let end = try #require(command.range(of: "' ", range: command.index(command.startIndex, offsetBy: prefix.count)..<command.endIndex))
        return command[end.upperBound...].split(separator: " ").map(String.init)
    }

    @Test func resolvesTheCommandToAnAbsolutePath() async throws {
        let command = try await SessionLauncher.command(for: type(named: "Echo", command: "echo"))
        let executable = try #require(try launchedWords(command).first)
        #expect(executable.hasPrefix("/"))
        #expect(FileManager.default.isExecutableFile(atPath: executable))
    }

    @Test func keepsArgumentsAfterTheExecutable() async throws {
        let command = try await SessionLauncher.command(for: type(named: "Echo", command: "echo hello there"))
        #expect(command?.hasSuffix(" hello there") == true)
    }

    @Test func anExplicitPathIsUsedAsWritten() async throws {
        let command = try await SessionLauncher.command(for: type(named: "Echo", command: "/bin/echo"))
        #expect(try launchedWords(command) == ["/bin/echo"])
    }

    /// Node-script CLIs under nvm find `node` through PATH, not through Relay's own environment.
    @Test func theCommandRunsWithTheExecutablesDirectoryFirstOnPath() async throws {
        let command = try await SessionLauncher.command(for: type(named: "Echo", command: "/bin/echo"))
        #expect(command?.hasPrefix("/usr/bin/env PATH='/bin:") == true)
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
