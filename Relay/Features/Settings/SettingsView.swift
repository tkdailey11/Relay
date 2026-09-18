import AppKit
import SwiftUI
import TerminalKit

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @Bindable var sessionTypes: SessionTypeStore

    var body: some View {
        TabView {
            TerminalSettingsView(settings: settings)
                .tabItem { Label("Terminal", systemImage: "terminal") }
            SessionTypeSettingsView(store: sessionTypes)
                .tabItem { Label("Session Types", systemImage: "sparkle") }
        }
        .frame(width: 560)
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

/// Listing every installed family would bury the handful that make sense in a terminal.
enum MonospacedFonts {
    static let families: [String] = {
        NSFontManager.shared.availableFontFamilies.filter { family in
            guard let font = NSFont(name: family, size: 12) else { return false }
            return font.isFixedPitch
        }.sorted()
    }()
}
