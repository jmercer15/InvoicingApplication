import XCTest
import Core
@testable import Data

final class BulkClaimExportHashVerifierTests: XCTestCase {
    func testVerifyDataMatchesExpectedHash() {
        let verifier = BulkClaimExportHashVerifier()
        let payload = Data("hello-world".utf8)
        let hash = verifier.hash(for: payload)

        XCTAssertTrue(verifier.verify(data: payload, expectedSHA256: hash))
    }

    func testVerifyDataDetectsMismatch() {
        let verifier = BulkClaimExportHashVerifier()
        let payload = Data("hello-world".utf8)
        let different = Data("different".utf8)
        let hash = verifier.hash(for: payload)

        XCTAssertFalse(verifier.verify(data: different, expectedSHA256: hash))
    }

    func testVerifyLinesUsesDeterministicCSVHash() {
        let verifier = BulkClaimExportHashVerifier()
        let lines = [
            BulkClaimLine(
                id: UUID(),
                batchId: UUID(),
                registrationNumber: "123456789",
                ndisNumber: "4300123456",
                supportsDeliveredFrom: Date(timeIntervalSince1970: 1_700_000_000),
                supportsDeliveredTo: Date(timeIntervalSince1970: 1_700_003_600),
                supportNumber: "01_011_0107_1_1",
                quantity: 1.5,
                unitPrice: 67.0,
                gstCode: GSTCode.p2.rawValue,
                isValid: true
            )
        ]

        let hash = verifier.hash(for: lines)

        XCTAssertTrue(verifier.verify(lines: lines, expectedSHA256: hash))
    }
}
