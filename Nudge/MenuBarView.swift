import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: ReminderStore
    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var updates: UpdateChecker
    @State private var text = ""

    private struct Entry: Identifiable {
        let id: UUID
        let label: String
        let title: String
        let highlighted: Bool
    }

    private var entries: [Entry] {
        let now = Date()
        let cal = Calendar.current
        let planned = store.items
            .filter { $0.kind == .planned && !$0.done && ($0.due ?? .distantPast) >= now }
            .sorted { ($0.due ?? now) < ($1.due ?? now) }
            .prefix(3)
        var result = planned.enumerated().map { index, r -> Entry in
            let due = r.due ?? now
            let label = cal.isDateInToday(due) ? Fmt.time(due, use24h: prefs.use24h) : Fmt.dayLabel(due)
            return Entry(id: r.id, label: label, title: r.title, highlighted: index == 0)
        }
        if result.count < 4 {
            let general = store.generalList().filter { !$0.done }.prefix(4 - result.count)
            result += general.map { Entry(id: $0.id, label: "Anytime", title: $0.title, highlighted: false) }
        }
        return result
    }

    private var leftToday: Int {
        store.generalList().filter { !$0.done }.count
            + store.list(.planned, on: store.today).filter { !$0.done }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image("NudgeBell").resizable().frame(width: 20, height: 20)
                Text("Next up").font(.system(size: 13, weight: .bold))
                Spacer()
                Text("\(leftToday) left today")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            if entries.isEmpty {
                Text("Nothing coming up")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 2) {
                    ForEach(entries) { e in
                        HStack(spacing: 10) {
                            Text(e.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(e.label == "Anytime" ? Color.secondary : Theme.dateText)
                                .frame(width: 66, alignment: .leading)
                            Text(e.title)
                                .font(.system(size: 13, weight: e.highlighted ? .semibold : .regular))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(e.highlighted ? Color(red: 0.59, green: 0.51, blue: 1.0).opacity(0.18) : Color.clear))
                    }
                }
            }

            TextField("Add a reminder…", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    store.quickAdd(text, spotDates: prefs.spotDates, generalDay: store.today)
                    text = ""
                }

            if let update = updates.available {
                Button {
                    updates.openDownload()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Nudge \(update.version) is out · Download")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                }
            }

            Divider()

            HStack {
                Button("Open Nudge") { AppDelegate.shared.showPanel(focus: true) }
                Spacer()
                Text("⌥ Space").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            HStack {
                Button("Settings…") { AppDelegate.shared.showSettings() }
                Spacer()
                Button("Quit Nudge") { NSApp.terminate(nil) }
            }
        }
        .buttonStyle(.borderless)
        .padding(14)
        .frame(width: 310)
    }
}
