import Core
import CryptoKit
import Foundation
import Testing
import CoreTesting

@Suite(.tags(.unit))
struct EncryptedExportContainerTests {
    @Test func roundTripPreservesPlaintext() throws {
        let plaintext = Data("{\"Client\":[]}".utf8)
        let encrypted = try EncryptedExportContainer.encrypt(plaintext: plaintext, passphrase: "phase-six-passphrase")
        #expect(EncryptedExportContainer.isEncryptedContainer(encrypted))
        let decrypted = try EncryptedExportContainer.decrypt(ciphertext: encrypted, passphrase: "phase-six-passphrase")
        #expect(decrypted == plaintext)
        #expect(encrypted[4] == 2)
    }

    @Test func decryptsLegacyVersionOneContainer() throws {
        let plaintext = Data("legacy backup".utf8)
        let passphrase = "legacy-passphrase"
        let salt = Data(repeating: 7, count: 16)
        let key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.utf8)),
            salt: salt,
            outputByteCount: 32
        )
        let nonce = try AES.GCM.Nonce(data: Data(repeating: 3, count: 12))
        let sealedBox = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
        let combined = try #require(sealedBox.combined)

        var legacyContainer = Data("INVE".utf8)
        legacyContainer.append(1)
        legacyContainer.append(salt)
        legacyContainer.append(combined)

        #expect(try EncryptedExportContainer.decrypt(ciphertext: legacyContainer, passphrase: passphrase) == plaintext)
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
