import Foundation

public enum MediaKind: String, Sendable {
    case gifs, stickers
}

public enum Rating: String, CaseIterable, Sendable {
    case g, pg, pg13 = "pg-13", r

    public var label: String {
        switch self {
        case .g: return "G"
        case .pg: return "PG"
        case .pg13: return "PG-13"
        case .r: return "R (everything)"
        }
    }
}

public enum GiphyError: LocalizedError, Equatable {
    case missingKey
    case invalidKey
    case rateLimited
    case http(Int)
    case badResponse

    public var errorDescription: String? {
        switch self {
        case .missingKey: return "Add your GIPHY API key in Settings."
        case .invalidKey: return "GIPHY rejected the API key. Check it in Settings."
        case .rateLimited: return "GIPHY rate limit reached. Try again in a bit."
        case .http(let code): return "GIPHY returned an error (HTTP \(code))."
        case .badResponse: return "Couldn't read GIPHY's response."
        }
    }
}

public struct GiphyClient: Sendable {
    public let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Search when `query` has text, trending otherwise.
    public static func makeURL(
        apiKey: String, kind: MediaKind, query: String, offset: Int, limit: Int, rating: Rating
    ) -> URL {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var c = URLComponents()
        c.scheme = "https"
        c.host = "api.giphy.com"
        c.path = "/v1/\(kind.rawValue)/\(q.isEmpty ? "trending" : "search")"
        var items = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "rating", value: rating.rawValue),
        ]
        if !q.isEmpty {
            items.append(URLQueryItem(name: "q", value: q))
            items.append(URLQueryItem(name: "lang", value: "en"))
        }
        c.queryItems = items
        return c.url!
    }

    public static func decodePage(_ data: Data, requestedOffset: Int = 0) throws -> GiphyPage {
        guard let response = try? JSONDecoder().decode(GiphyResponse.self, from: data) else {
            throw GiphyError.badResponse
        }
        let gifs = response.data.compactMap(\.value)
        let offset = response.pagination?.offset ?? requestedOffset
        let count = response.pagination?.count ?? response.data.count
        return GiphyPage(
            gifs: gifs,
            offset: offset,
            count: count,
            totalCount: response.pagination?.totalCount ?? (offset + count)
        )
    }

    /// Decodes a list of search terms. GIPHY sends these either as bare strings
    /// (trending searches) or as objects with a `name` (autocomplete).
    public static func decodeTerms(_ data: Data) throws -> [String] {
        struct Term: Decodable {
            let name: String
            init(from decoder: Decoder) throws {
                if let bare = try? decoder.singleValueContainer().decode(String.self) {
                    name = bare
                } else {
                    let c = try decoder.container(keyedBy: CodingKeys.self)
                    name = try c.decode(String.self, forKey: .name)
                }
            }
            enum CodingKeys: String, CodingKey { case name }
        }
        struct Response: Decodable { let data: [GiphyResponse.Lossy<Term>] }
        guard let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw GiphyError.badResponse
        }
        var seen = Set<String>()
        return response.data.compactMap { $0.value?.name }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    static func termsURL(apiKey: String, path: String, query: String? = nil) -> URL {
        var c = URLComponents()
        c.scheme = "https"
        c.host = "api.giphy.com"
        c.path = path
        c.queryItems = [URLQueryItem(name: "api_key", value: apiKey)]
        if let query {
            c.queryItems?.append(URLQueryItem(name: "q", value: query))
            c.queryItems?.append(URLQueryItem(name: "limit", value: "10"))
        }
        return c.url!
    }

    private func terms(from url: URL) async throws -> [String] {
        guard !apiKey.isEmpty else { throw GiphyError.missingKey }
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return try Self.decodeTerms(data)
        case 401, 403: throw GiphyError.invalidKey
        case 429: throw GiphyError.rateLimited
        default: throw GiphyError.http(status)
        }
    }

    /// What people are searching for right now.
    public func trendingSearches() async throws -> [String] {
        try await terms(from: Self.termsURL(apiKey: apiKey, path: "/v1/trending/searches"))
    }

    /// Popular searches that start with what's been typed.
    public func autocomplete(_ partial: String) async throws -> [String] {
        try await terms(
            from: Self.termsURL(apiKey: apiKey, path: "/v1/gifs/search/tags", query: partial))
    }

    public func page(
        kind: MediaKind, query: String, offset: Int, limit: Int = 40, rating: Rating
    ) async throws -> GiphyPage {
        guard !apiKey.isEmpty else { throw GiphyError.missingKey }
        let url = Self.makeURL(
            apiKey: apiKey, kind: kind, query: query, offset: offset, limit: limit, rating: rating)
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: return try Self.decodePage(data, requestedOffset: offset)
        case 401, 403: throw GiphyError.invalidKey
        case 429: throw GiphyError.rateLimited
        default: throw GiphyError.http(status)
        }
    }
}
