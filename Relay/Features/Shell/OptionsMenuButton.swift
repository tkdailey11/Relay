import SwiftUI

/// The hover-revealed “…” affordance that mirrors a row's or card's right-click menu, so the
/// same commands are reachable without a secondary click.
struct OptionsMenuButton<MenuContent: View>: View {
    let isHovered: Bool
    let accessibilityTitle: String
    @ViewBuilder let menu: () -> MenuContent

    var body: some View {
        Menu {
            menu()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 6))
                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden)
        .fixedSize()
        // Kept in the hierarchy and faded out rather than removed: an open menu would be
        // dismissed if the button vanished once the pointer moved away.
        .opacity(isHovered ? 1 : 0)
        .allowsHitTesting(isHovered)
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .accessibilityLabel(accessibilityTitle)
        .help(accessibilityTitle)
    }
}
