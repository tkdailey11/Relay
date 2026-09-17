import Foundation

/// Maps a session kind to the command line that starts it.
///
/// Relay is launched by the Finder, so its environment carries launchd's minimal PATH rather than
/// the user's. The CLIs these launchers depend on almost always live somewhere only the login
/// shell knows about, so each command's executable is resolved to an absolute path before the
/// terminal spawns it, which is also what lets a missing CLI be reported as an error instead of a
/// shell that flashes and exits.
enum SessionLauncher {
    /// nil launches the user's login shell. Anything else is a command line whose first word is an
    /// absolute path.
    static func command(for kind: SessionKind, defaults: UserDefaults = .standard) async throws -> String? {
        let candidates = candidates(for: kind, defaults: defaults)
        guard !candidates.isEmpty else { return nil }
        for candidate in candidates {
            var words = candidate.split(separator: " ").map(String.init)
            guard let name = words.first else { continue }
            if let executable = await LoginShellPath.shared.locate(name) {
                words[0] = quoted(executable.path)
                return words.joined(separator: " ")
            }
        }
        throw LaunchError.executableNotFound(kind: kind, names: candidates.compactMap {
            $0.split(separator: " ").first.map(String.init)
        })
    }

    /// The CLIs move faster than Relay ships, so the command line is overridable without a new
    /// build: `defaults write com.tylerdailey.Relay "RelayCommand.Copilot" "gh copilot"`.
    /// An empty string means "launch the login shell".
    private static func candidates(for kind: SessionKind, defaults: UserDefaults) -> [String] {
        if let configured = defaults.string(forKey: "RelayCommand.\(kind.rawValue)") {
            return configured.isEmpty ? [] : [configured]
        }
        switch kind {
        case .claude: return ["claude"]
        // GitHub moved Copilot from a `gh` extension to a standalone CLI; either may be installed.
        case .copilot: return ["copilot", "gh copilot"]
        case .shell: return []
        }
    }

    private static func quoted(_ path: String) -> String {
        path.contains(" ") ? "\"\(path)\"" : path
    }

    enum LaunchError: LocalizedError {
        case executableNotFound(kind: SessionKind, names: [String])

        var errorDescription: String? {
            switch self {
            case .executableNotFound(_, let names):
                let list = ListFormatter.localizedString(byJoining: names.map { "`\($0)`" })
                return "Relay couldn’t find \(list) on your login shell’s PATH."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .executableNotFound(let kind, _):
                return "Install the \(kind.rawValue) CLI, then start a new \(kind.rawValue) session."
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
        return ["\(home)/.local/bin", "\(home)/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    }

    /// A login shell runs the user's profile, which is where PATH is usually assembled. A broken
    /// profile would otherwise hang session start, so the shell gets a deadline.
    private static func loginShellPath() async -> [String] {
        await Task.detached(priority: .userInitiated) { () -> [String] in
            let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
            let process = Process()
            process.executableURL = URL(filePath: shell)
            process.arguments = ["-lc", "printf %s \"$PATH\""]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            process.standardInput = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return [] }
            let deadline = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: deadline)
            let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
            process.waitUntilExit()
            deadline.cancel()
            guard process.terminationStatus == 0 else { return [] }
            return String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: ":").map(String.init)
        }.value
    }
}
