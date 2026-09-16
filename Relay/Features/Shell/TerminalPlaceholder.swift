import SwiftUI

struct TerminalPlaceholder: View {
    let selectedSession: Session?
    @Binding var isExpanded: Bool
    let addSession: (SessionKind) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(selectedSession?.kind.rawValue ?? "Terminal",
                      systemImage: selectedSession?.kind.symbol ?? "terminal")
                Spacer()
                Text("UI PREVIEW").font(.caption.monospaced())
                // The only chrome left while expanded, so the way back stays on screen.
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.plain)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(isExpanded ? "Collapse terminal" : "Expand terminal")
                .help(isExpanded ? "Collapse terminal (⇧⌘↩)" : "Expand terminal (⇧⌘↩)")
            }
            .font(.caption).foregroundStyle(.secondary).padding(16)
            Divider().opacity(0.5)
            Spacer()
            ContentUnavailableView {
                Label(selectedSession == nil ? "A fresh space to work" : "Your session starts here",
                      systemImage: selectedSession?.kind.symbol ?? "plus.square.dashed")
            } description: {
                Text(selectedSession == nil
                     ? "Choose Claude, Copilot, or Shell to create a session preview."
                     : "The terminal surface is ready for a future connection.")
                Text("No processes are running in this UI preview.")
            } actions: {
                if selectedSession == nil {
                    Button("New Shell Session") { addSession(.shell) }
                        .buttonStyle(.borderedProminent)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color(.relayInk) : Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 0 : 16))
        .overlay {
            if !isExpanded {
                RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.07))
            }
        }
    }
}
