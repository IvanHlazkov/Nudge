import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var ui: UIState

    @State private var lists: [ReminderList] = []
    @State private var remindersDenied = false
    @State private var loginNeedsApproval = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button {
                    ui.showSettings = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left")
                        Image("NudgeBell").resizable().frame(width: 20, height: 20)
                        Text("Back to reminders")
                    }
                    .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(HoverButtonStyle())
                Spacer()
                Text("Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                QuitButton(showsTitle: true)
            }

            HStack(alignment: .top, spacing: 14) {
                alertsCard
                quickAddCard
                windowCard
            }

            remindersRow

            HStack {
                Text("Nudge \(version)")
                Spacer()
                Text("Made by Glaz Labs")
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.secondary)
            .padding(.horizontal, 4)
        }
        .onAppear(perform: refresh)
    }

    private func refresh() {
        let exporter = RemindersExporter.shared
        remindersDenied = exporter.accessDenied
        lists = exporter.lists()
        loginNeedsApproval = LoginItem.needsApproval
    }

    // MARK: Cards

    private var alertsCard: some View {
        SettingsCard(title: "Alerts") {
            ToggleRow(title: "Morning summary",
                      subtitle: "General reminders at 9:00",
                      isOn: $prefs.morningSummary)
            LabeledPicker(title: "Sound") {
                Picker("Sound", selection: $prefs.sound) {
                    Text("Default").tag(AlertSound.standard)
                    Text("None").tag(AlertSound.silent)
                }
            }
            LabeledPicker(title: "Snooze for") {
                Picker("Snooze for", selection: $prefs.snoozeMinutes) {
                    Text("10 min").tag(10)
                    Text("30 min").tag(30)
                    Text("1 h").tag(60)
                }
            }
        }
    }

    private var quickAddCard: some View {
        SettingsCard(title: "Quick add") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open / close Nudge").font(.system(size: 13, weight: .semibold))
                    Text("From any app").font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Keycap(text: "⌥")
                    Keycap(text: "Space")
                }
            }
            ToggleRow(title: "Spot dates as I type",
                      subtitle: "“tomorrow at 10 pm” → Planned",
                      isOn: $prefs.spotDates)
            LabeledPicker(title: "Time format") {
                Picker("Time format", selection: $prefs.use24h) {
                    Text("12h").tag(false)
                    Text("24h").tag(true)
                }
            }
        }
    }

    private var windowCard: some View {
        SettingsCard(title: "Window") {
            LabeledPicker(title: "Where Nudge sits") {
                Picker("Where Nudge sits", selection: $prefs.position) {
                    Text("On desktop").tag(PanelPosition.desktop)
                    Text("On top").tag(PanelPosition.onTop)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Glass opacity").font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(Int((prefs.opacity * 100).rounded()))%")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                Slider(value: $prefs.opacity, in: 0.4...1.0)
                    .tint(Theme.accent)
                    .controlSize(.small)
                    .accessibilityLabel("Glass opacity")
            }
            ToggleRow(title: "Hide when I click away",
                      subtitle: "Bring it back with ⌥Space",
                      isOn: $prefs.hideOnClickAway)
            ToggleRow(title: "Open at login", subtitle: nil, isOn: Binding(
                get: { prefs.openAtLogin },
                set: { on in
                    prefs.openAtLogin = on
                    loginNeedsApproval = LoginItem.needsApproval
                }))
            if loginNeedsApproval {
                Button("Approve in System Settings") { LoginItem.openSystemSettings() }
                    .buttonStyle(.link)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }
        }
    }

    // MARK: Apple Reminders

    private var remindersRow: some View {
        HStack(spacing: 16) {
            RemindersGlyph()
            VStack(alignment: .leading, spacing: 3) {
                Text("Send to Apple Reminders")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    if prefs.sendToReminders {
                        Circle().fill(Theme.green).frame(width: 7, height: 7)
                    }
                    Text(remindersStatus)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if prefs.sendToReminders {
                Picker("List", selection: $prefs.remindersListID) {
                    Text("Nudge").tag("")
                    ForEach(lists) { list in
                        Text(list.title).tag(list.id)
                    }
                }
                .frame(width: 150)
                .font(.system(size: 12))

                Button {
                    RemindersExporter.shared.exportAll()
                } label: {
                    Label("Send all now", systemImage: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(HoverButtonStyle())
            }
            Toggle("Send to Apple Reminders", isOn: Binding(
                get: { prefs.sendToReminders },
                set: { on in setSendToReminders(on) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.accent)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }

    private var remindersStatus: String {
        if remindersDenied {
            return "No access. Allow Nudge in System Settings › Privacy & Security › Reminders."
        }
        guard prefs.sendToReminders else {
            return "Copy what you add in Nudge into Reminders. Nothing comes back."
        }
        if let last = prefs.lastSent {
            let ago = Date().timeIntervalSince(last) < 60
                ? "just now"
                : RelativeDateTimeFormatter().localizedString(for: last, relativeTo: Date())
            return "Last sent \(ago) · one way: Nudge → Reminders"
        }
        return "Ready · one way: Nudge → Reminders"
    }

    private func setSendToReminders(_ on: Bool) {
        guard on else {
            prefs.sendToReminders = false
            return
        }
        RemindersExporter.shared.requestAccess { granted in
            remindersDenied = !granted
            prefs.sendToReminders = granted
            if granted {
                lists = RemindersExporter.shared.lists()
                RemindersExporter.shared.exportAll()
            }
        }
    }
}

// MARK: - Building blocks

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
    }
}

private struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.secondary)
                }
            }
            Spacer(minLength: 4)
            Toggle(title, isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Theme.accent)
                .controlSize(.small)
        }
    }
}

private struct LabeledPicker<P: View>: View {
    let title: String
    @ViewBuilder var picker: P

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 13, weight: .semibold))
            picker
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }
}
