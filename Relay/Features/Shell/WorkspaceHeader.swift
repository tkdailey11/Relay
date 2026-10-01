import SwiftUI

struct WorkspaceHeader: View {
    let name: String
    let path: String
    let sessionCount: Int
    let isTemporary: Bool
    let types: [SessionType]
    let addSession: (SessionType) -> Void
    @State private var gitHead: GitHead?

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
            guard !isTemporary else { return }
            for await head in GitService.heads(at: path) {
                gitHead = head
            }
        }
    }

    /// Takes priority over the path, which truncates first since the branch is the part that
    /// changes and the path is already in the sidebar.
    private func branchLabel(_ head: GitHead) -> some View {
        let (title, accessibility) = switch head {
        case .branch(let name): (name, "Git branch \(name)")
        case .detached(let commit): ("detached at \(commit)", "Git HEAD detached at \(commit)")
        }
        return Label(title, systemImage: "arrow.triangle.branch")
            .lineLimit(1).truncationMode(.middle)
            .layoutPriority(1)
            .help(title)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibility)
    }
}
