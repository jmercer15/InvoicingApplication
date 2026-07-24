import XCTest
@testable import Data
import Core

final class AllDataFactoriesComplianceTests: XCTestCase {
    func testCreateBulkClaimLineRequiresBatchRelationship() {
        let payload: [String: Any] = [
            "registrationNumber": "123456789",
            "ndisNumber": "4300123456",
            "supportNumber": "01_011_0107_1_1"
        ]

        XCTAssertThrowsError(
            try AllDataFactories.createBulkClaimLine(from: payload, entityMapping: [:])
        ) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "AllDataImport")
            XCTAssertEqual(nsError.code, 422)
        }
    }
}
