import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: ReminderStore
    @EnvironmentObject var notes: NoteStore
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var ui: UIState
    @State private var text = ""

    private var parsed: ParsedInput {
        DateParser.parse(text, enabled: prefs.spotDates && !ui.noteMode)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            quickAdd
            HStack(spacing: 14) {
                Group {
                    if ui.leftTab == .notes {
                        NotesCard()
                    } else {
                        ReminderCard(kind: .general, offset: .constant(0))
                    }
                }
                ReminderCard(kind: .planned, offset: $ui.plannedOffset)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image("NudgeBell")
                .resizable()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)
            Text("Nudge")
                .font(.system(size: 14, weight: .bold))
            Text("· All reminders in one place")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.secondary)
            Spacer()
            if prefs.sendToReminders {
                Button {
                    ui.showSettings = true
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(Theme.green).frame(width: 7, height: 7)
                        Text("Synced with Reminders")
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.84))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Your reminders stay in sync with Apple Reminders")
            }
            Button {
                ui.showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(HoverButtonStyle())
            QuitButton(showsTitle: false)
        }
    }

    private var quickAdd: some View {
        HStack(spacing: 12) {
            Button {
                ui.toggleNoteMode()
            } label: {
                Image(systemName: ui.noteMode ? "note.text" : "bell")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ui.noteMode ? Theme.accent : Theme.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(ui.noteMode ? "Writing a note · ⌃N for a reminder" : "Writing a reminder · ⌃N for a note")
            .accessibilityLabel(ui.noteMode ? "Switch to reminder" : "Switch to note")

            QuickAddField(text: $text,
                          focusToken: ui.focusToken,
                          highlight: ui.noteMode ? nil : parsed.range,
                          noteMode: ui.noteMode,
                          onSubmit: submit)
            Text(hint)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.9))
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
    }

    private var hint: String {
        if text.trimmingCharacters(in: .whitespaces).isEmpty {
            return ui.noteMode ? "⌃N for a reminder" : "⌃N for a note"
        }
        if ui.noteMode { return "↵ Save to Notes" }
        return "↵ " + reminderHint
    }

    private var reminderHint: String {
        if let due = parsed.due {
            let repeats = parsed.repeats.map { " · " + $0.label.lowercased() } ?? ""
            return "Save to Planned · \(Fmt.dayLabel(due)), \(Fmt.time(due, use24h: prefs.use24h))" + repeats
        }
        return "Save to General"
    }

    private func submit() {
        if ui.noteMode {
            guard notes.add(text) != nil else { return }
            ui.leftTab = .notes
            text = ""
            return
        }
        guard let added = store.quickAdd(text, spotDates: prefs.spotDates, generalDay: store.today) else { return }
        if added.kind == .planned {
            ui.plannedOffset = store.offset(of: added.day)
        } else {
            ui.leftTab = .general
        }
        text = ""
    }
}
