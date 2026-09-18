import SwiftUI

/// The enabled session types, offered wherever a new session can be started. Types are user
/// editable, so every one of these lists is built from the store rather than an enum.
struct NewSessionMenuItems: View {
    let types: [SessionType]
    let addSession: (SessionType) -> Void

    var body: some View {
        ForEach(types) { type in
            Button("New \(type.name) Session", systemImage: type.symbol) { addSession(type) }
        }
        if types.isEmpty {
            Button("No Session Types Enabled") {}.disabled(true)
        }
    }
}
