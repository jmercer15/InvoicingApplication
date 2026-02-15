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
        
        public init(name: String, description: String, unit: String, rate: String?, rateValue: Double?, ndisCode: String?) {
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
        public let rateValue: Double?
        public let unit: String?
        public let category: String?
        public let status: String?
        
        public init(itemNumber: String, description: String?, rate: String?, rateValue: Double?, unit: String?, category: String?, status: String?) {
            self.itemNumber = itemNumber
            self.description = description
            self.rate = rate
            self.rateValue = rateValue
            self.unit = unit
            self.category = category
            self.status = status
        }
    }
    
    public struct InvoiceJSON: Codable, Sendable {
        public let invoiceNumber: String
        public let dateIssued: Date?
        public let dateIssuedString: String?
        public let dateDue: Date?
        public let dateDueString: String?
        public let totalAmount: Double?
        public let totalAmountString: String?
        public let status: String?
        public let clientName: String?
        
        private enum CodingKeys: String, CodingKey {
            case invoiceNumber, dateIssued, dateIssuedString, dateDue, dateDueString
            case totalAmount, totalAmountString, status, clientName
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(invoiceNumber, forKey: .invoiceNumber)
            try container.encodeIfPresent(dateIssued, forKey: .dateIssued)
            try container.encodeIfPresent(dateIssuedString, forKey: .dateIssuedString)
            try container.encodeIfPresent(dateDue, forKey: .dateDue)
            try container.encodeIfPresent(dateDueString, forKey: .dateDueString)
            try container.encodeIfPresent(totalAmount, forKey: .totalAmount)
            try container.encodeIfPresent(totalAmountString, forKey: .totalAmountString)
            try container.encodeIfPresent(status, forKey: .status)
            try container.encodeIfPresent(clientName, forKey: .clientName)
        }
        
        public init(invoiceNumber: String, dateIssued: Date?, dateIssuedString: String?, dateDue: Date?, dateDueString: String?, totalAmount: Double?, totalAmountString: String?, status: String?, clientName: String?) {
            self.invoiceNumber = invoiceNumber
            self.dateIssued = dateIssued
            self.dateIssuedString = dateIssuedString
            self.dateDue = dateDue
            self.dateDueString = dateDueString
            self.totalAmount = totalAmount
            self.totalAmountString = totalAmountString
            self.status = status
            self.clientName = clientName
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            invoiceNumber = try container.decode(String.self, forKey: .invoiceNumber)
            dateIssued = try container.decodeIfPresent(Date.self, forKey: .dateIssued)
            dateIssuedString = try container.decodeIfPresent(String.self, forKey: .dateIssuedString)
            dateDue = try container.decodeIfPresent(Date.self, forKey: .dateDue)
            dateDueString = try container.decodeIfPresent(String.self, forKey: .dateDueString)
            totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount)
            totalAmountString = try container.decodeIfPresent(String.self, forKey: .totalAmountString)
            status = try container.decodeIfPresent(String.self, forKey: .status)
            clientName = try container.decodeIfPresent(String.self, forKey: .clientName)
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
