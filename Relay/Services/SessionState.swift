import SwiftUI
import TerminalKit

/// Where a session's process stands, as far as Relay can tell without watching its output.
/// The label is what the cards and tabs say; the tone is what colors the dot beside it.
enum SessionState: Equatable {
    case preview
    case notStarted
    case starting
    case running
    case exited(code: Int32?)
    case failed

    init(_ status: TerminalStatus) {
        switch status {
        case .starting: self = .starting
        case .running: self = .running
        case .exited(let code): self = .exited(code: code)
        case .failed: self = .failed
        case .closed: self = .notStarted
        }
    }

    var label: String {
        switch self {
        case .preview: "Preview"
        case .notStarted: "Not started"
        case .starting: "Starting"
        case .running: "Running"
        case .exited(let code): TerminalStatus.exited(code: code).label
        case .failed: "Failed"
        }
    }

    /// A non-zero exit reads as a problem, so a crashed agent stands out from one the user
    /// quit on purpose. An exit with no code is given the benefit of the doubt.
    var isProblem: Bool {
        switch self {
        case .failed: true
        case .exited(let code): code.map { $0 != 0 } ?? false
        default: false
        }
    }

    var color: Color {
        switch self {
        case .running: .green
        case .starting: .orange
        case .failed: .red
        case .exited: isProblem ? .red : .secondary.opacity(0.7)
        case .preview, .notStarted: .secondary.opacity(0.5)
        }
    }
}
