import Foundation

/// What Relay keeps of a closed session so it can be started again. Only the launch recipe
/// survives: the process and its scrollback are gone, so reopening gives a fresh terminal.
struct ClosedSession: Identifiable, Equatable {
    let id = UUID()
    let session: Session
    /// Where its card sat, so reopening puts it back instead of at the end.
    let index: Int
}

extension [ClosedSession] {
    /// Enough to undo a few slips without turning the menu into a log.
    static let limit = 10

    /// Newest first, which is the order the menu lists them in.
    mutating func remember(_ session: Session, at index: Int) {
        insert(ClosedSession(session: session, index: index), at: 0)
        if count > Self.limit { removeLast(count - Self.limit) }
    }

    /// Removes and returns the entry, so a session can only be reopened once.
    mutating func take(_ id: ClosedSession.ID) -> ClosedSession? {
        guard let position = firstIndex(where: { $0.id == id }) else { return nil }
        return remove(at: position)
    }
}
