import AppKit
import SwiftUI

/// Navy and gold, after the Gipper's old school colors.
enum Theme {
    static let gold = Color(red: 0.98, green: 0.76, blue: 0.20)
    static let navy = Color(red: 0.04, green: 0.08, blue: 0.20)
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.86)
    static let panelRadius: CGFloat = 16
    static let tagline = "Win one for the Gipher."

    /// Tints the blurred panel background navy.
    static let backdrop = LinearGradient(
        colors: [
            Color(red: 0.10, green: 0.17, blue: 0.40).opacity(0.62),
            Color(red: 0.03, green: 0.05, blue: 0.14).opacity(0.78),
        ],
        startPoint: .top, endPoint: .bottom)

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
        (Text("The").foregroundStyle(Theme.cream) + Text("Gipher").foregroundStyle(Theme.gold))
            .font(.system(size: size, weight: .black, design: .rounded))
            .italic()
    }
}

struct Keycap: View {
    let key: String

    var body: some View {
        Text(key)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 4))
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
