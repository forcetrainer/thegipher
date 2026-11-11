import AppKit
import Combine
import GipherCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let hotKey = HotKey()
    private var panel: PanelController!
    private var statusItem: NSStatusItem!
    private var searchMenuItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = PanelController(settings: settings)
        buildMainMenu()
        buildStatusItem()

        hotKey.onPress = { [weak self] in self?.panel.toggle() }
        settings.$hotkey.combineLatest(settings.$hotkeyPaused)
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] hotkey, paused in self?.registerHotkey(hotkey, paused: paused) }
            .store(in: &subscriptions)
        settings.$appearance
            .sink { NSApp.appearance = $0.nsAppearance }
            .store(in: &subscriptions)

        Paster.pruneOutbox()
        if settings.apiKey.isEmpty { panel.show() }
    }

    private func registerHotkey(_ hotkey: Hotkey, paused: Bool) {
        // Paused while Settings records a new shortcut, so pressing the old one
        // records it instead of opening the panel.
        guard !paused else {
            hotKey.unregister()
            return
        }
        let ok = hotKey.register(keyCode: hotkey.keyCode, modifiers: hotkey.modifiers)
        searchMenuItem.title = ok
            ? "Search GIFs   \(hotkey.label)"
            : "Search GIFs   (\(hotkey.label) is taken — pick another in Settings)"
        // Deferred: this runs while `settings` is mid-change.
        DispatchQueue.main.async { [settings] in
            if settings.hotkeyConflict != !ok { settings.hotkeyConflict = !ok }
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = Theme.menuBarImage()

        let menu = NSMenu()
        searchMenuItem = menu.addItem(
            withTitle: "Search GIFs", action: #selector(openSearch), keyEquivalent: "")
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit TheGipher", action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu
    }

    /// An accessory app shows no menu bar, but text fields still need an Edit menu
    /// for ⌘V / ⌘C / ⌘A to work.
    private func buildMainMenu() {
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(
            withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        let main = NSMenu()
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    @objc private func openSearch() {
        panel.show()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered,
                defer: false)
            window.title = "TheGipher Settings"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView(settings: settings))
            window.setContentSize(window.contentView!.fittingSize)
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

@main
enum Main {
    @MainActor
    static func main() {
        #if DEBUG
        if Snapshot.runIfRequested() { return }
        #endif
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
