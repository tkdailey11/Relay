import TerminalKit
import SwiftUI

struct WorkspaceShell: View {
    let terminals: TerminalSessionManager
    @State private var sessionPendingClose: Session?
    @State private var showsCloseConfirmation = false
    @State private var focusRequest = UUID()
    @State private var scrollbackSearch: ScrollbackSearchItem?
    let name: String
    let path: String
    @Binding var sessions: [Session]
    @Binding var selectedSessionID: UUID?
    var isTemporary = false
    @Binding var isTerminalExpanded: Bool
    let types: SessionTypeStore
    let addSession: (SessionType) -> Void
    private var selectedSession: Session? {
        sessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Terminal focus hides the workspace chrome rather than overlaying it, so the
            // terminal is never torn down and rebuilt.
            if !isTerminalExpanded {
                WorkspaceHeader(name: name, path: path, sessionCount: sessions.count,
                                isTemporary: isTemporary, types: types.enabled, addSession: addSession)
                if !sessions.isEmpty {
                    sessionCards
                }
            }
            TerminalPane(terminals: terminals, directory: path, focusRequest: focusRequest,
                         selectedSession: selectedSession, sessions: sessions,
                                selectSession: selectSession, closeSession: closeSession,
                                isExpanded: $isTerminalExpanded,
                                types: types, addSession: addSession)
            if !isTerminalExpanded {
                HStack(spacing: 6) {
                    Label("Terminal", systemImage: "terminal")
                    Spacer()
                    Text(isTemporary ? "Temporary · Cleared when Relay quits" : "Shell sessions run locally · Processes end when Relay quits")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(isTerminalExpanded ? 0 : 28).background(.background)
        .confirmationDialog("Close this session?", isPresented: $showsCloseConfirmation, titleVisibility: .visible) {
            Button("Close Session", role: .destructive) {
                if let sessionPendingClose { finishClosing(sessionPendingClose) }
                sessionPendingClose = nil
            }
        } message: {
            Text("The process running in this terminal will be stopped.")
        }
        .onChange(of: isTerminalExpanded) { focusRequest = UUID() }
        .sheet(item: $scrollbackSearch) { item in
            ScrollbackSearchView(sessionName: item.sessionName, scrollback: item.scrollback)
        }
        .focusedSceneValue(\.newSession, NewSessionAction(destinationName: name, add: addSession))
        // Nil until the selected session has a live terminal, which is what disables the
        // Terminal menu rather than letting it act on nothing.
        .focusedSceneValue(\.activeTerminal, activeTerminal)
        .focusedSceneValue(\.scrollbackSearch, activeTerminal.map { _ in
            ScrollbackSearchAction(show: showScrollbackSearch)
        })
        .focusedSceneValue(\.sessionSwitch, SessionSwitchAction(
            titles: sessions.map { types.resolve($0).name },
            selectedIndex: sessions.firstIndex { $0.id == selectedSessionID },
            select: selectSession
        ))
    }

    private var sessionCards: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(sessions) { session in
                    SessionCard(session: session, type: types.resolve(session),
                                status: terminals.status(for: session),
                                isSelected: session.id == selectedSessionID) {
                        selectSession(session)
                    }
                    .contextMenu {
                        Button("Close Session", systemImage: "xmark", role: .destructive) {
                            closeSession(session)
                        }
                    }
                }
            }.padding(3)
        }
        .fixedSize(horizontal: false, vertical: true)
        .scrollIndicators(.hidden)
    }

    private var activeTerminal: ActiveTerminalAction? {
        guard let selectedSession, let terminal = terminals.sessions[selectedSession.id] else { return nil }
        return ActiveTerminalAction(
            sessionName: types.resolve(selectedSession).name,
            perform: { terminal.perform($0) },
            scrollback: { terminal.scrollbackText }
        )
    }

    /// Read once when the sheet opens: a live terminal keeps producing output, and a result
    /// list that reshuffled underneath the user would be worse than a snapshot.
    private func showScrollbackSearch() {
        guard let activeTerminal else { return }
        scrollbackSearch = ScrollbackSearchItem(sessionName: activeTerminal.sessionName,
                                                scrollback: activeTerminal.scrollback())
    }

    private func selectSession(at index: Int) {
        guard sessions.indices.contains(index) else { return }
        selectSession(sessions[index])
    }

    private func selectSession(_ session: Session) {
        selectedSessionID = session.id
        focusRequest = UUID()
    }

    private func closeSession(_ session: Session) {
        if terminals.sessions[session.id]?.requiresCloseConfirmation == true {
            sessionPendingClose = session
            showsCloseConfirmation = true
        } else {
            finishClosing(session)
        }
    }

    private func finishClosing(_ session: Session) {
        terminals.close(session.id)
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            selectedSessionID = sessions.first?.id
        }
    }

}
