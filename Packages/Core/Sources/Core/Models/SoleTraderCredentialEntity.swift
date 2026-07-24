//
//  SoleTraderCredential.swift
//  Data
//
//  SwiftData entity for sole trader compliance credentials.
//

import Foundation
import SwiftData

@Model
public final class SoleTraderCredential {
    #Index<SoleTraderCredential>([\.credentialType])

    public var id: UUID = UUID()
    public var credentialType: String = ""
    public var issueDate: Date = Date()
    public var expiryDate: Date?
    public var issuingBody: String = ""
    public var referenceNumber: String = ""
    public var notes: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(id: UUID = UUID()) {
        self.id = id
    }

    // MARK: - Computed Properties

    /// Derives the credential status based on the expiry date relative to the current date.
    public var credentialStatus: CredentialStatus {
        guard let expiryDate else {
            return .current
        }
        let now = Date()
        if expiryDate < now { return .expired }
        let thirtyDaysFromNow = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        if expiryDate <= thirtyDaysFromNow { return .expiringSoon }
        return .current
    }

    /// Human-readable display name for the credential type string.
    public var displayName: String {
        CredentialType(rawValue: credentialType)?.displayName ?? credentialType
    }
}
