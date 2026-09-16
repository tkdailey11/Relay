import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: WorkspaceStore
    private var workspaces: [Workspace] { store.state.workspaces }
    @State private var isChoosingWorkspace = false
    @State private var isShowingError = false
    private var selectedIndex: Int? {
        workspaces.firstIndex { $0.id == store.state.selectedWorkspaceID }
    }

    var body: some View {
        NavigationSplitView {
            WorkspaceSidebar(store: store, addWorkspace: showWorkspacePicker)
                .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 320)
        } detail: {
            if store.destination == .temporary {
                WorkspaceShell(name: "Temporary Sessions", path: store.temporaryWorkingDirectory,
                               sessions: $store.temporarySessions,
                               selectedSessionID: $store.selectedTemporarySessionID,
                               isTemporary: true, addSession: store.addTemporarySession)
            } else if let index = selectedIndex {
                let workspace = workspaces[index]
                WorkspaceShell(name: workspace.name, path: workspace.path,
                               sessions: $store.state.workspaces[index].sessions,
                               selectedSessionID: $store.state.workspaces[index].selectedSessionID,
                               addSession: { store.addSession($0, to: workspace.id) })
            } else {
                ContentUnavailableView {
                    Label("Your next workspace", systemImage: "folder.badge.plus")
                } description: {
                    Text("Choose a local folder to make room for your sessions.")
                } actions: {
                    Button("Add Workspace", action: showWorkspacePicker)
                }
            }
        }
        .navigationTitle("")
        .frame(minWidth: 860, minHeight: 580).tint(.accentColor)
        .fileImporter(isPresented: $isChoosingWorkspace, allowedContentTypes: [.folder]) { result in
            handleWorkspaceImport(result)
        }
        .onChange(of: store.errorMessage, initial: true) {
            isShowingError = store.errorMessage != nil
        }
        .alert("Relay", isPresented: $isShowingError) {
            Button("OK") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private func showWorkspacePicker() {
        isChoosingWorkspace = true
    }

    private func handleWorkspaceImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            store.addWorkspace(at: url)
        case .failure(let error):
            store.errorMessage = "Relay couldn’t open the selected workspace. \(error.localizedDescription)"
        }
    }
}

#Preview("Dark") { ContentView(store: .preview()).preferredColorScheme(.dark) }
#Preview("Light") { ContentView(store: .preview()).preferredColorScheme(.light) }
