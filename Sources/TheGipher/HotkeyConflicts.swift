import AppKit
import ApplicationServices
import Carbon.HIToolbox
import GipherCore

/// Finds other things that already use a shortcut.
///
/// macOS offers no way to list the global hotkeys other apps have registered (two apps
/// can hold the same one, and both fire), so launchers and clipboard managers can't be
/// checked. What can be: macOS's own shortcuts, and the menu shortcuts of running apps.
enum HotkeyConflicts {
    /// True when macOS itself uses the shortcut (Spotlight, screenshots, Mission Control…)
    /// and it's switched on in System Settings › Keyboard › Keyboard Shortcuts.
    static func usedBySystem(_ hotkey: Hotkey) -> Bool {
        var copied: Unmanaged<CFArray>?
        guard CopySymbolicHotKeys(&copied) == noErr,
            let entries = copied?.takeRetainedValue() as? [[String: Any]]
        else { return false }
        return entries.contains { entry in
            (entry[kHISymbolicHotKeyEnabled as String] as? Bool) == true
                && (entry[kHISymbolicHotKeyCode as String] as? Int) == Int(hotkey.keyCode)
                && (entry[kHISymbolicHotKeyModifiers as String] as? Int) == Int(hotkey.modifiers)
        }
    }

    /// Menu commands in running apps that use the shortcut, as "Messages › Find Previous".
    /// Reading other apps' menus needs the Accessibility permission; without it this
    /// finds nothing.
    static func menuCommands(using hotkey: Hotkey) async -> [String] {
        guard AXIsProcessTrusted() else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != me }
            .map { (pid: $0.processIdentifier, name: $0.localizedName ?? "An app") }
        return await Task.detached(priority: .userInitiated) {
            var found: [String] = []
            for app in apps {
                let element = AXUIElementCreateApplication(app.pid)
                // Don't let one unresponsive app stall the whole check.
                AXUIElementSetMessagingTimeout(element, 0.4)
                guard let menuBar = attribute(element, kAXMenuBarAttribute) else { continue }
                let bar = menuBar as! AXUIElement
                if let title = firstMatch(in: bar, hotkey: hotkey, depth: 0) {
                    found.append("\(app.name) › \(title)")
                }
            }
            return found
        }.value
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private static func firstMatch(in element: AXUIElement, hotkey: Hotkey, depth: Int) -> String? {
        guard depth < 6, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement]
        else { return nil }
        for child in children {
            let character = attribute(child, kAXMenuItemCmdCharAttribute) as? String
            let virtualKey = attribute(child, kAXMenuItemCmdVirtualKeyAttribute) as? Int
            if character != nil || virtualKey != nil {
                let modifiers = attribute(child, kAXMenuItemCmdModifiersAttribute) as? Int ?? 0
                if hotkey.matchesMenuShortcut(
                    character: character, virtualKey: virtualKey, menuModifiers: modifiers)
                {
                    return attribute(child, kAXTitleAttribute) as? String ?? "a menu command"
                }
            }
            if let title = firstMatch(in: child, hotkey: hotkey, depth: depth + 1) {
                return title
            }
        }
        return nil
    }
}
