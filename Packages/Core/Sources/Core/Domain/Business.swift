import Foundation

/// Domain model for a business
public struct Business: Identifiable, Codable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var abn: String?
    public var email: String?
    public var phone: String?
    public var address: Address?
    public var logo: Data?
    public var bankDetails: BankDetails?
    public var accountingMethod: String
    public var ndiaOrganisationID: String?
    public var isRegisteredProvider: Bool
    public var defaultGstCode: String
    
    public init(
        id: UUID,
        name: String,
        abn: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: Address? = nil,
        logo: Data? = nil,
        bankDetails: BankDetails? = nil,
        accountingMethod: String = "Accrual",
        ndiaOrganisationID: String? = nil,
        isRegisteredProvider: Bool = false,
        defaultGstCode: String = GSTCode.p2.rawValue
    ) {
        self.id = id
        self.name = name
        self.abn = abn
        self.email = email
        self.phone = phone
        self.address = address
        self.logo = logo
        self.bankDetails = bankDetails
        self.accountingMethod = accountingMethod
        self.ndiaOrganisationID = ndiaOrganisationID
        self.isRegisteredProvider = isRegisteredProvider
        self.defaultGstCode = defaultGstCode
    }
}

/// Domain model for bank details
public struct BankDetails: Codable, Equatable, Hashable, Sendable {
    public var accountName: String
    public var accountNumber: String
    public var bsb: String
    public var bankName: String
    
    public init(
        accountName: String,
        accountNumber: String,
        bsb: String,
        bankName: String
    ) {
        self.accountName = accountName
        self.accountNumber = accountNumber
        self.bsb = bsb
        self.bankName = bankName
    }
}
