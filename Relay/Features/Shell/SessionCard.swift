import SwiftUI

struct SessionCard<MenuContent: View>: View {
    let session: Session
    let type: ResolvedSessionType
    let state: SessionState
    let isSelected: Bool
    let select: () -> Void
    let rename: () -> Void
    @ViewBuilder let menu: () -> MenuContent
    @State private var isHovered = false
    private var title: String { session.title(type) }
    private var status: String { state.label }

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: type.symbol).foregroundStyle(type.color)
                    Text(title).fontWeight(.medium)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor)
                    }
                }
                // Leaves room for the options button, which is overlaid outside the card's
                // button so its clicks are not swallowed by the selection button.
                .padding(.trailing, 22)
                HStack(spacing: 6) {
                    Circle().fill(state.color).frame(width: 6, height: 6)
                    Text(isSelected ? "Selected · \(status)" : status).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16).frame(minWidth: 184, alignment: .leading)
            .glassEffect(glass, in: RoundedRectangle(cornerRadius: 14))
            .contentShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                // A waiting session outranks selection: this is the card the user needs to find.
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(borderColor, lineWidth: needsAttention ? 2 : 1)
            }
        }
        .buttonStyle(.plain).onHover { isHovered = $0 }
        // Simultaneous so the first click still selects without waiting to rule out a
        // double-click, matching the tabs in terminal focus.
        .simultaneousGesture(TapGesture(count: 2).onEnded(rename))
        .help("Double-click to rename")
        // Ignoring the children replaces the button's own element, so the button role and
        // its press have to be restored. Rename is offered too: a double-click is not.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(accessibilityTraits)
        .accessibilityAction { select() }
        .accessibilityAction(named: Text("Rename")) { rename() }
        .accessibilityInputLabels([Text("\(title) session")])
        .accessibilityLabel("\(title) session")
        .accessibilityValue(isSelected ? "Selected, \(status)" : status)
        .overlay(alignment: .topTrailing) { optionsButton }
    }

    private var accessibilityTraits: AccessibilityTraits {
        isSelected ? [.isButton, .isSelected] : .isButton
    }

    private var needsAttention: Bool { state == .needsAttention }

    private var borderColor: Color {
        if needsAttention { return state.color }
        return isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.08)
    }

    /// Selection is carried by a tint rather than a heavier material, so a row of cards
    /// stays calm and the selected one still reads at a glance.
    private var glass: Glass {
        if needsAttention { return .regular.tint(state.color.opacity(0.18)).interactive() }
        return isSelected ? .regular.tint(Color.accentColor.opacity(0.25)).interactive()
                          : .regular.interactive()
    }

    private var optionsButton: some View {
        OptionsMenuButton(isHovered: isHovered,
                          accessibilityTitle: "\(title) session options",
                          menu: menu)
            .padding(.top, 12).padding(.trailing, 10)
    }
}
