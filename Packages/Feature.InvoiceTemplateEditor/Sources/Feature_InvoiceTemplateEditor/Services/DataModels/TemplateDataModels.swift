// MARK: - Data Models

import Foundation

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
}

public struct InvoiceTemplateData {
    public let invoiceNumber: String
    public let issueDate: Date
    public let dueDate: Date
    public let totalAmount: Double
    public let taxRate: Double
    public let subtotal: Double
    public let calculatedTotal: Double
}

