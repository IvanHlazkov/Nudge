import SwiftUI

/// One of the two big cards: General (no date/time) or Planned (with date/time).
struct ReminderCard: View {
    let kind: ReminderKind
    @Binding var offset: Int

    @EnvironmentObject var store: ReminderStore
    @State private var showCalendar = false

    private var day: Date { store.date(offset: offset) }

    var body: some View {
        let reminders = store.list(kind, on: day)
        let left = reminders.filter { !$0.done }.count

        VStack(alignment: .leading, spacing: 0) {
            (Text(kind == .general ? "General" : "Planned")
                .fontWeight(.bold)
                .foregroundStyle(Theme.text)
             + Text(kind == .general ? " · reminders without date and time" : " · reminders with date and time")
                .fontWeight(.medium)
                .foregroundStyle(Theme.secondary))
                .font(.system(size: 13))
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Fmt.dayLabel(day))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                if !reminders.isEmpty {
                    Text("\(left) left")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
            }
            .padding(.top, 6)

            Group {
                if reminders.isEmpty {
                    Text("Nothing planned for this day")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.77))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(reminders) { reminder in
                                ReminderRow(reminder: reminder, showTime: kind == .planned)
                            }
                        }
                    }
                    .scrollIndicators(.never)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.top, 8)

            footer
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
        .overlay(alignment: .bottom) {
            if showCalendar {
                MonthPicker(kind: kind, selected: day) { picked in
                    offset = store.offset(of: picked)
                    showCalendar = false
                }
                .padding(.bottom, 46)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: showCalendar)
        .onChange(of: offset) { showCalendar = false }
    }

    private var footer: some View {
        HStack {
            Button {
                offset -= 1
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left")
                    Text(Fmt.dayLabel(store.date(offset: offset - 1)))
                }
            }
            .buttonStyle(HoverButtonStyle())

            Spacer()

            Button {
                showCalendar.toggle()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 15))
                    .frame(width: 20)
            }
            .buttonStyle(HoverButtonStyle(active: showCalendar))
            .accessibilityLabel("Open calendar")

            Spacer()

            Button {
                offset += 1
            } label: {
                HStack(spacing: 6) {
                    Text(Fmt.dayLabel(store.date(offset: offset + 1)))
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(HoverButtonStyle())
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color(white: 0.9))
        .frame(height: 40)
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    let showTime: Bool

    @EnvironmentObject var store: ReminderStore
    @EnvironmentObject var prefs: Prefs
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.toggle(reminder.id)
            } label: {
                ZStack {
                    if reminder.done {
                        Circle().fill(Theme.accent)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(Color(white: 0.16))
                    } else {
                        Circle().strokeBorder(Color(white: 0.6), lineWidth: 2)
                    }
                }
                .frame(width: 20, height: 20)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reminder.done ? "Mark not done" : "Mark done")

            Text(reminder.title)
                .font(.system(size: 13.5))
                .strikethrough(reminder.done)
                .foregroundStyle(reminder.done ? Color(white: 0.74) : Theme.text)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            if hovering {
                Button {
                    store.delete(reminder.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Delete")
                .accessibilityLabel("Delete")
            }

            if showTime, let due = reminder.due {
                Text(Fmt.time(due, use24h: prefs.use24h))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.dateText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Theme.dateBackground))
            }
        }
        .padding(.horizontal, 4)
        .frame(minHeight: 34)
        .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? Color.white.opacity(0.05) : Color.clear))
        .onHover { hovering = $0 }
        .contextMenu {
            Button(reminder.done ? "Mark not done" : "Mark done") { store.toggle(reminder.id) }
            Button("Move to next day") { store.move(reminder.id, byDays: 1) }
            Divider()
            Button("Delete", role: .destructive) { store.delete(reminder.id) }
        }
    }
}

/// The NOV · 2026 calendar that pops up from the calendar button.
struct MonthPicker: View {
    let kind: ReminderKind
    let selected: Date
    let onPick: (Date) -> Void

    @EnvironmentObject var store: ReminderStore
    @State private var monthShift = 0

    private var cal: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2 // Monday
        return c
    }

    private var month: Date {
        let start = cal.date(from: cal.dateComponents([.year, .month], from: selected)) ?? selected
        return cal.date(byAdding: .month, value: monthShift, to: start) ?? start
    }

    private var cells: [Date] {
        let first = month
        let lead = (cal.component(.weekday, from: first) + 5) % 7 // Monday = 0
        let days = cal.range(of: .day, in: .month, for: first)?.count ?? 30
        let total = Int((Double(lead + days) / 7).rounded(.up)) * 7
        return (0..<total).compactMap { cal.date(byAdding: .day, value: $0 - lead, to: first) }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(Fmt.monthTitle(month))
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Button { monthShift -= 1 } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(HoverButtonStyle())
                    .accessibilityLabel("Previous month")
                Button { monthShift += 1 } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(HoverButtonStyle())
                    .accessibilityLabel("Next month")
            }
            .font(.system(size: 12, weight: .bold))

            let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(["M", "T", "W", "T", "F", "S", "S"].indices, id: \.self) { i in
                    Text(["M", "T", "W", "T", "F", "S", "S"][i])
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.77))
                }
                ForEach(cells, id: \.self) { date in
                    dayCell(date)
                }
            }
        }
        .padding(12)
        .frame(width: 252)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.17)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.1)))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = cal.isDate(date, inSameDayAs: selected)
        let isToday = cal.isDateInToday(date)
        let inMonth = cal.isDate(date, equalTo: month, toGranularity: .month)
        let hasDot = store.hasOpen(kind, on: date)

        return Button {
            onPick(date)
        } label: {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Theme.dateText : Color.clear)
                Text("\(cal.component(.day, from: date))")
                    .font(.system(size: 12, weight: isToday || isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? Color(red: 0.12, green: 0.1, blue: 0.2)
                                     : isToday ? Color(red: 1.0, green: 0.7, blue: 0.5)
                                     : inMonth ? Theme.text : Color(white: 0.6))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if hasDot && !isSelected {
                    Circle().fill(Theme.accent).frame(width: 4, height: 4).padding(.bottom, 3)
                }
            }
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).day().month(.wide)))
    }
}
