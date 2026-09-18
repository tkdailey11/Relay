import Foundation
import OSLog

/// Relay's loggers, one per area, so a tester's `log stream --predicate 'subsystem == "…"'`
/// or a sysdiagnose carries something readable.
///
/// os.Logger redacts interpolated strings by default, which is right for Console but leaves the
/// paths and command lines that explain most failures unreadable when reading back one's own
/// logs. Everything logged here is therefore also appended to `DiagnosticLog`, an in-memory
/// buffer the user can review and copy from the Help menu.
enum RelayLog {
    enum Category: String, CaseIterable {
        case app, workspace, session, terminal
    }

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tylerdailey.Relay"
    private static let loggers: [Category: Logger] = Dictionary(
        uniqueKeysWithValues: Category.allCases.map { ($0, Logger(subsystem: subsystem, category: $0.rawValue)) }
    )

    static func info(_ category: Category, _ message: @autoclosure () -> String) {
        let text = message()
        loggers[category]?.info("\(text, privacy: .private)")
        DiagnosticLog.shared.record(category: category, level: .info, message: text)
    }

    static func error(_ category: Category, _ message: @autoclosure () -> String) {
        let text = message()
        loggers[category]?.error("\(text, privacy: .private)")
        DiagnosticLog.shared.record(category: category, level: .error, message: text)
    }
}

/// A bounded, in-process record of what Relay did this run. It exists so a beta tester can hand
/// over something actionable without a sysdiagnose, and so nothing leaves the machine unless
/// they copy it themselves.
nonisolated final class DiagnosticLog: @unchecked Sendable {
    static let shared = DiagnosticLog()

    struct Entry: Equatable {
        let date: Date
        let category: RelayLog.Category
        let level: Level
        let message: String
    }

    enum Level: String, Equatable {
        case info = "INFO"
        case error = "ERROR"
    }

    /// Enough to cover a session's worth of launches without letting a chatty failure loop grow
    /// without bound.
    private let limit: Int
    private let lock = NSLock()
    private var storage: [Entry] = []

    init(limit: Int = 400) {
        self.limit = limit
    }

    var entries: [Entry] {
        lock.withLock { storage }
    }

    func record(category: RelayLog.Category, level: Level, message: String) {
        lock.withLock {
            storage.append(Entry(date: Date(), category: category, level: level, message: message))
            if storage.count > limit { storage.removeFirst(storage.count - limit) }
        }
    }

    func clear() {
        lock.withLock { storage.removeAll() }
    }
}
