import AppKit
import GhosttyKit

@MainActor
final class GhosttyRuntime {
    // libghostty global initialization and argv have process lifetime.
    private static var storage: Result<GhosttyRuntime, Error>?
    static var shared: Result<GhosttyRuntime, Error> {
        if let storage { return storage }
        let result = Result { try GhosttyRuntime() }
        storage = result
        return result
    }
    /// Settings can be chosen before any terminal exists, and reading them must not be what
    /// starts libghostty; until then the new values simply go into the first configuration.
    static var sharedIfStarted: Result<GhosttyRuntime, Error>? { storage }

    let app: ghostty_app_t
    private var config: ghostty_config_t
    private var settings: TerminalSettings
    private var observers: [NSObjectProtocol] = []
    private var appearanceObservation: NSKeyValueObservation?
    private let themes: (light: URL, dark: URL)
    /// libghostty reads a surface's command from the app configuration it was created under, and
    /// every config handed to ghostty_app_update_config has to outlive the surfaces that read it,
    /// so each distinct command keeps its config for the life of the process.
    private var commandConfigs: [String: ghostty_config_t] = [:]
    /// Configurations replaced by a settings change. A surface reads its configuration lazily,
    /// so the one it was created under is never freed.
    private var retired: [ghostty_config_t] = []
    /// Live surfaces, so a settings change reaches terminals already on screen.
    private let surfaces = NSHashTable<GhosttySurfaceView>.weakObjects()

    private init() throws {
        guard let resources = Bundle.module.url(forResource: "ghostty", withExtension: nil),
              let light = Bundle.module.url(forResource: "RelayLight", withExtension: nil),
              let dark = Bundle.module.url(forResource: "RelayDark", withExtension: nil) else {
            throw TerminalError.initialization("Bundled Ghostty resources are missing. Run Scripts/BuildGhostty.sh and rebuild.")
        }
        setenv("GHOSTTY_RESOURCES_DIR", resources.path, 1)
        let arguments = ["relay"]
        let argv = UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>.allocate(capacity: arguments.count + 1)
        for (index, argument) in arguments.enumerated() { argv[index] = strdup(argument) }
        argv[arguments.count] = nil
        guard ghostty_init(UInt(arguments.count), argv) == GHOSTTY_SUCCESS else {
            throw TerminalError.initialization("libghostty initialization failed.")
        }
        let settings = Terminal.settings.sanitized
        self.settings = settings
        self.themes = (light, dark)
        self.config = try Self.makeConfig(light: light, dark: dark, settings: settings, command: nil)
        var callbacks = ghostty_runtime_config_s()
        callbacks.supports_selection_clipboard = false
        callbacks.wakeup_cb = { _ in
            DispatchQueue.main.async {
                if case .success(let runtime) = GhosttyRuntime.shared { ghostty_app_tick(runtime.app) }
            }
        }
        callbacks.action_cb = { _, target, action in
            MainActor.assumeIsolated {
                guard target.tag == GHOSTTY_TARGET_SURFACE,
                      let surface = target.target.surface,
                      let userdata = ghostty_surface_userdata(surface) else { return false }
                let view = Unmanaged<GhosttySurfaceView>.fromOpaque(userdata).takeUnretainedValue()
                switch action.tag {
                case GHOSTTY_ACTION_SHOW_CHILD_EXITED:
                    view.processExited()
                    return true
                case GHOSTTY_ACTION_SET_TITLE, GHOSTTY_ACTION_PWD,
                     GHOSTTY_ACTION_CELL_SIZE, GHOSTTY_ACTION_INITIAL_SIZE,
                     GHOSTTY_ACTION_SIZE_LIMIT:
                    return true
                case GHOSTTY_ACTION_RING_BELL:
                    NSSound.beep()
                    return true
                default:
                    return false
                }
            }
        }
        callbacks.read_clipboard_cb = { userdata, location, state in
            MainActor.assumeIsolated {
                guard let view = GhosttySurfaceView.from(userdata), let surface = view.surface else { return }
                let text = location == GHOSTTY_CLIPBOARD_STANDARD
                    ? NSPasteboard.general.string(forType: .string) ?? "" : ""
                text.withCString { ghostty_surface_complete_clipboard_request(surface, $0, state, false) }
            }
        }
        callbacks.confirm_read_clipboard_cb = { userdata, text, state, request in
            MainActor.assumeIsolated {
                guard let view = GhosttySurfaceView.from(userdata), let text else { return }
                view.confirmClipboard(String(cString: text), state: state, request: request)
            }
        }
        callbacks.write_clipboard_cb = { userdata, text, location, confirm in
            MainActor.assumeIsolated {
                guard location == GHOSTTY_CLIPBOARD_STANDARD, let text,
                      let view = GhosttySurfaceView.from(userdata) else { return }
                let value = String(cString: text)
                if confirm {
                    view.confirmClipboard(value, state: nil, request: GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE)
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
            }
        }
        callbacks.close_surface_cb = { userdata, _ in
            MainActor.assumeIsolated { GhosttySurfaceView.from(userdata)?.processExited() }
        }
        guard let app = ghostty_app_new(&callbacks, self.config) else {
            ghostty_config_free(self.config)
            throw TerminalError.initialization("libghostty could not create its runtime.")
        }
        self.app = app
        ghostty_app_set_focus(app, NSApp.isActive)
        // The app's scheme, not the surface's, is what resolves `theme = light:…,dark:…`.
        // ghostty_surface_set_color_scheme only reports the scheme to the running program.
        syncColorScheme()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.syncColorScheme() }
        }
        for name in [NSApplication.didBecomeActiveNotification, NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    ghostty_app_set_focus(self.app, NSApp.isActive)
                }
            })
        }
    }

    private func syncColorScheme() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ghostty_app_set_color_scheme(app, dark ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT)
    }

    /// libghostty ignores the `command` field of ghostty_surface_config_s in 1.2.3, but honours
    /// `command` from the configuration a surface is created under, so the app configuration is
    /// swapped to one carrying this command for the duration of the call and restored after.
    /// Only `command` differs between them, and it is read once at spawn, so surfaces already
    /// running are unaffected by the swap.
    func withCommand<T>(_ command: String?, _ body: () throws -> T) rethrows -> T {
        guard let command, !command.isEmpty else { return try body() }
        guard let scoped = try? configuration(for: command) else { return try body() }
        ghostty_app_update_config(app, scoped)
        defer { ghostty_app_update_config(app, config) }
        return try body()
    }

    private func configuration(for command: String) throws -> ghostty_config_t {
        if let existing = commandConfigs[command] { return existing }
        let scoped = try Self.makeConfig(light: themes.light, dark: themes.dark,
                                         settings: settings, command: command)
        commandConfigs[command] = scoped
        return scoped
    }

    private static func makeConfig(light: URL, dark: URL, settings: TerminalSettings,
                                   command: String?) throws -> ghostty_config_t {
        guard let config = ghostty_config_new() else {
            throw TerminalError.initialization("libghostty could not allocate its configuration.")
        }
        do {
            try loadSettings(into: config, light: light, dark: dark, settings: settings, command: command)
        } catch {
            ghostty_config_free(config)
            throw error
        }
        ghostty_config_finalize(config)
        if ghostty_config_diagnostics_count(config) > 0 {
            let diagnostic = ghostty_config_get_diagnostic(config, 0)
            let message = diagnostic.message.map { String(cString: $0) } ?? "Invalid terminal configuration."
            ghostty_config_free(config)
            throw TerminalError.initialization(message)
        }
        return config
    }

    func register(_ view: GhosttySurfaceView) {
        surfaces.add(view)
    }

    /// Rewrites the configuration and pushes it into the terminals already on screen. A bad
    /// value is rejected by libghostty's own diagnostics, in which case the previous settings
    /// stay in force rather than the terminal breaking.
    func apply(_ settings: TerminalSettings) {
        guard settings != self.settings else { return }
        do {
            let updated = try Self.makeConfig(light: themes.light, dark: themes.dark,
                                              settings: settings, command: nil)
            // Never freed: a surface reads the configuration it was created under lazily.
            retired.append(config)
            retired.append(contentsOf: commandConfigs.values)
            commandConfigs.removeAll()
            config = updated
            self.settings = settings
            ghostty_app_update_config(app, updated)
            for view in surfaces.allObjects { view.applyConfiguration(updated) }
            TerminalDiagnostics.info("Applied terminal settings: \(settings.fontFamily ?? "default font") at \(Int(settings.fontSize))pt, \(surfaces.allObjects.count) surface(s)")
        } catch {
            TerminalDiagnostics.error("Could not apply terminal settings: \(error.localizedDescription)")
        }
    }

    /// A filesystem-safe directory name per command. Swift's own hashValue is seeded per process,
    /// which would leave a new directory behind on every launch, so this is an explicit FNV-1a.
    private static func directoryName(for command: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in command.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    /// libghostty takes settings from configuration files only. `ghostty_config_load_cli_args`
    /// parses Relay's real command line — the argv handed to `ghostty_init` is ignored — so every
    /// argument libghostty doesn't recognize, whether Xcode's, a UI test's or the user's, becomes a
    /// fatal diagnostic and the terminal never starts. Write the settings to a file Relay owns and
    /// point XDG_CONFIG_HOME at it instead, which also keeps the user's ~/.config/ghostty/config
    /// out. `config-file` is applied after the default files, so these values are the last word;
    /// a user's ~/Library/Application Support/com.mitchellh.ghostty/config still supplies keys
    /// Relay leaves unset.
    private static func loadSettings(into config: ghostty_config_t, light: URL, dark: URL,
                                     settings: TerminalSettings, command: String? = nil) throws {
        // Each command needs its own XDG_CONFIG_HOME because libghostty only ever reads
        // `ghostty/config` beneath it.
        let base = URL.applicationSupportDirectory.appending(path: "Relay/Terminal")
        let root = command.map { base.appending(path: "commands/\(Self.directoryName(for: $0))") } ?? base
        let file = root.appending(path: "relay.conf")
        do {
            try FileManager.default.createDirectory(at: root.appending(path: "ghostty"),
                                                    withIntermediateDirectories: true)
            try """
                theme = light:\(light.path),dark:\(dark.path)
                keybind = clear
                \(settings.configurationLines.joined(separator: "\n"))
                window-padding-x = 8
                window-padding-y = 8
                clipboard-read = ask
                clipboard-write = ask
                \(command.map { "command = \($0)\n" } ?? "")
                """.write(to: file, atomically: true, encoding: .utf8)
            try "config-file = \(file.path)\n"
                .write(to: root.appending(path: "ghostty/config"), atomically: true, encoding: .utf8)
        } catch {
            throw TerminalError.initialization("Relay couldn’t write its terminal settings. \(error.localizedDescription)")
        }
        // Shells inherit this process's environment, and XDG_CONFIG_HOME belongs to the user's
        // own tools, so it is restored before any surface can spawn one.
        let inherited = getenv("XDG_CONFIG_HOME").map { String(cString: $0) }
        setenv("XDG_CONFIG_HOME", root.path, 1)
        defer {
            if let inherited { setenv("XDG_CONFIG_HOME", inherited, 1) } else { unsetenv("XDG_CONFIG_HOME") }
        }
        ghostty_config_load_default_files(config)
        ghostty_config_load_recursive_files(config)
    }
}
