import Foundation
import Testing
import Core
import PersistenceModels
@testable import Data

@Suite struct BulkClaimExportHashVerifierTests {
    @Test func VerifyDataMatchesExpectedHash() {
        let verifier = BulkClaimExportHashVerifier()
        let payload = Data("hello-world".utf8)
        let hash = verifier.hash(for: payload)

        #expect(verifier.verify(data: payload, expectedSHA256: hash))
    }

    @Test func VerifyDataDetectsMismatch() {
        let verifier = BulkClaimExportHashVerifier()
        let payload = Data("hello-world".utf8)
        let different = Data("different".utf8)
        let hash = verifier.hash(for: payload)

        #expect(!(verifier.verify(data: different, expectedSHA256: hash)))
    }

    @Test func VerifyLinesUsesDeterministicCSVHash() {
        let verifier = BulkClaimExportHashVerifier()
        let line = BulkClaimLine(id: UUID())
        line.registrationNumber = "123456789"
        line.ndisNumber = "4300123456"
        line.supportsDeliveredFrom = Date(timeIntervalSince1970: 1_700_000_000)
        line.supportsDeliveredTo = Date(timeIntervalSince1970: 1_700_003_600)
        line.supportNumber = "01_011_0107_1_1"
        line.quantity = Decimal(string: "1.5")!
        line.unitPrice = Decimal(string: "67")!
        line.gstCode = GSTCode.p2.rawValue
        line.isValid = true
        let lines = [line]

        let hash = verifier.hash(for: lines)

        #expect(verifier.verify(lines: lines, expectedSHA256: hash))
    }
}
