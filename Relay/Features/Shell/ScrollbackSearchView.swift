import AppKit
import SwiftUI

/// `sheet(item:)` needs identity, and each search is taken against a snapshot of the scrollback
/// at the moment it was opened.
struct ScrollbackSearchItem: Identifiable {
    let id = UUID()
    let sessionName: String
    let scrollback: String
}

struct ScrollbackSearchView: View {
    let sessionName: String
    let scrollback: String
    @State private var query = ""
    @State private var selection: ScrollbackSearch.Match.ID?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    private var matches: [ScrollbackSearch.Match] {
        ScrollbackSearch.matches(for: query, in: scrollback)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search \(sessionName) scrollback", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isSearchFocused)
                    .onSubmit { copySelectedMatch() }
                if !query.isEmpty {
                    Text(countLabel).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
            }
            .padding(16)
            Divider()
            content
            Divider()
            HStack {
                Text("Relay searches the scrollback text. It cannot scroll the terminal to a match yet.")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Copy Line", action: copySelectedMatch)
                    .disabled(selection == nil)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(16)
        }
        .frame(width: 720, height: 460)
        .onAppear { isSearchFocused = true }
    }

    @ViewBuilder
    private var content: some View {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            placeholder("Type to search this session’s scrollback.", symbol: "text.magnifyingglass")
        } else if matches.isEmpty {
            placeholder("No matching lines.", symbol: "questionmark.circle")
        } else {
            List(matches, selection: $selection) { match in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(match.lineNumber)")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                    Text(match.text)
                        .font(.caption.monospaced())
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                .tag(match.id)
            }
            .listStyle(.inset)
        }
    }

    private func placeholder(_ message: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(.tertiary)
            Text(message).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var countLabel: String {
        let count = matches.count
        if count >= ScrollbackSearch.matchLimit { return "\(ScrollbackSearch.matchLimit)+ lines" }
        return count == 1 ? "1 line" : "\(count) lines"
    }

    private func copySelectedMatch() {
        guard let selection, let match = matches.first(where: { $0.id == selection }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(match.text, forType: .string)
    }
}
