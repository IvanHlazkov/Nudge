import SwiftUI

struct RootView: View {
    static let size = CGSize(width: 760, height: 470)

    @EnvironmentObject var prefs: Prefs
    @EnvironmentObject var ui: UIState

    var body: some View {
        ZStack {
            GlassBackground(cornerRadius: 20)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.2).opacity(prefs.opacity))
            WindowDragArea()
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)

            Group {
                if ui.showSettings {
                    SettingsView()
                } else {
                    MainView()
                }
            }
            .padding(20)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .foregroundStyle(Theme.text)
        .environment(\.colorScheme, .dark)
    }
}
