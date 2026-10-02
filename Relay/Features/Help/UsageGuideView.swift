import SwiftUI

/// The Help window: the bundled usage guide drawn with system text styles, so it follows the
/// appearance and text size like the rest of Relay rather than looking like a web page.
struct UsageGuideView: View {
    static let windowID = "help"
    @State private var guide = Result { try UsageGuide.load() }

    var body: some View {
        switch guide {
        case .success(let blocks):
            GuideBlocksView(blocks: blocks)
        case .failure(let error):
            ContentUnavailableView("Help Isn’t Available", systemImage: "questionmark.circle",
                                   description: Text(error.localizedDescription))
        }
    }
}

/// The scrolling page both Help windows draw their blocks into. Lazy, because the license
/// notices hold a few blocks of over a thousand lines each.
struct GuideBlocksView: View {
    let blocks: [UsageGuide.Block]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    BlockView(block: block)
                }
            }
            // A readable line length; wider windows just get more margin.
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 32).padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .textSelection(.enabled)
        }
    }
}

private struct BlockView: View {
    let block: UsageGuide.Block

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(level == 1 ? .largeTitle : level == 2 ? .title2 : .title3)
                .bold()
                .padding(.top, level == 1 ? 0 : 12)
                .accessibilityAddTraits(.isHeader)
        case .paragraph(let text):
            Text(text).fixedSize(horizontal: false, vertical: true)
        case .listItem(let marker, let depth, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Kept as wide as a marker even when continuing an item, so text stays aligned.
                Text(marker ?? "•").opacity(marker == nil ? 0 : 1)
                    .frame(minWidth: 14, alignment: .trailing)
                    .accessibilityHidden(true)
                Text(text).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, CGFloat(depth - 1) * 20)
        case .table(let header, let rows):
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow { ForEach(Array(header.enumerated()), id: \.offset) { Text($1).bold() } }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow { ForEach(Array(row.enumerated()), id: \.offset) { Text($1) } }
                }
            }
            .padding(14)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        case .code(let code):
            Text(code).font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}

#Preview {
    UsageGuideView().frame(width: 720, height: 760)
}
