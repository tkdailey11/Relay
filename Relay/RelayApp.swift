//
//  RelayApp.swift
//  Relay
//
//  Created by Tyler Dailey on 9/15/26.
//

import SwiftUI
import TerminalKit

@main
struct RelayApp: App {
    @NSApplicationDelegateAdaptor(RelayApplicationDelegate.self) private var delegate
    @State private var store: WorkspaceStore
    @State private var settings: SettingsStore

    init() {
        // libghostty's failures are the ones that make Relay useless rather than merely
        // degraded, so TerminalKit's log is joined to Relay's before any terminal can start.
        TerminalDiagnostics.handler = { level, message in
            switch level {
            case .info: RelayLog.info(.terminal, message)
            case .error: RelayLog.error(.terminal, message)
            }
        }
        let bundle = Bundle.main.infoDictionary ?? [:]
        RelayLog.info(.app, "Relay \(bundle["CFBundleShortVersionString"] as? String ?? "?") (\(bundle["CFBundleVersion"] as? String ?? "?")) started on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

        // Launch arguments travel through a shell, which strips quoting from the path, so the
        // UI test hands its workspace over in the environment instead.
        let environment = ProcessInfo.processInfo.environment
        let isUITesting = environment["RELAY_UI_TESTING"] != nil
        // Settings are read before any terminal starts, so the first surface is created under
        // them rather than under the defaults. Under test they come from a suite wiped on every
        // launch, so a run neither depends on nor overwrites real preferences.
        // SessionLauncher still reads command overrides from .standard, which no UI test sets.
        _settings = State(initialValue: SettingsStore(defaults: isUITesting ? Self.testingDefaults() : .standard))
        if isUITesting {
            let store = WorkspaceStore(fileURL: nil)
            if let path = environment["RELAY_UI_TEST_WORKSPACE"] {
                store.addWorkspace(at: URL(filePath: path))
            }
            _store = State(initialValue: store)
        } else {
            _store = State(initialValue: WorkspaceStore())
        }
    }

    private static func testingDefaults() -> UserDefaults {
        let suite = "com.tylerdailey.Relay.uitests"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite) ?? .standard
    }

    var body: some Scene {
        Window("Relay", id: "main") {
            ContentView(store: store)
                .onAppear { delegate.terminals = store.terminals }
        }
        .defaultLaunchBehavior(.presented)
        .defaultSize(width: 1180, height: 780)
        .commands { RelayCommands(settings: settings) }

        Settings {
            SettingsView(settings: settings)
        }
    }
}
