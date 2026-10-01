import SwiftUI

/// Type to filter every workspace and session, then Return to jump there. The jump itself is
/// left to `choose`, which the caller applies once the sheet has gone so the terminal it lands
/// on can take focus in a key window.
struct QuickSwitcherView: View {
    let items: [QuickSwitcherItem]
    /// Where the highlight starts, so an empty query opens on what is already showing.
    let currentItemID: String?
    let choose: (QuickSwitcherItem) -> Void
    @State private var query = ""
    @State private var highlightedID: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    private var matches: [QuickSwitcherItem] {
        QuickSwitcher.filter(items, query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Jump to a workspace or session", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit(chooseHighlighted)
                    // Handled here rather than by the list so typing never leaves the field.
                    .onKeyPress(.downArrow) { moveHighlight(by: 1) }
                    .onKeyPress(.upArrow) { moveHighlight(by: -1) }
                    .onKeyPress(.escape) {
                        dismiss()
                        return .handled
                    }
            }
            .padding(16)
            Divider()
            results
            Divider()
            HStack(spacing: 16) {
                hint("↑↓", "Navigate")
                hint("↩", "Open")
                hint("esc", "Close")
                Spacer()
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .frame(width: 560, height: 420)
        .onAppear {
            highlightedID = currentItemID ?? items.first?.id
            isSearchFocused = true
        }
        // A new query starts from its best match, not wherever the old highlight was.
        .onChange(of: query) { highlightedID = matches.first?.id }
    }

    @ViewBuilder
    private var results: some View {
        if matches.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "questionmark.circle").font(.largeTitle).foregroundStyle(.tertiary)
                Text("No matching workspaces or sessions.").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(matches) { item in
                            row(item).id(item.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: highlightedID, initial: true) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
        }
    }

    private func row(_ item: QuickSwitcherItem) -> some View {
        let isHighlighted = item.id == highlightedID
        return Button {
            choose(item)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.symbol)
                    .foregroundStyle(isHighlighted ? .white : item.color)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(isHighlighted ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                if let number = item.shortcutNumber {
                    Text("⌘\(number)").font(.caption.monospaced())
                        .foregroundStyle(isHighlighted ? .white.opacity(0.8) : .secondary)
                }
            }
            // Sessions sit under their destination, as they do in the sidebar's mental model.
            .padding(.leading, item.sessionID == nil ? 8 : 28)
            .padding(.trailing, 8).padding(.vertical, 6)
            .foregroundStyle(isHighlighted ? .white : .primary)
            .background(isHighlighted ? Color.accentColor : .clear, in: .rect(cornerRadius: 6))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.subtitle)")
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).font(.caption.monospaced())
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(.quaternary, in: .rect(cornerRadius: 3))
            Text(label)
        }
    }

    private func moveHighlight(by offset: Int) -> KeyPress.Result {
        let matches = matches
        guard !matches.isEmpty else { return .handled }
        let current = matches.firstIndex { $0.id == highlightedID } ?? -offset
        highlightedID = matches[min(max(current + offset, 0), matches.count - 1)].id
        return .handled
    }

    private func chooseHighlighted() {
        guard let item = matches.first(where: { $0.id == highlightedID }) ?? matches.first else { return }
        choose(item)
        dismiss()
    }
}

#Preview {
    let samples = Workspace.samples
    let items = QuickSwitcher.items(workspaces: samples, temporarySessions: [],
                                    resolve: { session in
        SessionType.presets.first { $0.id == session.typeID }.map(ResolvedSessionType.init)
            ?? .missing(named: session.typeName)
    })
    QuickSwitcherView(items: items, currentItemID: nil, choose: { _ in })
}
