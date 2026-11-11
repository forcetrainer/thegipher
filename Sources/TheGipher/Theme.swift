import AppKit
import SwiftUI

/// Navy and gold, after the Gipper's old school colors. Every color has a light and a
/// dark variant: gold-on-navy in dark mode, navy-on-cream in light mode.
enum Theme {
    static let panelRadius: CGFloat = 16
    static let tagline = "Win one for the Gipher."

    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        })
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static let navy = Color(red: 0.04, green: 0.08, blue: 0.20)

    /// Gold used as a fill: selected tab, selection ring, hovered chip.
    static let accent = dynamic(light: rgb(0.96, 0.70, 0.08), dark: rgb(0.98, 0.76, 0.20))
    /// Gold used for text and icons; darker in light mode so it stays readable.
    static let accentText = dynamic(light: rgb(0.66, 0.42, 0.00), dark: rgb(0.98, 0.76, 0.20))
    /// Text on top of an accent fill.
    static let onAccent = navy
    /// The "The" in the wordmark.
    static let ink = dynamic(light: rgb(0.04, 0.08, 0.20), dark: rgb(0.98, 0.95, 0.86))

    private static let backdropTop = dynamic(
        light: rgb(0.97, 0.96, 0.92, 0.60), dark: rgb(0.10, 0.17, 0.40, 0.62))
    private static let backdropBottom = dynamic(
        light: rgb(0.90, 0.92, 0.97, 0.72), dark: rgb(0.03, 0.05, 0.14, 0.78))

    /// Tints the blurred panel background.
    static let backdrop = LinearGradient(
        colors: [backdropTop, backdropBottom], startPoint: .top, endPoint: .bottom)

    static let footer = dynamic(light: rgb(0, 0, 0, 0.05), dark: rgb(0, 0, 0, 0.22))
    /// Covers the grid behind a large preview.
    static let scrim = dynamic(light: rgb(0.95, 0.95, 0.96, 0.93), dark: rgb(0.03, 0.05, 0.13, 0.93))
    /// Stands in for the blurred backdrop in offscreen snapshots.
    static let snapshotBase = dynamic(light: rgb(0.93, 0.93, 0.92), dark: rgb(0.07, 0.10, 0.22))

    /// Menu bar glyph: a filled badge with "GIF" knocked out. A template image, so
    /// macOS colors it for light and dark menu bars.
    static func menuBarImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 25, height: 15), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()
            let text = NSAttributedString(
                string: "GIF",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 10, weight: .black),
                    .foregroundColor: NSColor.black,
                    .kern: 0.4,
                ])
            let size = text.size()
            NSGraphicsContext.current?.cgContext.setBlendMode(.destinationOut)
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "TheGipher"
        return image
    }
}

struct Wordmark: View {
    var size: CGFloat = 13

    var body: some View {
        (Text("The").foregroundStyle(Theme.ink) + Text("Gipher").foregroundStyle(Theme.accentText))
            .font(.system(size: size, weight: .black, design: .rounded))
    }
}

struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.primary.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }
}

/// Lets a region of the borderless panel be dragged to move the window.
struct WindowDragHandle: NSViewRepresentable {
    final class HandleView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }

    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ view: HandleView, context: Context) {}
}
