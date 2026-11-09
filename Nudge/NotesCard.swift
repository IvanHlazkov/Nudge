import SwiftUI
import AppKit

struct LeftTabs: View {
    let subtitle: String

    @EnvironmentObject var ui: UIState

    var body: some View {
        HStack(spacing: 4) {
            Menu {
                Picker("Show", selection: $ui.leftTab) {
                    Label("General", systemImage: "checklist").tag(LeftTab.general)
                    Label("Notes", systemImage: "note.text").tag(LeftTab.notes)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                HStack(spacing: 5) {
                    Text(ui.leftTab == .notes ? "Notes" : "General")
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .contentShape(Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Switch between General and Notes")

            Text("· " + subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
                .padding(.leading, 2)
        }
    }
}

struct NotesCard: View {
    @EnvironmentObject var notes: NoteStore
    @EnvironmentObject var ui: UIState

    var body: some View {
        let list = notes.sorted

        VStack(alignment: .leading, spacing: 0) {
            LeftTabs(subtitle: list.isEmpty ? "quick thoughts" : "\(list.count) note\(list.count == 1 ? "" : "s")")
                .padding(.leading, -8)

            Group {
                if list.isEmpty {
                    VStack(spacing: 6) {
                        Text("No notes yet")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(white: 0.77))
                        Text("Press ⌃N to write one")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(list) { note in
                                NoteRow(note: note)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.top, 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }
}

struct NoteRow: View {
    let note: Note

    @EnvironmentObject var notes: NoteStore
    @EnvironmentObject var store: ReminderStore
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var ui: UIState
    @State private var hovering = false
    @State private var editing = false
    @State private var copied = false

    var body: some View {
        if editing {
            NoteEditor(note: note) { editing = false }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(note.text)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.text)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 4) {
                    if note.pinned {
                        Image(systemName: "pin.fill").font(.system(size: 9))
                    }
                    Text(copied ? "Copied" : stamp)
                }
                .font(.system(size: 11))
                .foregroundStyle(note.pinned ? Theme.accent : Color(white: 0.6))
            }
            .contentShape(Rectangle())
            .onTapGesture(count: 2) { editing = true }
            .help("Double-click to edit")

            if hovering {
                HStack(spacing: 0) {
                    icon(note.pinned ? "pin.slash" : "pin", note.pinned ? "Unpin" : "Pin") { notes.togglePin(note.id) }
                    icon("doc.on.doc", "Copy") { copy() }
                    icon("pencil", "Edit") { editing = true }
                    icon("xmark", "Delete") { notes.delete(note.id) }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8)
            .fill(hovering ? Color.white.opacity(0.07) : Color.white.opacity(0.03)))
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Edit…") { editing = true }
            Button(note.pinned ? "Unpin" : "Pin to top") { notes.togglePin(note.id) }
            Button("Copy") { copy() }
            Button("Turn into reminder") { makeReminder() }
            Divider()
            Button("Delete", role: .destructive) { notes.delete(note.id) }
        }
    }

    private var stamp: String {
        let date = note.created
        if Calendar.current.isDateInToday(date) { return Fmt.time(date, use24h: prefs.use24h) }
        return Fmt.dayLabel(date)
    }

    private func icon(_ name: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(note.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { copied = false }
    }

    private func makeReminder() {
        let firstLine = note.text.split(separator: "\n").first.map(String.init) ?? note.text
        guard let added = store.quickAdd(firstLine, spotDates: prefs.spotDates, generalDay: store.today) else { return }
        notes.delete(note.id)
        if added.kind == .planned {
            ui.plannedOffset = store.offset(of: added.day)
        } else {
            ui.leftTab = .general
        }
    }
}

struct NoteEditor: View {
    let note: Note
    let onClose: () -> Void

    @EnvironmentObject var notes: NoteStore
    @State private var text: String
    @State private var closed = false
    @FocusState private var focused: Bool

    init(note: Note, onClose: @escaping () -> Void) {
        self.note = note
        self.onClose = onClose
        _text = State(initialValue: note.text)
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $text)
                .font(.system(size: 13.5))
                .scrollContentBackground(.hidden)
                .padding(4)
                .frame(height: 90)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Theme.field))
                .focused($focused)

            HStack(spacing: 6) {
                Text("⌘↵ to save")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Button("Cancel", action: close)
                    .buttonStyle(HoverButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(action: save) {
                    Text("Save")
                        .foregroundStyle(Color(white: 0.12))
                        .padding(.horizontal, 6)
                        .frame(minHeight: 24)
                        .background(Capsule().fill(canSave ? Theme.accent : Color(white: 0.5)))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .font(.system(size: 12, weight: .semibold))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.accent.opacity(0.5)))
        .onAppear {
            Task { @MainActor in focused = true }
        }
    }

    private func close() {
        guard !closed else { return }
        closed = true
        onClose()
    }

    private func save() {
        guard canSave, !closed else { return }
        notes.update(note.id, text: text)
        close()
    }
}
