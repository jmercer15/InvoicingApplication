import Core
import PersistenceModels
import Foundation
import SwiftData

/// Actor responsible for handling data export operations in the background.
public actor DataExporterActor: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }
    
    /// Exports all data to a file in the specified format
    public func exportToFile(
        format: SwiftDataExportFormat = .json,
        redaction: ExportRedactionPreset = .none
    ) async throws -> (Data, String) {
        let context = modelContext
        return try SwiftDataExportService.exportToFile(context: context, format: format, redaction: redaction)
    }
    
    /// Exports all entities to a JSON Data object
    public func exportAllEntitiesToJSON(redaction: ExportRedactionPreset = .none) async throws -> Data {
        let context = modelContext
        return try SwiftDataExportService.exportAllEntitiesToJSON(context: context, redaction: redaction)
    }
    
    // MARK: - Specialized Entity Exports
    
    public func exportClients(redaction: ExportRedactionPreset = .none) async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<Client>()
        let clients = try context.fetch(fetchDescriptor)

        let clientsJSON = clients.map { client -> ExportModels.ClientJSON in
            let address = client.address

            return ExportModels.ClientJSON(
                fullName: client.fullName,
                email: client.email,
                phone: client.phone,
                address: exportAddressString(from: address),
                addressLine1: address?.streetNumber != nil && address?.streetName != nil ?
                    "\(address?.streetNumber ?? "") \(address?.streetName ?? "")" : nil,
                addressLine2: address?.unitNumber,
                addressCity: address?.suburb,
                addressState: address?.state,
                addressPostalCode: address?.postcode,
                city: address?.suburb,
                state: address?.state,
                postalCode: address?.postcode,
                zip: address?.postcode,
                addressStreet: address?.streetNumber != nil && address?.streetName != nil ?
                    "\(address?.streetNumber ?? "") \(address?.streetName ?? "")" : nil,
                ndisNumber: client.ndisNumber,
                ndis_number: client.ndisNumber
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(ExportFieldRedactor.redact(clientsJSON, preset: redaction))
    }
    
    public func exportPayees(redaction: ExportRedactionPreset = .none) async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<Payee>()
        let payees = try context.fetch(fetchDescriptor)

        let payeesJSON = payees.map { payee -> ExportModels.PayeeJSON in
            let addressText = exportAddressString(from: payee.address)
            let bankAccount = exportBankAccountNumber(from: payee)
            let bankBSB = exportBankBSB(from: payee)

            return ExportModels.PayeeJSON(
                payeeName: payee.fullName,
                email: payee.email,
                phone: payee.phone,
                address: addressText,
                bankAccount: bankAccount,
                bankBSB: bankBSB,
                status: payee.status,
                relationToClient: payee.relationToClient
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(ExportFieldRedactor.redact(payeesJSON, preset: redaction))
    }
    
    public func exportServices(redaction: ExportRedactionPreset = .none) async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<ClientService>()
        let services = try context.fetch(fetchDescriptor)

        let servicesJSON = services.map { service -> ExportModels.ServiceJSON in
            let formattedRate = service.rate > 0 ? ExportMachineFormatting.exportDecimal2(service.rate) : nil
            let rateValue = service.rate > 0 ? service.rate : nil
            return ExportModels.ServiceJSON(
                name: service.serviceName,
                description: exportServiceDescription(from: service) ?? "",
                unit: service.unit,
                rate: formattedRate,
                rateValue: rateValue,
                ndisCode: service.ndisCode
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(servicesJSON)
    }
    
    public func exportNDISItems(redaction: ExportRedactionPreset = .none) async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<NDISItem>()
        let ndisItems = try context.fetch(fetchDescriptor)

        let ndisItemsJSON = ndisItems.map { item -> ExportModels.NDISItemJSON in
            var primaryRateValue: Decimal = 0
            var primaryRateString: String = "0.00"

            let regionalPrices = item.regionalPrices ?? []
            if !regionalPrices.isEmpty {
                var foundNational = false
                for price in regionalPrices {
                    if price.regionIdentifier == "NATIONAL" {
                        primaryRateValue = price.amount
                        foundNational = true
                    }
                }
                if !foundNational, let first = regionalPrices.first {
                    primaryRateValue = first.amount
                }
            }
            primaryRateString = ExportMachineFormatting.exportDecimal2(primaryRateValue)

            return ExportModels.NDISItemJSON(
                itemNumber: item.itemNumber,
                description: item.itemDescription,
                rate: primaryRateString,
                rateValue: primaryRateValue,
                unit: item.unit,
                category: item.category,
                status: item.status
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(ndisItemsJSON)
    }
    
    public func exportInvoices(redaction: ExportRedactionPreset = .none) async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<Invoice>()
        let invoices = try context.fetch(fetchDescriptor)

        let invoicesJSON = invoices.map { invoice -> ExportModels.InvoiceJSON in
            let dateIssuedString = ExportMachineFormatting.exportDate(invoice.date)

            var dateDueString: String? = nil
            if let dueDate = invoice.dueDate {
                dateDueString = ExportMachineFormatting.exportDate(dueDate)
            }

            return ExportModels.InvoiceJSON(
                invoiceNumber: invoice.invoiceNumber,
                dateIssued: invoice.date,
                dateIssuedString: dateIssuedString,
                dateDue: invoice.dueDate,
                dateDueString: dateDueString,
                totalAmount: invoice.totalAmount,
                totalAmountString: ExportMachineFormatting.exportDecimal2(invoice.totalAmount),
                status: invoice.effectiveStatus.rawValue,
                clientName: invoice.clientName ?? invoice.client?.fullName,
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
                businessAddress: invoice.businessAddressSnapshot,
                clientNDISNumber: invoice.clientNDISNumber,
                clientEmail: invoice.clientEmail,
                clientPhone: invoice.clientPhone,
                clientAddress: invoice.clientAddressSnapshot,
                billingAuthority: invoice.billingAuthority?.rawValue,
                billToName: invoice.billToName,
                billToEmail: invoice.billToEmail,
                billToAddress: invoice.billToAddressSnapshot,
                bankName: invoice.bankName,
                bankAccountName: invoice.bankAccountName,
                bankBSB: invoice.bankBSB,
                bankAccountNumber: invoice.bankAccountNumber,
                editorConfiguration: invoice.invoiceEditorStateData,
                items: invoice.itemsArray.map { item in
                    ExportModels.InvoiceItemJSON(
                        id: item.id,
                        position: item.position,
                        itemDescription: item.itemDescription,
                        serviceDate: item.serviceDate,
                        itemCode: item.ndisItemNumber,
                        quantity: item.quantity,
                        unit: item.unit,
                        unitPrice: item.rate,
                        taxRate: item.taxRate,
                        gstCode: item.gstCode
                    )
                }
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(ExportFieldRedactor.redact(invoicesJSON, preset: redaction))
    }
    
    public func exportSessions(redaction: ExportRedactionPreset = .none) async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<Session>()
        let sessions = try context.fetch(fetchDescriptor)

        let sessionsJSON = sessions.map { session -> ExportModels.SessionJSON in
            let dateString = session.startTime.map(ExportMachineFormatting.exportDate) ?? ""
            let startTimeString = session.startTime.map(ExportMachineFormatting.exportTime) ?? ""
            let endTimeString = session.endTime.map(ExportMachineFormatting.exportTime)

            return ExportModels.SessionJSON(
                title: session.title,
                date: dateString,
                startTime: startTimeString,
                endTime: endTimeString,
                clientName: session.client?.fullName ?? "",
                location: session.location,
                notes: session.notes,
                status: session.status?.rawValue
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(sessionsJSON)
    }
    
    // MARK: - Private Helpers
    
    private func exportBankAccountNumber(from payee: Payee) -> String? {
        reflectedStringValue(
            from: payee,
            keys: ["bankAccountNumber", "bankAccount", "accountNumber"]
        )
    }

    private func exportBankBSB(from payee: Payee) -> String? {
        reflectedStringValue(
            from: payee,
            keys: ["bankBSB", "bsb", "bankRoutingNumber"]
        )
    }

    private func reflectedStringValue(from object: Any, keys: [String]) -> String? {
        let mirror = Mirror(reflecting: object)
        for child in mirror.children {
            guard let label = child.label else { continue }
            guard keys.contains(label) else { continue }

            if let stringValue = child.value as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }

            if let optionalString = child.value as? String? {
                let trimmed = (optionalString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        }
        return nil
    }

    private func exportAddressString(from address: Address?) -> String? {
        guard let addressEntity = address else { return nil }
        var components: [String] = []

        if !addressEntity.unitNumber.isEmpty {
            components.append("Unit \(addressEntity.unitNumber)")
        }

        if !addressEntity.streetNumber.isEmpty {
            if !addressEntity.streetName.isEmpty {
                components.append("\(addressEntity.streetNumber) \(addressEntity.streetName)")
            } else {
                components.append(addressEntity.streetNumber)
            }
        } else if !addressEntity.streetName.isEmpty {
            components.append(addressEntity.streetName)
        }

        if !addressEntity.suburb.isEmpty {
            components.append(addressEntity.suburb)
        }

        if !addressEntity.state.isEmpty {
            components.append(addressEntity.state)
        }

        if !addressEntity.postcode.isEmpty {
            components.append(addressEntity.postcode)
        }

        if !addressEntity.country.isEmpty && addressEntity.country.lowercased() != "australia" {
            components.append(addressEntity.country)
        }

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    private func exportServiceDescription(from service: ClientService) -> String? {
        if let description = service.ndisItem?.itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return description
        }
        if let status = service.status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            return status
        }
        return nil
    }
}
