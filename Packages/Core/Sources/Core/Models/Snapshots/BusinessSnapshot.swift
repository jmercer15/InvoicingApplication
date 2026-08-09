//
//  BusinessSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

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


    public init(
        abn: String,
        name: String,
        email: String,
        phone: String,
        id: UUID,
        logo: Data?,
        bankAccountName: String?,
        bankAccountNumber: String?,
        bankBSB: String?,
        bankName: String?,
        accountingMethod: String,
        ndiaOrganisationID: String?,
        isRegisteredProvider: Bool,
        defaultGstCode: String,
        address: AddressSnapshot?
    ) {
        self.abn = abn
        self.name = name
        self.email = email
        self.phone = phone
        self.id = id
        self.logo = logo
        self.bankAccountName = bankAccountName
        self.bankAccountNumber = bankAccountNumber
        self.bankBSB = bankBSB
        self.bankName = bankName
        self.accountingMethod = accountingMethod
        self.ndiaOrganisationID = ndiaOrganisationID
        self.isRegisteredProvider = isRegisteredProvider
        self.defaultGstCode = defaultGstCode
        self.address = address
    }

}
