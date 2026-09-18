import Foundation
import SwiftUI
import Observation

/// Owns the session types a user can start. Persisted as JSON in UserDefaults so it can be read
/// back, corrected or cleared from the command line if an edit ever makes Relay unusable:
/// `defaults delete com.tylerdailey.Relay RelaySessionTypes`.
@MainActor
@Observable
final class SessionTypeStore {
    static let storageKey = "RelaySessionTypes"
    /// Relay 0.1 kept per-kind command overrides here. They are folded into the presets once.
    static func legacyCommandKey(for name: String) -> String { "RelayCommand.\(name)" }

    private(set) var types: [SessionType] {
        didSet {
            guard types != oldValue else { return }
            save()
        }
    }

    private let defaults: UserDefaults
    var errorMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey) {
            do {
                types = try JSONDecoder().decode([SessionType].self, from: data)
            } catch {
                // A corrupt list would otherwise leave Relay unable to start anything at all.
                types = SessionType.presets
                RelayLog.error(.session, "Could not decode session types, restoring presets: \(error)")
            }
        } else {
            types = Self.migratedPresets(from: defaults)
        }
        ensureShellExists()
    }

    /// Relay 0.1's `defaults write com.tylerdailey.Relay RelayCommand.Copilot "gh copilot"`
    /// escape hatch becomes the preset's command, so an override a tester relied on survives.
    private static func migratedPresets(from defaults: UserDefaults) -> [SessionType] {
        SessionType.presets.map { preset in
            var type = preset
            if let legacy = defaults.string(forKey: legacyCommandKey(for: preset.name)) {
                type.command = legacy
                RelayLog.info(.session, "Migrated the \(preset.name) command override into its session type")
            }
            return type
        }
    }

    /// Relay is a terminal: without a way to start a login shell the empty state and ⌘N have
    /// nothing to do, so the Shell type is restored if a stored list somehow lacks it.
    private func ensureShellExists() {
        guard !types.contains(where: { $0.id == SessionType.shellID }) else { return }
        types.append(SessionType.presets.first { $0.id == SessionType.shellID }!)
    }

    var enabled: [SessionType] {
        types.filter(\.isEnabled)
    }

    /// The type ⌘N and the empty state start. Shell when it is enabled, else the first enabled
    /// type, so those controls always do something.
    var defaultType: SessionType {
        enabled.first { $0.id == SessionType.shellID } ?? enabled.first ?? types[0]
    }

    func type(id: String) -> SessionType? {
        types.first { $0.id == id }
    }

    /// Live values win so renaming a type updates sessions already started from it; a session
    /// whose type was deleted keeps the name it was started under.
    func resolve(_ session: Session) -> ResolvedSessionType {
        if let type = type(id: session.typeID) { return ResolvedSessionType(type) }
        return .missing(named: session.typeName)
    }

    func add(_ type: SessionType) {
        types.append(type)
        RelayLog.info(.session, "Added session type \(type.name) running \(type.command.isEmpty ? "the login shell" : type.command)")
    }

    func update(_ type: SessionType) {
        guard let index = types.firstIndex(where: { $0.id == type.id }) else { return }
        types[index] = type
    }

    func remove(_ id: String) {
        guard let type = type(id: id), type.isRemovable else { return }
        types.removeAll { $0.id == id }
        RelayLog.info(.session, "Removed session type \(type.name); sessions already started from it are unaffected")
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        types.move(fromOffsets: source, toOffset: destination)
    }

    func restorePresets() {
        var restored = types
        for preset in SessionType.presets where !restored.contains(where: { $0.id == preset.id }) {
            restored.append(preset)
        }
        types = restored
    }

    private func save() {
        do {
            defaults.set(try JSONEncoder().encode(types), forKey: Self.storageKey)
        } catch {
            RelayLog.error(.session, "Could not save session types: \(error)")
            errorMessage = "Relay couldn’t save your session types. \(error.localizedDescription)"
        }
    }

    static func preview() -> SessionTypeStore {
        SessionTypeStore(defaults: UserDefaults(suiteName: "RelaySessionTypePreview") ?? .standard)
    }
}
