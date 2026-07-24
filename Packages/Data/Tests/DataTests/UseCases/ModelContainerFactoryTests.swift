import XCTest
import SwiftData
@testable import Data
import Core

@MainActor
final class ModelContainerFactoryTests: XCTestCase {
    func testAppSchemaContainsExpectedCoreModels() {
        let modelIDs = Set(PersistenceSchema.appModels.map(ObjectIdentifier.init))

        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(Client.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(Invoice.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(Session.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(TravelCharge.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(TravelChargeAuditLog.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(ServiceAgreement.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(SupportLog.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(SoleTraderCredential.self)))
    }

    func testMakeInMemoryContainerWithAppSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        XCTAssertNotNil(container)
    }

    func testMakeInMemoryContainerWithSubsetSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer(
            models: [RegionalPrice.self]
        )
        XCTAssertNotNil(container)
    }

    func testMakePersistentContainerWithSubsetSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makePersistentContainer(
            models: [RegionalPrice.self],
            cloudSyncEnabled: false
        )
        XCTAssertNotNil(container)
    }

    func testMakeInMemoryContextReturnsContainerAndContext() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext(
            models: [RegionalPrice.self]
        )
        XCTAssertNotNil(container)
        XCTAssertNotNil(context)
        XCTAssertFalse(context.autosaveEnabled)
    }
}
