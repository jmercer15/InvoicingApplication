import Testing
import Foundation
@testable import Data
import Core
import PersistenceModels

@Suite struct AllDataFactoriesComplianceTests {
    @Test func CreateBulkClaimLineRequiresBatchRelationship() {
        let payload: [String: Any] = [
            "registrationNumber": "123456789",
            "ndisNumber": "4300123456",
            "supportNumber": "01_011_0107_1_1"
        ]

        do {
            _ = try AllDataFactories.createBulkClaimLine(from: payload, entityMapping: [:])
            Issue.record("Expected error")
        } catch {
            let nsError = error as NSError
            #expect(nsError.domain == "AllDataImport")
            #expect(nsError.code == 422)
        }
    }
}
