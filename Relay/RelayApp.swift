//
//  RelayApp.swift
//  Relay
//
//  Created by Tyler Dailey on 9/15/26.
//

import SwiftUI

@main
struct RelayApp: App {
    @NSApplicationDelegateAdaptor(RelayApplicationDelegate.self) private var delegate
    @State private var store: WorkspaceStore

    init() {
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
