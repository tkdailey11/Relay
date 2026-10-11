import Foundation
import Testing
@testable import Relay

struct GitServiceTests {
    private func makeDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "Relay Git \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeRepository(at url: URL, head: String) throws {
        let git = url.appending(path: ".git")
        try FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
        try head.write(to: git.appending(path: "HEAD"), atomically: true, encoding: .utf8)
    }

    @Test func readsTheBranchFromTheRepositoryOrAnyFolderInsideIt() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeRepository(at: root, head: "ref: refs/heads/feature/reorder\n")
        let nested = root.appending(path: "Sources/App")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        #expect(GitService.head(at: root.path) == .branch("feature/reorder"))
        #expect(GitService.head(at: nested.path) == .branch("feature/reorder"))
    }

    @Test func reportsADetachedHeadAsAnAbbreviatedCommit() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeRepository(at: root, head: "2dd9d31f6a0c4e5b9a1d7c3e8f0b2a4c6d8e0f12\n")
        #expect(GitService.head(at: root.path) == .detached("2dd9d31"))
    }

    @Test func followsTheGitFileThatWorktreesUse() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let main = root.appending(path: "main")
        try makeRepository(at: main, head: "ref: refs/heads/main\n")
        let worktreeGitDirectory = main.appending(path: ".git/worktrees/fix")
        try FileManager.default.createDirectory(at: worktreeGitDirectory, withIntermediateDirectories: true)
        try "ref: refs/heads/fix\n".write(to: worktreeGitDirectory.appending(path: "HEAD"),
                                          atomically: true, encoding: .utf8)
        let worktree = root.appending(path: "fix")
        try FileManager.default.createDirectory(at: worktree, withIntermediateDirectories: true)

        // Absolute, as `git worktree add` writes it, and relative, as submodules do.
        try "gitdir: \(worktreeGitDirectory.path)\n".write(to: worktree.appending(path: ".git"),
                                                          atomically: true, encoding: .utf8)
        #expect(GitService.head(at: worktree.path) == .branch("fix"))
        try "gitdir: ../main/.git/worktrees/fix\n".write(to: worktree.appending(path: ".git"),
                                                       atomically: true, encoding: .utf8)
        #expect(GitService.head(at: worktree.path) == .branch("fix"))
    }

    @Test func showsNothingOutsideARepositoryOrForAnUnreadableHead() throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(GitService.head(at: root.path) == nil)

        try makeRepository(at: root, head: "not a ref\n")
        #expect(GitService.head(at: root.path) == nil)
    }

    @Test(.timeLimit(.minutes(1)))
    func publishesBranchChangesAsTheyHappen() async throws {
        let root = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        try makeRepository(at: root, head: "ref: refs/heads/main\n")

        var iterator = GitService.heads(at: root.path).makeAsyncIterator()
        #expect(await iterator.next() == .branch("main"))

        // Atomic writes rename a temporary file over HEAD, which is also how Git updates it.
        try "ref: refs/heads/topic\n".write(to: root.appending(path: ".git/HEAD"),
                                            atomically: true, encoding: .utf8)
        #expect(await iterator.next() == .branch("topic"))

        // Deleting the repository is reported too, rather than leaving a stale branch on screen.
        try FileManager.default.removeItem(at: root.appending(path: ".git"))
        #expect(await iterator.next() == .some(nil))

        // And a repository that appears afterwards, as `git init` would make one.
        try makeRepository(at: root, head: "ref: refs/heads/main\n")
        #expect(await iterator.next() == .branch("main"))
    }
}

struct GitRecentBranchesTests {
    @Test func listsRecentBranchesNewestFirstSkippingTheCurrentAndDeletedOnes() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Relay Git \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let git = root.appending(path: ".git")
        try FileManager.default.createDirectory(at: git.appending(path: "refs/heads/feature"), withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(to: git.appending(path: "HEAD"), atomically: true, encoding: .utf8)
        for name in ["main", "dev", "feature/x"] {
            try "abc\n".write(to: git.appending(path: "refs/heads/\(name)"), atomically: true, encoding: .utf8)
        }
        try "abc refs/heads/old\n".write(to: git.appending(path: "packed-refs"), atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(at: git.appending(path: "logs"), withIntermediateDirectories: true)
        let entry = { (from: String, to: String) in
            "0000 1111 A <a@b> 1 +0000\tcheckout: moving from \(from) to \(to)\n"
        }
        try [entry("old", "gone"), entry("gone", "feature/x"), entry("feature/x", "dev"),
             entry("dev", "old"), entry("old", "main")].joined()
            .write(to: git.appending(path: "logs/HEAD"), atomically: true, encoding: .utf8)

        #expect(GitService.recentBranches(at: root.path) == ["old", "dev", "feature/x"])
        #expect(GitService.recentBranches(at: root.path, limit: 1) == ["old"])
    }

    @Test func hasNoRecentBranchesWithoutAReflog() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "Relay Git \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appending(path: ".git"), withIntermediateDirectories: true)
        try "ref: refs/heads/main\n".write(to: root.appending(path: ".git/HEAD"), atomically: true, encoding: .utf8)
        #expect(GitService.recentBranches(at: root.path).isEmpty)
    }
}

struct GitSwitchBranchTests {
    private func git(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/env")
        process.arguments = ["git", "-c", "user.name=T", "-c", "user.email=t@example.com"] + arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    private func succeeded(_ result: Result<Void, GitError>) -> Bool {
        if case .success = result { true } else { false }
    }

    /// A repository on `main` and `other`, where the two disagree about file.txt.
    private func makeRepository() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "Relay Git \(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "file.txt")
        try git(["init", "-b", "main"], in: root)
        try "one\n".write(to: file, atomically: true, encoding: .utf8)
        try git(["add", "."], in: root)
        try git(["commit", "-m", "one"], in: root)
        try git(["switch", "-c", "other"], in: root)
        try "two\n".write(to: file, atomically: true, encoding: .utf8)
        try git(["commit", "-am", "two"], in: root)
        try git(["switch", "main"], in: root)
        return root
    }

    @Test func switchesWhenTheTreeIsClean() async throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(succeeded(await GitService.switchBranch(to: "other", at: root.path)))
        #expect(GitService.head(at: root.path) == .branch("other"))
    }

    @Test func reportsConflictingLocalChangesAndLeavesThemAlone() async throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try "mine\n".write(to: root.appending(path: "file.txt"), atomically: true, encoding: .utf8)

        guard case .failure(let error) = await GitService.switchBranch(to: "other", at: root.path) else {
            Issue.record("Expected the switch to be refused")
            return
        }
        #expect(error.blockedByLocalChanges)
        #expect(GitService.head(at: root.path) == .branch("main"))
        #expect(try String(contentsOf: root.appending(path: "file.txt"), encoding: .utf8) == "mine\n")
    }

    @Test func stashesConflictingChangesThenSwitches() async throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try "mine\n".write(to: root.appending(path: "file.txt"), atomically: true, encoding: .utf8)

        #expect(succeeded(await GitService.stashAndSwitch(to: "other", at: root.path)))
        #expect(GitService.head(at: root.path) == .branch("other"))
        #expect(try String(contentsOf: root.appending(path: "file.txt"), encoding: .utf8) == "two\n")
    }

    @Test func restoresTheStashWhenTheSwitchStillFails() async throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        try "mine\n".write(to: root.appending(path: "file.txt"), atomically: true, encoding: .utf8)

        guard case .failure = await GitService.stashAndSwitch(to: "missing", at: root.path) else {
            Issue.record("Expected the switch to fail")
            return
        }
        #expect(GitService.head(at: root.path) == .branch("main"))
        #expect(try String(contentsOf: root.appending(path: "file.txt"), encoding: .utf8) == "mine\n")
    }
}
