import AppKit
import SwiftUI

struct WorkspaceSidebar: View {
    @Bindable var store: WorkspaceStore
    @Bindable var types: SessionTypeStore
    let addWorkspace: () -> Void
    @State private var workspacePendingRemoval: Workspace?
    @State private var showsRemoveConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                RelayMark()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Relay").font(.title2).bold()
                    Text("Your terminal sessions,\nin motion.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(20)
            List(selection: $store.destination) {
                Section("Workspaces") {
                    ForEach(store.state.workspaces) { workspace in
                        WorkspaceRow(workspace: workspace) { workspaceMenu(workspace) }
                            .tag(SessionDestination.workspace(workspace.id))
                            .contextMenu { workspaceMenu(workspace) }
                    }
                }
                Section {
                    Label("Temporary Sessions", systemImage: "terminal")
                        .padding(.vertical, 6)
                        .tag(SessionDestination.temporary)
                }
            }
            .listStyle(.sidebar)
            // Hidden so the column's own sidebar material runs the full height instead of the
            // list painting its own strip between the header and the launchers.
            .scrollContentBackground(.hidden)
            // ⌫ removes the selected workspace, matching the sidebars of other Mac apps.
            .onDeleteCommand(perform: removeSelectedWorkspace)
            Button(action: addWorkspace) {
                Label("Add Workspace", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain).padding(20)
            .keyboardShortcut("o", modifiers: [.command, .shift])
            Divider().padding(.horizontal, 16)
            temporarySessionLaunchers
        }
        .confirmationDialog(removalTitle, isPresented: $showsRemoveConfirmation, titleVisibility: .visible) {
            Button("Remove Workspace", role: .destructive) {
                if let workspacePendingRemoval { store.removeWorkspace(workspacePendingRemoval.id) }
                workspacePendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { workspacePendingRemoval = nil }
        } message: {
            Text(removalMessage)
        }
    }

    /// Shared by the row's options button and its right-click menu so the two never drift.
    @ViewBuilder private func workspaceMenu(_ workspace: Workspace) -> some View {
        Button("Show in Finder", systemImage: "folder") {
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: workspace.path)])
        }
        Divider()
        Button("Remove Workspace", systemImage: "minus.circle", role: .destructive) {
            confirmRemoval(of: workspace)
        }
    }

    /// A grid rather than a row: the session type list is user editable, so this has to hold
    /// however many are enabled without pushing the sidebar wider. It is also capped, because
    /// the sidebar has no scroll of its own below the workspace list — an unbounded grid would
    /// squeeze that list away once a user added enough types. The cap keeps the footer a fixed
    /// two or three rows and moves the rest into a menu, so nothing becomes unreachable.
    private var temporarySessionLaunchers: some View {
        let launchers = types.sidebarLaunchers
        return VStack(alignment: .leading, spacing: 12) {
            Text("TEMPORARY SESSION").font(.caption).bold().foregroundStyle(.secondary)
            GlassEffectContainer(spacing: 8) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 8)], spacing: 8) {
                ForEach(launchers.pinned) { type in
                    Button { store.addTemporarySession(type) } label: {
                        launcherTile(symbol: type.symbol, color: type.color.color, title: type.name)
                    }
                    .accessibilityLabel("New temporary \(type.name) session")
                    .accessibilityInputLabels([Text(type.name)])
                    .buttonStyle(.plain)
                    .help("New temporary \(type.name) session in your home directory")
                }
                if !launchers.overflow.isEmpty {
                    Menu {
                        ForEach(launchers.overflow) { type in
                            Button(type.name, systemImage: type.symbol) {
                                store.addTemporarySession(type)
                            }
                        }
                    } label: {
                        launcherTile(symbol: "ellipsis", color: .secondary,
                                     title: "\(launchers.overflow.count) more")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .accessibilityLabel("More temporary session types")
                    .help("Reorder session types in Settings to choose which appear here")
                    }
                }
            }
        }
        .padding(20)
    }

    /// Shared so the overflow menu is the same shape and weight as the launchers beside it.
    private func launcherTile(symbol: String, color: Color, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.title3).foregroundStyle(color)
                .accessibilityHidden(true)
            Text(title).font(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12))
    }

    private var removalTitle: Text {
        Text("Remove “\(workspacePendingRemoval?.name ?? "")” from Relay?")
    }

    private var removalMessage: String {
        let folder = "The folder stays on your Mac. Relay forgets this workspace and its sessions."
        guard let workspacePendingRemoval, store.hasRunningProcesses(in: workspacePendingRemoval.id) else {
            return folder
        }
        return "Processes are still running in this workspace’s sessions. Removing it will stop them. \(folder)"
    }

    private func confirmRemoval(of workspace: Workspace) {
        workspacePendingRemoval = workspace
        showsRemoveConfirmation = true
    }

    private func removeSelectedWorkspace() {
        guard case .workspace(let id) = store.destination,
              let workspace = store.state.workspaces.first(where: { $0.id == id }) else { return }
        confirmRemoval(of: workspace)
    }
}

private struct WorkspaceRow<MenuContent: View>: View {
    let workspace: Workspace
    @ViewBuilder let menu: () -> MenuContent
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.name).fontWeight(.medium)
                    Text(workspace.path).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            } icon: {
                Image(systemName: "folder").foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            OptionsMenuButton(isHovered: isHovered,
                              accessibilityTitle: "\(workspace.name) workspace options",
                              menu: menu)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}
