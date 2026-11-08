import AppKit
import SwiftUI

/// Owns the floating Nudge panel, the global hotkey, login item and wiring between services.
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!

    let store = ReminderStore()
    let prefs = Prefs.shared
    private var panel: FloatingPanel!
    private var hotKey: HotKey?
    private var desktopClicks: DesktopClickWatcher?

    /// Just above the desktop icons: behind normal windows, like a widget.
    private let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Launch at login: on by default, re-registered on every launch while the setting is on.
        if prefs.openAtLogin { LoginItem.set(true) }

        let notifications = NotificationManager.shared
        notifications.store = store
        notifications.onOpen = { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.showPanel(focus: false) }
        }
        notifications.setUp()

        RemindersExporter.shared.store = store

        store.onChange = { [weak self] change in self?.handle(change) }
        prefs.onChange = { [weak self] key in self?.prefChanged(key) }

        buildPanel()

        hotKey = HotKey { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.toggleFocus() }
        }

        // Clicking the desktop hides Nudge. ⌥Space or the menu bar bell brings it back.
        desktopClicks = DesktopClickWatcher { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.desktopClicked() }
        }
        desktopClicks?.start()

        notifications.reschedule()

        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.dayChanged() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.dayChanged() }
        }
    }

    // MARK: Panel

    private func buildPanel() {
        let root = RootView()
            .environmentObject(store)
            .environmentObject(prefs)
            .environmentObject(UIState.shared)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: RootView.size.width, height: RootView.size.height)

        panel = FloatingPanel(contentRect: hosting.frame)
        panel.contentView = hosting
        panel.delegate = self
        if !panel.setFrameUsingName(FloatingPanel.autosaveName) { panel.center() }
        panel.setFrameAutosaveName(FloatingPanel.autosaveName)
        applyLevel()
        panel.orderFrontRegardless()
        Task { @MainActor in self.panel.invalidateShadow() }
    }

    private func applyLevel() {
        if panel.isKeyWindow || prefs.position == .onTop {
            panel.level = .floating
        } else {
            panel.level = desktopLevel
        }
    }

    func showPanel(focus: Bool) {
        panel.level = .floating
        panel.orderFrontRegardless()
        panel.makeKey()
        if focus {
            UIState.shared.showSettings = false
            UIState.shared.focusToken += 1
        }
    }

    func hidePanel() {
        panel.makeFirstResponder(nil)
        panel.orderOut(nil)
    }

    private func desktopClicked() {
        guard prefs.hideOnDesktopClick, panel.isVisible else { return }
        hidePanel()
    }

    func showSettings() {
        UIState.shared.showSettings = true
        showPanel(focus: false)
    }

    private func toggleFocus() {
        if panel.isKeyWindow && panel.isVisible && panel.level == .floating && prefs.position == .desktop {
            // Second press: send Nudge back down to the desktop.
            panel.makeFirstResponder(nil)
            panel.level = desktopLevel
        } else {
            showPanel(focus: true)
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        panel.level = .floating
    }

    func windowDidResignKey(_ notification: Notification) {
        applyLevel()
    }

    // MARK: Changes

    private func handle(_ change: ReminderStore.Change) {
        NotificationManager.shared.reschedule()
        let exporter = RemindersExporter.shared
        switch change {
        case .added(let r), .updated(let r): exporter.export(r)
        case .removed(let r): exporter.remove(r)
        }
    }

    private func prefChanged(_ key: String) {
        switch key {
        case "position": applyLevel()
        case "sound", "morningSummary", "use24h", "snoozeMinutes": NotificationManager.shared.reschedule()
        case "remindersListID": RemindersExporter.shared.exportAll()
        default: break
        }
    }

    private func dayChanged() {
        store.refreshToday()
        NotificationManager.shared.reschedule()
    }
}
