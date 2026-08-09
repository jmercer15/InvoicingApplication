import Core
import Foundation
import Testing

@Suite(.tags(.unit))
struct KeychainStoreTests {
    private let service = "com.invoicing.tests.keychain"
    private let account = "a6-scaffold-\(UUID().uuidString)"

    @Test func saveReadDeleteRoundTrip() throws {
        let store = KeychainStore()
        let payload = Data("secret-token".utf8)

        try store.save(payload, account: account, service: service)
        defer { try? store.delete(account: account, service: service) }

        let read = try #require(try store.read(account: account, service: service))
        #expect(read == payload)

        try store.delete(account: account, service: service)
        #expect(try store.read(account: account, service: service) == nil)
    }

    @Test func saveUpdatesExistingItem() throws {
        let store = KeychainStore()
        defer { try? store.delete(account: account, service: service) }

        try store.save(Data("v1".utf8), account: account, service: service)
        try store.save(Data("v2".utf8), account: account, service: service)

        let read = try #require(try store.read(account: account, service: service))
        #expect(read == Data("v2".utf8))
    }

    @Test func emptyAccountIsRejected() {
        let store = KeychainStore()
        #expect(throws: KeychainStoreError.invalidParameters) {
            try store.save(Data("x".utf8), account: "", service: service)
        }
    }
}
