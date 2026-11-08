import AppKit

/// Borderless, transparent panel that can take keyboard focus without activating the app.
final class FloatingPanel: NSPanel {
    static let autosaveName = "NudgePanel"

    convenience init(contentRect: NSRect) {
        self.init(contentRect: contentRect,
                  styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
                  backing: .buffered,
                  defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        isFloatingPanel = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Nudge has no menu bar menus (it lives on the desktop), so wire up the usual
    /// editing shortcuts by hand: ⌘X ⌘C ⌘V ⌘A ⌘Z ⇧⌘Z.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        var action: Selector?
        if flags == .command {
            switch key {
            case "x": action = #selector(NSText.cut(_:))
            case "c": action = #selector(NSText.copy(_:))
            case "v": action = #selector(NSText.paste(_:))
            case "a": action = #selector(NSResponder.selectAll(_:))
            case "z": action = Selector(("undo:"))
            default: break
            }
        } else if flags == [.command, .shift], key == "z" {
            action = Selector(("redo:"))
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }
}
