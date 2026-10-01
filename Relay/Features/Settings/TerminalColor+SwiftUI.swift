import AppKit
import SwiftUI
import TerminalKit

extension Color {
    init(_ color: TerminalColor) {
        self.init(.sRGB, red: Double(color.red) / 255, green: Double(color.green) / 255,
                  blue: Double(color.blue) / 255)
    }
}

extension Binding where Value == TerminalColor {
    /// A ColorPicker edits a SwiftUI Color in whatever space the panel is set to; the terminal
    /// only understands sRGB, so the value is converted on the way back.
    var color: Binding<Color> {
        Binding<Color>(
            get: { Color(wrappedValue) },
            set: { wrappedValue = TerminalColor(NSColor($0)) ?? wrappedValue }
        )
    }
}
