//
//  BusinessSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation
import SwiftData

// MARK: - BusinessSnapshot

public struct BusinessSnapshot: Sendable, Equatable, Hashable {
    public let abn: String
    public let name: String
    public let email: String
    public let phone: String
    public let id: UUID
    public let logo: Data?
    public let bankAccountName: String?
    public let bankAccountNumber: String?
    public let bankBSB: String?
    public let bankName: String?
    public let accountingMethod: String
    public let ndiaOrganisationID: String?
    public let isRegisteredProvider: Bool
    public let defaultGstCode: String
    public let address: AddressSnapshot?

    public init(_ business: Business) {
        self.abn = business.abn
        self.name = business.name
        self.email = business.email
        self.phone = business.phone
        self.id = business.id
        self.logo = business.logo
        self.bankAccountName = business.bankAccountName
        self.bankAccountNumber = business.bankAccountNumber
        self.bankBSB = business.bankBSB
        self.bankName = business.bankName
        self.accountingMethod = business.accountingMethod
        self.ndiaOrganisationID = business.ndiaOrganisationID
        self.isRegisteredProvider = business.isRegisteredProvider
        self.defaultGstCode = business.defaultGstCode
        self.address = business.address.map(AddressSnapshot.init)
    }
}

