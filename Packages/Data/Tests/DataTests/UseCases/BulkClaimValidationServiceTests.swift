import Foundation
import Testing
import Core
import PersistenceModels
@testable import Data

@Suite struct BulkClaimValidationServiceTests {
    @Test func InvalidRowsAreMarkedAsBlockers() async {
        let service = BulkClaimValidationService()
        let invalid = BulkClaimLine(id: UUID())
        invalid.registrationNumber = ""
        invalid.ndisNumber = "ABC"
        invalid.supportsDeliveredFrom = Date()
        invalid.supportsDeliveredTo = Date().addingTimeInterval(-60)
        invalid.supportNumber = ""
        invalid.claimReference = nil
        invalid.quantity = 0
        invalid.hours = "1:99"
        invalid.unitPrice = 0
        invalid.gstCode = "P9"
        invalid.authorisedBy = nil
        invalid.participantApproved = nil
        invalid.inKindFundingProgram = nil
        invalid.claimTypeCode = "BAD"
        invalid.cancellationReason = nil
        invalid.abnOfSupportProvider = "123"

        let result = await service.validateAndSummarize(lines: [invalid.snapshot()])
        #expect(result.summary.totalRows == 1)
        #expect(result.summary.validRows == 0)
        #expect(result.summary.invalidRows == 1)
        #expect(result.summary.hasBlockers)
        #expect(!(result.lines[0].isValid))
        #expect(result.lines[0].validationErrorSummary != nil)
    }

    @Test func CancellationRowsRequireValidReason() async {
        let service = BulkClaimValidationService()

        let missingReason = BulkClaimLine(id: UUID())
        missingReason.registrationNumber = "12345"
        missingReason.ndisNumber = "4300000000"
        missingReason.supportsDeliveredFrom = Date()
        missingReason.supportsDeliveredTo = Date().addingTimeInterval(3600)
        missingReason.supportNumber = "01_001_0107_1_1"
        missingReason.claimReference = nil
        missingReason.quantity = 1
        missingReason.hours = nil
        missingReason.unitPrice = 100
        missingReason.gstCode = "P2"
        missingReason.authorisedBy = nil
        missingReason.participantApproved = nil
        missingReason.inKindFundingProgram = nil
        missingReason.claimTypeCode = BPRClaimTypeCode.canc.rawValue
        missingReason.cancellationReason = nil
        missingReason.abnOfSupportProvider = nil

        let validReason = BulkClaimLine(id: UUID())
        validReason.registrationNumber = "12345"
        validReason.ndisNumber = "4300000000"
        validReason.supportsDeliveredFrom = Date()
        validReason.supportsDeliveredTo = Date().addingTimeInterval(3600)
        validReason.supportNumber = "01_001_0107_1_1"
        validReason.claimReference = nil
        validReason.quantity = 1
        validReason.hours = nil
        validReason.unitPrice = 100
        validReason.gstCode = "P2"
        validReason.authorisedBy = nil
        validReason.participantApproved = nil
        validReason.inKindFundingProgram = nil
        validReason.claimTypeCode = BPRClaimTypeCode.canc.rawValue
        validReason.cancellationReason = CancellationReasonCode.nsdh.rawValue
        validReason.abnOfSupportProvider = nil

        let validated = await service.validate(lines: [missingReason.snapshot(), validReason.snapshot()])
        #expect(!(validated[0].isValid))
        #expect(validated[1].isValid)
    }
}
