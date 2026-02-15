import XCTest
import Core
@testable import Data

final class BulkClaimValidationServiceTests: XCTestCase {
    func testInvalidRowsAreMarkedAsBlockers() {
        let service = BulkClaimValidationService()
        let invalid = BulkClaimLine(
            id: UUID(),
            batchId: UUID(),
            registrationNumber: "",
            ndisNumber: "ABC",
            supportsDeliveredFrom: Date(),
            supportsDeliveredTo: Date().addingTimeInterval(-60),
            supportNumber: "",
            claimReference: nil,
            quantity: 0,
            hours: "1:99",
            unitPrice: 0,
            gstCode: "P9",
            authorisedBy: nil,
            participantApproved: nil,
            inKindFundingProgram: nil,
            claimTypeCode: "BAD",
            cancellationReason: nil,
            abnOfSupportProvider: "123",
            invoiceId: nil,
            invoiceItemId: nil
        )

        let result = service.validateAndSummarize(lines: [invalid])
        XCTAssertEqual(result.summary.totalRows, 1)
        XCTAssertEqual(result.summary.validRows, 0)
        XCTAssertEqual(result.summary.invalidRows, 1)
        XCTAssertTrue(result.summary.hasBlockers)
        XCTAssertFalse(result.lines[0].isValid)
        XCTAssertNotNil(result.lines[0].validationErrorSummary)
    }

    func testCancellationRowsRequireValidReason() {
        let service = BulkClaimValidationService()

        let missingReason = BulkClaimLine(
            id: UUID(),
            batchId: UUID(),
            registrationNumber: "12345",
            ndisNumber: "4300000000",
            supportsDeliveredFrom: Date(),
            supportsDeliveredTo: Date().addingTimeInterval(3600),
            supportNumber: "01_001_0107_1_1",
            claimReference: nil,
            quantity: 1,
            hours: nil,
            unitPrice: 100,
            gstCode: "P2",
            authorisedBy: nil,
            participantApproved: nil,
            inKindFundingProgram: nil,
            claimTypeCode: BPRClaimTypeCode.canc.rawValue,
            cancellationReason: nil,
            abnOfSupportProvider: nil,
            invoiceId: nil,
            invoiceItemId: nil
        )

        let validReason = BulkClaimLine(
            id: UUID(),
            batchId: UUID(),
            registrationNumber: "12345",
            ndisNumber: "4300000000",
            supportsDeliveredFrom: Date(),
            supportsDeliveredTo: Date().addingTimeInterval(3600),
            supportNumber: "01_001_0107_1_1",
            claimReference: nil,
            quantity: 1,
            hours: nil,
            unitPrice: 100,
            gstCode: "P2",
            authorisedBy: nil,
            participantApproved: nil,
            inKindFundingProgram: nil,
            claimTypeCode: BPRClaimTypeCode.canc.rawValue,
            cancellationReason: CancellationReasonCode.nsdh.rawValue,
            abnOfSupportProvider: nil,
            invoiceId: nil,
            invoiceItemId: nil
        )

        let validated = service.validate(lines: [missingReason, validReason])
        XCTAssertFalse(validated[0].isValid)
        XCTAssertTrue(validated[1].isValid)
    }
}
