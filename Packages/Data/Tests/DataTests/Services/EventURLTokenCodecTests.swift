@testable import Data
import Core
import XCTest

final class EventURLTokenCodecTests: XCTestCase {
    func testTokenRoundTrip() {
        let encoded = EventURLTokenCodec.encode(token: "sync-token-123", userURL: nil)
        let decoded = EventURLTokenCodec.decode(encoded)

        XCTAssertNotNil(encoded)
        XCTAssertEqual(decoded?.token, "sync-token-123")
        XCTAssertNil(decoded?.userURL)
    }

    func testTokenAndUserURLRoundTrip() {
        let userURL = URL(string: "https://example.com/path?a=1&b=two%20words#frag")!
        let encoded = EventURLTokenCodec.encode(token: "sync-token-456", userURL: userURL)
        let decoded = EventURLTokenCodec.decode(encoded)

        XCTAssertNotNil(encoded)
        XCTAssertEqual(decoded?.token, "sync-token-456")
        XCTAssertEqual(decoded?.userURL?.absoluteString, userURL.absoluteString)
    }

    func testMalformedURLRejection() {
        XCTAssertNil(EventURLTokenCodec.decode(URL(string: "https://example.com")!))
        XCTAssertNil(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?v=1")!))
        XCTAssertNil(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?t=token-only")!))
        XCTAssertNil(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?v=2&t=token")!))
        XCTAssertNil(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?v=1&t=%20%20")!))
    }
}
