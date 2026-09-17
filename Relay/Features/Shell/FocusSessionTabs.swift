import SwiftUI

struct FocusSessionTabs: View {
    let status: (Session) -> String
    let sessions: [Session]
    let selectedSessionID: Session.ID?
    let selectSession: (Session) -> Void
    let closeSession: (Session) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(sessions) { session in
                        let isSelected = session.id == selectedSessionID
                        Button {
                            selectSession(session)
                        } label: {
                            Label(session.kind.rawValue, systemImage: session.kind.symbol)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                .background(isSelected ? Color.accentColor.opacity(0.12) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .overlay(alignment: .bottom) {
                                    if isSelected && sessions.count > 1 {
                                        Capsule().fill(Color.accentColor).frame(height: 2)
                                            .padding(.horizontal, 10)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(session.kind.rawValue) session")
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                        .accessibilityValue(isSelected ? "Selected, \(status(session))" : status(session))
                        .contextMenu {
                            Button("Close Session", systemImage: "xmark", role: .destructive) {
                                closeSession(session)
                            }
                        }
                        .id(session.id)
                    }
                }
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
}
