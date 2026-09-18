import Foundation

/// Actions Relay drives from its menus. `relay.conf` sets `keybind = clear`, which removes
/// libghostty's own shortcuts so the menu bar owns every Command key; these put the ones worth
/// having back, as menu items a user can discover rather than bindings they have to know.
///
/// Each raw value is a libghostty binding action, verified against the linked library.
public enum TerminalAction: String, CaseIterable, Sendable {
    case clearScreen = "clear_screen"
    case scrollToTop = "scroll_to_top"
    case scrollToBottom = "scroll_to_bottom"
    case scrollPageUp = "scroll_page_up"
    case scrollPageDown = "scroll_page_down"
    case jumpToPreviousPrompt = "jump_to_prompt:-1"
    case jumpToNextPrompt = "jump_to_prompt:1"
}
