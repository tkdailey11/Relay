import AppKit
import GhosttyKit

@MainActor
final class GhosttySurfaceView: NSView, @preconcurrency NSTextInputClient {
    weak var session: TerminalSession?
    private(set) var surface: ghostty_surface_t?
    private let workingDirectory: URL
    private var didAttemptStart = false
    private var isClosed = false
    private var tracking: NSTrackingArea?
    private var lastPixelSize = CGSize.zero
    private var lastScale: CGFloat = 0
    private var marked = NSAttributedString(string: "")
    private var textAccumulator: [String]?
    private var wantsFocus = false

    init(workingDirectory: URL) {
        self.workingDirectory = workingDirectory
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(true)
        setAccessibilityRole(.textArea)
        setAccessibilityLabel("Terminal")
        NotificationCenter.default.addObserver(self, selector: #selector(windowFocusChanged),
                                              name: NSWindow.didBecomeKeyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowFocusChanged),
                                              name: NSWindow.didResignKeyNotification, object: nil)
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }

    static func from(_ userdata: UnsafeMutableRawPointer?) -> GhosttySurfaceView? {
        userdata.map { Unmanaged<GhosttySurfaceView>.fromOpaque($0).takeUnretainedValue() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            startIfNeeded()
            takeFocus()
        }
        guard let surface else { return }
        ghostty_surface_set_occlusion(surface, window != nil)
        if window == nil { ghostty_surface_set_focus(surface, false) }
        resizeSurface()
    }

    private func startIfNeeded() {
        guard !didAttemptStart, !isClosed else { return }
        didAttemptStart = true
        do {
            let runtime = try GhosttyRuntime.shared.get()
            var config = ghostty_surface_config_new()
            config.platform_tag = GHOSTTY_PLATFORM_MACOS
            config.platform.macos.nsview = Unmanaged.passUnretained(self).toOpaque()
            config.userdata = Unmanaged.passUnretained(self).toOpaque()
            config.scale_factor = Double(window?.backingScaleFactor ?? 1)
            // A nil command lets libghostty launch the user's login shell (from passwd).
            config.wait_after_command = true
            surface = workingDirectory.path.withCString {
                config.working_directory = $0
                return ghostty_surface_new(runtime.app, &config)
            }
            guard surface != nil else { throw TerminalError.initialization("libghostty could not create a shell surface.") }
            updateAppearance()
            resizeSurface()
            // AppKit attachment happens during SwiftUI reconciliation.
            DispatchQueue.main.async { [weak self] in self?.session?.updateStatus(.running) }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.session?.updateStatus(.failed(error.localizedDescription))
            }
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        if let surface {
            self.surface = nil
            ghostty_surface_free(surface)
        }
        removeFromSuperview()
    }

    func processExited() {
        // Never destroy a surface synchronously inside one of its C callbacks.
        DispatchQueue.main.async { [weak self] in self?.session?.updateStatus(.exited) }
    }

    override func layout() {
        super.layout()
        resizeSurface()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        resizeSurface()
    }

    private func resizeSurface() {
        guard let surface, window != nil, bounds.width > 0, bounds.height > 0 else { return }
        let scale = window?.backingScaleFactor ?? 1
        let pixels = convertToBacking(bounds).size
        if scale != lastScale {
            ghostty_surface_set_content_scale(surface, scale, scale)
            lastScale = scale
        }
        if pixels != lastPixelSize {
            ghostty_surface_set_size(surface, UInt32(pixels.width.rounded()), UInt32(pixels.height.rounded()))
            lastPixelSize = pixels
        }
        if let screen = window?.screen,
           let display = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            ghostty_surface_set_display_id(surface, display.uint32Value)
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateAppearance()
    }

    private func updateAppearance() {
        guard let surface else { return }
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ghostty_surface_set_color_scheme(surface, dark ? GHOSTTY_COLOR_SCHEME_DARK : GHOSTTY_COLOR_SCHEME_LIGHT)
    }

    /// SwiftUI asks for focus while it is still assembling the view tree, before AppKit has put
    /// this view in a window, so the request is held until it can be satisfied rather than
    /// dropped on a nil window.
    func requestFocus() {
        wantsFocus = true
        takeFocus()
    }

    private func takeFocus() {
        guard wantsFocus, let window else { return }
        wantsFocus = false
        if window.firstResponder !== self { window.makeFirstResponder(self) }
    }

    override func becomeFirstResponder() -> Bool {
        if let surface { ghostty_surface_set_focus(surface, window?.isKeyWindow == true) }
        return true
    }

    override func resignFirstResponder() -> Bool {
        if let surface { ghostty_surface_set_focus(surface, false) }
        return true
    }

    @objc private func windowFocusChanged(_ notification: Notification) {
        guard let changed = notification.object as? NSWindow, changed === window, let surface else { return }
        ghostty_surface_set_focus(surface, changed.isKeyWindow && changed.firstResponder === self)
    }

    override func keyDown(with event: NSEvent) {
        let wasComposing = hasMarkedText()
        textAccumulator = []
        interpretKeyEvents([event])
        let texts = textAccumulator ?? []
        textAccumulator = nil
        let action = event.isARepeat ? GHOSTTY_ACTION_REPEAT : GHOSTTY_ACTION_PRESS
        if texts.isEmpty {
            sendKey(event, action: action, text: GhosttyInput.text(event), composing: wasComposing || hasMarkedText())
        } else {
            for text in texts { sendKey(event, action: action, text: text) }
        }
    }

    override func keyUp(with event: NSEvent) { sendKey(event, action: GHOSTTY_ACTION_RELEASE) }

    override func flagsChanged(with event: NSEvent) {
        let flag: NSEvent.ModifierFlags
        switch event.keyCode {
        case 56, 60: flag = .shift
        case 59, 62: flag = .control
        case 58, 61: flag = .option
        case 54, 55: flag = .command
        case 57: flag = .capsLock
        default: return
        }
        sendKey(event, action: event.modifierFlags.contains(flag) ? GHOSTTY_ACTION_PRESS : GHOSTTY_ACTION_RELEASE)
    }

    private func sendKey(_ event: NSEvent, action: ghostty_input_action_e, text: String? = nil, composing: Bool = false) {
        guard let surface else { return }
        var key = GhosttyInput.key(event, action: action)
        key.composing = composing
        if let text, let first = text.utf8.first, first >= 0x20 {
            text.withCString { key.text = $0; _ = ghostty_surface_key(surface, key) }
        } else {
            _ = ghostty_surface_key(surface, key)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        // App menus own Command shortcuts, especially focus and session switching.
        // Control-only keys must reach the PTY even when AppKit has a matching text command.
        if event.modifierFlags.contains(.control), !event.modifierFlags.contains(.command) {
            keyDown(with: event)
            return true
        }
        return false
    }

    @objc func copy(_ sender: Any?) { binding("copy_to_clipboard") }
    @objc func paste(_ sender: Any?) { binding("paste_from_clipboard") }
    @objc override func selectAll(_ sender: Any?) { binding("select_all") }

    private func binding(_ name: String) {
        guard let surface else { return }
        name.withCString { _ = ghostty_surface_binding_action(surface, $0, UInt(name.utf8.count)) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self)
        addTrackingArea(area)
        tracking = area
    }

    private func mousePosition(_ event: NSEvent) {
        guard let surface else { return }
        let point = convert(event.locationInWindow, from: nil)
        ghostty_surface_mouse_pos(surface, point.x, bounds.height - point.y, GhosttyInput.modifiers(event.modifierFlags))
    }

    private func mouseButton(_ event: NSEvent, _ button: ghostty_input_mouse_button_e, _ state: ghostty_input_mouse_state_e) {
        guard let surface else { return }
        mousePosition(event)
        _ = ghostty_surface_mouse_button(surface, state, button, GhosttyInput.modifiers(event.modifierFlags))
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        mouseButton(event, GHOSTTY_MOUSE_LEFT, GHOSTTY_MOUSE_PRESS)
    }
    override func mouseUp(with event: NSEvent) { mouseButton(event, GHOSTTY_MOUSE_LEFT, GHOSTTY_MOUSE_RELEASE) }
    override func mouseDragged(with event: NSEvent) { mousePosition(event) }
    override func mouseMoved(with event: NSEvent) { mousePosition(event) }
    override func rightMouseDown(with event: NSEvent) { mouseButton(event, GHOSTTY_MOUSE_RIGHT, GHOSTTY_MOUSE_PRESS) }
    override func rightMouseUp(with event: NSEvent) { mouseButton(event, GHOSTTY_MOUSE_RIGHT, GHOSTTY_MOUSE_RELEASE) }
    override func rightMouseDragged(with event: NSEvent) { mousePosition(event) }
    override func otherMouseDown(with event: NSEvent) { mouseButton(event, GHOSTTY_MOUSE_MIDDLE, GHOSTTY_MOUSE_PRESS) }
    override func otherMouseUp(with event: NSEvent) { mouseButton(event, GHOSTTY_MOUSE_MIDDLE, GHOSTTY_MOUSE_RELEASE) }
    override func otherMouseDragged(with event: NSEvent) { mousePosition(event) }

    override func scrollWheel(with event: NSEvent) {
        guard let surface else { return }
        let momentum: Int32
        switch event.momentumPhase {
        case .began: momentum = 1
        case .stationary: momentum = 2
        case .changed: momentum = 3
        case .ended: momentum = 4
        case .cancelled: momentum = 5
        case .mayBegin: momentum = 6
        default: momentum = 0
        }
        let precision: Int32 = event.hasPreciseScrollingDeltas ? 1 : 0
        let multiplier = event.hasPreciseScrollingDeltas ? 2.0 : 1.0
        ghostty_surface_mouse_scroll(surface, event.scrollingDeltaX * multiplier,
                                     event.scrollingDeltaY * multiplier, precision | momentum << 1)
    }

    // NSTextInputClient preserves native dead keys and IME composition.
    func hasMarkedText() -> Bool { marked.length > 0 }
    func markedRange() -> NSRange { hasMarkedText() ? NSRange(location: 0, length: marked.length) : NSRange(location: NSNotFound, length: 0) }
    func selectedRange() -> NSRange { NSRange(location: NSNotFound, length: 0) }
    func validAttributesForMarkedText() -> [NSAttributedString.Key] { [] }
    func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? { nil }
    func characterIndex(for point: NSPoint) -> Int { NSNotFound }

    func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        marked = (string as? NSAttributedString) ?? NSAttributedString(string: string as? String ?? "")
        syncPreedit()
    }

    func unmarkText() {
        marked = NSAttributedString(string: "")
        syncPreedit()
    }

    private func syncPreedit() {
        guard let surface else { return }
        if marked.length == 0 { ghostty_surface_preedit(surface, nil, 0) }
        else { marked.string.withCString { ghostty_surface_preedit(surface, $0, UInt(marked.string.utf8.count)) } }
    }

    func insertText(_ string: Any, replacementRange: NSRange) {
        let text = (string as? NSAttributedString)?.string ?? string as? String ?? ""
        unmarkText()
        if textAccumulator != nil { textAccumulator?.append(text) }
        else if let surface { text.withCString { ghostty_surface_text(surface, $0, UInt(text.utf8.count)) } }
    }

    override func doCommand(by selector: Selector) { /* libghostty encodes non-text keys. */ }

    func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        guard let surface else { return .zero }
        var x = 0.0, y = 0.0, width = 0.0, height = 0.0
        ghostty_surface_ime_point(surface, &x, &y, &width, &height)
        let rect = convert(NSRect(x: x, y: bounds.height - y, width: width, height: height), to: nil)
        return window?.convertToScreen(rect) ?? rect
    }

    override func accessibilityValue() -> Any? {
        guard let surface else { return "" }
        let selection = ghostty_selection_s(
            top_left: ghostty_point_s(tag: GHOSTTY_POINT_VIEWPORT, coord: GHOSTTY_POINT_COORD_TOP_LEFT, x: 0, y: 0),
            bottom_right: ghostty_point_s(tag: GHOSTTY_POINT_VIEWPORT, coord: GHOSTTY_POINT_COORD_BOTTOM_RIGHT, x: 0, y: 0),
            rectangle: false)
        var text = ghostty_text_s()
        guard ghostty_surface_read_text(surface, selection, &text) else { return "" }
        defer { ghostty_surface_free_text(surface, &text) }
        guard let pointer = text.text else { return "" }
        return String(decoding: UnsafeRawBufferPointer(start: pointer, count: Int(text.text_len)), as: UTF8.self)
    }

    func confirmClipboard(_ text: String, state: UnsafeMutableRawPointer?, request: ghostty_clipboard_request_e) {
        guard let surface else { return }
        let alert = NSAlert()
        alert.messageText = request == GHOSTTY_CLIPBOARD_REQUEST_PASTE ? "Paste multiple lines?" : "Allow terminal clipboard access?"
        alert.informativeText = request == GHOSTTY_CLIPBOARD_REQUEST_PASTE
            ? "Pasting this text may run commands in the shell."
            : "A program running in this terminal has requested access to your clipboard."
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Cancel")
        // Complete synchronously, matching the callback lifetime; cancellation also releases the request.
        let allowed = alert.runModal() == .alertFirstButtonReturn
        guard self.surface == surface else { return }
        if request == GHOSTTY_CLIPBOARD_REQUEST_OSC_52_WRITE {
            if allowed {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        } else {
            (allowed ? text : "").withCString {
                ghostty_surface_complete_clipboard_request(surface, $0, state, true)
            }
        }
    }
}
