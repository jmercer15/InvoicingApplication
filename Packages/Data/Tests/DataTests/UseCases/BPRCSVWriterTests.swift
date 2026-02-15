import XCTest
import Core
@testable import Data

final class BPRCSVWriterTests: XCTestCase {
    func testHeaderAndColumnOrderAreExact() {
        let writer = BPRCSVWriter()
        let line = BulkClaimLine(
            id: UUID(),
            batchId: UUID(),
            registrationNumber: "12345",
            ndisNumber: "4300000000",
            supportsDeliveredFrom: Date(timeIntervalSince1970: 1_700_000_000),
            supportsDeliveredTo: Date(timeIntervalSince1970: 1_700_003_600),
            supportNumber: "01_001_0107_1_1",
            claimReference: "INV-1",
            quantity: 1,
            hours: nil,
            unitPrice: 100,
            gstCode: "P2",
            authorisedBy: "Worker",
            participantApproved: "Y",
            inKindFundingProgram: nil,
            claimTypeCode: nil,
            cancellationReason: nil,
            abnOfSupportProvider: "12345678901",
            invoiceId: UUID(),
            invoiceItemId: UUID()
        )

        let csv = writer.csvString(lines: [line])
        let rows = csv.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(rows.count, 2)

        XCTAssertEqual(
            String(rows[0]),
            "Registration Number,NDIS Number,Supports Delivered From,Supports Delivered To,Support Number,Claim Reference,Quantity,Hours,Unit Price,GST Code,Authorised By,Participant Approved,In Kind Funding Program,Claim Type,Cancellation Reason,ABN Of Support Provider"
        )

        let values = String(rows[1]).split(separator: ",", omittingEmptySubsequences: false)
        XCTAssertEqual(values.count, 16)
    }

    func testCSVEscapingAndChecksumAreDeterministic() {
        let writer = BPRCSVWriter()
        let line = BulkClaimLine(
            id: UUID(),
            batchId: UUID(),
            registrationNumber: "12345",
            ndisNumber: "4300000000",
            supportsDeliveredFrom: Date(timeIntervalSince1970: 1_700_000_000),
            supportsDeliveredTo: Date(timeIntervalSince1970: 1_700_003_600),
            supportNumber: "01_001_0107_1_1",
            claimReference: "INV,\"Q\"",
            quantity: nil,
            hours: "001:30",
            unitPrice: 100,
            gstCode: "P2",
            authorisedBy: "Worker",
            participantApproved: "Y",
            inKindFundingProgram: nil,
            claimTypeCode: BPRClaimTypeCode.thlt.rawValue,
            cancellationReason: nil,
            abnOfSupportProvider: "12345678901",
            invoiceId: UUID(),
            invoiceItemId: UUID()
        )

        let dataA = writer.csvData(lines: [line])
        let dataB = writer.csvData(lines: [line])

        XCTAssertEqual(dataA, dataB)

        let checksumA = writer.sha256Hex(for: dataA)
        let checksumB = writer.sha256Hex(for: dataB)
        XCTAssertEqual(checksumA, checksumB)

        guard let csv = String(data: dataA, encoding: .utf8) else {
            XCTFail("Expected valid UTF-8 CSV")
            return
        }
        XCTAssertTrue(csv.contains("\"INV,\"\"Q\"\"\""))
    }
}
