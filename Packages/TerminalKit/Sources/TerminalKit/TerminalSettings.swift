import Foundation

/// The parts of a terminal's appearance Relay lets a user change. Everything else stays with
/// libghostty's defaults, which a user's own `~/Library/Application Support/com.mitchellh.ghostty/config`
/// can still override for keys Relay leaves unset.
public struct TerminalSettings: Equatable, Sendable {
    /// nil uses libghostty's default monospaced face.
    public var fontFamily: String?
    public var fontSize: Double

    public static let minimumFontSize: Double = 6
    public static let maximumFontSize: Double = 72
    public static let `default` = TerminalSettings()

    public init(fontFamily: String? = nil, fontSize: Double = 13) {
        self.fontFamily = fontFamily
        self.fontSize = fontSize
    }

    /// A size outside this range renders a terminal no one can use, and the value arrives from
    /// user defaults, where anything at all can be written.
    public var sanitized: TerminalSettings {
        var copy = self
        copy.fontSize = fontSize.isFinite
            ? min(max(fontSize.rounded(), Self.minimumFontSize), Self.maximumFontSize)
            : Self.default.fontSize
        if let family = fontFamily?.trimmingCharacters(in: .whitespacesAndNewlines) {
            copy.fontFamily = family.isEmpty ? nil : family
        }
        return copy
    }

    /// libghostty takes its configuration as text, so each setting becomes a line in relay.conf.
    var configurationLines: [String] {
        let settings = sanitized
        var lines = ["font-size = \(Int(settings.fontSize))"]
        if let family = settings.fontFamily {
            lines.append("font-family = \(family)")
        }
        return lines
    }
}

/// Relay's entry point for terminal configuration. Setting this before the first terminal starts
/// chooses the configuration every surface is created under; setting it afterwards rewrites that
/// configuration and pushes it into the terminals already on screen.
@MainActor
public enum Terminal {
    public static var settings: TerminalSettings = .default {
        didSet {
            guard settings.sanitized != oldValue.sanitized else { return }
            if case .success(let runtime) = GhosttyRuntime.sharedIfStarted {
                runtime.apply(settings.sanitized)
            }
        }
    }
}
