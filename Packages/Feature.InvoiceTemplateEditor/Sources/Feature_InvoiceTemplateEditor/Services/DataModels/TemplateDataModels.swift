// MARK: - Data Models

import Foundation
import Core

// MARK: - Helper
private func formatAddress(_ address: Address?) -> String {
    guard let address = address else { return "" }
    var components: [String] = []
    if !address.unitNumber.isEmpty { components.append("Unit \(address.unitNumber)") }
    let street = "\(address.streetNumber) \(address.streetName)".trimmingCharacters(in: .whitespaces)
    if !street.isEmpty { components.append(street) }
    if !address.city.isEmpty { components.append(address.city) }
    if !address.state.isEmpty { components.append(address.state) }
    if !address.postcode.isEmpty { components.append(address.postcode) }
    if !address.country.isEmpty { components.append(address.country) }
    return components.joined(separator: ", ")
}

public struct ClientTemplateData {
    public let name: String
    public let address: String
    public let city: String
    public let email: String
    public let phone: String
    public let ndisNumber: String
    public let state: String
    public let postcode: String
    public let status: String
    public let isMinor: Bool
    public let hasNdisPlan: Bool
    
    public init(name: String, address: String, city: String, email: String, phone: String, ndisNumber: String, state: String, postcode: String, status: String, isMinor: Bool, hasNdisPlan: Bool) {
        self.name = name
        self.address = address
        self.city = city
        self.email = email
        self.phone = phone
        self.ndisNumber = ndisNumber
        self.state = state
        self.postcode = postcode
        self.status = status
        self.isMinor = isMinor
        self.hasNdisPlan = hasNdisPlan
    }
    
    public init(from invoice: Invoice, fallbackClient: Client? = nil) {
        // Use snapshotted data from invoice domain model if available
        let snapshotName = invoice.clientName ?? ""
        
        if !snapshotName.isEmpty {
            self.name = snapshotName
            self.address = formatAddress(invoice.clientAddress)
            self.city = invoice.clientAddress?.city ?? ""
            self.email = invoice.clientEmail ?? ""
            self.phone = invoice.clientPhone ?? ""
            self.ndisNumber = invoice.clientNDISNumber ?? ""
            self.state = invoice.clientAddress?.state ?? ""
            self.postcode = invoice.clientAddress?.postcode ?? ""
            // Fields not in snapshot default to reasonable values
            self.status = "Active"
            self.isMinor = false
            self.hasNdisPlan = !(invoice.clientNDISNumber ?? "").isEmpty
        } else if let client = fallbackClient {
            self.name = client.fullName
            self.address = client.address?.street ?? ""
            self.city = client.address?.city ?? ""
            self.email = client.email ?? ""
            self.phone = client.phone ?? ""
            self.ndisNumber = client.ndisNumber
            self.state = client.address?.state ?? ""
            self.postcode = client.address?.postcode ?? ""
            self.status = client.status
            self.isMinor = client.isMinor
            self.hasNdisPlan = client.hasNdisPlan
        } else {
            self.name = "No Client Data"
            self.address = ""
            self.city = ""
            self.email = ""
            self.phone = ""
            self.ndisNumber = ""
            self.state = ""
            self.postcode = ""
            self.status = "Unknown"
            self.isMinor = false
            self.hasNdisPlan = false
        }
    }
}

public struct BusinessTemplateData {
    public let name: String
    public let abn: String
    public let email: String
    public let phone: String
    public let address: String
    public let city: String
    public let state: String
    public let postcode: String
    public let bankAccountName: String
    public let bankAccountNumber: String
    public let bankBSB: String
    public let bankName: String
    
    public init(name: String, abn: String, email: String, phone: String, address: String, city: String, state: String, postcode: String, bankAccountName: String, bankAccountNumber: String, bankBSB: String, bankName: String) {
        self.name = name
        self.abn = abn
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.state = state
        self.postcode = postcode
        self.bankAccountName = bankAccountName
        self.bankAccountNumber = bankAccountNumber
        self.bankBSB = bankBSB
        self.bankName = bankName
    }
    
    public init(from invoice: Invoice, fallbackBusiness: Business? = nil) {
        let snapshotName = invoice.businessName ?? ""
        
        if !snapshotName.isEmpty {
            self.name = snapshotName
            self.abn = invoice.businessABN ?? ""
            self.email = invoice.businessEmail ?? ""
            self.phone = invoice.businessPhone ?? ""
            self.address = formatAddress(invoice.businessAddress)
            self.city = invoice.businessAddress?.city ?? ""
            self.state = invoice.businessAddress?.state ?? ""
            self.postcode = invoice.businessAddress?.postcode ?? ""
            self.bankAccountName = invoice.bankAccountName ?? ""
            self.bankAccountNumber = invoice.bankAccountNumber ?? ""
            self.bankBSB = invoice.bankBSB ?? ""
            self.bankName = invoice.bankName ?? ""
        } else if let business = fallbackBusiness {
            self.name = business.name
            self.abn = business.abn ?? ""
            self.email = business.email ?? ""
            self.phone = business.phone ?? ""
            self.address = business.address?.street ?? ""
            self.city = business.address?.city ?? ""
            self.state = business.address?.state ?? ""
            self.postcode = business.address?.postcode ?? ""
            self.bankAccountName = business.bankDetails?.accountName ?? ""
            self.bankAccountNumber = business.bankDetails?.accountNumber ?? ""
            self.bankBSB = business.bankDetails?.bsb ?? ""
            self.bankName = business.bankDetails?.bankName ?? ""
        } else {
            self.name = "No Business Data"
            self.abn = ""
            self.email = ""
            self.phone = ""
            self.address = ""
            self.city = ""
            self.state = ""
            self.postcode = ""
            self.bankAccountName = ""
            self.bankAccountNumber = ""
            self.bankBSB = ""
            self.bankName = ""
        }
    }
}

public struct PayeeTemplateData {
    public let name: String
    public let role: String
    public let id: String
    public let email: String
    public let phone: String
    public let address: String
    public let city: String
    public let state: String
    public let postcode: String
    
    public init(name: String, role: String, id: String, email: String, phone: String, address: String, city: String, state: String, postcode: String) {
        self.name = name
        self.role = role
        self.id = id
        self.email = email
        self.phone = phone
        self.address = address
        self.city = city
        self.state = state
        self.postcode = postcode
    }
    
    public init(from invoice: Invoice, fallbackPayee: Payee? = nil) {
        let snapshotName = invoice.payeeName ?? invoice.billToName ?? ""
        
        if !snapshotName.isEmpty {
            self.name = snapshotName
            self.role = "Parent/Guardian"
            self.id = invoice.payeeId?.uuidString ?? UUID().uuidString
            self.email = invoice.payeeEmail ?? invoice.billToEmail ?? ""
            self.phone = invoice.payeePhone ?? ""
            let payeeAddr = formatAddress(invoice.payeeAddress)
            let billToAddr = formatAddress(invoice.billToAddress)
            self.address = !payeeAddr.isEmpty ? payeeAddr : billToAddr
            self.city = invoice.payeeAddress?.city ?? invoice.billToAddress?.city ?? ""
            self.state = invoice.payeeAddress?.state ?? invoice.billToAddress?.state ?? ""
            self.postcode = invoice.payeeAddress?.postcode ?? invoice.billToAddress?.postcode ?? ""
        } else if let payee = fallbackPayee {
            self.name = payee.fullName
            self.role = payee.relationToClient ?? "Parent/Guardian"
            self.id = payee.id.uuidString
            self.email = payee.email ?? ""
            self.phone = payee.phone ?? ""
            self.address = payee.address?.street ?? ""
            self.city = payee.address?.city ?? ""
            self.state = payee.address?.state ?? ""
            self.postcode = payee.address?.postcode ?? ""
        } else {
            self.name = "No Payee Data"
            self.role = ""
            self.id = UUID().uuidString
            self.email = ""
            self.phone = ""
            self.address = ""
            self.city = ""
            self.state = ""
            self.postcode = ""
        }
    }
}

public struct ServiceTemplateData {
    public let name: String
    public let unit: String
    public let rate: Double
    public let amount: Double
    public let quantity: Double
    public let description: String
    public let serviceDate: Date
    public let ndisItemNumber: String?
    public let ndisSupportCategory: String?
    public let ndisRegistrationGroup: String?
    public let claimType: String?
    
    public init(name: String, unit: String, rate: Double, amount: Double, quantity: Double, description: String, serviceDate: Date, ndisItemNumber: String?, ndisSupportCategory: String?, ndisRegistrationGroup: String?, claimType: String?) {
        self.name = name
        self.unit = unit
        self.rate = rate
        self.amount = amount
        self.quantity = quantity
        self.description = description
        self.serviceDate = serviceDate
        self.ndisItemNumber = ndisItemNumber
        self.ndisSupportCategory = ndisSupportCategory
        self.ndisRegistrationGroup = ndisRegistrationGroup
        self.claimType = claimType
    }
    
    public init(from item: InvoiceItem) {
        self.name = item.itemDescription
        self.unit = item.unit ?? "hr"
        self.rate = item.rate
        self.amount = item.lineTotal
        self.quantity = item.quantity
        self.description = item.itemDescription
        self.serviceDate = item.serviceDate
        self.ndisItemNumber = item.ndisItemNumber
        self.ndisSupportCategory = item.ndisSupportCategory
        self.ndisRegistrationGroup = item.ndisRegistrationGroup
        self.claimType = item.claimType
    }
}

public struct InvoiceTemplateData {
    public let invoiceNumber: String
    public let issueDate: Date
    public let dueDate: Date
    public let totalAmount: Double
    public let taxRate: Double
    public let subtotal: Double
    public let calculatedTotal: Double
    public let notes: String
    public let paymentTerms: String
    public let creditApplied: Double
    public let discount: Double
    public let billToEmail: String?
    public let billingAuthority: String?
    
    public init(invoiceNumber: String, issueDate: Date, dueDate: Date, totalAmount: Double, taxRate: Double, subtotal: Double, calculatedTotal: Double, notes: String, paymentTerms: String, creditApplied: Double, discount: Double, billToEmail: String? = nil, billingAuthority: String? = nil) {
        self.invoiceNumber = invoiceNumber
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.totalAmount = totalAmount
        self.taxRate = taxRate
        self.subtotal = subtotal
        self.calculatedTotal = calculatedTotal
        self.notes = notes
        self.paymentTerms = paymentTerms
        self.creditApplied = creditApplied
        self.discount = discount
        self.billToEmail = billToEmail
        self.billingAuthority = billingAuthority
    }
    
    public init(from invoice: Invoice, items: [InvoiceItem]) {
        self.invoiceNumber = invoice.invoiceNumber
        self.issueDate = invoice.issueDate
        self.dueDate = invoice.dueDate ?? Date()
        self.notes = invoice.notes ?? ""
        self.paymentTerms = invoice.paymentTerms ?? ""
        self.creditApplied = invoice.creditApplied
        self.discount = invoice.discount
        self.taxRate = invoice.taxRate
        
        let subtotalCalc = items.reduce(0.0) { $0 + $1.lineTotal }
        self.subtotal = subtotalCalc
        
        // Calculate total - using invoice totalAmount if available, otherwise calculate from subtotal
        self.totalAmount = invoice.totalAmount
        self.calculatedTotal = invoice.totalAmount > 0 ? invoice.totalAmount : (subtotalCalc * (1 + invoice.taxRate / 100.0))
        
        self.billToEmail = invoice.billToEmail
        self.billingAuthority = invoice.billingAuthority
    }
}

