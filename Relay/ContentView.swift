import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: WorkspaceStore
    private var workspaces: [Workspace] { store.state.workspaces }
    private var selection: UUID? {
        get { store.state.selectedWorkspaceID }
        nonmutating set { store.state.selectedWorkspaceID = newValue }
    }
    private var selectedIndex: Int? { workspaces.firstIndex { $0.id == selection } }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    RelayMark()
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Relay").font(.title2.weight(.semibold))
                        Text("Your sessions, in motion.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
                List(selection: $store.state.selectedWorkspaceID) {
                    Section("Workspaces") {
                        ForEach(workspaces) { workspace in
                            Label {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workspace.name).fontWeight(.medium)
                                    Text(workspace.path).font(.caption).foregroundStyle(.secondary)
                                        .lineLimit(1).truncationMode(.middle)
                                }
                            } icon: {
                                Image(systemName: "folder").foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 6).tag(workspace.id)
                        }
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
                    Text("START A SESSION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(SessionKind.allCases) { kind in
                            Button { addSession(kind) } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: kind.symbol).font(.title3).foregroundStyle(kind.color)
                                    Text(kind.rawValue).font(.caption)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain).help("Preview a \(kind.rawValue) session")
                        }
                    }
                    .disabled(selectedIndex == nil)
                }
                .padding(20)
            }
            .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 320)
        } detail: {
            if let index = selectedIndex {
                WorkspaceShell(workspace: $store.state.workspaces[index], addSession: addSession)
            } else {
                ContentUnavailableView {
                    Label("Your next workspace", systemImage: "folder.badge.plus")
                } description: {
                    Text("Choose a local folder to make room for your sessions.")
                } actions: {
                    Button("Add Workspace", action: addWorkspace)
                }
            }
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(SessionKind.allCases) { kind in
                        Button("New \(kind.rawValue) Session", systemImage: kind.symbol) { addSession(kind) }
                    }
                } label: {
                    Label("New Session", systemImage: "plus")
                }
                .disabled(selectedIndex == nil).help("New preview session")
            }
        }
        .frame(minWidth: 860, minHeight: 580).tint(.blue)
        .alert("Workspace Storage", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func addSession(_ kind: SessionKind) {
        guard let index = selectedIndex else { return }
        let session = Session(kind: kind)
        store.state.workspaces[index].sessions.append(session)
        store.state.workspaces[index].selectedSessionID = session.id
    }

    private func addWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Add Workspace"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let existing = workspaces.first(where: { $0.path == url.path }) {
            selection = existing.id
            return
        }
        let workspace = Workspace(name: url.lastPathComponent, path: url.path)
        store.state.workspaces.append(workspace)
        selection = workspace.id
    }
}

#Preview("Dark") { ContentView(store: .preview()).preferredColorScheme(.dark) }
#Preview("Light") { ContentView(store: .preview()).preferredColorScheme(.light) }
