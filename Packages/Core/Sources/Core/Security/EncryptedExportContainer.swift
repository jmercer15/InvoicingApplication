import CryptoKit
import CommonCrypto
import Foundation

public enum EncryptedExportError: Error, Sendable, Equatable {
    case emptyPassphrase
    case invalidContainer
    case unsupportedVersion(UInt8)
    case decryptionFailed
    case passwordKeyDerivationFailed(status: Int32)
    case secureRandomGenerationFailed(status: Int32)
}

/// AES-GCM export wrapper for Settings JSON backups.
///
/// Container layout: magic (4) + version (1) + salt (16) + nonce (12) + ciphertext + tag (16, appended by CryptoKit).
/// Version 1 used HKDF and remains decrypt-only for backwards compatibility. Version 2 uses
/// PBKDF2-HMAC-SHA256 so passphrase-protected exports resist offline guessing attacks.
public enum EncryptedExportContainer {
    private static let magic = Data("INVE".utf8)
    private static let version: UInt8 = 2
    private static let legacyVersion: UInt8 = 1
    private static let saltLength = 16
    private static let nonceLength = 12
    private static let keyLength = 32
    private static let pbkdf2Iterations: UInt32 = 600_000

    public static let fileExtension = "invoicing-export"

    public static func encrypt(plaintext: Data, passphrase: String) throws -> Data {
        guard passphrase.isEmpty == false else { throw EncryptedExportError.emptyPassphrase }

        let salt = try randomBytes(count: saltLength)
        let key = try derivePBKDF2Key(passphrase: passphrase, salt: salt)
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
        guard containerVersion == version || containerVersion == legacyVersion else {
            throw EncryptedExportError.unsupportedVersion(containerVersion)
        }

        let salt = ciphertext[offset ..< offset + saltLength]
        offset += saltLength
        let sealedBoxData = ciphertext[offset...]

        let key: SymmetricKey
        if containerVersion == legacyVersion {
            key = deriveLegacyHKDFKey(passphrase: passphrase, salt: Data(salt))
        } else {
            key = try derivePBKDF2Key(passphrase: passphrase, salt: Data(salt))
        }
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

    private static func deriveLegacyHKDFKey(passphrase: String, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(passphrase.utf8)),
            salt: salt,
            outputByteCount: keyLength
        )
    }

    private static func derivePBKDF2Key(passphrase: String, salt: Data) throws -> SymmetricKey {
        let passphraseData = Data(passphrase.utf8)
        var derivedKey = Data(repeating: 0, count: keyLength)

        let status = derivedKey.withUnsafeMutableBytes { keyBytes in
            passphraseData.withUnsafeBytes { passphraseBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passphraseBytes.bindMemory(to: Int8.self).baseAddress,
                        passphraseData.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        pbkdf2Iterations,
                        keyBytes.bindMemory(to: UInt8.self).baseAddress,
                        keyLength
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw EncryptedExportError.passwordKeyDerivationFailed(status: status)
        }
        return SymmetricKey(data: derivedKey)
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
