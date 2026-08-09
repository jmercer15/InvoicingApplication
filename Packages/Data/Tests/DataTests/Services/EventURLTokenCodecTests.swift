import Foundation
@testable import Data
import Core
import Testing
import PersistenceModels
@Suite struct EventURLTokenCodecTests {
    @Test func TokenRoundTrip() {
        let encoded = EventURLTokenCodec.encode(token: "sync-token-123", userURL: nil)
        let decoded = EventURLTokenCodec.decode(encoded)

        #expect(encoded != nil)
        #expect(decoded?.token == "sync-token-123")
        #expect(decoded?.userURL == nil)
    }

    @Test func TokenAndUserURLRoundTrip() {
        let userURL = URL(string: "https://example.com/path?a=1&b=two%20words#frag")!
        let encoded = EventURLTokenCodec.encode(token: "sync-token-456", userURL: userURL)
        let decoded = EventURLTokenCodec.decode(encoded)

        #expect(encoded != nil)
        #expect(decoded?.token == "sync-token-456")
        #expect(decoded?.userURL?.absoluteString == userURL.absoluteString)
    }

    @Test func MalformedURLRejection() {
        #expect(EventURLTokenCodec.decode(URL(string: "https://example.com")!) == nil)
        #expect(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?v=1")!) == nil)
        #expect(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?t=token-only")!) == nil)
        #expect(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?v=2&t=token")!) == nil)
        #expect(EventURLTokenCodec.decode(URL(string: "invoicing://ek-token?v=1&t=%20%20")!) == nil)
    }
}
