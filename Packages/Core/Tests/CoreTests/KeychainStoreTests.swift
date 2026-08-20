@testable import Core
import Foundation
import Testing
import CoreTesting

@Suite(.tags(.unit))
struct KeychainStoreTests {
    private let service = "com.invoicing.tests.keychain"
    private let account = "a6-scaffold-\(UUID().uuidString)"

    @Test func saveReadDeleteRoundTrip() async throws {
        let store = KeychainStore(usesDataProtectionKeychain: false)
        let payload = Data("secret-token".utf8)

        try await store.save(payload, account: account, service: service)
        defer { Task { try? await store.delete(account: account, service: service) } }

        let read = try #require(try await store.read(account: account, service: service))
        #expect(read == payload)

        try await store.delete(account: account, service: service)
        #expect(try await store.read(account: account, service: service) == nil)
    }

    @Test func saveUpdatesExistingItem() async throws {
        let store = KeychainStore(usesDataProtectionKeychain: false)
        defer { Task { try? await store.delete(account: account, service: service) } }

        try await store.save(Data("v1".utf8), account: account, service: service)
        try await store.save(Data("v2".utf8), account: account, service: service)

        let read = try #require(try await store.read(account: account, service: service))
        #expect(read == Data("v2".utf8))
    }

    @Test func emptyAccountIsRejected() async {
        let store = KeychainStore(usesDataProtectionKeychain: false)
        await #expect(throws: KeychainStoreError.invalidParameters) {
            try await store.save(Data("x".utf8), account: "", service: service)
        }
    }
}
