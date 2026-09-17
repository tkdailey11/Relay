import Foundation
import Testing
@testable import Relay

struct SessionLauncherTests {
    private func defaults(_ overrides: [String: String]) -> UserDefaults {
        let suite = UserDefaults(suiteName: "SessionLauncherTests-\(UUID().uuidString)")!
        for (key, value) in overrides { suite.set(value, forKey: key) }
        return suite
    }

    @Test func shellLaunchesTheLoginShell() async throws {
        #expect(try await SessionLauncher.command(for: .shell, defaults: defaults([:])) == nil)
    }

    @Test func resolvesTheCommandToAnAbsolutePath() async throws {
        let command = try await SessionLauncher.command(for: .claude,
                                                        defaults: defaults(["RelayCommand.Claude": "echo"]))
        let executable = try #require(command?.split(separator: " ").first.map(String.init))
        #expect(executable.hasPrefix("/"))
        #expect(FileManager.default.isExecutableFile(atPath: executable))
    }

    @Test func keepsArgumentsAfterTheExecutable() async throws {
        let command = try await SessionLauncher.command(for: .copilot,
                                                        defaults: defaults(["RelayCommand.Copilot": "echo hello there"]))
        #expect(command?.hasSuffix(" hello there") == true)
    }

    @Test func anExplicitPathIsUsedAsWritten() async throws {
        let command = try await SessionLauncher.command(for: .claude,
                                                        defaults: defaults(["RelayCommand.Claude": "/bin/echo"]))
        #expect(command == "/bin/echo")
    }

    @Test func anEmptyOverrideFallsBackToTheLoginShell() async throws {
        #expect(try await SessionLauncher.command(for: .claude,
                                                  defaults: defaults(["RelayCommand.Claude": ""])) == nil)
    }

    @Test func aMissingExecutableIsReportedWithTheNameAndKind() async {
        let missing = "relay-not-installed-\(UUID().uuidString)"
        do {
            _ = try await SessionLauncher.command(for: .copilot, defaults: defaults(["RelayCommand.Copilot": missing]))
            Issue.record("Expected a missing-executable error")
        } catch let error as SessionLauncher.LaunchError {
            #expect(error.errorDescription?.contains(missing) == true)
            #expect(error.recoverySuggestion?.contains("Copilot") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func bothSpellingsOfTheCopilotCLIAreTried() async {
        // Neither is installed in CI, so the message has to name both to be actionable.
        do {
            _ = try await SessionLauncher.command(for: .copilot, defaults: defaults([:]))
        } catch let error as SessionLauncher.LaunchError {
            #expect(error.errorDescription?.contains("copilot") == true)
            #expect(error.errorDescription?.contains("gh") == true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
