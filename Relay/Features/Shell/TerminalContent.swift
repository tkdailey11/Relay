import SwiftUI
import TerminalKit

struct TerminalContent: View {
    let terminals: TerminalSessionManager
    let selectedSession: Session?
    let focusRequest: UUID
    let types: SessionTypeStore
    let addSession: (SessionType) -> Void

    private func name(of session: Session) -> String {
        types.resolve(session).name
    }

    var body: some View {
        if let selectedSession, let terminal = terminals.sessions[selectedSession.id] {
            TerminalView(session: terminal, focusRequest: focusRequest)
                .overlay(alignment: .bottom) {
                    switch terminal.status {
                    case .failed(let message):
                        Text(message).padding().background(.regularMaterial)
                    case .exited:
                        Text("\(name(of: selectedSession)) exited. Create a new \(name(of: selectedSession)) session to continue.")
                            .padding().background(.regularMaterial)
                    default:
                        EmptyView()
                    }
                }
        } else if let selectedSession, let error = terminals.errors[selectedSession.id] {
            ContentUnavailableView("Couldn’t Start \(name(of: selectedSession))",
                                   systemImage: "exclamationmark.triangle",
                                   description: Text(error))
        } else if let selectedSession, !terminals.allowsLaunching {
            ContentUnavailableView("\(name(of: selectedSession)) Preview", systemImage: types.resolve(selectedSession).symbol,
                                   description: Text("This preview launches no processes."))
        } else if let selectedSession {
            ProgressView("Starting \(name(of: selectedSession))…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("A fresh space to work", systemImage: "terminal")
            } description: {
                Text("Start a \(types.defaultType.name) session in this directory.")
            } actions: {
                Button("New \(types.defaultType.name) Session") { addSession(types.defaultType) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
