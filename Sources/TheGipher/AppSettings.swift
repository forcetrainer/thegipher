import AppKit
import Foundation
import GipherCore

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "Match system"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// nil means "follow the system".
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
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
    @Published var appearance: AppearanceChoice {
        didSet { if persists { defaults.set(appearance.rawValue, forKey: "appearance") } }
    }
    @Published var hotkey: Hotkey {
        didSet {
            guard persists, let data = try? JSONEncoder().encode(hotkey) else { return }
            defaults.set(data, forKey: "hotkeyV2")
        }
    }

    /// True while Settings is recording a new shortcut, so the current one doesn't fire.
    @Published var hotkeyPaused = false
    /// True when another app already owns the chosen shortcut.
    @Published var hotkeyConflict = false

    private init() {
        apiKey = defaults.string(forKey: "apiKey") ?? ""
        rating = defaults.string(forKey: "rating").flatMap(Rating.init(rawValue:)) ?? .r
        sendQuality =
            defaults.string(forKey: "sendQuality").flatMap(SendQuality.init(rawValue:)) ?? .original
        appearance =
            defaults.string(forKey: "appearance").flatMap(AppearanceChoice.init(rawValue:)) ?? .system
        if let data = defaults.data(forKey: "hotkeyV2"),
            let saved = try? JSONDecoder().decode(Hotkey.self, from: data)
        {
            hotkey = saved
        } else {
            hotkey = defaults.string(forKey: "hotkey").flatMap(Hotkey.legacy) ?? .default
        }
    }
}

/// A saved list of GIFs, newest first: the ones you've sent, and your favorites.
@MainActor
final class GifListStore {
    static let recents = GifListStore(key: "recents", limit: 60)
    static let favorites = GifListStore(key: "favorites", limit: 1000)

    private let key: String
    private let limit: Int
    private(set) var gifs: [Gif]

    private init(key: String, limit: Int) {
        self.key = key
        self.limit = limit
        let data = UserDefaults.standard.data(forKey: key) ?? Data()
        gifs = (try? JSONDecoder().decode([Gif].self, from: data)) ?? []
    }

    func contains(_ id: String) -> Bool {
        gifs.contains { $0.id == id }
    }

    func add(_ gif: Gif) {
        gifs.removeAll { $0.id == gif.id }
        gifs.insert(gif, at: 0)
        if gifs.count > limit { gifs.removeLast(gifs.count - limit) }
        save()
    }

    func remove(_ id: String) {
        gifs.removeAll { $0.id == id }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(gifs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
