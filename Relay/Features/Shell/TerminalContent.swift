import SwiftUI
import TerminalKit

struct TerminalContent: View {
    let terminals: TerminalSessionManager
    let selectedSession: Session?
    let focusRequest: UUID
    let addSession: (SessionKind) -> Void

    var body: some View {
        if let selectedSession, let terminal = terminals.sessions[selectedSession.id] {
            TerminalView(session: terminal, focusRequest: focusRequest)
                .overlay(alignment: .bottom) {
                    switch terminal.status {
                    case .failed(let message):
                        Text(message).padding().background(.regularMaterial)
                    case .exited:
                        Text("Shell exited. Create a new Shell session to continue.")
                            .padding().background(.regularMaterial)
                    default:
                        EmptyView()
                    }
                }
        } else if let selectedSession, let error = terminals.errors[selectedSession.id] {
            ContentUnavailableView("Couldn’t Start Shell", systemImage: "exclamationmark.triangle",
                                   description: Text(error))
        } else if let selectedSession, selectedSession.kind != .shell || !terminals.allowsLaunching {
            ContentUnavailableView("\(selectedSession.kind.rawValue) Preview", systemImage: selectedSession.kind.symbol,
                                   description: Text("This launcher is not connected yet. Start a Shell session to use the terminal."))
        } else if selectedSession != nil {
            ProgressView("Starting shell…").frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("A fresh space to work", systemImage: "terminal")
            } description: {
                Text("Start a Shell session in this directory.")
            } actions: {
                Button("New Shell Session") { addSession(.shell) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
