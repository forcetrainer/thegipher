import Foundation

/// One encoding of a GIF (GIPHY calls these "renditions"): a size/quality variant.
public struct Rendition: Codable, Hashable, Sendable {
    public var url: URL?
    public var width: Int?
    public var height: Int?
    public var size: Int?

    public init(url: URL? = nil, width: Int? = nil, height: Int? = nil, size: Int? = nil) {
        self.url = url
        self.width = width
        self.height = height
        self.size = size
    }

    enum CodingKeys: String, CodingKey { case url, width, height, size }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let raw = try? c.decode(String.self, forKey: .url), !raw.isEmpty {
            url = URL(string: raw)
        }
        width = Self.int(c, .width)
        height = Self.int(c, .height)
        size = Self.int(c, .size)
    }

    /// GIPHY sends numbers as strings ("200"); accept either form.
    private static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let s = try? c.decode(String.self, forKey: key) { return Int(s) }
        return try? c.decode(Int.self, forKey: key)
    }

    public var aspectRatio: Double? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return Double(width) / Double(height)
    }
}

public enum SendQuality: String, CaseIterable, Sendable {
    case original, medium, small

    public var label: String {
        switch self {
        case .original: return "Original (best quality)"
        case .medium: return "Medium (under 5 MB)"
        case .small: return "Small (under 2 MB)"
        }
    }
}

public struct Gif: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    /// The GIF's page on giphy.com.
    public let url: URL?
    public let images: [String: Rendition]

    public init(id: String, title: String = "", url: URL? = nil, images: [String: Rendition]) {
        self.id = id
        self.title = title
        self.url = url
        self.images = images
    }

    enum CodingKeys: String, CodingKey { case id, title, url, images }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)).flatMap(URL.init(string:))
        images = (try? c.decode([String: Rendition].self, forKey: .images)) ?? [:]
    }

    private func first(_ names: [String]) -> Rendition? {
        for name in names {
            if let r = images[name], r.url != nil { return r }
        }
        return nil
    }

    /// Small animated rendition for the results grid.
    public var preview: Rendition? {
        first(["fixed_width", "fixed_width_downsampled", "downsized", "original"])
    }

    /// The rendition that gets pasted into the conversation.
    public func sendRendition(_ quality: SendQuality) -> Rendition? {
        switch quality {
        case .original:
            return first(["original", "downsized_large", "downsized_medium", "downsized", "fixed_width"])
        case .medium:
            return first(["downsized_medium", "downsized", "fixed_width", "original"])
        case .small:
            return first(["downsized", "fixed_width", "original"])
        }
    }
}

public struct GiphyPage: Sendable {
    /// GIPHY refuses offsets past this, however many results a search has.
    public static let maxOffset = 4999

    public let gifs: [Gif]
    public let offset: Int
    public let count: Int
    public let totalCount: Int

    public var nextOffset: Int { offset + count }

    public var hasMore: Bool {
        count > 0 && nextOffset < min(totalCount, Self.maxOffset)
    }
}

struct GiphyResponse: Decodable {
    struct Pagination: Decodable {
        let totalCount: Int?
        let count: Int?
        let offset: Int?
        enum CodingKeys: String, CodingKey {
            case totalCount = "total_count", count, offset
        }
    }

    /// Decodes to nil instead of failing, so one malformed result doesn't sink the page.
    struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    let data: [Lossy<Gif>]
    let pagination: Pagination?
}
