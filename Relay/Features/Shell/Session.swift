import Foundation

struct Session: Identifiable, Codable, Equatable {
    var id = UUID()
    /// References a SessionType by id. The type may later be deleted, which must not disturb a
    /// running session, so the name it was started under is stored alongside.
    var typeID: String
    var typeName: String
    /// Set by the user to tell sessions apart, such as two Claude sessions on different tasks.
    /// Nil shows the type's name, so renaming the type in Settings still reaches the session.
    var customName: String?
    /// An SF Symbol chosen for this session alone. Nil follows the type's icon, so changing
    /// the type in Settings still reaches sessions that never picked their own.
    var symbol: String?

    init(id: UUID = UUID(), type: SessionType) {
        self.id = id
        self.typeID = type.id
        self.typeName = type.name
    }

    init(id: UUID = UUID(), typeID: String, typeName: String) {
        self.id = id
        self.typeID = typeID
        self.typeName = typeName
    }

    private enum CodingKeys: String, CodingKey {
        case id, typeID, typeName, customName, symbol
        /// Relay 0.1 stored a `SessionKind` raw value here: "Claude", "Copilot" or "Shell".
        case kind
    }

    /// Written explicitly because CodingKeys carries the legacy `kind`, which is only ever read.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(typeID, forKey: .typeID)
        try container.encode(typeName, forKey: .typeName)
        try container.encodeIfPresent(customName, forKey: .customName)
        try container.encodeIfPresent(symbol, forKey: .symbol)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        customName = try container.decodeIfPresent(String.self, forKey: .customName)
        symbol = try container.decodeIfPresent(String.self, forKey: .symbol)
        if let typeID = try container.decodeIfPresent(String.self, forKey: .typeID) {
            self.typeID = typeID
            // A snapshot written before typeName existed falls back to the id.
            typeName = try container.decodeIfPresent(String.self, forKey: .typeName) ?? typeID
        } else {
            // The preset ids are the lowercased 0.1 names, so the migration is mechanical and
            // a session started before this release keeps working against its preset.
            let kind = try container.decode(String.self, forKey: .kind)
            typeID = kind.lowercased()
            typeName = kind
        }
    }

    /// Choosing the type's own icon clears the override, like renaming back to the type's name.
    mutating func setSymbol(_ symbol: String?, typeSymbol: String) {
        self.symbol = symbol == typeSymbol ? nil : symbol
    }

    /// A fresh session of the same type and name. Only the launch recipe carries over: the new
    /// terminal starts clean, since a running process can't be cloned.
    func duplicate() -> Session {
        var copy = Session(typeID: typeID, typeName: typeName)
        copy.customName = customName
        copy.symbol = symbol
        return copy
    }

    /// What the UI calls this session: its custom name, falling back to its type's.
    func title(_ type: ResolvedSessionType) -> String {
        customName ?? type.name
    }

    /// A blank name, or the type's own, clears the custom one: the tab never goes untitled,
    /// and a session left on its type's name keeps following that type through renames.
    mutating func rename(to name: String, typeName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        customName = trimmed.isEmpty || trimmed == typeName ? nil : trimmed
    }
}
