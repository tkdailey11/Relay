import AppKit
import SwiftUI
import TerminalKit

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        TabView {
            TerminalSettingsView(settings: settings)
                .tabItem { Label("Terminal", systemImage: "terminal") }
            SessionSettingsView(settings: settings)
                .tabItem { Label("Sessions", systemImage: "sparkle") }
        }
        .frame(width: 520)
    }
}

private struct TerminalSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker("Font:", selection: $settings.fontFamily) {
                    Text("System Monospaced").tag("")
                    Divider()
                    ForEach(MonospacedFonts.families, id: \.self) { family in
                        Text(family).tag(family)
                    }
                }
                HStack {
                    Slider(value: $settings.fontSize,
                           in: TerminalSettings.minimumFontSize...TerminalSettings.maximumFontSize,
                           step: 1) {
                        Text("Size:")
                    }
                    Text("\(Int(settings.fontSize)) pt")
                        .font(.body.monospacedDigit())
                        .frame(width: 48, alignment: .trailing)
                }
            } footer: {
                Text("Changes apply to open terminals immediately.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                // A preview beats guessing, since the terminal may be behind the Settings window.
                Text("relay $ echo \"the quick brown fox\"")
                    .font(fontFamily.map { Font.custom($0, size: settings.fontSize) }
                          ?? .system(size: settings.fontSize, design: .monospaced))
                    .lineLimit(1).truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            }
            Section {
                Button("Restore Defaults") {
                    settings.fontFamily = ""
                    settings.resetFontSize()
                }
            }
        }
        .formStyle(.grouped)
    }

    private var fontFamily: String? {
        settings.fontFamily.isEmpty ? nil : settings.fontFamily
    }
}

private struct SessionSettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                ForEach(SessionKind.allCases) { kind in
                    CommandField(settings: settings, kind: kind)
                }
            } header: {
                Text("Command")
            } footer: {
                Text("Leave a command empty to launch your login shell instead. Relay resolves the first word on your login shell’s PATH, so a bare name is usually enough.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct CommandField: View {
    @Bindable var settings: SettingsStore
    let kind: SessionKind
    @State private var text = ""

    var body: some View {
        // LabeledContent keeps the session kind visible once the field has been filled in,
        // which a placeholder alone does not.
        LabeledContent(kind.rawValue) {
            HStack {
                TextField("", text: $text, prompt: Text(placeholder))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("\(kind.rawValue) command")
                Button("Reset") {
                    settings.clearOverride(for: kind)
                    text = ""
                }
                .disabled(!settings.hasOverride(for: kind))
                .accessibilityLabel("Reset \(kind.rawValue) command")
            }
        }
        .onAppear { text = settings.command(for: kind) }
        .onChange(of: text) { settings.setCommand(text, for: kind) }
    }

    private var placeholder: String {
        switch kind {
        case .claude: "claude"
        case .copilot: "copilot"
        case .shell: "your login shell"
        }
    }
}

/// Listing every installed family would bury the handful that make sense in a terminal.
enum MonospacedFonts {
    static let families: [String] = {
        NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            return font.isFixedPitch
        }.sorted()
    }()
}
