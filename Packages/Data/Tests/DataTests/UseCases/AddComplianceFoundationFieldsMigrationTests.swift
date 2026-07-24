import XCTest
import SwiftData
@testable import Data
import Core

@MainActor
final class AddComplianceFoundationFieldsMigrationTests: XCTestCase {
    private var modelContext: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContext = context
    }

    override func tearDown() async throws {
        modelContext = nil
        try await super.tearDown()
    }

    func testMigrationSetsDefaultsAndNormalizesBlankOrgID() throws {
        let business = Business(id: UUID(), abn: "53004085616")
        business.defaultGstCode = ""
        business.ndiaOrganisationID = "   "
        modelContext.insert(business)
        try modelContext.save()

        try AddComplianceFoundationFields_v1.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Business>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.defaultGstCode, "P2")
        XCTAssertNil(fetched.first?.ndiaOrganisationID)
    }

    func testMigrationIsIdempotentAndPreservesConfiguredValues() throws {
        let business = Business(id: UUID(), abn: "53004085617")
        business.defaultGstCode = "P1"
        business.ndiaOrganisationID = "123456789"
        business.isRegisteredProvider = true
        modelContext.insert(business)
        try modelContext.save()

        try AddComplianceFoundationFields_v1.execute(modelContext: modelContext)
        try AddComplianceFoundationFields_v1.execute(modelContext: modelContext)

        let fetched = try modelContext.fetch(FetchDescriptor<Business>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.defaultGstCode, "P1")
        XCTAssertEqual(fetched.first?.ndiaOrganisationID, "123456789")
        XCTAssertEqual(fetched.first?.isRegisteredProvider, true)
    }
}
