import Core
import PersistenceModels
import Foundation

struct InvoiceDocumentConfigurationEnvelope: Codable {
    var version = InvoiceEditorConfiguration.currentVersion
    var title = "Tax Invoice"
    var billParticipantDirectly = true
    var billToPhone = ""
    var discountAmount: Decimal = 0
    var showsTaxSummary = true
    var paperSize: PaperSize = .default
    var pageOrientation: PageOrientation = .portrait
    var template: InvoiceTemplateConfiguration = .default

    init(
        version: Int = InvoiceEditorConfiguration.currentVersion,
        title: String = "Tax Invoice",
        billParticipantDirectly: Bool = true,
        billToPhone: String = "",
        discountAmount: Decimal = 0,
        showsTaxSummary: Bool = true,
        paperSize: PaperSize = .default,
        pageOrientation: PageOrientation = .portrait,
        template: InvoiceTemplateConfiguration = .default
    ) {
        self.version = version
        self.title = title
        self.billParticipantDirectly = billParticipantDirectly
        self.billToPhone = billToPhone
        self.discountAmount = discountAmount
        self.showsTaxSummary = showsTaxSummary
        self.paperSize = paperSize
        self.pageOrientation = pageOrientation
        self.template = template
    }

    init(
        shared configuration: InvoiceEditorConfiguration,
        paperSize: PaperSize = .default,
        pageOrientation: PageOrientation = .portrait,
        template: InvoiceTemplateConfiguration = .default
    ) {
        self.init(
            version: configuration.version,
            title: configuration.title,
            billParticipantDirectly: configuration.billParticipantDirectly,
            billToPhone: configuration.billToPhone,
            discountAmount: configuration.discountAmount,
            showsTaxSummary: configuration.showsTaxSummary,
            paperSize: paperSize,
            pageOrientation: pageOrientation,
            template: template
        )
    }

    static func decode(from invoice: Invoice) -> Self {
        guard let data = invoice.invoiceEditorStateData,
              let value = try? JSONDecoder().decode(Self.self, from: data)
        else {
            // Existing/imported invoices without editor metadata must remain visually stable.
            // Current Template Editor preferences seed creation only; they never retroactively
            // restyle persisted records that predate the editor envelope.
            return Self()
        }
        return value
    }

    func encoded() throws -> Data { try JSONEncoder().encode(self) }

    private enum CodingKeys: String, CodingKey {
        case version, title, billParticipantDirectly, billToPhone, discountAmount
        case showsTaxSummary, paperSize, pageOrientation, template
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: container.resilientValue(Int.self, forKey: .version, default: 1),
            title: container.resilientValue(String.self, forKey: .title, default: "Tax Invoice"),
            billParticipantDirectly: container.resilientValue(
                Bool.self,
                forKey: .billParticipantDirectly,
                default: true
            ),
            billToPhone: container.resilientValue(String.self, forKey: .billToPhone, default: ""),
            discountAmount: container.resilientValue(Decimal.self, forKey: .discountAmount, default: 0),
            showsTaxSummary: container.resilientValue(Bool.self, forKey: .showsTaxSummary, default: true),
            paperSize: container.resilientValue(PaperSize.self, forKey: .paperSize, default: .default),
            pageOrientation: container.resilientValue(
                PageOrientation.self,
                forKey: .pageOrientation,
                default: .portrait
            ),
            template: container.resilientValue(
                InvoiceTemplateConfiguration.self,
                forKey: .template,
                // Persisted invoice decoding must be deterministic. Template Editor preferences
                // seed newly created invoices only; missing legacy fields use historical defaults.
                default: .default
            )
        )
    }
}

private extension KeyedDecodingContainer {
    func resilientValue<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key,
        default defaultValue: Value
    ) -> Value {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue
    }
}

extension InvoiceStatus {
    init(coreStatus: Core.InvoiceStatus) {
        switch coreStatus {
        case .reviewDraft: self = .draft
        case .readyToSend: self = .readyToSend
        case .pending: self = .sent
        case .received: self = .paid
        case .overdue: self = .overdue
        case .cancelled: self = .cancelled
        case .voided: self = .voided
        }
    }

    var coreStatus: Core.InvoiceStatus {
        switch self {
        case .draft: .reviewDraft
        case .readyToSend: .readyToSend
        case .sent: .pending
        case .paid: .received
        case .overdue: .overdue
        case .cancelled: .cancelled
        case .voided: .voided
        }
    }
}

extension InvoiceLineItemSnapshot {
    init(coreItem: InvoiceItem) {
        let clientService = coreItem.clientService
        let session = coreItem.session
        let serviceItemNumber = clientService?.ndisItemNumber.nonBlank
            ?? clientService?.ndisCode.nonBlank
        let fallbackRate = session?.assignedRate ?? clientService?.rate ?? 0

        self.init(
            id: coreItem.id,
            sortOrder: Int(coreItem.position),
            itemDescription: coreItem.itemDescription.nonBlank
                ?? session?.assignedServiceName.nonBlank
                ?? clientService?.serviceName.nonBlank
                ?? "",
            serviceDate: coreItem.serviceDate,
            itemCode: coreItem.ndisItemNumber.nonBlank ?? serviceItemNumber ?? "",
            quantity: coreItem.quantity,
            unit: coreItem.unit.nonBlank ?? clientService?.unit.nonBlank ?? "",
            unitPrice: coreItem.rate == 0 ? fallbackRate : coreItem.rate,
            taxRate: coreItem.taxRate,
            gstCode: coreItem.gstCode.nonBlank ?? clientService?.gstCode.nonBlank ?? "",
            claimType: coreItem.claimType,
            sessionID: session?.id,
            clientServiceID: clientService?.id
        )
    }
}

extension InvoiceSnapshot {
    init(coreInvoice invoice: Invoice) {
        let state = InvoiceDocumentConfigurationEnvelope.decode(from: invoice)
        let linkedBusiness = invoice.business
        let linkedClient = invoice.client
        let billingAuthority = invoice.billingAuthority ?? linkedClient?.billingAuthority
        let clientSnapshot: (name: String, address: String, email: String, phone: String) = (
            invoice.clientName.nonBlank ?? linkedClient?.fullName.nonBlank ?? "",
            invoice.clientAddressSnapshot?.fullFormattedAddress.nonBlank
                ?? invoice.clientAddress?.fullFormattedAddress.nonBlank
                ?? linkedClient?.address?.fullFormattedAddress.nonBlank
                ?? "",
            invoice.clientEmail.nonBlank ?? linkedClient?.email.nonBlank ?? "",
            invoice.clientPhone.nonBlank ?? linkedClient?.phone.nonBlank ?? ""
        )
        let billingRecipient: (name: String, address: String, email: String, phone: String)
        switch billingAuthority ?? .client {
        case .parentGuardian:
            let payee = invoice.payee ?? linkedClient?.payee
            billingRecipient = (
                invoice.payeeName.nonBlank ?? payee?.fullName.nonBlank ?? "",
                invoice.payeeAddressSnapshot?.fullFormattedAddress.nonBlank
                    ?? invoice.payeeAddress?.fullFormattedAddress.nonBlank
                    ?? payee?.address?.fullFormattedAddress.nonBlank
                    ?? "",
                invoice.payeeEmail.nonBlank ?? payee?.email.nonBlank ?? "",
                invoice.payeePhone.nonBlank ?? payee?.phone.nonBlank ?? ""
            )
        case .planManager:
            billingRecipient = (
                linkedClient?.planManager?.name.nonBlank ?? "",
                linkedClient?.planManager?.address?.fullFormattedAddress.nonBlank ?? "",
                linkedClient?.planManager?.email.nonBlank ?? "",
                linkedClient?.planManager?.phone.nonBlank ?? ""
            )
        case .ndia:
            billingRecipient = ("NDIA", "", "", "")
        case .client:
            billingRecipient = clientSnapshot
        }
        let billsParticipantDirectly = billingAuthority.map { $0 == .client }
            ?? state.billParticipantDirectly
        let shouldMigrateGlobalTax = invoice.taxRate != 0 &&
            !invoice.itemsArray.contains(where: { $0.taxRate != 0 })
        let items = invoice.itemsArray.map { item in
            var snapshot = InvoiceLineItemSnapshot(coreItem: item)
            if shouldMigrateGlobalTax {
                snapshot.taxRate = invoice.taxRate
            }
            return snapshot
        }
        let document = InvoiceDocument(
            id: invoice.id,
            invoiceNumber: invoice.invoiceNumber,
            title: state.title,
            status: InvoiceStatus(coreStatus: invoice.effectiveStatus),
            issueDate: invoice.issueDate,
            dueDate: invoice.dueDate ?? invoice.issueDate,
            sellerName: invoice.businessName.nonBlank ?? linkedBusiness?.name.nonBlank ?? "",
            sellerAddress: invoice.businessAddressSnapshot?.fullFormattedAddress.nonBlank
                ?? invoice.businessAddress?.fullFormattedAddress.nonBlank
                ?? linkedBusiness?.address?.fullFormattedAddress.nonBlank
                ?? "",
            sellerEmail: invoice.businessEmail.nonBlank ?? linkedBusiness?.email.nonBlank ?? "",
            sellerPhone: invoice.businessPhone.nonBlank ?? linkedBusiness?.phone.nonBlank ?? "",
            sellerTaxID: invoice.businessABN.nonBlank ?? linkedBusiness?.abn.nonBlank ?? "",
            billParticipantDirectly: billsParticipantDirectly,
            billToName: invoice.billToName.nonBlank ?? billingRecipient.name,
            billToEmail: invoice.billToEmail.nonBlank ?? billingRecipient.email,
            billToAddress: invoice.billToAddressSnapshot?.fullFormattedAddress.nonBlank
                ?? invoice.billToAddress?.fullFormattedAddress.nonBlank
                ?? billingRecipient.address,
            billToPhone: state.billToPhone.nonBlank ?? billingRecipient.phone,
            billingAuthority: billingAuthority?.rawValue ?? "",
            clientName: clientSnapshot.name,
            clientAddress: clientSnapshot.address,
            clientEmail: clientSnapshot.email,
            clientPhone: clientSnapshot.phone,
            clientTaxID: invoice.clientNDISNumber.nonBlank ?? linkedClient?.ndisNumber.nonBlank ?? "",
            bankName: invoice.bankName.nonBlank ?? linkedBusiness?.bankName.nonBlank ?? "",
            bankAccountName: invoice.bankAccountName.nonBlank ?? linkedBusiness?.bankAccountName.nonBlank ?? "",
            bankBSB: invoice.bankBSB.nonBlank ?? linkedBusiness?.bankBSB.nonBlank ?? "",
            bankAccountNumber: invoice.bankAccountNumber.nonBlank ?? linkedBusiness?.bankAccountNumber.nonBlank ?? "",
            currencyCode: InvoiceCurrencyCode.normalizedOrDefault(invoice.currencyCode),
            defaultTaxRate: invoice.taxRate,
            paymentTerms: invoice.paymentTerms.nonBlank ?? "",
            notes: invoice.notes.nonBlank ?? "",
            discountAmount: state.discountAmount,
            discountPercent: invoice.discount,
            creditApplied: invoice.creditApplied,
            showsTaxSummary: state.showsTaxSummary,
            paperSize: state.paperSize,
            pageOrientation: state.pageOrientation,
            subtotal: 0,
            taxTotal: 0,
            grandTotal: 0
        )
        document.revision = invoice.invoiceEditorRevision
        document.templateConfiguration = state.template
        document.lineItems = items.map {
            InvoiceLineItem(
                id: $0.id, sortOrder: $0.sortOrder, itemDescription: $0.itemDescription,
                serviceDate: $0.serviceDate, itemCode: $0.itemCode, quantity: $0.quantity,
                unit: $0.unit, unitPrice: $0.unitPrice, taxRate: $0.taxRate, gstCode: $0.gstCode,
                claimType: $0.claimType, sessionID: $0.sessionID, clientServiceID: $0.clientServiceID
            )
        }
        document.recalculateTotals()
        self.init(document, clientID: invoice.client?.id)
    }
}

private extension Optional where Wrapped == String {
    var nonBlank: String? {
        self?.nonBlank
    }
}

private extension String {
    var nonBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

extension InvoiceClientOption {
    init(_ client: Client) {
        let authority = client.billingAuthority ?? .client
        let recipient: (name: String, address: String, email: String, phone: String)
        switch authority {
        case .parentGuardian:
            recipient = (
                client.payee?.fullName ?? "",
                client.payee?.address?.fullFormattedAddress ?? "",
                client.payee?.email ?? "",
                client.payee?.phone ?? ""
            )
        case .planManager:
            recipient = (
                client.planManager?.name ?? "",
                client.planManager?.address?.fullFormattedAddress ?? "",
                client.planManager?.email ?? "",
                client.planManager?.phone ?? ""
            )
        case .ndia:
            recipient = ("NDIA", "", "", "")
        case .client:
            recipient = (
                client.fullName,
                client.address?.fullFormattedAddress ?? "",
                client.email ?? "",
                client.phone ?? ""
            )
        }

        id = client.id
        name = client.fullName
        address = client.address?.fullFormattedAddress ?? ""
        email = client.email ?? ""
        phone = client.phone ?? ""
        taxID = client.ndisNumber
        billsDirectly = authority == .client
        billingAuthority = authority.rawValue
        billToName = recipient.name
        billToAddress = recipient.address
        billToEmail = recipient.email
        billToPhone = recipient.phone
    }
}
