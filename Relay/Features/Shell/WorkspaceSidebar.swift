import SwiftUI

struct WorkspaceSidebar: View {
    @Bindable var store: WorkspaceStore
    let addWorkspace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RelayMark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Relay").font(.title2.weight(.semibold))
                    Text("Your sessions, in motion.").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)
            List(selection: $store.destination) {
                Section("Workspaces") {
                    ForEach(store.state.workspaces) { workspace in
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workspace.name).fontWeight(.medium)
                                Text(workspace.path).font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle)
                            }
                        } icon: {
                            Image(systemName: "folder").foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6).tag(SessionDestination.workspace(workspace.id))
                    }
                }
                Section {
                    Label("Temporary Sessions", systemImage: "terminal")
                        .padding(.vertical, 6)
                        .tag(SessionDestination.temporary)
                }
            }
            .listStyle(.sidebar)
            Button(action: addWorkspace) {
                Label("Add Workspace", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).padding(20)
            .keyboardShortcut("o", modifiers: [.command, .shift])
            Divider().padding(.horizontal, 16)
            VStack(alignment: .leading, spacing: 12) {
                Text("TEMPORARY SESSION").font(.caption).bold().foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(SessionKind.allCases) { kind in
                        Button { store.addTemporarySession(kind) } label: {
                            VStack(spacing: 8) {
                                Image(systemName: kind.symbol).font(.title3).foregroundStyle(kind.color)
                                    .accessibilityHidden(true)
                                Text(kind.rawValue).font(.caption)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .accessibilityLabel("New temporary \(kind.rawValue) session")
                        .accessibilityInputLabels([Text(kind.rawValue)])
                        .buttonStyle(.plain).help("New temporary \(kind.rawValue) session in your home directory")
                    }
                }
            }
            .padding(20)
        }
    }
}
