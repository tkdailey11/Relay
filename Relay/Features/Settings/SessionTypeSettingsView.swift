import SwiftUI

/// The session types a user can start. Presets are ordinary rows here: they can be renamed,
/// pointed at a different command, disabled or removed, and new ones added for any CLI.
struct SessionTypeSettingsView: View {
    @Bindable var store: SessionTypeStore
    @State private var selection: SessionType.ID?
    /// One sheet, not two: SwiftUI honours only the last `.sheet` attached to a view, so adding
    /// and editing share a single presentation driven by this.
    @State private var editing: EditorTarget?

    private struct EditorTarget: Identifiable {
        let id = UUID()
        var type: SessionType
        var isNew: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(store.types) { type in
                    row(for: type).tag(type.id)
                }
                .onMove { store.move(fromOffsets: $0, toOffset: $1) }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            Divider()
            HStack(spacing: 8) {
                Menu {
                    Button("Custom Session Type…") {
                        editing = EditorTarget(type: SessionType(name: "", command: "",
                                                                 symbol: "bolt", color: .blue),
                                               isNew: true)
                    }
                    let suggestions = SessionType.catalog.filter { candidate in
                        !store.types.contains { $0.id == candidate.id }
                    }
                    if !suggestions.isEmpty {
                        Divider()
                        ForEach(suggestions) { preset in
                            Button(preset.name, systemImage: preset.symbol) { store.add(preset) }
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                Button {
                    if let selection { store.remove(selection) }
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .labelStyle(.iconOnly)
                .disabled(!canRemoveSelection)
                .help(removeHelp)

                Spacer()
                Button("Edit…") {
                    if let type = store.type(id: selection ?? "") {
                        editing = EditorTarget(type: type, isNew: false)
                    }
                }
                .disabled(selection == nil)
                Button("Restore Presets") { store.restorePresets() }
            }
            .padding(.horizontal, 12).padding(.top, 12)
            // The sidebar only has room for a few launchers, so say what decides which ones
            // rather than leaving a user to discover that dragging a row matters.
            Text("Enabled types appear in every New Session menu. Drag to reorder: the first few also get a button in the sidebar, and the rest move into its menu.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .sheet(item: $editing) { target in
            SessionTypeEditor(type: target.type, isNew: target.isNew) { edited in
                if target.isNew { store.add(edited) } else { store.update(edited) }
            }
        }
    }

    private var canRemoveSelection: Bool {
        guard let selection, let type = store.type(id: selection) else { return false }
        return type.isRemovable
    }

    private var removeHelp: String {
        guard let selection, let type = store.type(id: selection), !type.isRemovable else {
            return "Remove the selected session type"
        }
        return "\(type.name) can’t be removed: Relay needs a way to start a login shell."
    }

    private func row(for type: SessionType) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: Binding(
                get: { type.isEnabled },
                set: { isEnabled in
                    var updated = type
                    updated.isEnabled = isEnabled
                    store.update(updated)
                }
            ))
            .labelsHidden()
            .accessibilityLabel("Enable \(type.name)")

            Image(systemName: type.symbol)
                .foregroundStyle(type.color.color)
                .frame(width: 20)
                .accessibilityHidden(true)
            Text(type.name)
                .fontWeight(.medium)
                .foregroundStyle(type.isEnabled ? .primary : .secondary)
            Spacer()
            Text(type.command.isEmpty ? "login shell" : type.command)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
        }
        .padding(.vertical, 3)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.name) session type")
    }
}

/// One sheet for both adding and editing, since the fields are the same either way.
private struct SessionTypeEditor: View {
    @State var type: SessionType
    var isNew = false
    let save: (SessionType) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 38), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(isNew ? "New Session Type" : "Edit \(type.name)")
                .font(.title3).bold().padding(20)
            Divider()
            Form {
                Section {
                    TextField("Name", text: $type.name, prompt: Text("Aider"))
                        .accessibilityLabel("Name")
                    TextField("Command", text: $type.command, prompt: Text("aider --no-auto-commits"))
                        .font(.body.monospaced())
                        .accessibilityLabel("Command")
                } footer: {
                    Text("Relay resolves the first word on your login shell’s PATH, so a bare name is usually enough. Leave it empty to launch your login shell.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Color") {
                    HStack(spacing: 8) {
                        ForEach(SessionColor.allCases, id: \.self) { option in
                            Button { type.color = option } label: {
                                Circle().fill(option.color).frame(width: 22, height: 22)
                                    .overlay {
                                        Circle().strokeBorder(.primary.opacity(type.color == option ? 0.8 : 0.1),
                                                              lineWidth: type.color == option ? 2 : 1)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.name)
                            .accessibilityAddTraits(type.color == option ? [.isSelected] : [])
                        }
                    }
                }
                Section("Icon") {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(SessionType.symbols, id: \.self) { symbol in
                            Button { type.symbol = symbol } label: {
                                Image(systemName: symbol)
                                    .frame(width: 32, height: 28)
                                    .foregroundStyle(type.symbol == symbol ? type.color.color : .secondary)
                                    .background(type.symbol == symbol ? type.color.color.opacity(0.15) : .clear,
                                                in: RoundedRectangle(cornerRadius: 6))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(symbol)
                            .accessibilityAddTraits(type.symbol == symbol ? [.isSelected] : [])
                        }
                    }
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "Add" : "Save") {
                    save(type)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(type.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(20)
        }
        .frame(width: 520, height: 620)
    }
}
