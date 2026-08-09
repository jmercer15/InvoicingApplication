import Core
import Foundation

/// Applies export redaction presets to dictionary and typed JSON payloads.
enum ExportFieldRedactor {
    static let bankAndNDISFieldKeys: Set<String> = [
        "ndisNumber",
        "ndis_number",
        "clientNDISNumber",
        "participantNdisNumber",
        "participantName",
        "ndiaOrganisationID",
        "bankAccountName",
        "bankAccountNumber",
        "bankBSB",
        "bankName",
        "bankAccount",
        "submissionRef",
        "submission_ref",
        "clientTaxID",
        "taxID",
        "taxId",
    ]

    static func redactExportPayload(
        _ payload: [String: [[String: Any]]],
        preset: ExportRedactionPreset
    ) -> [String: [[String: Any]]] {
        guard preset == .omitBankAndNDISIdentifiers else { return payload }
        return payload.mapValues { rows in
            rows.map { redactRow($0, preset: preset) }
        }
    }

    static func redactRow(_ row: [String: Any], preset: ExportRedactionPreset) -> [String: Any] {
        guard preset == .omitBankAndNDISIdentifiers else { return row }
        var copy = row
        for key in bankAndNDISFieldKeys {
            copy.removeValue(forKey: key)
        }
        return copy
    }

    static func redact(_ clients: [ExportModels.ClientJSON], preset: ExportRedactionPreset) -> [ExportModels.ClientJSON] {
        guard preset == .omitBankAndNDISIdentifiers else { return clients }
        return clients.map { client in
            ExportModels.ClientJSON(
                fullName: client.fullName,
                email: client.email,
                phone: client.phone,
                address: client.address,
                addressLine1: client.addressLine1,
                addressLine2: client.addressLine2,
                addressCity: client.addressCity,
                addressState: client.addressState,
                addressPostalCode: client.addressPostalCode,
                city: client.city,
                state: client.state,
                postalCode: client.postalCode,
                zip: client.zip,
                addressStreet: client.addressStreet,
                ndisNumber: nil,
                ndis_number: nil
            )
        }
    }

    static func redact(_ payees: [ExportModels.PayeeJSON], preset: ExportRedactionPreset) -> [ExportModels.PayeeJSON] {
        guard preset == .omitBankAndNDISIdentifiers else { return payees }
        return payees.map { payee in
            ExportModels.PayeeJSON(
                payeeName: payee.payeeName,
                email: payee.email,
                phone: payee.phone,
                address: payee.address,
                bankAccount: nil,
                bankBSB: nil,
                status: payee.status,
                relationToClient: payee.relationToClient
            )
        }
    }

    static func redact(_ invoices: [ExportModels.InvoiceJSON], preset: ExportRedactionPreset) -> [ExportModels.InvoiceJSON] {
        guard preset == .omitBankAndNDISIdentifiers else { return invoices }
        return invoices.map { invoice in
            ExportModels.InvoiceJSON(
                invoiceNumber: invoice.invoiceNumber,
                dateIssued: invoice.dateIssued,
                dateIssuedString: invoice.dateIssuedString,
                dateDue: invoice.dateDue,
                dateDueString: invoice.dateDueString,
                totalAmount: invoice.totalAmount,
                totalAmountString: invoice.totalAmountString,
                status: invoice.status,
                clientName: invoice.clientName,
                currencyCode: invoice.currencyCode,
                taxRate: invoice.taxRate,
                discount: invoice.discount,
                creditApplied: invoice.creditApplied,
                paymentTerms: invoice.paymentTerms,
                notes: invoice.notes,
                paidDate: invoice.paidDate,
                sentDate: invoice.sentDate,
                businessName: invoice.businessName,
                businessABN: invoice.businessABN,
                businessEmail: invoice.businessEmail,
                businessPhone: invoice.businessPhone,
                businessAddress: invoice.businessAddress,
                clientNDISNumber: nil,
                clientEmail: invoice.clientEmail,
                clientPhone: invoice.clientPhone,
                clientAddress: invoice.clientAddress,
                billingAuthority: invoice.billingAuthority,
                billToName: invoice.billToName,
                billToEmail: invoice.billToEmail,
                billToAddress: invoice.billToAddress,
                bankName: nil,
                bankAccountName: nil,
                bankBSB: nil,
                bankAccountNumber: nil,
                editorConfiguration: invoice.editorConfiguration,
                items: invoice.items
            )
        }
    }
}
