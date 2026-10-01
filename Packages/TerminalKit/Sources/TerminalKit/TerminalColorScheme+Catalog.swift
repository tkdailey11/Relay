import Foundation

/// Popular schemes shipped with Relay so a user can switch without finding and importing a file.
/// Values are taken from the Ghostty theme files in iTerm2-Color-Schemes
/// (https://github.com/mbadolato/iTerm2-Color-Schemes, MIT). IDs are stored in preferences, so
/// they must never change.
extension TerminalColorScheme {
    public static let catalog: [TerminalColorScheme] = [
        catppuccinLatte, catppuccinMocha, dracula, gruvboxDark, gruvboxLight,
        nord, solarizedDark, solarizedLight, tokyoNight, tokyoNightDay,
    ]

    public static let catppuccinLatte = scheme(
        id: "catppuccin.latte", name: "Catppuccin Latte",
        background: "EFF1F5", foreground: "4C4F69", cursor: "DC8A78", cursorText: "EFF1F5",
        selection: "DC8A78", selectedText: "EFF1F5",
        palette: ["BCC0CC", "D20F39", "40A02B", "DF8E1D", "1E66F5", "EA76CB", "179299", "5C5F77",
                  "ACB0BE", "E7103F", "46B02F", "E49931", "3878F6", "EF95D7", "19A1A8", "6C6F85"])

    public static let catppuccinMocha = scheme(
        id: "catppuccin.mocha", name: "Catppuccin Mocha",
        background: "1E1E2E", foreground: "CDD6F4", cursor: "F5E0DC", cursorText: "1E1E2E",
        selection: "F5E0DC", selectedText: "1E1E2E",
        palette: ["45475A", "F38BA8", "A6E3A1", "F9E2AF", "89B4FA", "F5C2E7", "94E2D5", "BAC2DE",
                  "585B70", "F7AEC2", "C2ECBF", "FCD682", "AECCFC", "F398DA", "B1EAE1", "A6ADC8"])

    public static let dracula = scheme(
        id: "dracula", name: "Dracula",
        background: "282A36", foreground: "F8F8F2", cursor: "F8F8F2", cursorText: "282A36",
        selection: "44475A", selectedText: "FFFFFF",
        palette: ["21222C", "FF5555", "50FA7B", "F1FA8C", "BD93F9", "FF79C6", "8BE9FD", "F8F8F2",
                  "6272A4", "FF6E6E", "69FF94", "FFFFA5", "D6ACFF", "FF92DF", "A4FFFF", "FFFFFF"])

    public static let gruvboxDark = scheme(
        id: "gruvbox.dark", name: "Gruvbox Dark",
        background: "282828", foreground: "EBDBB2", cursor: "EBDBB2", cursorText: "282828",
        selection: "665C54", selectedText: "EBDBB2",
        palette: ["282828", "CC241D", "98971A", "D79921", "458588", "B16286", "689D6A", "A89984",
                  "928374", "FB4934", "B8BB26", "FABD2F", "83A598", "D3869B", "8EC07C", "EBDBB2"])

    public static let gruvboxLight = scheme(
        id: "gruvbox.light", name: "Gruvbox Light",
        background: "FBF1C7", foreground: "3C3836", cursor: "3C3836", cursorText: "FBF1C7",
        selection: "3C3836", selectedText: "FBF1C7",
        palette: ["FBF1C7", "CC241D", "98971A", "D79921", "458588", "B16286", "689D6A", "7C6F64",
                  "928374", "9D0006", "79740E", "B57614", "076678", "8F3F71", "427B58", "3C3836"])

    public static let nord = scheme(
        id: "nord", name: "Nord",
        background: "2E3440", foreground: "D8DEE9", cursor: "ECEFF4", cursorText: "282828",
        selection: "ECEFF4", selectedText: "4C566A",
        palette: ["3B4252", "BF616A", "A3BE8C", "EBCB8B", "81A1C1", "B48EAD", "88C0D0", "E5E9F0",
                  "596377", "BF616A", "A3BE8C", "EBCB8B", "81A1C1", "B48EAD", "8FBCBB", "ECEFF4"])

    public static let solarizedDark = scheme(
        id: "solarized.dark", name: "Solarized Dark",
        background: "002B36", foreground: "839496", cursor: "839496", cursorText: "073642",
        selection: "073642", selectedText: "93A1A1",
        palette: ["073642", "DC322F", "859900", "B58900", "268BD2", "D33682", "2AA198", "EEE8D5",
                  "335E69", "CB4B16", "586E75", "657B83", "839496", "6C71C4", "93A1A1", "FDF6E3"])

    public static let solarizedLight = scheme(
        id: "solarized.light", name: "Solarized Light",
        background: "FDF6E3", foreground: "657B83", cursor: "657B83", cursorText: "EEE8D5",
        selection: "EEE8D5", selectedText: "586E75",
        palette: ["073642", "DC322F", "859900", "B58900", "268BD2", "D33682", "2AA198", "BBB5A2",
                  "002B36", "CB4B16", "586E75", "657B83", "839496", "6C71C4", "93A1A1", "FDF6E3"])

    public static let tokyoNight = scheme(
        id: "tokyonight", name: "Tokyo Night",
        background: "1A1B26", foreground: "C0CAF5", cursor: "C0CAF5", cursorText: "15161E",
        selection: "33467C", selectedText: "C0CAF5",
        palette: ["15161E", "F7768E", "9ECE6A", "E0AF68", "7AA2F7", "BB9AF7", "7DCFFF", "A9B1D6",
                  "414868", "F7768E", "9ECE6A", "E0AF68", "7AA2F7", "BB9AF7", "7DCFFF", "C0CAF5"])

    public static let tokyoNightDay = scheme(
        id: "tokyonight.day", name: "Tokyo Night Day",
        background: "E1E2E7", foreground: "3760BF", cursor: "3760BF", cursorText: "E1E2E7",
        selection: "99A7DF", selectedText: "3760BF",
        palette: ["E9E9ED", "F52A65", "587539", "8C6C3E", "2E7DE9", "9854F1", "007197", "6172B0",
                  "A1A6C5", "F52A65", "587539", "8C6C3E", "2E7DE9", "9854F1", "007197", "3760BF"])

    private static func scheme(id: String, name: String, background: String, foreground: String,
                               cursor: String, cursorText: String, selection: String, selectedText: String,
                               palette: [String]) -> TerminalColorScheme {
        TerminalColorScheme(id: id, name: name,
                            background: TerminalColor(hex: background)!, foreground: TerminalColor(hex: foreground)!,
                            cursor: TerminalColor(hex: cursor)!, cursorText: TerminalColor(hex: cursorText)!,
                            selectionBackground: TerminalColor(hex: selection)!,
                            selectionForeground: TerminalColor(hex: selectedText)!,
                            palette: palette.map { TerminalColor(hex: $0)! })
    }
}
