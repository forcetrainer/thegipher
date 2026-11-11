import XCTest
@testable import GipherCore

final class GipherCoreTests: XCTestCase {
    private let fixture = """
    {
      "data": [
        {
          "id": "abc123",
          "title": "Happy Cat GIF",
          "url": "https://giphy.com/gifs/abc123",
          "images": {
            "original": {"url": "https://media.giphy.com/media/abc123/giphy.gif", "width": "480", "height": "270", "size": "2048000"},
            "fixed_width": {"url": "https://media.giphy.com/media/abc123/200w.gif", "width": "200", "height": "113", "size": "300000"},
            "downsized": {"url": "https://media.giphy.com/media/abc123/giphy-downsized.gif", "width": 320, "height": 180},
            "original_mp4": {"mp4": "https://media.giphy.com/media/abc123/giphy.mp4", "width": "480", "height": "270"},
            "downsized_medium": {"url": "", "width": "0", "height": "0"}
          }
        },
        {"title": "no id, should be skipped"},
        {"id": "bare", "images": {}}
      ],
      "pagination": {"total_count": 9000, "count": 3, "offset": 40},
      "meta": {"status": 200, "msg": "OK"}
    }
    """.data(using: .utf8)!

    func testDecodesPageAndSkipsMalformedItems() throws {
        let page = try GiphyClient.decodePage(fixture)
        XCTAssertEqual(page.gifs.map(\.id), ["abc123", "bare"])
        XCTAssertEqual(page.offset, 40)
        XCTAssertEqual(page.count, 3)
        XCTAssertEqual(page.nextOffset, 43)
        XCTAssertTrue(page.hasMore)

        let gif = page.gifs[0]
        XCTAssertEqual(gif.title, "Happy Cat GIF")
        XCTAssertEqual(gif.images["original"]?.width, 480)
        XCTAssertEqual(gif.images["original"]?.size, 2_048_000)
        XCTAssertEqual(gif.images["downsized"]?.width, 320, "numeric (non-string) sizes decode too")
        XCTAssertNil(gif.images["downsized_medium"]?.url, "empty url string means no rendition")
    }

    func testRenditionSelection() throws {
        let gif = try GiphyClient.decodePage(fixture).gifs[0]
        XCTAssertEqual(gif.preview?.url?.lastPathComponent, "200w.gif")
        XCTAssertEqual(gif.sendRendition(.original)?.url?.lastPathComponent, "giphy.gif")
        // downsized_medium has no url and the mp4-only rendition is never picked.
        XCTAssertEqual(gif.sendRendition(.medium)?.url?.lastPathComponent, "giphy-downsized.gif")
        XCTAssertEqual(gif.sendRendition(.small)?.url?.lastPathComponent, "giphy-downsized.gif")
        XCTAssertEqual(gif.preview?.aspectRatio ?? 0, 200.0 / 113.0, accuracy: 0.001)

        let bare = try GiphyClient.decodePage(fixture).gifs[1]
        XCTAssertNil(bare.preview)
        XCTAssertNil(bare.sendRendition(.original))
    }

    func testHasMoreStopsAtEndAndAtGiphyOffsetCap() {
        func page(offset: Int, count: Int, total: Int) -> GiphyPage {
            GiphyPage(gifs: [], offset: offset, count: count, totalCount: total)
        }
        XCTAssertTrue(page(offset: 0, count: 40, total: 100).hasMore)
        XCTAssertFalse(page(offset: 80, count: 20, total: 100).hasMore)
        XCTAssertFalse(page(offset: 40, count: 0, total: 100).hasMore)
        XCTAssertFalse(page(offset: 4960, count: 40, total: 1_000_000).hasMore)
    }

    func testBadPayloadThrows() {
        XCTAssertThrowsError(try GiphyClient.decodePage(Data("<html>".utf8))) {
            XCTAssertEqual($0 as? GiphyError, .badResponse)
        }
    }

    func testSearchURL() {
        let url = GiphyClient.makeURL(
            apiKey: "KEY", kind: .gifs, query: "  it's fine & dandy ", offset: 40, limit: 40, rating: .r)
        let c = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let q = Dictionary(uniqueKeysWithValues: c.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(c.host, "api.giphy.com")
        XCTAssertEqual(c.path, "/v1/gifs/search")
        XCTAssertEqual(q["q"], "it's fine & dandy")
        XCTAssertEqual(q["api_key"], "KEY")
        XCTAssertEqual(q["offset"], "40")
        XCTAssertEqual(q["rating"], "r")
        XCTAssertTrue(url.absoluteString.contains("%26"), "ampersand in the query must be escaped")
    }

    func testEmptyQueryUsesTrending() {
        let url = GiphyClient.makeURL(
            apiKey: "KEY", kind: .stickers, query: "   ", offset: 0, limit: 40, rating: .pg13)
        let c = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(c.path, "/v1/stickers/trending")
        XCTAssertNil(c.queryItems?.first { $0.name == "q" })
        XCTAssertEqual(c.queryItems?.first { $0.name == "rating" }?.value, "pg-13")
    }

    func testDecodesTermsInBothShapes() throws {
        let trending = Data(#"{"data":["party","dogs","Party",""],"meta":{"status":200}}"#.utf8)
        XCTAssertEqual(try GiphyClient.decodeTerms(trending), ["party", "dogs"])

        let autocomplete = Data(
            #"{"data":[{"name":"happy bday","analytics_response_payload":"x"},{"oops":1},{"name":"happy birthday funny"}]}"#
                .utf8)
        XCTAssertEqual(
            try GiphyClient.decodeTerms(autocomplete), ["happy bday", "happy birthday funny"])

        XCTAssertThrowsError(try GiphyClient.decodeTerms(Data("nope".utf8)))
    }

    func testAutocompleteURL() {
        let url = GiphyClient.termsURL(apiKey: "KEY", path: "/v1/gifs/search/tags", query: "happy b")
        let c = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        XCTAssertEqual(c.path, "/v1/gifs/search/tags")
        XCTAssertEqual(c.queryItems?.first { $0.name == "q" }?.value, "happy b")
    }

    func testGifRoundTripsThroughCodable() throws {
        let gif = try GiphyClient.decodePage(fixture).gifs[0]
        let again = try JSONDecoder().decode(Gif.self, from: JSONEncoder().encode(gif))
        XCTAssertEqual(gif, again)
    }
}
