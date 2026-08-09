import CryptoKit
import Foundation

public enum EncryptedExportError: Error, Sendable, Equatable {
    case emptyPassphrase
    case invalidContainer
    case unsupportedVersion(UInt8)
    case decryptionFailed
    case secureRandomGenerationFailed(status: Int32)
}

/// AES-GCM export wrapper for Settings JSON backups.
///
/// Container layout: magic (4) + version (1) + salt (16) + nonce (12) + ciphertext + tag (16, appended by CryptoKit).
public enum EncryptedExportContainer {
    private static let magic = Data("INVE".utf8)
    private static let version: UInt8 = 1
    private static let saltLength = 16
    private static let nonceLength = 12

    public static let fileExtension = "invoicing-export"

    public static func encrypt(plaintext: Data, passphrase: String) throws -> Data {
        guard passphrase.isEmpty == false else { throw EncryptedExportError.emptyPassphrase }

        let salt = try randomBytes(count: saltLength)
        let key = deriveKey(passphrase: passphrase, salt: salt)
        let nonce = try AES.GCM.Nonce(data: randomBytes(count: nonceLength))
        let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)

        guard let combined = sealed.combined else {
            throw EncryptedExportError.invalidContainer
        }

        var output = Data()
        output.append(magic)
        output.append(version)
        output.append(salt)
        output.append(combined)
        return output
    }

    public static func decrypt(ciphertext: Data, passphrase: String) throws -> Data {
        guard passphrase.isEmpty == false else { throw EncryptedExportError.emptyPassphrase }
        guard ciphertext.count > magic.count + 1 + saltLength + nonceLength + 16 else {
            throw EncryptedExportError.invalidContainer
        }
        guard ciphertext.prefix(magic.count) == magic else {
            throw EncryptedExportError.invalidContainer
        }

        var offset = magic.count
        let containerVersion = ciphertext[offset]
        offset += 1
        guard containerVersion == version else {
            throw EncryptedExportError.unsupportedVersion(containerVersion)
        }

        let salt = ciphertext[offset ..< offset + saltLength]
        offset += saltLength
        let sealedBoxData = ciphertext[offset...]

        let key = deriveKey(passphrase: passphrase, salt: Data(salt))
        let sealedBox = try AES.GCM.SealedBox(combined: sealedBoxData)
        do {
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw EncryptedExportError.decryptionFailed
        }
    }

    public static func isEncryptedContainer(_ data: Data) -> Bool {
        data.count >= magic.count && data.prefix(magic.count) == magic
    }

    private static func deriveKey(passphrase: String, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.utf8)),
            salt: salt,
            outputByteCount: 32
        )
    }

    private static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw EncryptedExportError.secureRandomGenerationFailed(status: status)
        }
        return Data(bytes)
    }
}
