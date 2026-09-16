import SwiftUI

struct WorkspaceShell: View {
    let name: String
    let path: String
    @Binding var sessions: [Session]
    @Binding var selectedSessionID: UUID?
    var isTemporary = false
    let addSession: (SessionKind) -> Void
    private var selectedSession: Session? {
        sessions.first { $0.id == selectedSessionID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            WorkspaceHeader(name: name, path: path, sessionCount: sessions.count,
                            isTemporary: isTemporary, addSession: addSession)
            if !sessions.isEmpty {
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
            TerminalPlaceholder(selectedSession: selectedSession, addSession: addSession)
            HStack(spacing: 6) {
                Label("Application shell", systemImage: "circle.dotted")
                Spacer()
                Text(isTemporary ? "Temporary · Cleared when Relay quits" : "Session metadata only · No running processes")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).background(.background)
    }

    private func closeSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            selectedSessionID = sessions.first?.id
        }
    }

}
