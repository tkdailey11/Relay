import Foundation

struct Session: Identifiable, Codable, Equatable {
    var id = UUID()
    let kind: SessionKind
}
