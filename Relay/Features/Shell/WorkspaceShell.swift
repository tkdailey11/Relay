import TerminalKit
import SwiftUI

struct WorkspaceShell: View {
    let terminals: TerminalSessionManager
    @State private var sessionPendingClose: Session?
    @State private var showsCloseConfirmation = false
    @State private var focusRequest = UUID()
    let name: String
    let path: String
    @Binding var sessions: [Session]
    @Binding var selectedSessionID: UUID?
    var isTemporary = false
    @Binding var isTerminalExpanded: Bool
    let addSession: (SessionKind) -> Void
    private var selectedSession: Session? {
        sessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Terminal focus hides the workspace chrome rather than overlaying it, so the
            // terminal is never torn down and rebuilt.
            if !isTerminalExpanded {
                WorkspaceHeader(name: name, path: path, sessionCount: sessions.count,
                                isTemporary: isTemporary, addSession: addSession)
                if !sessions.isEmpty {
                    sessionCards
                }
            }
            TerminalPane(terminals: terminals, directory: path, focusRequest: focusRequest,
                         selectedSession: selectedSession, sessions: sessions,
                                selectSession: selectSession, closeSession: closeSession,
                                isExpanded: $isTerminalExpanded,
                                addSession: addSession)
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
        .focusedSceneValue(\.sessionSwitch, SessionSwitchAction(
            titles: sessions.map(\.kind.rawValue),
            selectedIndex: sessions.firstIndex { $0.id == selectedSessionID },
            select: selectSession
        ))
    }

    private var sessionCards: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 12) {
                ForEach(sessions) { session in
                    SessionCard(session: session, status: terminals.status(for: session), isSelected: session.id == selectedSessionID) {
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
