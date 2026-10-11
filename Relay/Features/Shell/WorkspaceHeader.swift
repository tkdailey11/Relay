import SwiftUI

struct WorkspaceHeader: View {
    let name: String
    let path: String
    let sessionCount: Int
    let isTemporary: Bool
    let types: [SessionType]
    let addSession: (SessionType) -> Void
    @State private var gitHead: GitHead?
    @State private var recentBranches: [String] = []
    @State private var switchError: String?
    @State private var stashOffer: String?

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isTemporary ? "terminal" : "folder.fill").font(.title2).foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(name).font(.title).bold()
                    .lineLimit(1).truncationMode(.middle)
                    .help(name)
                HStack(spacing: 10) {
                    // A floor so even a very long branch name can't squeeze the path away.
                    Text(path).lineLimit(1).truncationMode(.middle)
                        .frame(minWidth: 80, alignment: .leading)
                    if let gitHead {
                        branchLabel(gitHead)
                    }
                }
                .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Text("^[\(sessionCount) session](inflect: true)")
                .font(.caption).foregroundStyle(.secondary)
            Menu {
                NewSessionMenuItems(types: types, addSession: addSession)
            } label: {
                Label("New Session", systemImage: "plus")
            }
            .help(isTemporary ? "New temporary session" : "New session in \(name)")
        }
        // Keyed by path so switching workspaces swaps the watch. Temporary sessions run in the
        // home folder, where a dotfiles repository would be noise rather than project context.
        .task(id: isTemporary ? nil : path) {
            gitHead = nil
            recentBranches = []
            guard !isTemporary else { return }
            for await head in GitService.heads(at: path) {
                gitHead = head
                recentBranches = GitService.recentBranches(at: path)
            }
        }
        .alert("Couldn’t Switch Branch", isPresented: Binding(get: { switchError != nil },
                                                             set: { if !$0 { switchError = nil } })) {
        } message: {
            Text(switchError ?? "")
        }
        .alert("Stash changes and switch to \(stashOffer ?? "")?",
               isPresented: Binding(get: { stashOffer != nil }, set: { if !$0 { stashOffer = nil } })) {
            Button("Stash and Switch") {
                if let branch = stashOffer { switchBranch(to: branch, stashing: true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your uncommitted changes would be overwritten. Relay can stash them first. They stay in the stash, not on the new branch; run “git stash pop” to bring them back.")
        }
    }

    /// Takes priority over the path, which truncates first since the branch is the part that
    /// changes and the path is already in the sidebar.
    private func branchLabel(_ head: GitHead) -> some View {
        let (title, accessibility) = switch head {
        case .branch(let name): (name, "Git branch \(name)")
        case .detached(let commit): ("detached at \(commit)", "Git HEAD detached at \(commit)")
        }
        return Menu {
            Section("Recent Branches") {
                ForEach(recentBranches, id: \.self) { branch in
                    Button(branch) { switchBranch(to: branch) }
                }
                if recentBranches.isEmpty {
                    Button("No Other Recent Branches") {}.disabled(true)
                }
            }
        } label: {
            Label(title, systemImage: "arrow.triangle.branch")
                .lineLimit(1).truncationMode(.middle)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .layoutPriority(1)
        .help("\(title) — switch branch")
        .accessibilityLabel(accessibility)
    }

    private func switchBranch(to branch: String, stashing: Bool = false) {
        Task {
            let result = stashing ? await GitService.stashAndSwitch(to: branch, at: path)
                                  : await GitService.switchBranch(to: branch, at: path)
            guard case .failure(let error) = result else { return }
            if error.blockedByLocalChanges && !stashing {
                stashOffer = branch
            } else {
                switchError = error.message
            }
        }
    }
}
