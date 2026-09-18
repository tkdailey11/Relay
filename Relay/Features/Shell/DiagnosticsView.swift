import AppKit
import UniformTypeIdentifiers
import SwiftUI

/// `sheet(item:)` needs identity, and each report is a snapshot taken at the moment it was asked
/// for, so every one is distinct.
struct DiagnosticsReportItem: Identifiable {
    let id = UUID()
    let text: String
}

/// Shows the report before it goes anywhere. A tester is being asked to paste their directory
/// names into a bug tracker, so they get to read what they are handing over, and nothing leaves
/// the machine unless they press Copy.
struct DiagnosticsView: View {
    let report: String
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Diagnostics").font(.title3).bold()
                Text("Paste this into a bug report. It stays on your Mac until you copy it, and it includes your workspace paths.")
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            Divider()
            ScrollView {
                Text(report)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(.quaternary.opacity(0.3))
            Divider()
            HStack {
                Button("Save…", action: save)
                Spacer()
                Button("Done") { dismiss() }
                Button(didCopy ? "Copied" : "Copy", action: copy)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .frame(width: 720, height: 560)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        didCopy = true
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Relay Diagnostics.txt"
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? report.write(to: url, atomically: true, encoding: .utf8)
    }
}

#Preview {
    DiagnosticsView(report: "# Relay Diagnostics\n\n## Environment\n- Relay: 0.1.0 (42)")
}
