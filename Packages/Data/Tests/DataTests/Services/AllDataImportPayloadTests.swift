@testable import Data
import Core
import XCTest

final class AllDataImportPayloadTests: XCTestCase {
    func testRowsReturnsTypedRowsForKnownEntities() throws {
        let payloadData = try JSONSerialization.data(withJSONObject: [
            "Client": [
                [
                    "id": "client-1",
                    "fullName": "Jordan Participant"
                ]
            ],
            "Invoice": [
                [
                    "id": "invoice-1",
                    "invoiceNumber": "INV-001"
                ]
            ],
            "Ignored": [
                [
                    "id": "ignored-1"
                ]
            ]
        ])

        let payload = try AllDataImportPayload(data: payloadData)

        XCTAssertEqual(payload.sortedKeys, ["Client", "Ignored", "Invoice"])
        XCTAssertEqual(payload.rows(for: .client)?.count, 1)
        XCTAssertEqual(payload.rows(for: .client)?.first?["fullName"] as? String, "Jordan Participant")
        XCTAssertEqual(payload.rows(for: .invoice)?.first?["invoiceNumber"] as? String, "INV-001")
        XCTAssertNil(payload.rows(for: .address))
    }

    func testInvalidJSONUsesExistingImportErrorShape() {
        let invalidData = Data("{".utf8)

        XCTAssertThrowsError(try AllDataImportPayload(data: invalidData)) { error in
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ImportError")
            XCTAssertEqual(nsError.code, 100)
            XCTAssertEqual(nsError.localizedDescription, "Invalid JSON Format")
        }
    }
}
