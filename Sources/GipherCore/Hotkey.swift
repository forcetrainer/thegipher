import Foundation

/// A global keyboard shortcut: a hardware key code plus modifier keys.
/// Modifiers use the Carbon bit values, which is what hotkey registration takes.
public struct Hotkey: Codable, Equatable, Sendable {
    public static let command: UInt32 = 0x100
    public static let shift: UInt32 = 0x200
    public static let option: UInt32 = 0x800
    public static let control: UInt32 = 0x1000

    public var keyCode: UInt32
    public var modifiers: UInt32
    /// How the key is shown ("G", "Space", "F5"), captured when the shortcut is recorded.
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    public static let `default` = Hotkey(keyCode: 5, modifiers: option | command, keyLabel: "G")

    /// For example "⌥⌘G", with modifiers in the order macOS menus use.
    public var label: String {
        var symbols = ""
        if modifiers & Self.control != 0 { symbols += "⌃" }
        if modifiers & Self.option != 0 { symbols += "⌥" }
        if modifiers & Self.shift != 0 { symbols += "⇧" }
        if modifiers & Self.command != 0 { symbols += "⌘" }
        return symbols + keyLabel
    }

    /// A plain key (or Shift + key) would hijack ordinary typing everywhere, so a
    /// shortcut needs ⌘, ⌥ or ⌃ unless it's a function key.
    public var isUsable: Bool {
        !keyLabel.isEmpty
            && (modifiers & (Self.command | Self.option | Self.control) != 0
                || Self.functionKeys[keyCode] != nil)
    }

    private static let functionKeys: [UInt32: String] = [
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    private static let namedKeys: [UInt32: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    /// The display name for a pressed key. `characters` is what the key types with
    /// modifiers ignored; it's used for everything that isn't a named or function key.
    public static func keyName(keyCode: UInt32, characters: String?) -> String {
        if let name = namedKeys[keyCode] ?? functionKeys[keyCode] { return name }
        let typed = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return typed.uppercased()
    }

    /// Shortcuts saved by early builds, which offered a fixed list.
    public static func legacy(_ preset: String) -> Hotkey? {
        switch preset {
        case "optCmdG": return Hotkey(keyCode: 5, modifiers: option | command, keyLabel: "G")
        case "ctrlCmdG": return Hotkey(keyCode: 5, modifiers: control | command, keyLabel: "G")
        case "ctrlOptG": return Hotkey(keyCode: 5, modifiers: control | option, keyLabel: "G")
        case "shiftCmdG": return Hotkey(keyCode: 5, modifiers: shift | command, keyLabel: "G")
        case "ctrlOptSpace":
            return Hotkey(keyCode: 49, modifiers: control | option, keyLabel: "Space")
        default: return nil
        }
    }
}
