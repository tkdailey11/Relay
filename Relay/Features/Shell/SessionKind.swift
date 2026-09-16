import SwiftUI

enum SessionKind: String, CaseIterable, Identifiable, Codable {
    case claude = "Claude", copilot = "Copilot", shell = "Shell"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .claude: "sparkle"
        case .copilot: "chevron.left.forwardslash.chevron.right"
        case .shell: "terminal"
        }
    }
    var color: Color {
        switch self {
        case .claude: .orange
        case .copilot: Color(.relayViolet)
        case .shell: .accentColor
        }
    }
}
