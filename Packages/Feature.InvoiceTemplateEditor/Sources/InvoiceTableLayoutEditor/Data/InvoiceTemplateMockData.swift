import Core
import Foundation

/// Deterministic, non-persisted content used only to preview application template formatting.
enum InvoiceTemplateMockData {
    static func snapshot(
        template: InvoiceTemplateConfiguration = .default
    ) -> InvoiceSnapshot {
        snapshot(defaults: InvoiceTemplateDefaults(configuration: template))
    }

    static func snapshot(defaults: InvoiceTemplateDefaults) -> InvoiceSnapshot {
        let defaults = defaults.sanitized
        let calendar = Calendar(identifier: .gregorian)
        let issueDate = calendar.date(from: DateComponents(year: 2026, month: 7, day: 14))
            ?? Date(timeIntervalSinceReferenceDate: 805_420_800)
        let dueDate = calendar.date(byAdding: .day, value: 14, to: issueDate) ?? issueDate
        let document = InvoiceDocument(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            invoiceNumber: "INV-DEMO-001",
            title: "Tax Invoice",
            status: .readyToSend,
            issueDate: issueDate,
            dueDate: dueDate,
            sellerName: "Harbour Allied Health",
            sellerAddress: "18 River Terrace, Brisbane QLD 4000",
            sellerEmail: "accounts@harbourhealth.example",
            sellerPhone: "07 3000 1234",
            sellerTaxID: "12 345 678 901",
            billParticipantDirectly: false,
            billToName: "Northside Plan Management",
            billToEmail: "invoices@northside.example",
            billToAddress: "90 Boundary Street, Brisbane QLD 4000",
            billToPhone: "07 3000 5678",
            billingAuthority: "Plan Manager",
            clientName: "Alex Morgan",
            clientAddress: "42 Jacaranda Avenue, New Farm QLD 4005",
            clientEmail: "alex.morgan@example.com",
            clientPhone: "0412 345 678",
            clientTaxID: "430012345",
            bankName: "Example Bank",
            bankAccountName: "Harbour Allied Health",
            bankBSB: "123-456",
            bankAccountNumber: "12345678",
            currencyCode: InvoiceCurrencyCode.defaultValue,
            defaultTaxRate: 0,
            paymentTerms: "Payment due within 14 days.",
            notes: "Thank you for choosing Harbour Allied Health."
        )
        document.paperSize = defaults.paperSize
        document.pageOrientation = defaults.pageOrientation
        document.templateConfiguration = defaults.configuration
        document.lineItems = [
            InvoiceLineItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                sortOrder: 0,
                itemDescription: "Therapeutic Supports",
                serviceDate: issueDate,
                itemCode: "15_054_0128_1_3",
                quantity: 1.5,
                unit: "Hour",
                unitPrice: 193.99
            ),
            InvoiceLineItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                sortOrder: 1,
                itemDescription: "Provider travel — labour costs",
                serviceDate: issueDate,
                itemCode: "15_799_0128_1_3",
                quantity: 0.5,
                unit: "Hour",
                unitPrice: 193.99
            ),
            InvoiceLineItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
                sortOrder: 2,
                itemDescription: "Provider travel — non-labour costs",
                serviceDate: issueDate,
                itemCode: "15_800_0128_1_3",
                quantity: 18,
                unit: "Kilometre",
                unitPrice: 0.99
            )
        ]
        document.recalculateTotals()
        return InvoiceSnapshot(document)
    }
}
