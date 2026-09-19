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
    let types: SessionTypeStore
    let addSession: (SessionType) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                if isExpanded && !sessions.isEmpty {
                    FocusSessionTabs(status: terminals.status, resolve: types.resolve,
                                     sessions: sessions, selectedSessionID: selectedSession?.id,
                                     selectSession: selectSession, closeSession: closeSession)
                } else {
                    Label(selectedSession.map { types.resolve($0).name } ?? "Terminal",
                          systemImage: selectedSession.map { types.resolve($0).symbol } ?? "terminal")
                    Spacer()
                }
                if isExpanded {
                    Menu("New Session", systemImage: "plus") {
                        NewSessionMenuItems(types: types.enabled, addSession: addSession)
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
                        // Opt out of the header's .caption so the way back stays easy to hit.
                        .font(.title3)
                        .contentShape(.rect)
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
            // Expand explicitly: an empty-state ContentUnavailableView hugs its content,
            // which would otherwise let the header drift to the middle of the pane.
            TerminalContent(terminals: terminals, selectedSession: selectedSession,
                            focusRequest: focusRequest, types: types, addSession: addSession)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: selectedSession?.id) {
            guard let selectedSession else { return }
            await terminals.prepare(selectedSession, type: types.type(id: selectedSession.typeID),
                                    directory: directory)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colorScheme == .dark ? Color(.relayInk) : Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 16))
        .overlay {
            if !isExpanded {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.07))
            }
        }
    }
}
