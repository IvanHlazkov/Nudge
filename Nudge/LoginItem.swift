import Foundation
import ServiceManagement

/// Launch at login, using the modern SMAppService API (macOS 13+).
/// Nudge turns this on by itself the first time it runs; it can be switched off in Settings.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// True when macOS wants the user to approve Nudge in System Settings › General › Login Items.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func set(_ on: Bool) {
        let service = SMAppService.mainApp
        do {
            if on {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled || service.status == .requiresApproval {
                    try service.unregister()
                }
            }
        } catch {
            NSLog("Nudge: could not update login item: \(error.localizedDescription)")
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
