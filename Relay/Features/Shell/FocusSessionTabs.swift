import SwiftUI

struct FocusSessionTabs: View {
    let state: (Session) -> SessionState
    let resolve: (Session) -> ResolvedSessionType
    let sessions: [Session]
    let selectedSessionID: Session.ID?
    let selectSession: (Session) -> Void
    let renameSession: (Session) -> Void
    let changeIcon: (Session) -> Void
    let duplicateSession: (Session) -> Void
    let closeSession: (Session) -> Void
    let moveSession: (Session.ID, Int) -> Void
    @State private var reorder = HorizontalReorder(coordinateSpace: "focusSessionTabs", spacing: 4)

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(sessions) { session in
                        let isSelected = session.id == selectedSessionID
                        let type = resolve(session)
                        let title = session.title(type)
                        Button {
                            selectSession(session)
                        } label: {
                            Label(title, systemImage: type.symbol)
                                .lineLimit(1)
                                // Tabs hide every session but the selected one, so a stopped
                                // or failed session would otherwise go unnoticed.
                                .overlay(alignment: .topTrailing) {
                                    let state = state(session)
                                    if state != .running && state != .preview && state != .notStarted {
                                        Circle().fill(state.color).frame(width: 6, height: 6)
                                            .offset(x: 8, y: -4)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                .background(isSelected ? Color.accentColor.opacity(0.12) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                // A plain button only hit-tests what it draws, and an unselected
                                // tab's background is clear, so claim the whole tab explicitly.
                                .contentShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(alignment: .bottom) {
                                    if isSelected && sessions.count > 1 {
                                        Capsule().fill(Color.accentColor).frame(height: 2)
                                            .padding(.horizontal, 10)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        // Simultaneous so the first click still selects without waiting to
                        // rule out a double-click, as Finder and Safari tabs do.
                        .simultaneousGesture(TapGesture(count: 2).onEnded {
                            renameSession(session)
                        })
                        .help("Double-click to rename")
                        .accessibilityLabel("\(title) session")
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        .accessibilityValue(isSelected ? "Selected, \(state(session).label)" : state(session).label)
                        .contextMenu {
                            Button("Rename Session…", systemImage: "pencil") {
                                renameSession(session)
                            }
                            Button("Change Icon…", systemImage: "face.smiling") {
                                changeIcon(session)
                            }
                            Button("Duplicate Session", systemImage: "plus.square.on.square") {
                                duplicateSession(session)
                            }
                            Divider()
                            Button("Move Left", systemImage: "arrow.left") { step(session, by: -1) }
                                .disabled(!sessions.canMove(session.id, by: -1))
                            Button("Move Right", systemImage: "arrow.right") { step(session, by: 1) }
                                .disabled(!sessions.canMove(session.id, by: 1))
                            Divider()
                            Button("Close Session", systemImage: "xmark", role: .destructive) {
                                closeSession(session)
                            }
                        }
                        .horizontallyReorderable(session.id, order: sessions.map(\.id),
                                                 using: reorder, move: moveSession)
                        .id(session.id)
                    }
                }
                .coordinateSpace(.named(reorder.coordinateSpace))
            }
            .scrollIndicators(.hidden)
            .onChange(of: selectedSessionID, initial: true) {
                if let selectedSessionID {
                    proxy.scrollTo(selectedSessionID)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func step(_ session: Session, by offset: Int) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        withAnimation(.snappy) { moveSession(session.id, index + offset) }
    }
}
