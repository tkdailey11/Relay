import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: WorkspaceStore
    private var workspaces: [Workspace] { store.state.workspaces }
    @State private var isChoosingWorkspace = false
    @State private var isShowingError = false
    @State private var isTerminalExpanded = false
    @State private var diagnosticsReport: DiagnosticsReportItem?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var sidebarVisibilityBeforeFocus = NavigationSplitViewVisibility.all
    private var selectedIndex: Int? {
        workspaces.firstIndex { $0.id == store.state.selectedWorkspaceID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WorkspaceSidebar(store: store, addWorkspace: showWorkspacePicker)
                .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 320)
        } detail: {
            if store.destination == .temporary {
                WorkspaceShell(terminals: store.terminals, name: "Temporary Sessions", path: store.temporaryWorkingDirectory,
                               sessions: $store.temporarySessions,
                               selectedSessionID: $store.selectedTemporarySessionID,
                               isTemporary: true, isTerminalExpanded: $isTerminalExpanded,
                               addSession: store.addTemporarySession)
            } else if let index = selectedIndex {
                let workspace = workspaces[index]
                WorkspaceShell(terminals: store.terminals, name: workspace.name, path: workspace.path,
                               sessions: $store.state.workspaces[index].sessions,
                               selectedSessionID: $store.state.workspaces[index].selectedSessionID,
                               isTerminalExpanded: $isTerminalExpanded,
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
        .focusedSceneValue(\.diagnostics, DiagnosticsAction(show: showDiagnostics))
        .sheet(item: $diagnosticsReport) { report in
            DiagnosticsView(report: report.text)
        }
        .focusedSceneValue(\.terminalFocus, isShowingShell
                           ? TerminalFocusAction(isExpanded: isTerminalExpanded, toggle: toggleTerminalFocus)
                           : nil)
        .onChange(of: isShowingShell) { _, isShowing in
            if !isShowing { isTerminalExpanded = false }
        }
        // Keyed off the state itself so the menu command and the terminal's own button
        // move the sidebar identically.
        .onChange(of: isTerminalExpanded) { _, isExpanded in
            if isExpanded {
                sidebarVisibilityBeforeFocus = columnVisibility
                columnVisibility = .detailOnly
            } else {
                columnVisibility = sidebarVisibilityBeforeFocus
            }
        }
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

    private var isShowingShell: Bool {
        store.destination == .temporary || selectedIndex != nil
    }

    // Built on demand: the report is a snapshot of the moment the user asked for it.
    private func showDiagnostics() {
        diagnosticsReport = DiagnosticsReportItem(text: DiagnosticsReport.make(store: store))
    }

    private func showWorkspacePicker() {
        isChoosingWorkspace = true
    }

    // Deliberately unanimated: the terminal should resize once rather than reflow its
    // grid on every frame of a transition.
    private func toggleTerminalFocus() {
        isTerminalExpanded.toggle()
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
