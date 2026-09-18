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
        if environment["RELAY_UI_TESTING"] != nil {
            let store = WorkspaceStore(fileURL: nil)
            if let path = environment["RELAY_UI_TEST_WORKSPACE"] {
                store.addWorkspace(at: URL(filePath: path))
            }
            _store = State(initialValue: store)
        } else {
            _store = State(initialValue: WorkspaceStore())
        }
    }
    var body: some Scene {
        Window("Relay", id: "main") {
            ContentView(store: store)
                .onAppear { delegate.terminals = store.terminals }
        }
        .defaultLaunchBehavior(.presented)
        .defaultSize(width: 1180, height: 780)
        .commands { RelayCommands() }
    }
}
