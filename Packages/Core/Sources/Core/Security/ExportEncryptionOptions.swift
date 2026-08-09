import Foundation

/// Optional AES-GCM wrapping for Settings JSON exports.
public struct ExportEncryptionOptions: Sendable, Equatable {
    public let passphrase: String

    public init(passphrase: String) {
        self.passphrase = passphrase
    }
}
