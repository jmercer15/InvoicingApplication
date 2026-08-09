import Core
import Foundation

/// Models used specifically for data export formatting
public struct ExportModels {
    
    public struct ExportDynamicCodingKeys: CodingKey {
        public var stringValue: String
        public var intValue: Int?
        
        public init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        public init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
    
    public struct ClientJSON: Codable, Sendable {
        public var fullName: String
        public var email: String?
        public var phone: String?
        public var address: String?
        public var addressLine1: String?
        public var addressLine2: String?
        public var addressCity: String?
        public var addressState: String?
        public var addressPostalCode: String?
        public var city: String?
        public var state: String?
        public var postalCode: String?
        public var zip: String?
        public var addressStreet: String?
        public var ndisNumber: String?
        public var ndis_number: String?
        
        enum CodingKeys: String, CodingKey {
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
        
        public init(fullName: String,
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
    
    public struct PayeeJSON: Codable, Sendable {
        public let payeeName: String
        public let email: String?
        public let phone: String?
        public let address: String?
        public let bankAccount: String?
        public let bankBSB: String?
        public let status: String?
        public let relationToClient: String?
        
        public init(payeeName: String, email: String?, phone: String?, address: String?, bankAccount: String?, bankBSB: String?, status: String?, relationToClient: String?) {
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
    
    public struct ServiceJSON: Codable, Sendable {
        public var name: String
        public var description: String
        public var unit: String
        public var rate: String?
        public var rateValue: Decimal?
        public var ndisCode: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case description
            case unit
            case rate
            case rateValue = "rate_value"
            case ndisCode = "ndis_code"
        }
        
        public init(name: String, description: String, unit: String, rate: String?, rateValue: Decimal?, ndisCode: String?) {
            self.name = name
            self.description = description
            self.unit = unit
            self.rate = rate
            self.rateValue = rateValue
            self.ndisCode = ndisCode
        }
    }
    
    public struct NDISItemJSON: Codable, Sendable {
        public let itemNumber: String
        public let description: String?
        public let rate: String?
        public let rateValue: Decimal?
        public let unit: String?
        public let category: String?
        public let status: String?
        
        public init(itemNumber: String, description: String?, rate: String?, rateValue: Decimal?, unit: String?, category: String?, status: String?) {
            self.itemNumber = itemNumber
            self.description = description
            self.rate = rate
            self.rateValue = rateValue
            self.unit = unit
            self.category = category
            self.status = status
        }
    }
    
    public struct InvoiceItemJSON: Codable, Sendable {
        public let id: UUID
        public let position: Int32
        public let itemDescription: String
        public let serviceDate: Date
        public let itemCode: String?
        public let quantity: Decimal
        public let unit: String?
        public let unitPrice: Decimal
        public let taxRate: Decimal
        public let gstCode: String?
    }

    public struct InvoiceJSON: Codable, Sendable {
        public let invoiceNumber: String
        public let dateIssued: Date?
        public let dateIssuedString: String?
        public let dateDue: Date?
        public let dateDueString: String?
        public let totalAmount: Decimal?
        public let totalAmountString: String?
        public let status: String?
        public let clientName: String?
        public let currencyCode: String
        public let taxRate: Decimal
        public let discount: Decimal
        public let creditApplied: Decimal
        public let paymentTerms: String?
        public let notes: String?
        public let paidDate: Date?
        public let sentDate: Date?
        public let businessName: String?
        public let businessABN: String?
        public let businessEmail: String?
        public let businessPhone: String?
        public let businessAddress: AddressSnapshot?
        public let clientNDISNumber: String?
        public let clientEmail: String?
        public let clientPhone: String?
        public let clientAddress: AddressSnapshot?
        public let billingAuthority: String?
        public let billToName: String?
        public let billToEmail: String?
        public let billToAddress: AddressSnapshot?
        public let bankName: String?
        public let bankAccountName: String?
        public let bankBSB: String?
        public let bankAccountNumber: String?
        public let editorConfiguration: Data?
        public let items: [InvoiceItemJSON]

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

        public init(
            invoiceNumber: String,
            dateIssued: Date?,
            dateIssuedString: String?,
            dateDue: Date?,
            dateDueString: String?,
            totalAmount: Decimal?,
            totalAmountString: String?,
            status: String?,
            clientName: String?,
            currencyCode: String,
            taxRate: Decimal,
            discount: Decimal,
            creditApplied: Decimal,
            paymentTerms: String?,
            notes: String?,
            paidDate: Date?,
            sentDate: Date?,
            businessName: String?,
            businessABN: String?,
            businessEmail: String?,
            businessPhone: String?,
            businessAddress: AddressSnapshot?,
            clientNDISNumber: String?,
            clientEmail: String?,
            clientPhone: String?,
            clientAddress: AddressSnapshot?,
            billingAuthority: String?,
            billToName: String?,
            billToEmail: String?,
            billToAddress: AddressSnapshot?,
            bankName: String?,
            bankAccountName: String?,
            bankBSB: String?,
            bankAccountNumber: String?,
            editorConfiguration: Data?,
            items: [InvoiceItemJSON]
        ) {
            self.invoiceNumber = invoiceNumber
            self.dateIssued = dateIssued
            self.dateIssuedString = dateIssuedString
            self.dateDue = dateDue
            self.dateDueString = dateDueString
            self.totalAmount = totalAmount
            self.totalAmountString = totalAmountString
            self.status = status
            self.clientName = clientName
            self.currencyCode = currencyCode
            self.taxRate = taxRate
            self.discount = discount
            self.creditApplied = creditApplied
            self.paymentTerms = paymentTerms
            self.notes = notes
            self.paidDate = paidDate
            self.sentDate = sentDate
            self.businessName = businessName
            self.businessABN = businessABN
            self.businessEmail = businessEmail
            self.businessPhone = businessPhone
            self.businessAddress = businessAddress
            self.clientNDISNumber = clientNDISNumber
            self.clientEmail = clientEmail
            self.clientPhone = clientPhone
            self.clientAddress = clientAddress
            self.billingAuthority = billingAuthority
            self.billToName = billToName
            self.billToEmail = billToEmail
            self.billToAddress = billToAddress
            self.bankName = bankName
            self.bankAccountName = bankAccountName
            self.bankBSB = bankBSB
            self.bankAccountNumber = bankAccountNumber
            self.editorConfiguration = editorConfiguration
            self.items = items
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            invoiceNumber = try container.decode(String.self, forKey: .invoiceNumber)
            dateIssued = try container.decodeIfPresent(Date.self, forKey: .dateIssued)
            dateIssuedString = try container.decodeIfPresent(String.self, forKey: .dateIssuedString)
            dateDue = try container.decodeIfPresent(Date.self, forKey: .dateDue)
            dateDueString = try container.decodeIfPresent(String.self, forKey: .dateDueString)
            totalAmount = Self.decodeOptionalLegacyDecimal(from: container, forKey: .totalAmount)
            totalAmountString = try container.decodeIfPresent(String.self, forKey: .totalAmountString)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            clientName = try container.decodeIfPresent(String.self, forKey: .clientName)
            currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode) ?? "AUD"
            taxRate = Self.decodeLegacyDecimal(from: container, forKey: .taxRate)
            discount = Self.decodeLegacyDecimal(from: container, forKey: .discount)
            creditApplied = Self.decodeLegacyDecimal(from: container, forKey: .creditApplied)
            paymentTerms = try container.decodeIfPresent(String.self, forKey: .paymentTerms)
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
            paidDate = try container.decodeIfPresent(Date.self, forKey: .paidDate)
            sentDate = try container.decodeIfPresent(Date.self, forKey: .sentDate)
            businessName = try container.decodeIfPresent(String.self, forKey: .businessName)
            businessABN = try container.decodeIfPresent(String.self, forKey: .businessABN)
            businessEmail = try container.decodeIfPresent(String.self, forKey: .businessEmail)
            businessPhone = try container.decodeIfPresent(String.self, forKey: .businessPhone)
            businessAddress = try container.decodeIfPresent(AddressSnapshot.self, forKey: .businessAddress)
            clientNDISNumber = try container.decodeIfPresent(String.self, forKey: .clientNDISNumber)
            clientEmail = try container.decodeIfPresent(String.self, forKey: .clientEmail)
            clientPhone = try container.decodeIfPresent(String.self, forKey: .clientPhone)
            clientAddress = try container.decodeIfPresent(AddressSnapshot.self, forKey: .clientAddress)
            billingAuthority = try container.decodeIfPresent(String.self, forKey: .billingAuthority)
            billToName = try container.decodeIfPresent(String.self, forKey: .billToName)
            billToEmail = try container.decodeIfPresent(String.self, forKey: .billToEmail)
            billToAddress = try container.decodeIfPresent(AddressSnapshot.self, forKey: .billToAddress)
            bankName = try container.decodeIfPresent(String.self, forKey: .bankName)
            bankAccountName = try container.decodeIfPresent(String.self, forKey: .bankAccountName)
            bankBSB = try container.decodeIfPresent(String.self, forKey: .bankBSB)
            bankAccountNumber = try container.decodeIfPresent(String.self, forKey: .bankAccountNumber)
            editorConfiguration = try container.decodeIfPresent(Data.self, forKey: .editorConfiguration)
            items = try container.decodeIfPresent([InvoiceItemJSON].self, forKey: .items) ?? []
        }

        private static func decodeLegacyDecimal(
            from container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) -> Decimal {
            if let decimal = try? container.decodeIfPresent(Decimal.self, forKey: key) {
                return decimal
            }
            let legacy = (try? container.decodeIfPresent(Double.self, forKey: key)) ?? nil
            return Decimal(legacy ?? 0)
        }

        private static func decodeOptionalLegacyDecimal(
            from container: KeyedDecodingContainer<CodingKeys>,
            forKey key: CodingKeys
        ) -> Decimal? {
            if let decimal = try? container.decodeIfPresent(Decimal.self, forKey: key) {
                return decimal
            }
            if let legacy = try? container.decodeIfPresent(Double.self, forKey: key) {
                return Decimal(legacy)
            }
            return nil
        }
    }
    
    public struct SessionJSON: Codable, Sendable {
        public var title: String
        public var date: String
        public var startTime: String
        public var endTime: String?
        public var clientName: String
        public var location: String?
        public var notes: String?
        public var status: String?
        
        public init(title: String, date: String, startTime: String, endTime: String?, clientName: String, location: String?, notes: String?, status: String?) {
            self.title = title
            self.date = date
            self.startTime = startTime
            self.endTime = endTime
            self.clientName = clientName
            self.location = location
            self.notes = notes
            self.status = status
        }
    }
}
