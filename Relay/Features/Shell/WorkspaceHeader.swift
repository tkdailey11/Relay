import SwiftUI

struct WorkspaceHeader: View {
    let name: String
    let path: String
    let sessionCount: Int
    let isTemporary: Bool
    let addSession: (SessionKind) -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: isTemporary ? "terminal" : "folder.fill").font(.title2).foregroundStyle(.blue)
                .accessibilityHidden(true)
                .frame(width: 48, height: 48)
                .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(name).font(.title).bold()
                    .lineLimit(1).truncationMode(.middle)
                    .help(name)
                Text(path).font(.callout).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text("^[\(sessionCount) session](inflect: true)")
                .font(.caption).foregroundStyle(.secondary)
            Menu {
                ForEach(SessionKind.allCases) { kind in
                    Button("New \(kind.rawValue) Session", systemImage: kind.symbol) { addSession(kind) }
                }
            } label: {
                Label("New Session", systemImage: "plus")
            }
            .help(isTemporary ? "New temporary session" : "New session in \(name)")
        }
    }
}
