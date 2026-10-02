import SwiftUI

/// Gives one session an icon of its own, so two sessions of the same type can be told apart
/// at a glance as well as by name.
struct SessionIconPicker: View {
    let sessionName: String
    let type: ResolvedSessionType
    /// The session's own symbol, or nil while it follows its type's.
    let current: String?
    let choose: (String?) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Icon for \(sessionName)").font(.title3).bold()
            SymbolGrid(selection: current ?? type.symbol, tint: type.color) { symbol in
                choose(symbol)
                dismiss()
            }
            HStack {
                Button("Use \(type.name) Icon") {
                    choose(nil)
                    dismiss()
                }
                .disabled(current == nil)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}
