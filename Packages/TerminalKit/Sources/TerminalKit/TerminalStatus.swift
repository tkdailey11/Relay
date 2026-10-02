import Foundation

public enum TerminalStatus: Equatable, Sendable {
    case starting
    case running
    /// The code is nil when libghostty reported the surface closing without one.
    case exited(code: Int32?)
    case failed(String)
    case closed

    public var label: String {
        switch self {
        case .starting: "Starting"
        case .running: "Running"
        case .exited(let code):
            if let code, code != 0 { "Exited (\(code))" } else { "Exited" }
        case .failed: "Failed"
        case .closed: "Closed"
        }
    }
}
