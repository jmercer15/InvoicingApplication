import Foundation
import Testing
import Core
import PersistenceModels
@testable import Data

@Suite struct BPRCSVWriterTests {
    @Test func HeaderAndColumnOrderAreExact() {
        let writer = BPRCSVWriter()
        let line = BulkClaimLine(id: UUID())
        line.registrationNumber = "12345"
        line.ndisNumber = "4300000000"
        line.supportsDeliveredFrom = Date(timeIntervalSince1970: 1_700_000_000)
        line.supportsDeliveredTo = Date(timeIntervalSince1970: 1_700_003_600)
        line.supportNumber = "01_001_0107_1_1"
        line.claimReference = "INV-1"
        line.quantity = Decimal(1)
        line.hours = nil
        line.unitPrice = Decimal(100)
        line.gstCode = "P2"
        line.authorisedBy = "Worker"
        line.participantApproved = "Y"
        line.inKindFundingProgram = nil
        line.claimTypeCode = nil
        line.cancellationReason = nil
        line.abnOfSupportProvider = "12345678901"

        let csv = writer.csvString(lines: [line])
        let rows = csv.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(rows.count == 2)

        #expect(String(rows[0]) == "Registration Number,NDIS Number,Supports Delivered From,Supports Delivered To,Support Number,Claim Reference,Quantity,Hours,Unit Price,GST Code,Authorised By,Participant Approved,In Kind Funding Program,Claim Type,Cancellation Reason,ABN Of Support Provider")

        let values = String(rows[1]).split(separator: ",", omittingEmptySubsequences: false)
        #expect(values.count == 16)
    }

    @Test func CSVEscapingAndChecksumAreDeterministic() {
        let writer = BPRCSVWriter()
        let line = BulkClaimLine(id: UUID())
        line.registrationNumber = "12345"
        line.ndisNumber = "4300000000"
        line.supportsDeliveredFrom = Date(timeIntervalSince1970: 1_700_000_000)
        line.supportsDeliveredTo = Date(timeIntervalSince1970: 1_700_003_600)
        line.supportNumber = "01_001_0107_1_1"
        line.claimReference = "INV,\"Q\""
        line.quantity = nil
        line.hours = "001:30"
        line.unitPrice = 100
        line.gstCode = "P2"
        line.authorisedBy = "Worker"
        line.participantApproved = "Y"
        line.inKindFundingProgram = nil
        line.claimTypeCode = BPRClaimTypeCode.thlt.rawValue
        line.cancellationReason = nil
        line.abnOfSupportProvider = "12345678901"

        let dataA = writer.csvData(lines: [line])
        let dataB = writer.csvData(lines: [line])

        #expect(dataA == dataB)

        let checksumA = writer.sha256Hex(for: dataA)
        let checksumB = writer.sha256Hex(for: dataB)
        #expect(checksumA == checksumB)

        guard let csv = String(data: dataA, encoding: .utf8) else {
            Issue.record("Expected valid UTF-8 CSV")
            return
        }
        #expect(csv.contains("\"INV,\"\"Q\"\"\""))
    }
}
