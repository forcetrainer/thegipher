import AppKit
import Carbon.HIToolbox
import GipherCore
import SwiftUI

/// A borderless panel that takes keyboard input without activating this app,
/// so the app you were typing in (Messages) stays frontmost and ready for the paste.
private final class SearchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    let model: SearchModel
    private let settings: AppSettings
    private let panel: SearchPanel
    private var targetApp: NSRunningApplication?
    private var keyMonitor: Any?

    init(settings: AppSettings) {
        self.settings = settings
        model = SearchModel(settings: settings)
        panel = SearchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false  // header and footer drag it instead
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.animationBehavior = .utilityWindow
        panel.delegate = self

        let backdrop = NSVisualEffectView()
        backdrop.material = .popover
        backdrop.state = .active
        backdrop.blendingMode = .behindWindow
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = Theme.panelRadius
        backdrop.layer?.masksToBounds = true
        let host = NSHostingView(rootView: SearchView(model: model, settings: settings))
        host.frame = backdrop.bounds
        host.autoresizingMask = [.width, .height]
        backdrop.addSubview(host)
        panel.contentView = backdrop

        model.onSend = { [weak self] gif, mode in self?.send(gif, mode: mode) }
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            targetApp = front
        }
        positionPanel()
        installKeyMonitor()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
        model.panelDidOpen()
    }

    func hide() {
        guard panel.isVisible else { return }
        removeKeyMonitor()
        UserDefaults.standard.set(NSStringFromPoint(panel.frame.origin), forKey: Self.originKey)
        panel.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private static let originKey = "panelOrigin"

    /// Reopen where it was last left (handy once you've moved it beside the
    /// conversation for dragging); otherwise center on the screen with the pointer.
    private func positionPanel() {
        let size = panel.frame.size
        if let saved = UserDefaults.standard.string(forKey: Self.originKey) {
            let frame = NSRect(origin: NSPointFromString(saved), size: size)
            if NSScreen.screens.contains(where: { $0.visibleFrame.contains(frame) }) {
                panel.setFrameOrigin(frame.origin)
                return
            }
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(
                x: visible.midX - size.width / 2,
                y: visible.minY + (visible.height - size.height) * 0.62))
        }
    }

    // MARK: Sending

    private func send(_ gif: Gif, mode: SendMode) {
        guard model.sendingID == nil else { return }
        model.sendingID = gif.id
        model.message = nil
        Task {
            defer { model.sendingID = nil }
            do {
                let file = try await Paster.file(for: gif, quality: settings.sendQuality).value
                Paster.copy(file)
                GifListStore.recents.add(gif)
            } catch {
                model.message = error.localizedDescription
                return
            }
            guard mode != .copyOnly else {
                model.message = "Copied."
                return
            }
            guard Paster.canAutoPaste else {
                model.message = "Copied — press ⌘V. Allow TheGipher under Accessibility to paste automatically."
                Paster.requestAutoPastePermission()
                return
            }
            hide()
            if let targetApp, NSWorkspace.shared.frontmostApplication != targetApp {
                targetApp.activate()
            }
            // Give the target app a beat to take keyboard focus back.
            try? await Task.sleep(for: .milliseconds(140))
            Paster.pressPaste()
            if mode == .pasteAndSend {
                // The GIF has to finish attaching before Return will send it.
                try? await Task.sleep(for: .milliseconds(600))
                Paster.pressReturn()
            }
        }
    }

    // MARK: Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns true when the key was consumed.
    private func handle(_ event: NSEvent) -> Bool {
        let command = event.modifierFlags.contains(.command)
        switch Int(event.keyCode) {
        case kVK_Escape:
            if model.previewing { model.previewing = false } else { hide() }
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            guard let gif = model.choice else { return false }
            send(gif, mode: command ? .pasteAndSend : .paste)
            return true
        case kVK_Space:
            // Space previews the highlighted GIF; with nothing highlighted it's just a space.
            guard model.selected != nil else { return false }
            model.previewing.toggle()
            return true
        case kVK_ANSI_D where command:
            guard let gif = model.selected else { return false }
            model.toggleFavorite(gif)
            return true
        case kVK_Tab: return model.acceptSuggestion()
        case kVK_DownArrow: return model.move(.down)
        case kVK_UpArrow: return model.move(.up)
        case kVK_LeftArrow: return !command && model.move(.left)
        case kVK_RightArrow: return !command && model.move(.right)
        case kVK_ANSI_1 where command: model.tab = .gifs; return true
        case kVK_ANSI_2 where command: model.tab = .stickers; return true
        case kVK_ANSI_3 where command: model.tab = .favorites; return true
        case kVK_ANSI_4 where command: model.tab = .recent; return true
        default: return false
        }
    }
}
