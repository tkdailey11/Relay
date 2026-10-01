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
