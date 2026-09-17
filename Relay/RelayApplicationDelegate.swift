import TerminalKit
import AppKit

@MainActor
final class RelayApplicationDelegate: NSObject, NSApplicationDelegate {
    weak var terminals: TerminalSessionManager?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard terminals?.sessions.values.contains(where: \.requiresCloseConfirmation) == true else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = "Quit Relay?"
        alert.informativeText = "Processes are still running in your terminal sessions. Quitting will stop them."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        terminals?.closeAll()
    }
}
