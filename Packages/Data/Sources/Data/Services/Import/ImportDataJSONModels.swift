import Core
import PersistenceModels
import Foundation

struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

public struct ClientJSON: Codable {
    var id: UUID?
    var fullName: String
    var email: String?
    var phone: String?
    var address: String?
    var addressLine1: String?
    var addressLine2: String?
    var addressCity: String?
    var addressState: String?
    var addressPostalCode: String?
    var city: String?
    var state: String?
    var postalCode: String?
    var zip: String?
    var addressStreet: String?
    var ndisNumber: String?
    var ndis_number: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "fullName"
        case email
        case phone
        case address
        case addressLine1 = "address_line_1"
        case addressLine2 = "address_line_2"
        case addressCity = "address_city"
        case addressState = "address_state"
        case addressPostalCode = "address_postal_code"
        case city
        case state
        case postalCode = "postal_code"
        case zip
        case addressStreet = "street"
        case ndisNumber = "ndis_number"
        case ndis_number = "ndis_number_alt"
    }
    
    // For backward compatibility
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try? container.decode(UUID.self, forKey: .id)

        // Handle different client name fields
        if let name = try? container.decode(String.self, forKey: .fullName) {
            self.fullName = name
        } else {
            // Try to decode from alternative fields that might exist in different JSON formats
            let clientNameKey = "clientName"
            let fullNameKey = "full_name"
            let nameKey = "name"
            
            let additionalContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
            
            if let name = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: clientNameKey)!) {
                self.fullName = name
            } else if let name = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: fullNameKey)!) {
                self.fullName = name
            } else if let name = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: nameKey)!) {
                self.fullName = name
            } else {
                self.fullName = ""
            }
        }
        
        // Standard fields
        self.email = try? container.decode(String.self, forKey: .email)
        self.phone = try? container.decode(String.self, forKey: .phone)
        self.address = try? container.decode(String.self, forKey: .address)
        
        // Address components
        self.addressLine1 = try? container.decode(String.self, forKey: .addressLine1)
        self.addressLine2 = try? container.decode(String.self, forKey: .addressLine2)
        self.addressCity = try? container.decode(String.self, forKey: .addressCity)
        self.addressState = try? container.decode(String.self, forKey: .addressState)
        self.addressPostalCode = try? container.decode(String.self, forKey: .addressPostalCode)
        
        // Alternative address fields
        self.city = try? container.decode(String.self, forKey: .city)
        self.state = try? container.decode(String.self, forKey: .state)
        self.postalCode = try? container.decode(String.self, forKey: .postalCode)
        self.zip = try? container.decode(String.self, forKey: .zip)
        self.addressStreet = try? container.decode(String.self, forKey: .addressStreet)
        
        // NDIS number fields
        self.ndisNumber = try? container.decode(String.self, forKey: .ndisNumber)
        self.ndis_number = try? container.decode(String.self, forKey: .ndis_number)
        
        // Check for alternative fields using dynamic keys
        let additionalContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        
        // Try additional address fields that might be present
        if self.addressLine1 == nil {
            self.addressLine1 = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "addressLine1")!)
        }
        if self.addressCity == nil && self.city == nil {
            self.city = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "city")!)
        }
        if self.addressState == nil && self.state == nil {
            self.state = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "state")!)
        }
        if self.addressPostalCode == nil && self.postalCode == nil && self.zip == nil {
            self.zip = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "zipCode")!)
        }
    }
    
    // Custom initializer for direct creation
    public init(fullName: String, 
         id: UUID? = nil,
         email: String? = nil, 
         phone: String? = nil, 
         address: String? = nil,
         addressLine1: String? = nil, 
         addressLine2: String? = nil, 
         addressCity: String? = nil, 
         addressState: String? = nil, 
         addressPostalCode: String? = nil, 
         city: String? = nil, 
         state: String? = nil, 
         postalCode: String? = nil, 
         zip: String? = nil, 
         addressStreet: String? = nil, 
         ndisNumber: String? = nil, 
         ndis_number: String? = nil) {
        
        self.id = id
        self.fullName = fullName
        self.email = email
        self.phone = phone
        self.address = address
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.addressCity = addressCity
        self.addressState = addressState
        self.addressPostalCode = addressPostalCode
        self.city = city
        self.state = state
        self.postalCode = postalCode
        self.zip = zip
        self.addressStreet = addressStreet
        self.ndisNumber = ndisNumber
        self.ndis_number = ndis_number
    }
}

public struct PayeeJSON: Codable {
    public let id: UUID?
    public let payeeName: String
    public let email: String?
    public let phone: String?
    public let address: String?
    public let bankAccount: String?
    public let bankBSB: String?
    public let status: String?
    public let relationToClient: String?

    public init(
        id: UUID? = nil,
        payeeName: String,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        bankAccount: String? = nil,
        bankBSB: String? = nil,
        status: String? = nil,
        relationToClient: String? = nil
    ) {
        self.id = id
        self.payeeName = payeeName
        self.email = email
        self.phone = phone
        self.address = address
        self.bankAccount = bankAccount
        self.bankBSB = bankBSB
        self.status = status
        self.relationToClient = relationToClient
    }
}

public struct ServiceJSON: Codable {
    public var name: String
    public var description: String
    public var unit: String
    public var rate: String?
    public var rateValue: Double?
    public var ndisCode: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case unit
        case rate
        case rateValue = "rate_value"
        case ndisCode = "ndis_code"
    }
}

public struct NDISItemJSON: Codable {
    public let itemNumber: String
    public let description: String?
    public let rate: String?
    public let rateValue: Double?
    public let unit: String?
    public let category: String?
    public let status: String?
}

public struct InvoiceTransferItemJSON: Codable, Sendable {
    public var id: UUID?
    public var position: Int32?
    public var itemDescription: String
    public var serviceDate: Date?
    public var itemCode: String?
    public var quantity: Double
    public var unit: String?
    public var unitPrice: Double
    public var taxRate: Double?
    public var gstCode: String?
}

/// Compatibility payload for invoice-only imports. Optional fields apply as patches
/// when an invoice number already exists; this is intentionally distinct from export DTOs.
public struct InvoiceImportPayload: Codable, Sendable {
    public let invoiceNumber: String
    public let dateIssued: Date?
    public let dateIssuedString: String?
    public let dateDue: Date?
    public let dateDueString: String?
    public let totalAmount: Double?
    public let totalAmountString: String?
    public let status: String?
    public let clientName: String?
    public var userData: Data? = nil
    public var currencyCode: String? = nil
    public var taxRate: Double? = nil
    public var discount: Double? = nil
    public var creditApplied: Double? = nil
    public var paymentTerms: String? = nil
    public var notes: String? = nil
    public var paidDate: Date? = nil
    public var sentDate: Date? = nil
    public var businessName: String? = nil
    public var businessABN: String? = nil
    public var businessEmail: String? = nil
    public var businessPhone: String? = nil
    public var businessAddress: AddressSnapshot? = nil
    public var clientNDISNumber: String? = nil
    public var clientEmail: String? = nil
    public var clientPhone: String? = nil
    public var clientAddress: AddressSnapshot? = nil
    public var billingAuthority: String? = nil
    public var billToName: String? = nil
    public var billToEmail: String? = nil
    public var billToAddress: AddressSnapshot? = nil
    public var bankName: String? = nil
    public var bankAccountName: String? = nil
    public var bankBSB: String? = nil
    public var bankAccountNumber: String? = nil
    public var editorConfiguration: Data? = nil
    public var items: [InvoiceTransferItemJSON]? = nil
    
    // This property won't be encoded/decoded
    private enum CodingKeys: String, CodingKey {
        case invoiceNumber, dateIssued, dateIssuedString, dateDue, dateDueString
        case totalAmount, totalAmountString, status, clientName
        case currencyCode, taxRate, discount, creditApplied, paymentTerms, notes
        case paidDate, sentDate
        case businessName, businessABN, businessEmail, businessPhone, businessAddress
        case clientNDISNumber, clientEmail, clientPhone, clientAddress
        case billingAuthority, billToName, billToEmail, billToAddress
        case bankName, bankAccountName, bankBSB, bankAccountNumber
        case editorConfiguration, items
    }
}
