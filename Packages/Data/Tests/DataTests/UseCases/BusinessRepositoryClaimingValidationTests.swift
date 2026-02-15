import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class BusinessRepositoryClaimingValidationTests: XCTestCase {
    private var modelContext: ModelContext!
    private var repository: BusinessRepositorySwiftData!

    override func setUp() async throws {
        try await super.setUp()
        let schema = complianceSchema()
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(container)
        repository = BusinessRepositorySwiftData(modelContext: modelContext)
    }

    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        try await super.tearDown()
    }

    func testUpdateRejectsInvalidDefaultGSTCode() async throws {
        let business = Business(
            id: UUID(),
            name: "Validation Business",
            abn: "53004085620",
            defaultGstCode: "P9"
        )

        do {
            _ = try await repository.update(business)
            XCTFail("Expected invalid GST code to fail validation.")
        } catch let error as RepositoryError {
            guard case .validationFailed(let message) = error else {
                XCTFail("Expected validationFailed, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("GST"))
        }
    }

    func testUpdateRejectsRegisteredProviderWithoutValidOrgID() async throws {
        let business = Business(
            id: UUID(),
            name: "Registered Provider",
            abn: "53004085621",
            ndiaOrganisationID: "12 34",
            isRegisteredProvider: true,
            defaultGstCode: "P2"
        )

        do {
            _ = try await repository.update(business)
            XCTFail("Expected invalid NDIA org id to fail validation.")
        } catch let error as RepositoryError {
            guard case .validationFailed(let message) = error else {
                XCTFail("Expected validationFailed, got \(error)")
                return
            }
            XCTAssertTrue(message.contains("NDIA Organisation ID"))
        }
    }

    func testUpdateNormalizesClaimingFields() async throws {
        let business = Business(
            id: UUID(),
            name: "Normalized Provider",
            abn: "53004085622",
            ndiaOrganisationID: " 123456 ",
            isRegisteredProvider: true,
            defaultGstCode: " p1 "
        )

        let updated = try await repository.update(business)

        XCTAssertEqual(updated.defaultGstCode, "P1")
        XCTAssertEqual(updated.ndiaOrganisationID, "123456")
        XCTAssertTrue(updated.isRegisteredProvider)
    }
}
