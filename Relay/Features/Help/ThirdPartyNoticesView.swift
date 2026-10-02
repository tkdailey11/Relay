import SwiftUI

/// The licenses of the software Relay is built on, shown as the bundled `THIRD-PARTY-NOTICES.md`
/// text. Most of those licenses require the notice to travel with the app, so it is read from
/// the bundle rather than linking to a website that could move.
struct ThirdPartyNoticesView: View {
    static let windowID = "third-party-notices"
    @State private var lines = Result { try Self.load() }

    private enum LoadError: LocalizedError {
        case missing

        var errorDescription: String? { "The license notices aren’t included in this build." }
    }

    private static func load(from bundle: Bundle = .main) throws -> [String] {
        guard let url = bundle.url(forResource: "THIRD-PARTY-NOTICES", withExtension: "md") else {
            throw LoadError.missing
        }
        return try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
    }

    var body: some View {
        switch lines {
        case .success(let lines):
            ScrollView {
                // The file is long, and one Text for all of it would be laid out up front.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.callout.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(24)
                .textSelection(.enabled)
            }
        case .failure(let error):
            ContentUnavailableView("Licenses Aren’t Available", systemImage: "doc.text",
                                   description: Text(error.localizedDescription))
        }
    }
}

#Preview {
    ThirdPartyNoticesView().frame(width: 720, height: 760)
}
