#if DEBUG
import AppKit
import GipherCore
import SwiftUI

/// Debug builds only: `TheGipher --snapshot <grid|empty|setup> <out.png>` renders the
/// search panel offscreen with fixed content, to check layout without launching the app.
/// `--snapshot live <out.png> [query]` runs a real G-rated search with the installed
/// app's API key instead, for README screenshots.
/// Add `--light` for light mode and, with `live`, `--preview` to show the large preview.
/// (The blurred backdrop doesn't render offscreen; a flat color stands in.)
@MainActor
enum Snapshot {
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshot"), args.count > flag + 2 else {
            return false
        }
        let state = args[flag + 1]
        let output = URL(fileURLWithPath: args[flag + 2])

        _ = NSApplication.shared
        let settings = AppSettings.shared
        let model = SearchModel(settings: settings)
        let appearance = NSAppearance(named: args.contains("--light") ? .aqua : .darkAqua)
        NSApp.appearance = appearance
        // The Recent tab needs no API key, so it can show any content offline.
        model.tab = .recent
        switch state {
        case "grid":
            let gifs = (0..<16).map { Gif(id: "demo\($0)", title: "Demo \($0)", images: [:]) }
            model.loadSnapshot(
                items: gifs,
                suggestions: ["happy birthday", "happy dance", "happy friday", "happy cry", "so happy"],
                selection: 1)
        case "empty":
            model.loadSnapshot(items: [], suggestions: [], selection: nil)
        case "setup":
            model.tab = .gifs
        case "live":
            settings.persists = false
            settings.apiKey =
                UserDefaults(suiteName: "com.thegipher.app")?.string(forKey: "apiKey") ?? ""
            settings.rating = .g
            model.tab = .gifs
            let term = args.count > flag + 3 && !args[flag + 3].hasPrefix("--") ? args[flag + 3] : ""
            model.search(term)
        default:
            model.loadSnapshot(items: [], suggestions: [], selection: nil)
        }

        let size = NSSize(width: 760, height: 540)
        let root = SearchView(model: model, settings: settings)
            .frame(width: size.width, height: size.height)
            .background(Theme.snapshotBase)
            .clipShape(RoundedRectangle(cornerRadius: Theme.panelRadius))
        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(
            contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        // Live searches need time for results and their previews to arrive.
        RunLoop.current.run(until: Date().addingTimeInterval(state == "live" ? 8 : 0.6))
        if args.contains("--preview") {
            model.preview(index: 2)
            RunLoop.current.run(until: Date().addingTimeInterval(5))
        }

        // Render at 2x for a crisp image.
        guard
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: Int(size.width) * 2,
                pixelsHigh: Int(size.height) * 2, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
                bitsPerPixel: 0)
        else { return true }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: output)
        return true
    }
}
#endif
