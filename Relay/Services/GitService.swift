import Foundation

/// What a repository's HEAD points at.
nonisolated enum GitHead: Equatable, Sendable {
    case branch(String)
    /// An abbreviated commit, as `git status` shows a detached HEAD.
    case detached(String)
}

struct GitError: Error, Equatable, Sendable {
    let message: String
    /// Git refused because uncommitted changes to tracked files would be lost, the one failure
    /// stashing can fix.
    var blockedByLocalChanges = false
}

/// Reads Git metadata straight from the repository's files rather than running `git`. On a Mac
/// without the Command Line Tools, `/usr/bin/git` is a stub that pops an install dialog, and Git
/// must never be required. HEAD is a one-line file, so reading it is also cheap enough to redo
/// every time the repository changes.
nonisolated enum GitService {
    /// The HEAD of the repository containing `directory`, searching upward as Git does so a
    /// workspace inside a repository still shows its branch. Nil outside a repository.
    static func head(at directory: String) -> GitHead? {
        gitDirectory(containing: directory).flatMap(head(inGitDirectory:))
    }

    /// Yields the current HEAD, then again whenever it changes, until the consumer stops
    /// listening. Changes come from watching the git directory: Git replaces HEAD by renaming
    /// a lock file over it, so a watch on the file itself would stop at the first checkout.
    static func heads(at directory: String) -> AsyncStream<GitHead?> {
        AsyncStream { continuation in
            let watcher = GitHeadWatcher(directory: directory) { continuation.yield($0) }
            continuation.onTermination = { _ in watcher.cancel() }
            watcher.start()
        }
    }

    /// The directory holding HEAD. A `.git` file instead of a folder is what worktrees and
    /// submodules use, and it names the real git directory.
    static func gitDirectory(containing directory: String) -> URL? {
        var current = URL(filePath: directory, directoryHint: .isDirectory).standardizedFileURL
        while true {
            let candidate = current.appending(path: ".git")
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: candidate.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue { return candidate }
                return linkedGitDirectory(from: candidate, relativeTo: current)
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return nil }
            current = parent
        }
    }

    static func head(inGitDirectory gitDirectory: URL) -> GitHead? {
        guard let contents = try? String(contentsOf: gitDirectory.appending(path: "HEAD"), encoding: .utf8) else {
            return nil
        }
        let line = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        if line.hasPrefix("ref: ") {
            let ref = String(line.dropFirst("ref: ".count))
            let branchPrefix = "refs/heads/"
            return .branch(ref.hasPrefix(branchPrefix) ? String(ref.dropFirst(branchPrefix.count)) : ref)
        }
        guard line.count >= 7, line.allSatisfy(\.isHexDigit) else { return nil }
        return .detached(String(line.prefix(7)))
    }

    /// The branches HEAD most recently moved to, newest first, found in HEAD's reflog
    /// ("checkout: moving from A to B"). The current branch and branches that no longer exist
    /// are left out. Read from files like everything else here, so listing needs no Git.
    static func recentBranches(at directory: String, limit: Int = 3) -> [String] {
        guard let gitDirectory = gitDirectory(containing: directory),
              let log = try? String(contentsOf: gitDirectory.appending(path: "logs/HEAD"), encoding: .utf8)
        else { return [] }
        let current: String? = if case .branch(let name)? = head(inGitDirectory: gitDirectory) { name } else { nil }
        let commonDirectory = commonGitDirectory(of: gitDirectory)
        let packed = (try? String(contentsOf: commonDirectory.appending(path: "packed-refs"), encoding: .utf8)) ?? ""
        var found: [String] = []
        for line in log.split(separator: "\n").reversed() {
            guard let range = line.range(of: "\tcheckout: moving from ") else { continue }
            let move = line[range.upperBound...]
            guard let separator = move.range(of: " to ", options: .backwards) else { continue }
            // Newest side first: the branch moved to, then the one left behind.
            for name in [String(move[separator.upperBound...]), String(move[..<separator.lowerBound])]
            where name != current && !found.contains(name)
                && branchExists(name, in: commonDirectory, packedRefs: packed) {
                found.append(name)
            }
            if found.count >= limit { break }
        }
        return Array(found.prefix(limit))
    }

    /// Worktrees keep HEAD in their own directory but share branches with the main one.
    private static func commonGitDirectory(of gitDirectory: URL) -> URL {
        guard let contents = try? String(contentsOf: gitDirectory.appending(path: "commondir"), encoding: .utf8) else {
            return gitDirectory
        }
        let path = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = path.hasPrefix("/") ? URL(filePath: path) : gitDirectory.appending(path: path)
        return url.standardizedFileURL
    }

    private static func branchExists(_ name: String, in gitDirectory: URL, packedRefs: String) -> Bool {
        if FileManager.default.fileExists(atPath: gitDirectory.appending(path: "refs/heads/\(name)").path) { return true }
        return packedRefs.split(separator: "\n").contains { $0.hasSuffix(" refs/heads/\(name)") }
    }

    /// Switches the repository containing `directory` to `branch` with `git switch`, which
    /// refuses rather than lose uncommitted work. Git is only run for an explicit request like
    /// this one, never to read state.
    static func switchBranch(to branch: String, at directory: String) async -> Result<Void, GitError> {
        await Task.detached { switchNow(to: branch, at: directory) }.value
    }

    /// Stashes uncommitted changes, then switches. If the switch still fails the stash is put
    /// back, so a failure leaves the working tree as it was found.
    static func stashAndSwitch(to branch: String, at directory: String) async -> Result<Void, GitError> {
        await Task.detached {
            let stash = run(["stash", "push", "-m", "Relay: before switching to \(branch)"], at: directory)
            guard stash.status == 0 else { return .failure(GitError(message: stash.failureMessage("Git couldn’t stash your changes."))) }
            // Nothing to stash leaves nothing to restore; popping then would take an older stash.
            let stashed = stash.output.contains("Saved working directory")
            let result = switchNow(to: branch, at: directory)
            if case .failure = result, stashed { _ = run(["stash", "pop"], at: directory) }
            return result
        }.value
    }

    private nonisolated static func switchNow(to branch: String, at directory: String) -> Result<Void, GitError> {
        let result = run(["switch", branch], at: directory)
        guard result.status != 0 else { return .success(()) }
        return .failure(GitError(message: result.failureMessage("Git couldn’t switch to \(branch)."),
                                 blockedByLocalChanges: result.errors.contains("Your local changes")))
    }

    private struct GitResult {
        var status: Int32
        var output: String
        var errors: String

        func failureMessage(_ fallback: String) -> String {
            let message = errors.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? fallback : message
        }
    }

    private nonisolated static func run(_ arguments: [String], at directory: String) -> GitResult {
        guard let git = gitExecutable() else { return GitResult(status: -1, output: "", errors: "Git isn’t installed.") }
        let process = Process()
        process.executableURL = git
        process.arguments = ["-C", directory] + arguments
        let output = Pipe(), errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        do { try process.run() } catch { return GitResult(status: -1, output: "", errors: error.localizedDescription) }
        // Both pipes are drained concurrently so neither can fill and stall Git.
        nonisolated(unsafe) var outputData = Data()
        let drain = DispatchQueue(label: "Relay.GitService.drain")
        let group = DispatchGroup()
        drain.async(group: group) { outputData = output.fileHandleForReading.readDataToEndOfFile() }
        let errorData = errors.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        process.waitUntilExit()
        return GitResult(status: process.terminationStatus,
                         output: String(decoding: outputData, as: UTF8.self),
                         errors: String(decoding: errorData, as: UTF8.self))
    }

    /// A real Git, or nil. Without the Command Line Tools `/usr/bin/git` is a stub that opens an
    /// install dialog, so it is used only once `xcode-select` confirms a developer directory.
    private static func gitExecutable() -> URL? {
        for path in ["/opt/homebrew/bin/git", "/usr/local/bin/git"]
        where FileManager.default.isExecutableFile(atPath: path) {
            return URL(filePath: path)
        }
        let probe = Process()
        probe.executableURL = URL(filePath: "/usr/bin/xcode-select")
        probe.arguments = ["-p"]
        probe.standardOutput = FileHandle.nullDevice
        probe.standardError = FileHandle.nullDevice
        guard (try? probe.run()) != nil else { return nil }
        probe.waitUntilExit()
        return probe.terminationStatus == 0 ? URL(filePath: "/usr/bin/git") : nil
    }

    private static func linkedGitDirectory(from file: URL, relativeTo directory: URL) -> URL? {
        guard let contents = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let line = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("gitdir: ") else { return nil }
        let path = String(line.dropFirst("gitdir: ".count))
        let url = path.hasPrefix("/") ? URL(filePath: path) : directory.appending(path: path)
        return url.standardizedFileURL
    }
}

/// Watches one workspace's git directory, or the workspace folder itself while it isn't in a
/// repository, so a `git init` there is noticed. Every event re-resolves the repository from
/// scratch, so a deleted or re-created `.git` never leaves the watch on a directory that is gone.
private nonisolated final class GitHeadWatcher: @unchecked Sendable {
    private let directory: String
    private let onChange: @Sendable (GitHead?) -> Void
    private let queue = DispatchQueue(label: "Relay.GitHeadWatcher", qos: .utility)
    // Touched only on `queue`.
    private var source: DispatchSourceFileSystemObject?
    private var watchedDirectory: URL?
    private var lastHead: GitHead??
    private var isCancelled = false

    init(directory: String, onChange: @escaping @Sendable (GitHead?) -> Void) {
        self.directory = directory
        self.onChange = onChange
    }

    func start() {
        queue.async { self.refresh() }
    }

    func cancel() {
        queue.async {
            self.isCancelled = true
            self.source?.cancel()
            self.source = nil
        }
    }

    private func refresh() {
        guard !isCancelled else { return }
        let gitDirectory = GitService.gitDirectory(containing: directory)
        let target = gitDirectory ?? URL(filePath: directory, directoryHint: .isDirectory)
        if target != watchedDirectory || source == nil {
            watch(target)
        }
        let head = gitDirectory.flatMap(GitService.head(inGitDirectory:))
        // Git writes many files under the directory for one command; only report real changes.
        guard lastHead != .some(head) else { return }
        lastHead = .some(head)
        onChange(head)
    }

    private func watch(_ target: URL) {
        source?.cancel()
        source = nil
        watchedDirectory = target
        let descriptor = open(target.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            // A renamed or deleted directory can't be watched any further; drop it so the next
            // refresh opens whatever is there now.
            if !source.data.isDisjoint(with: [.rename, .delete]) {
                self.source?.cancel()
                self.source = nil
            }
            self.refresh()
        }
        source.setCancelHandler { close(descriptor) }
        self.source = source
        source.resume()
    }
}
