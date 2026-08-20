import Foundation
import Security

/// Default ``KeychainStoring`` implementation using generic passwords.
///
/// Items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and the add-or-update pattern
/// recommended for idempotent secret rotation.
public actor KeychainStore: KeychainStoring {
    private let usesDataProtectionKeychain: Bool

    public init() {
        self.usesDataProtectionKeychain = true
    }

    /// Test-only escape hatch for non-sandboxed hosts, which lack the data-protection Keychain entitlement.
    internal init(usesDataProtectionKeychain: Bool) {
        self.usesDataProtectionKeychain = usesDataProtectionKeychain
    }

    public func read(account: String, service: String) throws -> Data? {
        try validate(account: account, service: service)

        let query = baseQuery(account: account, service: service)
            .merging([
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]) { _, new in new }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw KeychainStoreError.unexpectedStatus(status)
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    public func save(_ data: Data, account: String, service: String) throws {
        try validate(account: account, service: service)

        let query = baseQuery(account: account, service: service)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        if updateStatus != errSecItemNotFound {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        addQuery.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    public func delete(account: String, service: String) throws {
        try validate(account: account, service: service)

        let status = SecItemDelete(baseQuery(account: account, service: service) as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainStoreError.unexpectedStatus(status)
        }
    }

    private func validate(account: String, service: String) throws {
        guard !account.isEmpty, !service.isEmpty else {
            throw KeychainStoreError.invalidParameters
        }
    }

    private func baseQuery(account: String, service: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        if usesDataProtectionKeychain {
            query[kSecUseDataProtectionKeychain as String] = true
        }
        return query
    }
}
