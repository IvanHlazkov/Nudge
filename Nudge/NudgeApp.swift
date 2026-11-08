import SwiftUI

@main
struct NudgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.store)
                .environmentObject(appDelegate.prefs)
        } label: {
            Image(systemName: "bell")
        }
        .menuBarExtraStyle(.window)
    }
}
