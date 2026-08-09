@testable import Data
import Core
import Foundation
import PersistenceModels
import Testing
@Suite struct AllDataImportPayloadTests {
    @Test func RowsReturnsTypedRowsForKnownEntities() throws {
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

        #expect(payload.sortedKeys == ["Client", "Ignored", "Invoice"])
        #expect(payload.rows(for: .client)?.count == 1)
        #expect(payload.rows(for: .client)?.first?["fullName"] as? String == "Jordan Participant")
        #expect(payload.rows(for: .invoice)?.first?["invoiceNumber"] as? String == "INV-001")
        #expect(payload.rows(for: .address) == nil)
    }

    @Test func InvalidJSONUsesExistingImportErrorShape() {
        let invalidData = Data("{".utf8)

        do {
            _ = try AllDataImportPayload(data: invalidData)
            Issue.record("Expected error")
        } catch {
            let nsError = error as NSError
            #expect(nsError.domain == "ImportError")
            #expect(nsError.code == 100)
            #expect(nsError.localizedDescription == "Invalid JSON Format")
        }
    }
}
