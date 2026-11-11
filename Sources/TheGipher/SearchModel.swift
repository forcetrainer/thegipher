import Foundation
import GipherCore

@MainActor
final class SearchModel: ObservableObject {
    enum Tab: String, CaseIterable, Identifiable {
        case gifs, stickers, recent
        var id: String { rawValue }
        var label: String {
            switch self {
            case .gifs: return "GIFs"
            case .stickers: return "Stickers"
            case .recent: return "Recent"
            }
        }
    }

    static let columns = 4

    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            reload(debounce: !skipDebounce)
            skipDebounce = false
        }
    }
    @Published var tab: Tab = .gifs {
        didSet { if tab != oldValue { reload() } }
    }
    @Published private(set) var items: [Gif] = []
    /// Suggested searches: what's trending when the field is empty, completions of
    /// what's been typed otherwise.
    @Published private(set) var suggestions: [String] = []
    @Published var selection: Int?
    @Published private(set) var isLoading = false
    @Published var message: String?
    @Published var sendingID: String?
    /// Bumped each time the panel opens, so the view can refocus the search field.
    @Published private(set) var focusToken = 0

    var onSend: ((Gif) -> Void)?
    var onCopyOnly: ((Gif) -> Void)?

    private let settings: AppSettings
    private let recents: RecentsStore
    private var task: Task<Void, Never>?
    private var suggestionTask: Task<Void, Never>?
    private var generation = 0
    private var nextOffset = 0
    private var hasMore = false
    private var loadingMore = false
    private var skipDebounce = false

    // Suggestions cost API calls, so remember them.
    private var trendingTerms: (terms: [String], fetched: Date)?
    private var completions: [String: [String]] = [:]

    init(settings: AppSettings, recents: RecentsStore) {
        self.settings = settings
        self.recents = recents
    }

    /// The GIF that Return sends: the highlighted one, or the top result.
    var choice: Gif? {
        if let selection, items.indices.contains(selection) { return items[selection] }
        return items.first
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func panelDidOpen() {
        message = nil
        sendingID = nil
        focusToken += 1
        if query.isEmpty { reload() } else { search("") }
    }

    /// Run a search right away (a tapped suggestion), skipping the typing delay.
    func search(_ term: String) {
        skipDebounce = term != query
        query = term
    }

    /// Tab key: complete what's typed with the first suggestion that would change it.
    func acceptSuggestion() -> Bool {
        let current = trimmedQuery.lowercased()
        guard let term = suggestions.first(where: { $0.lowercased() != current }) else {
            return false
        }
        search(term)
        return true
    }

    func reload(debounce: Bool = false) {
        task?.cancel()
        suggestionTask?.cancel()
        generation += 1
        let gen = generation
        selection = nil
        nextOffset = 0
        hasMore = false
        loadingMore = false
        message = nil

        if tab == .recent {
            let q = trimmedQuery.lowercased()
            items = q.isEmpty ? recents.gifs : recents.gifs.filter { $0.title.lowercased().contains(q) }
            suggestions = []
            isLoading = false
            return
        }
        guard !settings.apiKey.isEmpty else {
            items = []
            suggestions = []
            isLoading = false
            return
        }
        isLoading = true
        task = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
            await fetch(generation: gen, offset: 0)
        }
        suggestionTask = Task {
            if debounce {
                try? await Task.sleep(for: .milliseconds(250))
                if Task.isCancelled { return }
            }
            await loadSuggestions(generation: gen)
        }
    }

    func loadMoreIfNeeded(index: Int) {
        guard hasMore, !isLoading, !loadingMore, index >= items.count - 12 else { return }
        loadingMore = true
        let gen = generation
        let offset = nextOffset
        task = Task { await fetch(generation: gen, offset: offset) }
    }

    private func fetch(generation gen: Int, offset: Int) async {
        let client = GiphyClient(apiKey: settings.apiKey)
        let kind: MediaKind = tab == .stickers ? .stickers : .gifs
        do {
            let page = try await client.page(
                kind: kind, query: query, offset: offset, rating: settings.rating)
            guard gen == generation else { return }
            // GIPHY can repeat a GIF across pages; the grid needs unique ids.
            var seen = offset == 0 ? Set<String>() : Set(items.map(\.id))
            let fresh = page.gifs.filter { $0.preview != nil && seen.insert($0.id).inserted }
            items = offset == 0 ? fresh : items + fresh
            nextOffset = page.nextOffset
            hasMore = page.hasMore
        } catch {
            guard gen == generation, !Task.isCancelled else { return }
            if offset == 0 { items = [] }
            message = error.localizedDescription
        }
        isLoading = false
        loadingMore = false
    }

    private func loadSuggestions(generation gen: Int) async {
        let client = GiphyClient(apiKey: settings.apiKey)
        let typed = trimmedQuery.lowercased()
        // Suggestions are a nicety: on any failure, just show none.
        let terms: [String]
        if typed.isEmpty {
            if let cached = trendingTerms, Date().timeIntervalSince(cached.fetched) < 900 {
                terms = cached.terms
            } else {
                terms = (try? await client.trendingSearches()) ?? []
                if !terms.isEmpty { trendingTerms = (terms, Date()) }
            }
        } else if let cached = completions[typed] {
            terms = cached
        } else {
            terms = (try? await client.autocomplete(typed)) ?? []
            if !terms.isEmpty { completions[typed] = terms }
        }
        guard gen == generation else { return }
        suggestions = terms
    }

    // MARK: Keyboard navigation

    enum Move { case up, down, left, right }

    /// Returns false when the key should fall through to the search field.
    func move(_ move: Move) -> Bool {
        guard !items.isEmpty else { return false }
        let cols = Self.columns
        switch (move, selection) {
        case (.down, nil):
            selection = 0
        case (.down, let current?):
            selection = min(current + cols, items.count - 1)
        case (.up, nil):
            return false
        case (.up, let current?):
            selection = current < cols ? nil : current - cols
        case (.left, nil), (.right, nil):
            return false
        case (.left, let current?):
            selection = max(current - 1, 0)
        case (.right, let current?):
            selection = min(current + 1, items.count - 1)
        }
        if let selection { loadMoreIfNeeded(index: selection) }
        return true
    }

    #if DEBUG
    /// Fills the grid with fixed content for layout snapshots.
    func loadSnapshot(items: [Gif], suggestions: [String], selection: Int?) {
        self.items = items
        self.suggestions = suggestions
        self.selection = selection
        isLoading = false
    }
    #endif
}
