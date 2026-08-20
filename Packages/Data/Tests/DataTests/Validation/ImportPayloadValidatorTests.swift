import Core
@testable import Data
import Foundation
import Testing
import CoreTesting
import PersistenceModels

@Suite(.tags(.unit))
struct ImportPayloadValidatorTests {
    @Test func rejectsEncryptedContainerOnPlainImport() {
        let encrypted = (try? EncryptedExportContainer.encrypt(
            plaintext: Data("{}".utf8),
            passphrase: "test-passphrase-123"
        )) ?? Data()

        #expect(throws: ImportPayloadValidationError.self) {
            try ImportPayloadValidator.validateJSONImport(data: encrypted, source: .clients)
        }
    }

    @Test func rejectsOversizedPayload() {
        let oversized = Data(repeating: 0x7B, count: ImportPayloadValidator.maxJSONPayloadBytes + 1)
        #expect(throws: ImportPayloadValidationError.self) {
            try ImportPayloadValidator.validateJSONImport(data: oversized, source: .allData)
        }
    }

    @Test func acceptsEntityArrayEnvelope() throws {
        let data = Data("[{\"fullName\":\"Alex\"}]".utf8)
        try ImportPayloadValidator.validateJSONImport(data: data, source: .clients)
    }

    @Test func rejectsNonObjectRowsForEntityImport() {
        let data = Data("[1,2,3]".utf8)
        #expect(throws: ImportPayloadValidationError.self) {
            try ImportPayloadValidator.validateJSONImport(data: data, source: .clients)
        }
    }
}
