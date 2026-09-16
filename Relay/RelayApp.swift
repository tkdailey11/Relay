//
//  RelayApp.swift
//  Relay
//
//  Created by Tyler Dailey on 9/15/26.
//

import SwiftUI

@main
struct RelayApp: App {
    @State private var store = WorkspaceStore()
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .defaultSize(width: 1180, height: 780)
        .commands { RelayCommands() }
    }
}
