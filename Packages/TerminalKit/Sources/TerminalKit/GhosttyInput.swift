import AppKit
import GhosttyKit

// Keep platform keycodes intact: libghostty handles terminal escape sequences and key protocols.
enum GhosttyInput {
    static func modifiers(_ flags: NSEvent.ModifierFlags) -> ghostty_input_mods_e {
        var value: UInt32 = 0
        if flags.contains(.shift) { value |= GHOSTTY_MODS_SHIFT.rawValue }
        if flags.contains(.control) { value |= GHOSTTY_MODS_CTRL.rawValue }
        if flags.contains(.option) { value |= GHOSTTY_MODS_ALT.rawValue }
        if flags.contains(.command) { value |= GHOSTTY_MODS_SUPER.rawValue }
        if flags.contains(.capsLock) { value |= GHOSTTY_MODS_CAPS.rawValue }
        return ghostty_input_mods_e(value)
    }

    static func key(_ event: NSEvent, action: ghostty_input_action_e) -> ghostty_input_key_s {
        var key = ghostty_input_key_s()
        key.action = action
        key.keycode = UInt32(event.keyCode)
        key.mods = modifiers(event.modifierFlags)
        key.consumed_mods = modifiers(event.modifierFlags.subtracting([.control, .command]))
        if event.type == .keyDown || event.type == .keyUp {
            key.unshifted_codepoint = event.characters(byApplyingModifiers: [])?.unicodeScalars.first?.value ?? 0
        }
        return key
    }

    static func text(_ event: NSEvent) -> String? {
        guard let text = event.characters else { return nil }
        if text.unicodeScalars.count == 1, let scalar = text.unicodeScalars.first {
            if (0xF700...0xF8FF).contains(scalar.value) { return nil }
            if scalar.value < 0x20 {
                return event.characters(byApplyingModifiers: event.modifierFlags.subtracting(.control))
            }
        }
        return text
    }
}
