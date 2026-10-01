import SwiftUI
import TerminalKit
import UniformTypeIdentifiers

/// Which colors terminals use in light and dark mode, and the schemes to choose from: Relay's
/// own, plus any a user imports from another terminal or builds here.
struct ColorSchemeSettingsView: View {
    @Bindable var settings: SettingsStore
    @State private var selection: TerminalColorScheme.ID?
    @State private var editing: EditorTarget?
    @State private var isImporting = false

    private struct EditorTarget: Identifiable {
        let id = UUID()
        var scheme: TerminalColorScheme
        var isNew: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Light appearance:").gridColumnAlignment(.trailing)
                    schemePicker("Light appearance", selection: $settings.lightColorSchemeID)
                }
                GridRow {
                    Text("Dark appearance:")
                    schemePicker("Dark appearance", selection: $settings.darkColorSchemeID)
                }
            }
            .padding(16)
            Divider()
            List(selection: $selection) {
                ForEach(settings.colorSchemes) { scheme in
                    row(for: scheme).tag(scheme.id)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .contextMenu(forSelectionType: TerminalColorScheme.ID.self) { ids in
                if let scheme = ids.first.flatMap(settings.colorScheme(id:)) {
                    Button(scheme.isBuiltIn ? "Edit a Copy…" : "Edit…") { edit(scheme) }
                    Button("Duplicate") { selection = settings.duplicateColorScheme(scheme).id }
                    if !scheme.isBuiltIn {
                        Divider()
                        Button("Remove", role: .destructive) { settings.removeColorScheme(id: scheme.id) }
                    }
                }
            } primaryAction: { ids in
                if let scheme = ids.first.flatMap(settings.colorScheme(id:)) { edit(scheme) }
            }
            .dropDestination(for: URL.self) { urls, _ in
                importSchemes(from: urls)
                return true
            }
            Divider()
            HStack(spacing: 8) {
                Menu {
                    Button("New Scheme…") {
                        let base = selectedScheme ?? settings.darkColors
                        var scheme = base
                        scheme.id = UUID().uuidString
                        scheme.name = "Untitled"
                        editing = EditorTarget(scheme: scheme, isNew: true)
                    }
                    Button("Import…") { isImporting = true }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    if let selection { settings.removeColorScheme(id: selection) }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .labelStyle(.iconOnly)
                .disabled(selectedScheme?.isBuiltIn ?? true)
                .help(selectedScheme?.isBuiltIn == true
                      ? "Built-in schemes can’t be removed"
                      : "Remove the selected color scheme")

                Spacer()
                Button(selectedScheme?.isBuiltIn == true ? "Edit a Copy…" : "Edit…") {
                    if let selectedScheme { edit(selectedScheme) }
                }
                .disabled(selectedScheme == nil)
                Button("Restore Defaults") { settings.restoreDefaultColorSchemes() }
                    .help("Use Relay Light and Relay Dark again. Your schemes are kept.")
            }
            .padding(.horizontal, 12).padding(.top, 12)
            Text("Import iTerm2 (.itermcolors), Terminal (.terminal) or Ghostty theme files, or drop them on the list. Built-in schemes are fixed, so editing one saves a copy.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .frame(minHeight: 520)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): importSchemes(from: urls)
            case .failure(let error): settings.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $editing) { target in
            ColorSchemeEditor(scheme: target.scheme, isNew: target.isNew) { edited in
                if target.isNew {
                    settings.addColorScheme(edited)
                    selection = edited.id
                } else {
                    settings.updateColorScheme(edited)
                }
            }
        }
        .alert("Some Color Schemes Weren’t Imported",
               isPresented: Binding(get: { settings.errorMessage != nil },
                                    set: { if !$0 { settings.errorMessage = nil } })) {
            Button("OK") { settings.errorMessage = nil }
        } message: {
            Text(settings.errorMessage ?? "")
        }
    }

    private var selectedScheme: TerminalColorScheme? {
        selection.flatMap(settings.colorScheme(id:))
    }

    private func edit(_ scheme: TerminalColorScheme) {
        if scheme.isBuiltIn {
            var copy = scheme
            copy.id = UUID().uuidString
            copy.name = "\(scheme.name) Copy"
            editing = EditorTarget(scheme: copy, isNew: true)
        } else {
            editing = EditorTarget(scheme: scheme, isNew: false)
        }
    }

    private func importSchemes(from urls: [URL]) {
        if let last = settings.importColorSchemes(from: urls).last { selection = last.id }
    }

    private func schemePicker(_ label: String, selection: Binding<String>) -> some View {
        Picker(label, selection: selection) {
            ForEach(TerminalColorScheme.builtIn) { Text($0.name).tag($0.id) }
            if !settings.customColorSchemes.isEmpty {
                Divider()
                ForEach(settings.customColorSchemes) { Text($0.name).tag($0.id) }
            }
        }
        .labelsHidden()
        .frame(maxWidth: 260)
    }

    private func row(for scheme: TerminalColorScheme) -> some View {
        HStack(spacing: 10) {
            ColorSchemeSwatch(scheme: scheme)
            Text(scheme.name).fontWeight(.medium)
            Spacer()
            if scheme.id == settings.lightColors.id {
                badge("Light", systemImage: "sun.max")
            }
            if scheme.id == settings.darkColors.id {
                badge("Dark", systemImage: "moon")
            }
            if scheme.isBuiltIn {
                Text("Built-in").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(scheme.name) color scheme")
    }

    private func badge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12), in: Capsule())
    }
}

/// A scheme at a glance: its text on its background, and the six ANSI hues programs use most.
struct ColorSchemeSwatch: View {
    let scheme: TerminalColorScheme

    var body: some View {
        HStack(spacing: 3) {
            Text("Aa")
                .font(.caption.monospaced().bold())
                .foregroundStyle(Color(scheme.foreground))
            ForEach(1..<7) { index in
                Circle().fill(Color(scheme.palette[index])).frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(Color(scheme.background), in: RoundedRectangle(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(.primary.opacity(0.12)) }
        .accessibilityHidden(true)
    }
}

/// Every color a scheme sets, with a preview, so a change can be judged before it reaches the
/// terminals. Edits stay in the sheet until Save: each change rebuilds libghostty's
/// configuration, which a color picker drag would otherwise do continuously.
private struct ColorSchemeEditor: View {
    @State var scheme: TerminalColorScheme
    var isNew = false
    let save: (TerminalColorScheme) -> Void
    @Environment(\.dismiss) private var dismiss

    private static let ansiNames = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Text(isNew ? "New Color Scheme" : "Edit Color Scheme").font(.title3).bold()
                TextField("Name", text: $scheme.name, prompt: Text("Name"))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Name")
            }
            .padding(20)
            Divider()
            Form {
                Section {
                    ColorSchemePreview(scheme: scheme)
                }
                Section("Text") {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow {
                            colorCell("Background", $scheme.background)
                            colorCell("Foreground", $scheme.foreground)
                        }
                        GridRow {
                            colorCell("Cursor", $scheme.cursor)
                            colorCell("Cursor text", $scheme.cursorText)
                        }
                        GridRow {
                            colorCell("Selection", $scheme.selectionBackground)
                            colorCell("Selected text", $scheme.selectionForeground)
                        }
                    }
                }
                Section("ANSI Colors") {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                        GridRow {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                            ForEach(Self.ansiNames, id: \.self) { name in
                                Text(name).font(.caption2).foregroundStyle(.secondary)
                                    .gridColumnAlignment(.center)
                            }
                        }
                        ansiRow("Normal", offset: 0)
                        ansiRow("Bright", offset: 8)
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    scheme.name = scheme.name.trimmingCharacters(in: .whitespaces)
                    save(scheme)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(scheme.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        // Settings sheets are clipped to the Settings window, so this has to fit without a
        // scroll that would hide the ANSI colors below the fold.
        .frame(width: 560, height: 600)
    }

    private func colorCell(_ title: String, _ color: Binding<TerminalColor>) -> some View {
        HStack {
            Text(title)
            Spacer()
            ColorPicker(title, selection: color.color, supportsOpacity: false)
                .labelsHidden()
                .help(color.wrappedValue.hex)
        }
        .frame(maxWidth: .infinity)
    }

    private func ansiRow(_ title: String, offset: Int) -> some View {
        GridRow {
            Text(title).font(.caption).foregroundStyle(.secondary)
            ForEach(0..<8) { index in
                ColorPicker("\(title) \(Self.ansiNames[index])",
                            selection: $scheme.palette[offset + index].color, supportsOpacity: false)
                    .labelsHidden()
                    .help("\(title) \(Self.ansiNames[index].lowercased()) (color \(offset + index))")
            }
        }
    }
}

/// A few lines of typical output, drawn with SwiftUI in the scheme's colors, since the live
/// terminal is likely hidden behind Settings.
struct ColorSchemePreview: View {
    let scheme: TerminalColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            line(("relay", 2), (" ~/code ", 4), ("$ ", nil), ("ls", nil))
            line(("README.md  ", nil), ("Sources/  ", 12), ("build.sh*  ", 10), ("archive.zip", 9))
            line((" M ", 1), ("Sources/App.swift  ", nil), ("?? ", 3), ("notes.txt  ", nil), ("# untracked", 8))
            HStack(spacing: 0) {
                Text("selected").foregroundStyle(Color(scheme.selectionForeground))
                    .background(Color(scheme.selectionBackground))
                Text(" ")
                Text(" ").foregroundStyle(Color(scheme.cursorText)).background(Color(scheme.cursor))
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(scheme.foreground))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(scheme.background), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of \(scheme.name)")
    }

    /// Each segment is text and the palette index it is drawn in, or nil for the foreground.
    private func line(_ segments: (String, Int?)...) -> Text {
        var string = AttributedString()
        for (text, index) in segments {
            var segment = AttributedString(text)
            segment.foregroundColor = Color(index.map { scheme.palette[$0] } ?? scheme.foreground)
            string += segment
        }
        return Text(string)
    }
}

#Preview {
    ColorSchemeSettingsView(settings: SettingsStore(defaults: UserDefaults(suiteName: "RelayColorPreview")!,
                                                    apply: { _ in }))
        .frame(width: 560)
}
