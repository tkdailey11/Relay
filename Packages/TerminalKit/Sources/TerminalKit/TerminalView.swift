import SwiftUI

/// The container may be recreated by SwiftUI; the session's actual terminal NSView is retained.
public struct TerminalView: NSViewRepresentable {
    public let session: TerminalSession
    public let focusRequest: UUID

    public init(session: TerminalSession, focusRequest: UUID) {
        self.session = session
        self.focusRequest = focusRequest
    }

    public func makeNSView(context: Context) -> NSView {
        NSView()
    }

    public func updateNSView(_ container: NSView, context: Context) {
        let view = session.terminalView
        let changed = view.superview !== container
        if changed {
            container.subviews.forEach { $0.removeFromSuperview() }
            view.removeFromSuperview()
            view.frame = container.bounds
            view.autoresizingMask = [.width, .height]
            container.addSubview(view)
        }
        if changed || context.coordinator.focusRequest != focusRequest {
            context.coordinator.focusRequest = focusRequest
            view.requestFocus()
        }
    }

    public static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        nsView.subviews.forEach { $0.removeFromSuperview() }
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator {
        var focusRequest: UUID?
    }
}
