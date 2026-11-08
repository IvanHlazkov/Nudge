import AppKit
import CoreGraphics

/// Notices clicks on the desktop (the wallpaper), so Nudge can hide itself.
/// Uses a global mouse monitor, which needs no Accessibility or Screen Recording permission.
final class DesktopClickWatcher {
    private var monitor: Any?
    private let onDesktopClick: () -> Void

    init(onDesktopClick: @escaping () -> Void) {
        self.onDesktopClick = onDesktopClick
    }

    func start() {
        guard monitor == nil else { return }
        // Only fires for clicks in OTHER apps, never for clicks inside Nudge itself.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self else { return }
            let point = NSEvent.mouseLocation
            let callback = self.onDesktopClick
            // Give Finder a moment to become the active app after a desktop click.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                if DesktopClickWatcher.isDesktop(at: point) { callback() }
            }
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit { stop() }

    /// True when the click landed on the wallpaper / desktop icons, not on any window, the Dock or the menu bar.
    static func isDesktop(at cocoaPoint: NSPoint) -> Bool {
        // Clicking the desktop always makes Finder the active app.
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return false }

        // Window bounds use top-left origin on the primary screen.
        guard let primary = NSScreen.screens.first else { return false }
        let point = CGPoint(x: cocoaPoint.x, y: primary.frame.maxY - cocoaPoint.y)

        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return false }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let screenSizes = NSScreen.screens.map { $0.frame.size }

        for window in windows {
            let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            if pid == myPID { continue }
            let alpha = (window[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1
            if alpha <= 0.01 { continue }
            guard let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict) else { continue }
            // Skip invisible system overlays that cover a whole screen (real full-screen apps are layer 0).
            let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            if layer != 0 && screenSizes.contains(bounds.size) { continue }
            if bounds.contains(point) {
                // A real window, the Dock or the menu bar is under the click.
                return false
            }
        }
        return true
    }
}
