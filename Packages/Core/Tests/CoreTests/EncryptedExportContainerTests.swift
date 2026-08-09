import Core
import Foundation
import Testing

@Suite(.tags(.unit))
struct EncryptedExportContainerTests {
    @Test func roundTripPreservesPlaintext() throws {
        let plaintext = Data("{\"Client\":[]}".utf8)
        let encrypted = try EncryptedExportContainer.encrypt(plaintext: plaintext, passphrase: "phase-six-passphrase")
        #expect(EncryptedExportContainer.isEncryptedContainer(encrypted))
        let decrypted = try EncryptedExportContainer.decrypt(ciphertext: encrypted, passphrase: "phase-six-passphrase")
        #expect(decrypted == plaintext)
    }

    @Test func wrongPassphraseFailsDecryption() throws {
        let encrypted = try EncryptedExportContainer.encrypt(
            plaintext: Data("secret".utf8), passphrase: "correct-passphrase")
        #expect(throws: EncryptedExportError.decryptionFailed) {
            _ = try EncryptedExportContainer.decrypt(ciphertext: encrypted, passphrase: "wrong-passphrase")
        }
    }

    @Test func emptyPassphraseRejected() {
        #expect(throws: EncryptedExportError.emptyPassphrase) {
            _ = try EncryptedExportContainer.encrypt(plaintext: Data("x".utf8), passphrase: "")
        }
    }
}
