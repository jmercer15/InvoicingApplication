import XCTest
import SwiftData
@testable import Data

@MainActor
final class ModelContainerFactoryTests: XCTestCase {
    func testAppSchemaContainsExpectedCoreModels() {
        let modelIDs = Set(PersistenceSchema.appModels.map(ObjectIdentifier.init))

        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(ClientEntity.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(InvoiceEntity.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(SessionEntity.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(TravelChargeEntity.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(TravelChargeAuditLogEntity.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(ServiceAgreementEntity.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(SupportLogEntity.self)))
        XCTAssertTrue(modelIDs.contains(ObjectIdentifier(SoleTraderCredentialEntity.self)))
    }

    func testMakeInMemoryContainerWithAppSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        XCTAssertNotNil(container)
    }

    func testMakeInMemoryContainerWithSubsetSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer(
            models: [RegionalPriceEntity.self]
        )
        XCTAssertNotNil(container)
    }

    func testMakePersistentContainerWithSubsetSchemaSucceeds() throws {
        let container = try ModelContainerFactory.makePersistentContainer(
            models: [RegionalPriceEntity.self]
        )
        XCTAssertNotNil(container)
    }

    func testMakeInMemoryContextReturnsContainerAndContext() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext(
            models: [RegionalPriceEntity.self]
        )
        XCTAssertNotNil(container)
        XCTAssertNotNil(context)
        XCTAssertFalse(context.autosaveEnabled)
    }
}
