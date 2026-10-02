import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var store: WorkspaceStore
    let sessionTypes: SessionTypeStore
    private var workspaces: [Workspace] { store.state.workspaces }
    @State private var isChoosingWorkspace = false
    @State private var isShowingError = false
    @State private var isTerminalExpanded = false
    @State private var diagnosticsReport: DiagnosticsReportItem?
    @State private var isShowingQuickSwitcher = false
    /// Applied when the switcher's sheet closes, so the terminal it lands on takes focus in a
    /// key window instead of behind the sheet.
    @State private var pendingSwitch: QuickSwitcherItem?
    /// Most recently jumped-to first, for this launch only.
    @State private var recentItemIDs: [String] = []
    /// A command for the workspace shell to run, which owns the prompts and confirmations that
    /// act on a session. The shell clears it as it takes it.
    @State private var paletteCommand: PaletteCommand?
    @Environment(\.openSettings) private var openSettings
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var sidebarVisibilityBeforeFocus = NavigationSplitViewVisibility.all
    private var selectedIndex: Int? {
        workspaces.firstIndex { $0.id == store.state.selectedWorkspaceID }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            WorkspaceSidebar(store: store, types: sessionTypes, addWorkspace: showWorkspacePicker)
                .navigationSplitViewColumnWidth(min: 230, ideal: 260, max: 320)
        } detail: {
            detail
        }
        .navigationTitle("")
        .frame(minWidth: 860, minHeight: 580).tint(.accentColor)
        // The window itself is the translucent surface; the chrome layers materials on top
        // of it and the terminal pane stays opaque over both.
        .containerBackground(.thinMaterial, for: .window)
        .focusedSceneValue(\.diagnostics, DiagnosticsAction(show: showDiagnostics))
        .sheet(item: $diagnosticsReport) { report in
            DiagnosticsView(report: report.text)
        }
        .focusedSceneValue(\.destinationSwitch, DestinationSwitchAction(
            canStep: store.destinations.count > 1,
            showQuickSwitcher: { isShowingQuickSwitcher = true },
            step: store.selectAdjacentDestination
        ))
        .sheet(isPresented: $isShowingQuickSwitcher, onDismiss: applyPendingSwitch) {
            QuickSwitcherView(items: quickSwitcherItems, recents: recentItemIDs,
                              currentItemID: currentSwitcherItemID,
                              choose: { pendingSwitch = $0 })
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

    @ViewBuilder
    private var detail: some View {
        if store.destination == .temporary {
            WorkspaceShell(terminals: store.terminals, name: "Temporary Sessions",
                           path: store.temporaryWorkingDirectory,
                           sessions: $store.temporarySessions,
                           selectedSessionID: $store.selectedTemporarySessionID,
                           closedSessions: closedSessions(for: .temporary),
                           isTemporary: true, isTerminalExpanded: $isTerminalExpanded,
                           paletteCommand: $paletteCommand,
                           types: sessionTypes,
                           addSession: store.addTemporarySession)
        } else if let index = selectedIndex {
            let workspace = workspaces[index]
            WorkspaceShell(terminals: store.terminals, name: workspace.name, path: workspace.path,
                           sessions: $store.state.workspaces[index].sessions,
                           selectedSessionID: $store.state.workspaces[index].selectedSessionID,
                           closedSessions: closedSessions(for: .workspace(workspace.id)),
                           isTerminalExpanded: $isTerminalExpanded,
                           paletteCommand: $paletteCommand,
                           types: sessionTypes,
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

    private func closedSessions(for destination: SessionDestination) -> Binding<[ClosedSession]> {
        Binding(get: { store.closedSessions[destination] ?? [] },
                set: { store.closedSessions[destination] = $0 })
    }

    private var isShowingShell: Bool {
        store.destination == .temporary || selectedIndex != nil
    }

    private var quickSwitcherItems: [QuickSwitcherItem] {
        QuickSwitcher.items(workspaces: workspaces, temporarySessions: store.temporarySessions,
                            resolve: sessionTypes.resolve, state: store.terminals.state(for:))
            + QuickSwitcher.commands(paletteContext)
    }

    private var paletteContext: PaletteContext {
        let isTemporary = store.destination == .temporary
        let sessions = isTemporary ? store.temporarySessions
            : selectedIndex.map { workspaces[$0].sessions } ?? []
        let selectedID = isTemporary ? store.selectedTemporarySessionID
            : selectedIndex.flatMap { workspaces[$0].selectedSessionID }
        let selected = sessions.first { $0.id == selectedID }
        let closedKey: SessionDestination? = isTemporary ? .temporary
            : selectedIndex.map { .workspace(workspaces[$0].id) }
        let closed = closedKey.flatMap { store.closedSessions[$0]?.first }?.session
        return PaletteContext(
            sessionTypes: sessionTypes.enabled, defaultTypeID: sessionTypes.defaultType.id,
            destinationName: isTemporary ? "Temporary Sessions"
                : selectedIndex.map { workspaces[$0].name } ?? "Temporary Sessions",
            selectedSessionTitle: selected.map { $0.title(sessionTypes.resolve($0)) },
            closedSessionTitle: closed.map { $0.title(sessionTypes.resolve($0)) },
            isTerminalFocused: isShowingShell ? isTerminalExpanded : nil)
    }

    private var currentSwitcherItemID: String? {
        if store.destination == .temporary {
            return store.selectedTemporarySessionID?.uuidString ?? "temporary"
        }
        guard let index = selectedIndex else { return nil }
        return (workspaces[index].selectedSessionID ?? workspaces[index].id).uuidString
    }

    private func applyPendingSwitch() {
        guard let pendingSwitch else { return }
        self.pendingSwitch = nil
        switch pendingSwitch.kind {
        case .destination(let destination):
            remember(pendingSwitch)
            store.select(destination)
        case .session(let destination, let sessionID):
            remember(pendingSwitch)
            store.select(destination, sessionID: sessionID)
        case .command(let command):
            run(command)
        }
    }

    private func remember(_ item: QuickSwitcherItem) {
        recentItemIDs.removeAll { $0 == item.id }
        recentItemIDs.insert(item.id, at: 0)
        if recentItemIDs.count > 8 { recentItemIDs.removeLast() }
    }

    private func run(_ command: PaletteCommand) {
        switch command {
        case .newSession(let typeID):
            guard let type = sessionTypes.enabled.first(where: { $0.id == typeID }) else { return }
            if store.destination == .temporary || selectedIndex == nil {
                store.addTemporarySession(type)
            } else if let index = selectedIndex {
                store.addSession(type, to: workspaces[index].id)
            }
        case .addWorkspace:
            showWorkspacePicker()
        case .toggleTerminalFocus:
            toggleTerminalFocus()
        case .openSettings:
            openSettings()
        case .renameSession, .changeIcon, .duplicateSession, .closeSession, .reopenClosedSession:
            paletteCommand = command
        }
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

#Preview("Dark") {
    ContentView(store: .preview(), sessionTypes: .preview()).preferredColorScheme(.dark)
}
#Preview("Light") {
    ContentView(store: .preview(), sessionTypes: .preview()).preferredColorScheme(.light)
}
