import Foundation

public enum TerminalError: LocalizedError, Equatable {
    case invalidDirectory(String)
    case initialization(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDirectory(let path): "The terminal’s working directory is unavailable: \(path)"
        case .initialization(let message): "The terminal couldn’t start. \(message)"
        }
    }
}
