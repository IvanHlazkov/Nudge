import SwiftUI

struct MainView: View {
    @EnvironmentObject var store: ReminderStore
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var ui: UIState
    @State private var text = ""

    private var parsed: ParsedInput {
        DateParser.parse(text, enabled: prefs.spotDates)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            quickAdd
            HStack(spacing: 14) {
                ReminderCard(kind: .general, offset: .constant(0))
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
                        Text("Sending to Reminders")
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.84))
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("New reminders are copied to Apple Reminders")
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
        HStack(spacing: 14) {
            QuickAddField(text: $text,
                          focusToken: ui.focusToken,
                          highlight: parsed.range,
                          onSubmit: submit)
            Text("↵ " + hint)
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
        if text.trimmingCharacters(in: .whitespaces).isEmpty { return "Press enter to save" }
        if let due = parsed.due {
            return "Save to Planned · \(Fmt.dayLabel(due)), \(Fmt.time(due, use24h: prefs.use24h))"
        }
        return "Save to General"
    }

    private func submit() {
        guard let added = store.quickAdd(text, spotDates: prefs.spotDates, generalDay: store.today) else { return }
        if added.kind == .planned {
            ui.plannedOffset = store.offset(of: added.day)
        }
        text = ""
    }
}
