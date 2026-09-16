import SwiftUI

struct WorkspaceShell: View {
    @Binding var workspace: Workspace
    let addSession: (SessionKind) -> Void
    @Environment(\.colorScheme) private var colorScheme
    private var selectedSession: Session? {
        workspace.sessions.first { $0.id == workspace.selectedSessionID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 14) {
                Image(systemName: "folder.fill").font(.title2).foregroundStyle(.blue)
                    .frame(width: 48, height: 48)
                    .background(.blue.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(workspace.name).font(.title.weight(.semibold))
                    Text(workspace.path).font(.callout).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Text("\(workspace.sessions.count) \(workspace.sessions.count == 1 ? "session" : "sessions")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !workspace.sessions.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(workspace.sessions) { session in
                            SessionCard(session: session, isSelected: session.id == workspace.selectedSessionID) {
                                workspace.selectedSessionID = session.id
                            }
                            .contextMenu {
                                Button("Close Session", systemImage: "xmark", role: .destructive) {
                                    workspace.sessions.removeAll { $0.id == session.id }
                                    if workspace.selectedSessionID == session.id {
                                        workspace.selectedSessionID = workspace.sessions.first?.id
                                    }
                                }
                            }
                        }
                    }.padding(3)
                }.scrollIndicators(.hidden)
            }
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: selectedSession?.kind.symbol ?? "terminal")
                    Text(selectedSession?.kind.rawValue ?? "Terminal")
                    Spacer()
                    Text("UI PREVIEW").font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .font(.caption).foregroundStyle(.secondary).padding(16)
                Divider().opacity(0.5)
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: selectedSession?.kind.symbol ?? "plus.square.dashed")
                        .font(.system(size: 32, weight: .light)).foregroundStyle(selectedSession?.kind.color ?? .blue)
                    Text(selectedSession == nil ? "A fresh space to work" : "Your session starts here")
                        .font(.title2.weight(.medium))
                    Text(selectedSession == nil
                         ? "Choose Claude, Copilot, or Shell to create a session preview."
                         : "The terminal surface is ready for a future connection.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if selectedSession == nil {
                        Button("New Shell Session") { addSession(.shell) }.buttonStyle(.borderedProminent)
                    }
                    Text("No processes are running in this UI preview.").font(.caption).foregroundStyle(.tertiary)
                }.padding(24)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(colorScheme == .dark ? Color(red: 0.055, green: 0.065, blue: 0.085) : Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.07)))
            HStack(spacing: 6) {
                Image(systemName: "circle.dotted")
                Text("Application shell")
                Spacer()
                Text("Session metadata only · No running processes")
            }.font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).background(.background)
    }
}

private struct SessionCard: View {
    let session: Session
    let isSelected: Bool
    let select: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: session.kind.symbol).foregroundStyle(session.kind.color)
                    Text(session.kind.rawValue).fontWeight(.medium)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 6) {
                    Circle().fill(isSelected ? Color.blue : Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
                    Text(isSelected ? "Selected · Preview" : "Preview").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(16).frame(width: 184, alignment: .leading)
            .background(isSelected ? Color.blue.opacity(0.09) : Color.primary.opacity(isHovered ? 0.06 : 0.025),
                        in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isSelected ? Color.blue.opacity(0.4) : Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain).onHover { isHovered = $0 }
        .accessibilityLabel("\(session.kind.rawValue) session")
        .accessibilityValue(isSelected ? "Selected, preview" : "Preview")
    }
}

struct RelayMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(spacing: 1) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 11, weight: .bold))
                Text(">_").font(.system(size: 17, weight: .bold, design: .monospaced))
            }.foregroundStyle(.white)
        }
        .frame(width: 40, height: 40).accessibilityHidden(true)
    }
}
