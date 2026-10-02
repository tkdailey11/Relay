import SwiftUI

/// The licenses of the software Relay is built on, drawn from the bundled
/// `THIRD-PARTY-NOTICES.md` the same way Help draws the usage guide. Most of those licenses
/// require the notice to travel with the app, so it is read from the bundle rather than linking
/// to a website that could move.
struct ThirdPartyNoticesView: View {
    static let windowID = "third-party-notices"
    @State private var notices = Result { try UsageGuide.load(resource: "THIRD-PARTY-NOTICES") }

    var body: some View {
        switch notices {
        case .success(let blocks):
            GuideBlocksView(blocks: blocks)
        case .failure:
            ContentUnavailableView("Licenses Aren’t Available", systemImage: "doc.text",
                                   description: Text("The license notices aren’t included in this build."))
        }
    }
}

#Preview {
    ThirdPartyNoticesView().frame(width: 720, height: 760)
}
