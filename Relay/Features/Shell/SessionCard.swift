import SwiftUI

struct SessionCard: View {
    let session: Session
    let type: ResolvedSessionType
    let status: String
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: type.symbol).foregroundStyle(type.color)
                    Text(type.name).fontWeight(.medium)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
                    Text(isSelected ? "Selected · \(status)" : status).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16).frame(minWidth: 184, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.09) : Color.primary.opacity(isHovered ? 0.06 : 0.025),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain).onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityInputLabels([Text("\(type.name) session")])
        .accessibilityLabel("\(type.name) session")
        .accessibilityValue(isSelected ? "Selected, \(status)" : status)
    }
}
