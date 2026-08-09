import Testing
@testable import Data
import Core
import PersistenceModels

@Suite struct EventKitSyncIdentityKeysTests {
    @Test func IdentityStringsPrefixesEventAndExternalIdentifiers() {
        #expect(EventKitSyncIdentityKeys.identityStrings(
                eventIdentifier: "ek-id",
                externalIdentifier: "external-id"
            ) == ["event:ek-id", "external:external-id"])
    }

    @Test func IdentityStringsSkipsEmptyFragments() {
        #expect(EventKitSyncIdentityKeys.identityStrings(eventIdentifier: "", externalIdentifier: nil).isEmpty)

        #expect(EventKitSyncIdentityKeys.identityStrings(eventIdentifier: nil, externalIdentifier: "only-external") == ["external:only-external"])
    }
}
