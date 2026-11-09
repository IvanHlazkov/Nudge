import SwiftUI

@main
struct NudgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.prefs)
                .environmentObject(UpdateChecker.shared)
        } label: {
            MenuBarLabel(store: appDelegate.store, prefs: appDelegate.prefs)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: ReminderStore
    @ObservedObject var prefs: Prefs

    private var text: String? {
        guard prefs.showNextInMenuBar,
              let next = store.nextPlanned(after: store.now),
              let due = next.due,
              Calendar.current.isDateInToday(due) else { return nil }
        let title = next.title.count > 22 ? String(next.title.prefix(21)) + "…" : next.title
        return "\(Fmt.time(due, use24h: prefs.use24h)) · \(title)"
    }

    var body: some View {
        if let text {
            HStack(spacing: 4) {
                Image(systemName: "bell")
                Text(text)
            }
        } else {
            Image(systemName: "bell")
        }
    }
}
