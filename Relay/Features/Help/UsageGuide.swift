import Foundation

/// `Docs/USAGE.md`, bundled with the app and split into the blocks Help draws. SwiftUI's `Text`
/// renders only inline markdown, so Foundation's full parser does the block structure and each
/// block keeps its inline styling (code, emphasis, links) as an `AttributedString`.
///
/// Only the markdown the guide uses is drawn specially. Anything else, such as a block quote,
/// still shows as a plain paragraph rather than disappearing.
enum UsageGuide {
    enum Block: Equatable {
        case heading(level: Int, text: AttributedString)
        case paragraph(AttributedString)
        /// `marker` is nil for a second paragraph inside the same item, which continues it
        /// rather than starting a new bullet.
        case listItem(marker: String?, depth: Int, text: AttributedString)
        case table(header: [AttributedString], rows: [[AttributedString]])
        case code(String)
    }

    enum LoadError: LocalizedError {
        case missing

        var errorDescription: String? { "The Relay guide isn’t included in this build." }
    }

    static func load(from bundle: Bundle = .main) throws -> [Block] {
        guard let url = bundle.url(forResource: "USAGE", withExtension: "md") else { throw LoadError.missing }
        return try blocks(from: String(contentsOf: url, encoding: .utf8))
    }

    static func blocks(from markdown: String) throws -> [Block] {
        let document = try AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .full, failurePolicy: .returnPartiallyParsedIfPossible))
        var blocks: [Block] = []
        var table: (id: Int, header: [AttributedString], rows: [Int: [AttributedString]])?
        var lastListItemID: Int?

        func finishTable() {
            guard let finished = table else { return }
            blocks.append(.table(header: finished.header,
                                 rows: finished.rows.sorted { $0.key < $1.key }.map(\.value)))
            table = nil
        }

        for (intent, range) in document.runs[\.presentationIntent] {
            guard let intent else { continue }
            var text = AttributedString(document[range])
            text.presentationIntent = nil
            // Components run from the innermost block outward.
            let components = intent.components

            if let tableComponent = components.first(where: { if case .table = $0.kind { true } else { false } }) {
                if table?.id != tableComponent.identity {
                    finishTable()
                    table = (tableComponent.identity, [], [:])
                }
                let isHeader = components.contains { $0.kind == .tableHeaderRow }
                let row = components.lazy.compactMap { component -> Int? in
                    if case .tableRow(let index) = component.kind { index } else { nil }
                }.first
                if isHeader {
                    table?.header.append(text)
                } else if let row {
                    table?.rows[row, default: []].append(text)
                }
                continue
            }
            finishTable()

            let kinds = components.map(\.kind)
            if let level = kinds.lazy.compactMap({ kind -> Int? in
                if case .header(let level) = kind { level } else { nil }
            }).first {
                blocks.append(.heading(level: level, text: text))
            } else if kinds.contains(where: { if case .codeBlock = $0 { true } else { false } }) {
                let code = String(text.characters)
                blocks.append(.code(code.hasSuffix("\n") ? String(code.dropLast()) : code))
            } else if let itemIndex = components.firstIndex(where: { if case .listItem = $0.kind { true } else { false } }),
                      case .listItem(let ordinal) = components[itemIndex].kind {
                let lists = kinds.filter { $0 == .orderedList || $0 == .unorderedList }
                let isOrdered = kinds[(itemIndex + 1)...].first { $0 == .orderedList || $0 == .unorderedList } == .orderedList
                let id = components[itemIndex].identity
                let marker = id == lastListItemID ? nil : (isOrdered ? "\(ordinal)." : "•")
                lastListItemID = id
                blocks.append(.listItem(marker: marker, depth: max(lists.count, 1), text: text))
            } else {
                blocks.append(.paragraph(text))
            }
        }
        finishTable()
        return blocks
    }
}
