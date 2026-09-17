import SwiftUI
import TerminalKit

struct TerminalPane: View {
    let terminals: TerminalSessionManager
    let directory: String
    let focusRequest: UUID
    let selectedSession: Session?
    let sessions: [Session]
    let selectSession: (Session) -> Void
    let closeSession: (Session) -> Void
    @Binding var isExpanded: Bool
    let addSession: (SessionKind) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if isExpanded && !sessions.isEmpty {
                    FocusSessionTabs(status: terminals.status, sessions: sessions, selectedSessionID: selectedSession?.id,
                                     selectSession: selectSession, closeSession: closeSession)
                } else {
                    Label(selectedSession?.kind.rawValue ?? "Terminal",
                          systemImage: selectedSession?.kind.symbol ?? "terminal")
                    Spacer()
                }
                if isExpanded {
                    Menu("New Session", systemImage: "plus") {
                        ForEach(SessionKind.allCases) { kind in
                            Button("New \(kind.rawValue) Session", systemImage: kind.symbol) {
                                addSession(kind)
                            }
                        }
                    }
                    .labelStyle(.iconOnly)
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("New session in the current destination")
                }
                Text(selectedSession.map { terminals.status(for: $0) } ?? "").font(.caption.monospaced())
                // Keep the way back visible even when the tabs overflow.
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(isExpanded ? "Collapse terminal" : "Expand terminal")
                .help(isExpanded ? "Collapse terminal (⇧⌘↩)" : "Expand terminal (⇧⌘↩)")
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, isExpanded ? 12 : 16)
            .padding(.vertical, isExpanded ? 6 : 16)
            Divider().opacity(0.5)
            TerminalContent(terminals: terminals, selectedSession: selectedSession,
                            focusRequest: focusRequest, addSession: addSession)
        }
        .task(id: selectedSession?.id) {
            if let selectedSession { terminals.prepare(selectedSession, directory: directory) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color(.relayInk) : Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 16))
        .overlay {
            if !isExpanded {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.07))
            }
        }
    }
}
