import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!

    let store = ReminderStore()
    let notes = NoteStore()
    let prefs = Prefs.shared
    private var panel: FloatingPanel!
    private var hotKey: HotKey?
    private var clickAway: ClickAwayWatcher?
    private var minuteTimer: Timer?

    private let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if prefs.openAtLogin { LoginItem.set(true) }

        let notifications = NotificationManager.shared
        notifications.store = store
        notifications.onOpen = { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.showPanel(focus: false) }
        }
        notifications.setUp()

        RemindersExporter.shared.store = store
        RemindersExporter.shared.startWatching()

        store.onChange = { [weak self] change in self?.handle(change) }
        prefs.onChange = { [weak self] key in self?.prefChanged(key) }

        buildPanel()

        hotKey = HotKey { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.toggle() }
        }

        clickAway = ClickAwayWatcher { [weak self] in
            guard let self else { return }
            Task { @MainActor in self.clickedAway() }
        }
        clickAway?.start()

        notifications.reschedule()
        startMinuteTimer()
        UpdateChecker.shared.start()

        NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.dayChanged() }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.dayChanged() }
        }
    }

    private func startMinuteTimer() {
        let start = Calendar.current.nextDate(after: Date(), matching: DateComponents(second: 0),
                                              matchingPolicy: .nextTime) ?? Date().addingTimeInterval(60)
        let timer = Timer(fire: start, interval: 60, repeats: true) { [weak self] _ in
            self?.store.tick()
        }
        timer.tolerance = 2
        RunLoop.main.add(timer, forMode: .common)
        minuteTimer = timer
    }

    private func buildPanel() {
        let root = RootView()
            .environmentObject(store)
            .environmentObject(notes)
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
        RemindersExporter.shared.schedulePull()
        panel.level = .floating
        panel.orderFrontRegardless()
        panel.makeKey()
        if focus {
            UIState.shared.showSettings = false
            UIState.shared.noteMode = false
            UIState.shared.focusToken += 1
        }
    }

    func hidePanel() {
        panel.makeFirstResponder(nil)
        panel.orderOut(nil)
    }

    private func clickedAway() {
        guard prefs.hideOnClickAway, panel.isVisible else { return }
        hidePanel()
    }

    func showSettings() {
        UIState.shared.showSettings = true
        showPanel(focus: false)
    }

    private func toggle() {
        if panel.isVisible && panel.isKeyWindow {
            hidePanel()
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

    private func handle(_ change: ReminderStore.Change) {
        NotificationManager.shared.reschedule()
        guard !store.syncing else { return }
        let exporter = RemindersExporter.shared
        switch change {
        case .added(let r), .updated(let r): exporter.export(r)
        case .removed(let r): exporter.remove(r)
        }
    }

    private func prefChanged(_ key: String) {
        switch key {
        case "position": applyLevel()
        case "sound", "morningSummary", "use24h": NotificationManager.shared.reschedule()
        case "remindersListID": RemindersExporter.shared.exportAll()
        default: break
        }
    }

    private func dayChanged() {
        store.tick()
        RemindersExporter.shared.schedulePull()
        NotificationManager.shared.reschedule()
    }
}
