import XCTest
@testable import Data

final class AllDataFactoriesComplianceTests: XCTestCase {
    func testCreateBulkClaimLineEntityRequiresBatchRelationship() {
        let payload: [String: Any] = [
            "registrationNumber": "123456789",
            "ndisNumber": "4300123456",
            "supportNumber": "01_011_0107_1_1"
        ]

        XCTAssertThrowsError(
            try AllDataFactories.createBulkClaimLineEntity(from: payload, entityMapping: [:])
        ) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "AllDataImport")
            XCTAssertEqual(nsError.code, 422)
        }
    }
}
