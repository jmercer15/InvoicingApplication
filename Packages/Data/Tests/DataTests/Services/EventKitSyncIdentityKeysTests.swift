import XCTest
@testable import Data
import Core

final class EventKitSyncIdentityKeysTests: XCTestCase {
    func testIdentityStringsPrefixesEventAndExternalIdentifiers() {
        XCTAssertEqual(
            EventKitSyncIdentityKeys.identityStrings(
                eventIdentifier: "ek-id",
                externalIdentifier: "external-id"
            ),
            ["event:ek-id", "external:external-id"]
        )
    }

    func testIdentityStringsSkipsEmptyFragments() {
        XCTAssertTrue(
            EventKitSyncIdentityKeys.identityStrings(eventIdentifier: "", externalIdentifier: nil).isEmpty
        )

        XCTAssertEqual(
            EventKitSyncIdentityKeys.identityStrings(eventIdentifier: nil, externalIdentifier: "only-external"),
            ["external:only-external"]
        )
    }
}
