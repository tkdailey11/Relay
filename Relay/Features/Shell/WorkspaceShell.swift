import SwiftUI

struct WorkspaceShell: View {
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
            TerminalPlaceholder(selectedSession: selectedSession, isExpanded: $isTerminalExpanded,
                                addSession: addSession)
            if !isTerminalExpanded {
                HStack(spacing: 6) {
                    Label("Application shell", systemImage: "circle.dotted")
                    Spacer()
                    Text(isTemporary ? "Temporary · Cleared when Relay quits" : "Session metadata only · No running processes")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(isTerminalExpanded ? 0 : 28).background(.background)
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
                    SessionCard(session: session, isSelected: session.id == selectedSessionID) {
                        selectedSessionID = session.id
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
        selectedSessionID = sessions[index].id
    }

    private func closeSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            selectedSessionID = sessions.first?.id
        }
    }

}
