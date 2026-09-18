import Foundation

struct Session: Identifiable, Codable, Equatable {
    var id = UUID()
    /// References a SessionType by id. The type may later be deleted, which must not disturb a
    /// running session, so the name it was started under is stored alongside.
    var typeID: String
    var typeName: String

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
        case id, typeID, typeName
        /// Relay 0.1 stored a `SessionKind` raw value here: "Claude", "Copilot" or "Shell".
        case kind
    }

    /// Written explicitly because CodingKeys carries the legacy `kind`, which is only ever read.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(typeID, forKey: .typeID)
        try container.encode(typeName, forKey: .typeName)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
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
}
