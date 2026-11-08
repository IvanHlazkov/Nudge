import SwiftUI
import AppKit

/// Text field that colours the date part of what you type ("tomorrow at 10 pm") purple, live.
struct QuickAddField: NSViewRepresentable {
    @Binding var text: String
    var focusToken: Int
    var highlight: NSRange?
    var onSubmit: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 14)
        field.textColor = .white
        field.lineBreakMode = .byClipping
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.placeholderAttributedString = Self.placeholder
        field.delegate = context.coordinator
        field.setAccessibilityLabel("New reminder")
        context.coordinator.lastFocusToken = focusToken
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
        context.coordinator.applyHighlight(to: field)

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            Task { @MainActor in
                field.window?.makeFirstResponder(field)
            }
        }
    }

    private static var placeholder: NSAttributedString {
        let font = NSFont.systemFont(ofSize: 14)
        let result = NSMutableAttributedString(
            string: "Upload homework for teacher review ",
            attributes: [.font: font, .foregroundColor: Theme.nsPlaceholder])
        result.append(NSAttributedString(
            string: "tomorrow at 10 pm",
            attributes: [.font: font, .foregroundColor: Theme.nsDateText]))
        return result
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: QuickAddField
        var lastFocusToken = 0

        init(_ parent: QuickAddField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            if selector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if selector == #selector(NSResponder.cancelOperation(_:)) {
                parent.text = ""
                return true
            }
            return false
        }

        /// Colours the live editor's text. Only changes display attributes, never the text itself.
        func applyHighlight(to field: NSTextField) {
            guard let editor = field.currentEditor() as? NSTextView,
                  let storage = editor.textStorage else { return }
            editor.insertionPointColor = .white
            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: full)
            storage.addAttribute(.foregroundColor, value: NSColor.white, range: full)
            if let range = parent.highlight, NSMaxRange(range) <= storage.length {
                storage.addAttribute(.foregroundColor, value: Theme.nsDateText, range: range)
                storage.addAttribute(.backgroundColor, value: Theme.nsDateBackground, range: range)
            }
            storage.endEditing()
        }
    }
}
