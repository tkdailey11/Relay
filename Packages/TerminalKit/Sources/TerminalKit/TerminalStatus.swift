import Foundation

public enum TerminalStatus: Equatable, Sendable {
    case starting
    case running
    case exited
    case failed(String)
    case closed

    public var label: String {
        switch self {
        case .starting: "Starting"
        case .running: "Running"
        case .exited: "Exited"
        case .failed: "Failed"
        case .closed: "Closed"
        }
    }
}
