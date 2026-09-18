import Foundation
import OSLog

/// TerminalKit's logging. libghostty's initialization and surface failures are the ones that
/// make Relay useless rather than merely degraded, so they go to Console like everything else
/// and, through `handler`, into the report Relay's Help menu produces.
@MainActor
public enum TerminalDiagnostics {
    public enum Level: Sendable {
        case info, error
    }

    /// Installed by the host application. TerminalKit stays unaware of Relay's own logging.
    public static var handler: (@Sendable (Level, String) -> Void)?

    private static let logger = Logger(subsystem: "com.tylerdailey.Relay", category: "terminalkit")

    static func info(_ message: @autoclosure () -> String) {
        let text = message()
        logger.info("\(text, privacy: .private)")
        handler?(.info, text)
    }

    static func error(_ message: @autoclosure () -> String) {
        let text = message()
        logger.error("\(text, privacy: .private)")
        handler?(.error, text)
    }
}
