import SwiftUI
import AppKit

struct GlassBackground: NSViewRepresentable {
    var cornerRadius: CGFloat = 20

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.mask(radius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    private static func mask(radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}

struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct HoverButtonStyle: ButtonStyle {
    var active = false

    func makeBody(configuration: Configuration) -> some View {
        HoverBody(configuration: configuration, active: active)
    }

    private struct HoverBody: View {
        let configuration: ButtonStyleConfiguration
        let active: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8)
                .frame(minHeight: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(configuration.isPressed ? 0.16 : (active ? 0.14 : (hovering ? 0.08 : 0))))
                )
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}

struct Keycap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 7)
            .frame(minWidth: 24, minHeight: 24)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.12)))
    }
}

struct RemindersGlyph: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(Color.white)
            .frame(width: 36, height: 36)
            .overlay(
                VStack(alignment: .leading, spacing: 3) {
                    row(Theme.accent)
                    row(Color(red: 0.55, green: 0.49, blue: 0.96))
                    row(Color(red: 0.29, green: 0.66, blue: 1.0))
                }
            )
            .accessibilityHidden(true)
    }

    private func row(_ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Capsule().fill(Color(white: 0.55)).frame(width: 14, height: 2)
        }
    }
}

struct QuitButton: View {
    var showsTitle: Bool

    var body: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            if showsTitle {
                Label("Quit Nudge", systemImage: "power")
                    .font(.system(size: 13, weight: .semibold))
            } else {
                Image(systemName: "power")
                    .font(.system(size: 13, weight: .semibold))
            }
        }
        .buttonStyle(HoverButtonStyle())
        .help("Quit Nudge")
        .accessibilityLabel("Quit Nudge")
    }
}
