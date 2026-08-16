//
//  NDISInvoiceBuilder.swift
//  InvoicingApplication
//
//  Extension on NDISBillingIntegrationService containing SwiftData invoice creation,
//  line item generation, and relationship linking.
//

import Foundation
import Core
import PersistenceModels
import SwiftData

// MARK: - Invoice & Line Item Creation

extension NDISBillingIntegrationService {

    /// Creates and inserts a new draft `Invoice` for an NDIS billing run.
    func makeInvoice(for client: Client, in modelContext: ModelContext) throws -> Invoice {
        let creationDefaults = InvoiceCreationDefaults.load(from: .standard)
        let issueDate = Date()
        let randomSuffix = String(format: "%04d", Int.random(in: 0..<10000))
        let invoiceNumber = "NDIS-\(Int(Date().timeIntervalSince1970))-\(randomSuffix)"
        let invoice = Invoice(id: UUID(), invoiceNumber: invoiceNumber)
        invoice.client = client
        invoice.date = issueDate
        invoice.issueDate = issueDate
        invoice.dueDate = Calendar.current.date(
            byAdding: .day,
            value: creationDefaults.paymentTermsDays,
            to: issueDate
        )
        invoice.paymentTerms = creationDefaults.paymentTermsText.trimmedNil
        invoice.notes = creationDefaults.notes.trimmedNil
        invoice.status = .reviewDraft
        invoice.totalAmount = 0
        invoice.taxRate = Decimal(creationDefaults.taxRate)
        invoice.invoiceEditorStateData = try creationDefaults.editorConfiguration.encoded()
        invoice.business = try EntityResolutionService(context: modelContext).resolveBusiness()
        invoice.snapshotRelatedData()
        modelContext.insert(invoice)
        return invoice
    }

    /// Creates and inserts `InvoiceItem` records for each claimable line.
    func insertInvoiceItems(
        for lineItems: [NDISClaimableLineItem],
        session: Session,
        invoice: Invoice,
        clientService: ClientService?,
        draftGSTBySupport: [String: String],
        existingCount: Int,
        modelContext: ModelContext
    ) -> [InvoiceItem] {
        let creationDefaults = InvoiceCreationDefaults.load(from: .standard)
        let supportName = clientService?.serviceName ?? clientService?.ndisItem?.name
        let supportUnit = Self.resolvedUnit(
            clientServiceUnit: clientService?.unit,
            catalogueUnit: clientService?.ndisItem?.unit
        )
        let resolvedGST = Self.resolvedGSTCode(
            draftCode: nil,
            clientServiceCode: clientService?.gstCode,
            fallback: GSTCode.p2
        )

        var items: [InvoiceItem] = []
        for (offset, item) in lineItems.enumerated() {
            let lineGST = Self.resolvedGSTCode(
                draftCode: draftGSTBySupport[item.supportItemNumber],
                clientServiceCode: clientService?.gstCode,
                fallback: resolvedGST
            )
            let invoiceItem = InvoiceItem(
                id: UUID(),
                itemDescription: Self.lineDescription(
                    serviceName: supportName,
                    code: item.supportItemNumber
                )
            )
            invoiceItem.position = Int32(existingCount + offset)
            invoiceItem.ndisItemNumber = item.supportItemNumber
            invoiceItem.rate = Self.currencyDecimal(item.unitPrice)
            invoiceItem.quantity = Self.currencyDecimal(item.quantity)
            invoiceItem.unit = Self.unitForClaimType(item.claimType, supportUnit: supportUnit)
            invoiceItem.gstCode = lineGST.rawValue
            invoiceItem.taxRate = lineGST.isGSTFree ? 0 : Decimal(creationDefaults.taxRate)
            invoiceItem.serviceDate = session.startTime ?? Date()
            invoiceItem.claimType = NDISClaimType(rawValue: item.claimType) ?? .direct
            invoiceItem.invoice = invoice
            invoiceItem.session = session
            invoiceItem.clientService = clientService
            modelContext.insert(invoiceItem)
            items.append(invoiceItem)
        }
        return items
    }
}

// MARK: - Invoice Formatting Helpers

extension NDISBillingIntegrationService {
    static func lineDescription(serviceName: String?, code: String) -> String {
        let name = serviceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return trimmedCode }
        if trimmedCode.isEmpty { return name }
        return "\(name) (\(trimmedCode))"
    }

    static func resolvedUnit(clientServiceUnit: String?, catalogueUnit: String?) -> String {
        let serviceUnit = clientServiceUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !serviceUnit.isEmpty { return serviceUnit }
        let catalogue = catalogueUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !catalogue.isEmpty { return catalogue }
        return "hour"
    }

    static func unitForClaimType(_ claimType: String, supportUnit: String) -> String {
        if claimType.contains("NonLabour") || claimType == NDISClaimType.activityTransport.rawValue { return "km" }
        if claimType.contains("OtherCosts") { return "each" }
        if claimType == NDISClaimType.centreCapitalCost.rawValue
            || claimType == NDISClaimType.establishmentFee.rawValue { return "unit" }
        return supportUnit
    }

    static func resolvedGSTCode(
        draftCode: String?,
        clientServiceCode: String?,
        fallback: GSTCode
    ) -> GSTCode {
        if let draftCode, let code = GSTCode(rawValue: draftCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) {
            return code
        }
        if let clientServiceCode,
           let code = GSTCode(rawValue: clientServiceCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) {
            return code
        }
        return fallback
    }

    static func currencyDecimal(_ value: Decimal) -> Decimal {
        InvoiceFinancialCalculator.currencyRounded(value)
    }
}
