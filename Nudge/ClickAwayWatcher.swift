import AppKit

final class ClickAwayWatcher {
    private var mouseMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private let onClickAway: () -> Void

    init(onClickAway: @escaping () -> Void) {
        self.onClickAway = onClickAway
    }

    func start() {
        guard mouseMonitor == nil else { return }

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.onClickAway()
        }

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
