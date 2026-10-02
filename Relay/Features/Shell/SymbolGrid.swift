import SwiftUI

/// The icons Relay offers, shared by the session type editor and the per-session picker so
/// the two never offer different choices.
struct SymbolGrid: View {
    let selection: String
    let tint: Color
    let select: (String) -> Void
    private let columns = [GridItem(.adaptive(minimum: 38), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SessionType.symbols, id: \.self) { symbol in
                Button { select(symbol) } label: {
                    Image(systemName: symbol)
                        .frame(width: 32, height: 28)
                        .foregroundStyle(selection == symbol ? tint : .secondary)
                        .background(selection == symbol ? tint.opacity(0.15) : .clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(symbol)
                .accessibilityAddTraits(selection == symbol ? [.isSelected] : [])
            }
        }
    }
}
