import Core
import PersistenceModels
@testable import Data
import Foundation
import Testing

@Suite(.tags(.integration))
struct ExportFieldRedactorTests {
    @Test func omitBankAndNDISIdentifiersRemovesSensitiveKeys() {
        let row: [String: Any] = [
            "fullName": "Alex Example",
            "ndisNumber": "431234567",
            "bankAccountNumber": "12345678",
            "bankBSB": "012-345",
            "email": "alex@example.com",
        ]

        let redacted = ExportFieldRedactor.redactRow(row, preset: .omitBankAndNDISIdentifiers)

        #expect(redacted["fullName"] as? String == "Alex Example")
        #expect(redacted["email"] as? String == "alex@example.com")
        #expect(redacted["ndisNumber"] == nil)
        #expect(redacted["bankAccountNumber"] == nil)
        #expect(redacted["bankBSB"] == nil)
    }

    @Test func omitBankAndNDISIdentifiersRemovesClaimAdjacentFields() {
        let row: [String: Any] = [
            "participantName": "Jordan Participant",
            "participantNdisNumber": "4300123456",
            "submissionRef": "SUB-123",
        ]

        let redacted = ExportFieldRedactor.redactRow(row, preset: .omitBankAndNDISIdentifiers)

        #expect(redacted["participantName"] == nil)
        #expect(redacted["participantNdisNumber"] == nil)
        #expect(redacted["submissionRef"] == nil)
    }

    @Test func nonePresetLeavesRowUntouched() {
        let row = ["ndisNumber": "431234567"]
        let redacted = ExportFieldRedactor.redactRow(row, preset: .none)
        #expect(redacted["ndisNumber"] as? String == "431234567")
    }

    @Test func redactExportPayloadAppliesToAllEntities() {
        let payload: [String: [[String: Any]]] = [
            "Client": [["fullName": "A", "ndisNumber": "1"]],
            "Invoice": [["invoiceNumber": "INV-1", "bankBSB": "000-111"]],
        ]

        let redacted = ExportFieldRedactor.redactExportPayload(payload, preset: .omitBankAndNDISIdentifiers)

        #expect(redacted["Client"]?.first?["ndisNumber"] == nil)
        #expect(redacted["Invoice"]?.first?["bankBSB"] == nil)
        #expect(redacted["Client"]?.first?["fullName"] as? String == "A")
    }

    @Test func typedClientRedactionClearsNDISFields() {
        let clients = [
            ExportModels.ClientJSON(
                fullName: "Test",
                ndisNumber: "431234567",
                ndis_number: "431234567"
            ),
        ]

        let redacted = ExportFieldRedactor.redact(clients, preset: .omitBankAndNDISIdentifiers)
        #expect(redacted.first?.ndisNumber == nil)
        #expect(redacted.first?.ndis_number == nil)
        #expect(redacted.first?.fullName == "Test")
    }
}
