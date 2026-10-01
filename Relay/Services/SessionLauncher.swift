import Foundation

/// Maps a session type to the command line that starts it.
///
/// Relay is launched by the Finder, so its environment carries launchd's minimal PATH rather than
/// the user's. The CLIs these launchers depend on almost always live somewhere only the login
/// shell knows about, so each command's executable is resolved to an absolute path before the
/// terminal spawns it, which is also what lets a missing CLI be reported as an error instead of a
/// shell that flashes and exits.
enum SessionLauncher {
    /// nil launches the user's login shell. Anything else is a command line whose first word is
    /// an absolute path. `command` comes from the session's type, so a user who installed a CLI
    /// somewhere unusual can point Relay at it in Settings.
    static func command(for type: SessionType) async throws -> String? {
        try await resolve(type.resolvedCommand, typeName: type.name)
    }

    static func resolve(_ command: String?, typeName: String) async throws -> String? {
        guard let command, !command.isEmpty else { return nil }
        var words = command.split(separator: " ").map(String.init)
        guard let name = words.first else { return nil }
        if let executable = await LoginShellPath.shared.locate(name) {
            words[0] = quoted(executable.path)
            // The spawned process would otherwise inherit Relay's launchd PATH, so a CLI that is
            // a Node script (`#!/usr/bin/env node`) under nvm starts and then can't find node.
            // The executable's own directory comes first, which covers a node install that is
            // only known through a path set in Settings.
            let searchPath = await LoginShellPath.shared.searchPath(including: executable.deletingLastPathComponent().path)
            let resolved = "/usr/bin/env PATH=\(singleQuoted(searchPath)) " + words.joined(separator: " ")
            RelayLog.info(.session, "Resolved \(typeName) to \(resolved)")
            return resolved
        }
        let searchPath = await LoginShellPath.shared.describeSearchPath()
        RelayLog.error(.session, "Could not find \(name) for \(typeName) on PATH: \(searchPath)")
        throw LaunchError.executableNotFound(typeName: typeName, name: name)
    }

    private static func quoted(_ path: String) -> String {
        path.contains(" ") ? "\"\(path)\"" : path
    }

    private static func singleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }

    enum LaunchError: LocalizedError {
        case executableNotFound(typeName: String, name: String)

        var errorDescription: String? {
            switch self {
            case .executableNotFound(_, let name):
                return "Relay couldn’t find `\(name)` on your login shell’s PATH."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .executableNotFound(let typeName, _):
                return "Install it, or set the full path for \(typeName) in Settings ▸ Session Types."
            }
        }
    }
}

/// The login shell's PATH, resolved once per run and shared by every launcher.
private actor LoginShellPath {
    static let shared = LoginShellPath()
    private var directories: [String]?

    func locate(_ name: String) async -> URL? {
        // An explicit path in a configured command is used as written.
        if name.contains("/") {
            let url = URL(filePath: NSString(string: name).expandingTildeInPath)
            return isExecutable(url) ? url : nil
        }
        for directory in await searchPath() {
            let url = URL(filePath: directory).appending(path: name)
            if isExecutable(url) { return url }
        }
        return nil
    }

    /// Included in diagnostics: "the CLI is installed" and "the CLI is on the PATH Relay can
    /// see" are different claims, and only the second one matters here.
    func describeSearchPath() async -> String {
        await searchPath().joined(separator: ":")
    }

    /// The PATH a launched CLI runs with, led by `directory`.
    func searchPath(including directory: String) async -> String {
        ([directory] + (await searchPath()).filter { $0 != directory }).joined(separator: ":")
    }

    private func searchPath() async -> [String] {
        if let directories { return directories }
        var resolved = await Self.loginShellPath()
        // The current process's PATH is a poor substitute but costs nothing, and covers the case
        // where Relay was started from a terminal that already had the CLIs on its PATH.
        resolved += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        resolved += Self.conventionalDirectories
        var seen: Set<String> = []
        let unique = resolved.filter { !$0.isEmpty && seen.insert($0).inserted }
        directories = unique
        return unique
    }

    private func isExecutable(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
            && !isDirectory.boolValue
            && FileManager.default.isExecutableFile(atPath: url.path)
    }

    private static var conventionalDirectories: [String] {
        let home = NSHomeDirectory()
        // ~/.claude/local is where older Claude Code installs live, reached only through an alias.
        return ["\(home)/.local/bin", "\(home)/.claude/local", "\(home)/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    }

    /// PATH is read from an interactive login shell, because version managers and npm installs
    /// usually add to it in .zshrc, which a non-interactive shell never reads. Interactive
    /// profiles can print banners or prompts, so the value is delimited by markers. A broken
    /// profile would otherwise hang session start, so the shell gets a deadline.
    private static func loginShellPath() async -> [String] {
        await Task.detached(priority: .userInitiated) { () -> [String] in
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let marker = "__RELAY_PATH__"
            let process = Process()
            process.executableURL = URL(filePath: shell)
            process.arguments = ["-ilc", "printf '\(marker)%s\(marker)' \"$PATH\""]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            guard (try? process.run()) != nil else {
                RelayLog.error(.session, "Could not run \(shell) to read the login shell PATH")
                return []
            }
            let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: deadline)
            let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
            process.waitUntilExit()
            deadline.cancel()
            let output = String(decoding: data, as: UTF8.self)
            guard let path = extractPath(from: output, marker: marker) else {
                RelayLog.error(.session, "\(shell) -ilc exited with status \(process.terminationStatus) without reporting PATH; falling back to conventional directories")
                return []
            }
            return path.split(separator: ":").map(String.init)
        }.value
    }

    static func extractPath(from output: String, marker: String) -> String? {
        guard let start = output.range(of: marker),
              let end = output.range(of: marker, range: start.upperBound..<output.endIndex) else { return nil }
        return String(output[start.upperBound..<end.lowerBound])
    }
}
