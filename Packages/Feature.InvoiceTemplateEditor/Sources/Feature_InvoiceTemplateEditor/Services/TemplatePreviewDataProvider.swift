import Foundation
import SwiftUI

/// Defines the data required to render template previews without depending on live application state.
public protocol TemplatePreviewDataProvider {
    func getPreviewBusinessData() -> BusinessTemplateData
    func getPreviewClientData() -> ClientTemplateData
    func getPreviewPayeeData() -> PayeeTemplateData
    func getPreviewServiceData() -> [ServiceTemplateData]
    func getPreviewInvoiceData() -> InvoiceTemplateData
}

/// Mock implementation that returns deterministic preview data for the inspector and canvas.
public struct MockPreviewDataProvider: TemplatePreviewDataProvider {
    public init() {}

    public func getPreviewBusinessData() -> BusinessTemplateData {
        BusinessTemplateData(
            name: "Acme Therapy Services",
            abn: "12 345 678 901",
            email: "accounts@acmetherapy.com",
            phone: "(02) 8000 1234",
            address: "Suite 12, 45 Market Street",
            city: "Sydney",
            state: "NSW",
            postcode: "2000",
            bankAccountName: "Acme Therapy Services",
            bankAccountNumber: "12345678",
            bankBSB: "062-000",
            bankName: "Commonwealth Bank"
        )
    }

    public func getPreviewClientData() -> ClientTemplateData {
        ClientTemplateData(
            name: "Jamie Smith",
            address: "10 Ocean View Drive",
            city: "Newcastle",
            email: "jamie.smith@example.com",
            phone: "0412 345 678",
            ndisNumber: "4301 2345 6789",
            state: "NSW",
            postcode: "2300",
            status: "Active",
            isMinor: false,
            hasNdisPlan: true
        )
    }

    public func getPreviewPayeeData() -> PayeeTemplateData {
        PayeeTemplateData(
            name: "Jordan Lee",
            role: "Plan Manager",
            id: "PLAN-9321",
            email: "jordan.lee@planwise.com.au",
            phone: "(03) 9000 1234",
            address: "Level 8, 100 Collins Street",
            city: "Melbourne",
            state: "VIC",
            postcode: "3000"
        )
    }

    public func getPreviewServiceData() -> [ServiceTemplateData] {
        [
            ServiceTemplateData(
                name: "Occupational Therapy Session",
                unit: "hour",
                rate: 150.0,
                amount: 225.0,
                quantity: 1.5,
                description: "Weekly functional capacity assessment",
                serviceDate: Date(),
                ndisItemNumber: "15_056_0128_1_3",
                ndisSupportCategory: "Capacity Building",
                ndisRegistrationGroup: "Therapeutic Supports",
                claimType: "Direct Support"
            ),
            ServiceTemplateData(
                name: "Progress Report",
                unit: "fixed",
                rate: 220.0,
                amount: 220.0,
                quantity: 1,
                description: "Quarterly NDIA progress report",
                serviceDate: Date().addingTimeInterval(-86400 * 7),
                ndisItemNumber: "15_005_0128_1_3",
                ndisSupportCategory: "Capacity Building",
                ndisRegistrationGroup: "Therapeutic Supports",
                claimType: "NDIA Report"
            )
        ]
    }

    public func getPreviewInvoiceData() -> InvoiceTemplateData {
        InvoiceTemplateData(
            invoiceNumber: "INV-2025-0012",
            issueDate: Date().addingTimeInterval(-86400 * 3),
            dueDate: Date().addingTimeInterval(86400 * 11),
            totalAmount: 445.0,
            taxRate: 0.0,
            subtotal: 445.0,
            calculatedTotal: 445.0
        )
    }
}
