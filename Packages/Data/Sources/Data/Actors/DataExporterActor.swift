import Foundation
import SwiftData

/// Actor responsible for handling data export operations in the background
@ModelActor
public actor DataExporterActor {
    
    /// Exports all data to a file in the specified format
    public func exportToFile(format: SwiftDataExportFormat = .json) async throws -> (Data, String) {
        let context = modelContext
        return try SwiftDataExportService.exportToFile(context: context, format: format)
    }
    
    /// Exports all entities to a JSON Data object
    public func exportAllEntitiesToJSON() async throws -> Data {
        let context = modelContext
        return try SwiftDataExportService.exportAllEntitiesToJSON(context: context)
    }
    
    // MARK: - Specialized Entity Exports
    
    public func exportClients() async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<ClientEntity>()
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
        return try encoder.encode(clientsJSON)
    }
    
    public func exportPayees() async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<PayeeEntity>()
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
        return try encoder.encode(payeesJSON)
    }
    
    public func exportServices() async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<ClientServiceEntity>()
        let services = try context.fetch(fetchDescriptor)

        let servicesJSON = services.map { service -> ExportModels.ServiceJSON in
            let formattedRate = service.rate > 0 ? String(format: "%.2f", service.rate) : nil
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
    
    public func exportNDISItems() async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<NDISItemEntity>()
        let ndisItems = try context.fetch(fetchDescriptor)

        let ndisItemsJSON = ndisItems.map { item -> ExportModels.NDISItemJSON in
            var primaryRateValue: Double = 0.0
            var primaryRateString: String = "0.00"

            if !item.regionalPrices.isEmpty {
                var foundNational = false
                for price in item.regionalPrices {
                    if price.regionIdentifier == "NATIONAL" {
                        primaryRateValue = price.amount
                        foundNational = true
                    }
                }
                if !foundNational, let first = item.regionalPrices.first {
                    primaryRateValue = first.amount
                }
            }
            primaryRateString = String(format: "%.2f", primaryRateValue)

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
    
    public func exportInvoices() async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<InvoiceEntity>()
        let invoices = try context.fetch(fetchDescriptor)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let invoicesJSON = invoices.map { invoice -> ExportModels.InvoiceJSON in
            let dateIssuedString = dateFormatter.string(from: invoice.date)

            var dateDueString: String? = nil
            if let dueDate = invoice.dueDate {
                dateDueString = dateFormatter.string(from: dueDate)
            }

            return ExportModels.InvoiceJSON(
                invoiceNumber: invoice.invoiceNumber,
                dateIssued: invoice.date,
                dateIssuedString: dateIssuedString,
                dateDue: invoice.dueDate,
                dateDueString: dateDueString,
                totalAmount: invoice.totalAmount,
                totalAmountString: String(format: "%.2f", invoice.totalAmount),
                status: invoice.status.rawValue,
                clientName: invoice.clientName ?? invoice.client?.fullName
            )
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(invoicesJSON)
    }
    
    public func exportSessions() async throws -> Data {
        let context = modelContext
        let fetchDescriptor = FetchDescriptor<SessionEntity>()
        let sessions = try context.fetch(fetchDescriptor)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"

        let sessionsJSON = sessions.map { session -> ExportModels.SessionJSON in
            let dateString = session.startTime != nil ? dateFormatter.string(from: session.startTime!) : ""

            let startTimeString = session.startTime != nil ? timeFormatter.string(from: session.startTime!) : ""
            let endTimeString = session.endTime != nil ? timeFormatter.string(from: session.endTime!) : nil

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
    
    private func exportBankAccountNumber(from payee: PayeeEntity) -> String? {
        reflectedStringValue(
            from: payee,
            keys: ["bankAccountNumber", "bankAccount", "accountNumber"]
        )
    }

    private func exportBankBSB(from payee: PayeeEntity) -> String? {
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

    private func exportAddressString(from address: AddressEntity?) -> String? {
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

    private func exportServiceDescription(from service: ClientServiceEntity) -> String? {
        if let description = service.ndisItem?.itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return description
        }
        if let status = service.status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            return status
        }
        return nil
    }
}
