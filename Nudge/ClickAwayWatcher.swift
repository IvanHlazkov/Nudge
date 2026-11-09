import AppKit

/// Notices when you leave Nudge: a click anywhere outside it (the desktop, another app's window,
/// the Dock, the menu bar) or switching to another app with ⌘Tab. Nudge then hides until ⌥Space.
/// Uses a global mouse monitor, which needs no Accessibility or Screen Recording permission.
final class ClickAwayWatcher {
    private var mouseMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private let onClickAway: () -> Void

    init(onClickAway: @escaping () -> Void) {
        self.onClickAway = onClickAway
    }

    func start() {
        guard mouseMonitor == nil else { return }

        // Global monitors only see clicks that go to OTHER apps, never clicks inside Nudge itself.
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.onClickAway()
        }

        // Switching apps from the keyboard (⌘Tab, Spotlight…) counts as leaving too.
        let myPID = ProcessInfo.processInfo.processIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != myPID else { return }
            self?.onClickAway()
        }
    }

    func stop() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
    }

    deinit { stop() }
}
