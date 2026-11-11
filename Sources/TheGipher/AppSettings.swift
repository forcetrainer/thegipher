import Carbon.HIToolbox
import Foundation
import GipherCore

enum HotkeyPreset: String, CaseIterable, Identifiable {
    case optCmdG, ctrlCmdG, ctrlOptG, shiftCmdG, ctrlOptSpace

    var id: String { rawValue }

    var label: String {
        switch self {
        case .optCmdG: return "⌥⌘G"
        case .ctrlCmdG: return "⌃⌘G"
        case .ctrlOptG: return "⌃⌥G"
        case .shiftCmdG: return "⇧⌘G"
        case .ctrlOptSpace: return "⌃⌥Space"
        }
    }

    var keyCode: UInt32 {
        self == .ctrlOptSpace ? UInt32(kVK_Space) : UInt32(kVK_ANSI_G)
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .optCmdG: return UInt32(optionKey | cmdKey)
        case .ctrlCmdG: return UInt32(controlKey | cmdKey)
        case .ctrlOptG: return UInt32(controlKey | optionKey)
        case .shiftCmdG: return UInt32(shiftKey | cmdKey)
        case .ctrlOptSpace: return UInt32(controlKey | optionKey)
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard
    /// Off while rendering snapshots, so temporary values aren't saved.
    var persists = true

    @Published var apiKey: String {
        didSet { if persists { defaults.set(apiKey, forKey: "apiKey") } }
    }
    @Published var rating: Rating {
        didSet { if persists { defaults.set(rating.rawValue, forKey: "rating") } }
    }
    @Published var sendQuality: SendQuality {
        didSet { if persists { defaults.set(sendQuality.rawValue, forKey: "sendQuality") } }
    }
    @Published var hotkey: HotkeyPreset {
        didSet { if persists { defaults.set(hotkey.rawValue, forKey: "hotkey") } }
    }

    private init() {
        apiKey = defaults.string(forKey: "apiKey") ?? ""
        rating = defaults.string(forKey: "rating").flatMap(Rating.init(rawValue:)) ?? .r
        sendQuality = defaults.string(forKey: "sendQuality").flatMap(SendQuality.init(rawValue:)) ?? .original
        hotkey = defaults.string(forKey: "hotkey").flatMap(HotkeyPreset.init(rawValue:)) ?? .optCmdG
    }
}

/// The GIFs you've sent most recently, newest first.
@MainActor
final class RecentsStore {
    static let shared = RecentsStore()
    private let key = "recents"
    private let limit = 60
    private(set) var gifs: [Gif]

    private init() {
        let data = UserDefaults.standard.data(forKey: key) ?? Data()
        gifs = (try? JSONDecoder().decode([Gif].self, from: data)) ?? []
    }

    func add(_ gif: Gif) {
        gifs.removeAll { $0.id == gif.id }
        gifs.insert(gif, at: 0)
        if gifs.count > limit { gifs.removeLast(gifs.count - limit) }
        if let data = try? JSONEncoder().encode(gifs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
