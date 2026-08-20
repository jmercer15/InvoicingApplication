import Foundation

/// Minimal keychain seam for future credential storage (API keys, mail tokens, mTLS material).
///
/// No call sites are required today; adopt when a feature persists secrets outside SwiftData.
public protocol KeychainStoring: Sendable {
    /// Reads generic-password bytes for `service` + `account`. Returns `nil` when absent.
    func read(account: String, service: String) async throws -> Data?

    /// Inserts or updates generic-password bytes for `service` + `account`.
    func save(_ data: Data, account: String, service: String) async throws

    /// Deletes the generic-password item when present.
    func delete(account: String, service: String) async throws
}

/// Errors surfaced by ``KeychainStore``.
public enum KeychainStoreError: Error, Sendable, Equatable {
    case unexpectedStatus(OSStatus)
    case invalidParameters
}

extension KeychainStoreError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        case .invalidParameters:
            return "Keychain account and service must be non-empty."
        }
    }
}
