import Foundation

enum SessionDestination: Hashable {
    case workspace(UUID)
    case temporary
}
