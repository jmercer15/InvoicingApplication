import Foundation
import SwiftData
import Data
import Core

// Structs for parsing the new invoice JSON format
struct InvoiceImportJSON: Codable {
    let invoiceNumber: String
    let issueDate: String?
    let dueDate: String?
    let clientName: String
    let items: [InvoiceItemImportJSON]?
    let totalAmount: Double?
    let gstComponent: Double?
    let status: String?
    
    enum CodingKeys: String, CodingKey {
        case invoiceNumber = "Invoice Number"
        case issueDate = "Issue Date"
        case dueDate = "Due Date"
        case clientName = "Client Name"
        case items = "Items"
        case totalAmount = "Total Amount"
        case gstComponent = "GST Component"
        case status = "Status"
    }
    
    // Convert to standard format
    func toInvoiceJSON() -> InvoiceJSON {
        // Parse dates properly
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let issueDateParsed = issueDate.flatMap { dateFormatter.date(from: $0) }
        let dueDateParsed = dueDate.flatMap { dateFormatter.date(from: $0) }
        
        // Encode self as Data for userData
        let userData = try? JSONEncoder().encode(self)
        
        return InvoiceJSON(
            invoiceNumber: invoiceNumber,
            dateIssued: issueDateParsed,
            dateIssuedString: issueDate,
            dateDue: dueDateParsed,
            dateDueString: dueDate,
            totalAmount: totalAmount,
            totalAmountString: totalAmount != nil ? String(totalAmount!) : nil,
            status: status,
            clientName: clientName,
            userData: userData
        )
    }
}

struct InvoiceItemImportJSON: Codable {
    let description: String
    let quantity: Int
    let unitPrice: Double
    
    enum CodingKeys: String, CodingKey {
        case description = "Description"
        case quantity = "Quantity"
        case unitPrice = "Unit Price"
    }
}

struct InvoiceData: Codable {
    let invoices: [ActualInvoiceJSON]?
}

struct ActualInvoiceJSON: Codable {
    let id: String?
    let invoiceNumber: String
    let issueDate: String?
    let dueDate: String?
    let serviceIDs: [Int]?
    let items: [InvoiceItemJSON]?
    let totalAmount: Double?
    let gstComponent: Double?
    let status: String?
}

struct InvoiceItemJSON: Codable {
    let id: String?
    let name: String
    let quantity: Int
    let unitPrice: Double
}

/// Handles import functionality for invoice data from JSON files
struct InvoiceImport {
    static func importInvoices(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        // First try to decode as the new format with specific field names
        let decoder = JSONDecoder()
        
        do {
            let newFormatInvoices = try decoder.decode([InvoiceImportJSON].self, from: data)
            let convertedInvoices = newFormatInvoices.map { $0.toInvoiceJSON() }
            return try processInvoices(convertedInvoices, fileName: fileName, context: context)
        } catch {
            // Try as single invoice in new format
            do {
                let newFormatInvoice = try decoder.decode(InvoiceImportJSON.self, from: data)
                return try processInvoices([newFormatInvoice.toInvoiceJSON()], fileName: fileName, context: context)
            } catch {
                // Try standard format (array or single item)
                do {
                    let invoices = try decoder.decode([InvoiceJSON].self, from: data)
                    return try processInvoices(invoices, fileName: fileName, context: context)
                } catch {
                    // Try as single invoice
                    do {
                        let invoice = try decoder.decode(InvoiceJSON.self, from: data)
                        return try processInvoices([invoice], fileName: fileName, context: context)
                    } catch {
                        // If both formats fail, try with adapter
                        return try importInvoicesWithAdapter(data: data, fileName: fileName, context: context)
                    }
                }
            }
        }
    }
    
    private static func importInvoicesWithAdapter(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        
        // Try to decode as a wrapper object with "invoices" property
        do {
            let invoiceData = try decoder.decode(InvoiceData.self, from: data)
            if let invoices = invoiceData.invoices {
                return try processActualInvoices(invoices, fileName: fileName, context: context)
            }
        } catch {
            // If that fails, try as a direct array
            do {
                let invoices = try decoder.decode([ActualInvoiceJSON].self, from: data)
                return try processActualInvoices(invoices, fileName: fileName, context: context)
            } catch {
                throw error
            }
        }
        
        throw NSError(
            domain: "InvoiceImportError",
            code: 1002,
            userInfo: [
                NSLocalizedDescriptionKey: "Could not find valid invoice data in the JSON file"
            ]
        )
    }
    
    private static func processActualInvoices(_ invoices: [ActualInvoiceJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        // Convert the actual JSON format to our expected format
        let dateFormatter = ISO8601DateFormatter()
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd"
        
        // Pre-fetch clients to match by invoice number prefix
        let clientFetchDescriptor = FetchDescriptor<ClientEntity>()
        let allClients: [ClientEntity]
        do {
            allClients = try context.fetch(clientFetchDescriptor)
        } catch {
            allClients = []
        }
        
        let convertedInvoices = invoices.map { invoice -> InvoiceJSON in
            // Convert dates from ISO format to string format for our existing processor
            let issueDate: Date? = invoice.issueDate.flatMap { dateString in dateFormatter.date(from: dateString) }
            let dueDate: Date? = invoice.dueDate.flatMap { dateString in dateFormatter.date(from: dateString) }
            
            // Extract client name from invoice number if possible (e.g., "TAYL-M-0027" -> "Taylor, Matthew")
            var clientName: String? = nil
            
            // Parse invoice number format: SURNAME-FIRSTINITIAL-NUMBER
            let invoiceParts = invoice.invoiceNumber.split(separator: "-")
            if invoiceParts.count >= 2 {
                let surnamePrefix = String(invoiceParts[0]) // e.g., "TAYL"
                let firstInitial = String(invoiceParts[1])   // e.g., "M"
                
                // Try to match clients by surname prefix and first initial
                if let matchedClient = allClients.first(where: { client in
                    let fullName = client.fullName.uppercased()
                    let nameParts = fullName.split(separator: " ")
                    
                    if nameParts.count >= 2 {
                        let lastName = String(nameParts.last!)
                        let firstName = String(nameParts.first!)
                        
                        // Check if surname starts with the prefix (e.g., "TAYLOR" starts with "TAYL")
                        let lastNamePrefix = String(lastName.prefix(surnamePrefix.count))
                        let firstNameInitial = String(firstName.prefix(1))
                        
                        return lastNamePrefix == surnamePrefix && firstNameInitial == firstInitial
                    }
                    return false
                }) {
                    clientName = matchedClient.fullName
                }
            }
            
            // Encode invoice as Data for userData
            let userData = try? JSONEncoder().encode(invoice)
            
            let invoiceJSON = InvoiceJSON(
                invoiceNumber: invoice.invoiceNumber,
                dateIssued: issueDate,
                dateIssuedString: issueDate != nil ? displayFormatter.string(from: issueDate!) : invoice.issueDate,
                dateDue: dueDate,
                dateDueString: dueDate != nil ? displayFormatter.string(from: dueDate!) : invoice.dueDate,
                totalAmount: invoice.totalAmount,
                totalAmountString: invoice.totalAmount != nil ? String(invoice.totalAmount!) : nil,
                status: invoice.status,
                clientName: clientName,
                userData: userData
            )
            
            return invoiceJSON
        }
        
        // Use regular processor to handle the converted data
        return try processInvoices(convertedInvoices, fileName: fileName, context: context)
    }
    
    private static func processInvoices(_ invoices: [InvoiceJSON], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var errorMessages: [String] = []
        
        // Dictionary to track processed invoices and their original data
        var processedInvoicesData: [String: Data] = [:]
        
        // First process all invoices
        for invoice in invoices {
            // Check required fields
            guard !invoice.invoiceNumber.isEmpty else {
                errorMessages.append("Skipped invoice - missing invoice number")
                failed += 1
                continue
            }
            
            guard let clientName = invoice.clientName, !clientName.isEmpty else {
                errorMessages.append("Skipped invoice \(invoice.invoiceNumber) - missing client name")
                failed += 1
                continue
            }
            
            do {
                // Check if invoice already exists
                let invoiceFetchDescriptor = FetchDescriptor<InvoiceEntity>(predicate: #Predicate { $0.invoiceNumber == invoice.invoiceNumber })
                let existingInvoices = try context.fetch(invoiceFetchDescriptor)
                
                let invoiceEntity: InvoiceEntity
                
                if let existingInvoice = existingInvoices.first {
                    // Update existing invoice
                    invoiceEntity = existingInvoice
                } else {
                    // Create new invoice
                    invoiceEntity = InvoiceEntity(id: UUID(), invoiceNumber: invoice.invoiceNumber)
                    context.insert(invoiceEntity)
                }
                
                // Find client by name
                let clientFetchDescriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.fullName.localizedStandardContains(clientName) })
                let matchingClients = try context.fetch(clientFetchDescriptor)
                
                if let client = matchingClients.first {
                    invoiceEntity.client = client
                    
                    // Set payee relationship based on client's billing authority
                    // If billing authority is parent/guardian and client has a payee, link invoice to that payee
                    if client.billingAuthority == .parentGuardian, let clientPayee = client.payee {
                        invoiceEntity.payee = clientPayee
                    } else {
                        // Explicitly clear payee relationship if not applicable
                        invoiceEntity.payee = nil
                    }
                } else {
                    // Client not found, clear relationships
                    invoiceEntity.client = nil
                    invoiceEntity.payee = nil
                }
                
                // Set dates
                if let issueDate = invoice.dateIssued {
                    invoiceEntity.date = issueDate
                    invoiceEntity.issueDate = issueDate
                } else if let dateString = invoice.dateIssuedString {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: dateString) {
                        invoiceEntity.date = date
                        invoiceEntity.issueDate = date
                    }
                }
                
                if let dueDate = invoice.dateDue {
                    invoiceEntity.dueDate = dueDate
                } else if let dateString = invoice.dateDueString {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: dateString) {
                        invoiceEntity.dueDate = date
                    }
                }
                
                // Set amount
                if let amount = invoice.totalAmount {
                    invoiceEntity.totalAmount = amount
                } else if let amountString = invoice.totalAmountString, let amount = Double(amountString) {
                    invoiceEntity.totalAmount = amount
                }
                
                invoiceEntity.status = try parseInvoiceStatus(invoice.status, invoiceNumber: invoice.invoiceNumber)
                
                // Populate snapshot fields from relationships after setting them
                // This ensures payee data is populated from client.payee when billing authority is Parent/Guardian
                invoiceEntity.snapshotRelatedData()
                
                // Store original user data for later use with line items
                if let userData = invoice.userData {
                    processedInvoicesData[invoice.invoiceNumber] = userData
                }
                
                successful += 1
            } catch {
                failed += 1
                errorMessages.append("Error importing invoice \(invoice.invoiceNumber): \(error.localizedDescription)")
            }
        }
        
        // No explicit save needed here, changes are tracked by ModelContext
        
        // Now handle line items if we have original data
        let decoder = JSONDecoder()
        for (invoiceNumber, userData) in processedInvoicesData {
            if let actualInvoice = try? decoder.decode(ActualInvoiceJSON.self, from: userData), let items = actualInvoice.items, !items.isEmpty {
                try addLineItemsToInvoice(invoiceNumber: invoiceNumber, items: items, context: context)
            } else if let newFormatInvoice = try? decoder.decode(InvoiceImportJSON.self, from: userData), let items = newFormatInvoice.items, !items.isEmpty {
                try addLineItemsFromNewFormat(invoiceNumber: invoiceNumber, items: items, context: context)
            }
        }
        
        // No explicit save needed here, changes are tracked by ModelContext
        
        return ImportResult(
            source: .invoices,
            successful: successful,
            failed: failed,
            messages: errorMessages,
            fileName: fileName
        )
    }
    
    private static func addLineItemsToInvoice(invoiceNumber: String, items: [InvoiceItemJSON], context: ModelContext) throws {
        // Find the invoice by invoice number
        let invoiceFetchDescriptor = FetchDescriptor<InvoiceEntity>(predicate: #Predicate { $0.invoiceNumber == invoiceNumber })
        let invoices = try context.fetch(invoiceFetchDescriptor)
        guard let invoice = invoices.first else { return }

        let existingItems = invoice.items
        for item in existingItems {
            context.delete(item)
        }
        invoice.items.removeAll()

        // Add new line items
        for item in items {
            let lineItem = InvoiceItemEntity(id: UUID(), itemDescription: item.name)
            context.insert(lineItem)
            lineItem.quantity = Double(item.quantity)
            lineItem.rate = item.unitPrice
            lineItem.invoice = invoice
            lineItem.serviceDate = invoice.issueDate
            
            // Try to find a matching ClientServiceEntity for the invoice's client
            if let client = invoice.client {
                let clientServices = client.clientServices
                if clientServices.first(where: { $0.serviceName.caseInsensitiveCompare(item.name) == .orderedSame }) != nil {
                    // Relationship is managed through the invoice's client
                } else {
                    // Create a new ClientServiceEntity for this client
                    let newClientService = ClientServiceEntity(id: UUID(), serviceName: item.name, unit: "", rate: item.unitPrice)
                    context.insert(newClientService)
                    newClientService.client = client // Link to the invoice's client
                    newClientService.isActive = true
                    newClientService.startDate = invoice.issueDate // Use invoice issue date as default start
                    
                    print("Created new ClientService '\(item.name)' for client '\(client.fullName)' during invoice import.")
                }
            }
        }
    }
    
    private static func addLineItemsFromNewFormat(invoiceNumber: String, items: [InvoiceItemImportJSON], context: ModelContext) throws {
        // Find the invoice by invoice number
        let invoiceFetchDescriptor = FetchDescriptor<InvoiceEntity>(predicate: #Predicate { $0.invoiceNumber == invoiceNumber })
        let invoices = try context.fetch(invoiceFetchDescriptor)
        guard let invoice = invoices.first else { return }

        let existingItems = invoice.items
        for item in existingItems {
            context.delete(item)
        }
        invoice.items.removeAll()

        // Add new line items
        for item in items {
            let lineItem = InvoiceItemEntity(id: UUID(), itemDescription: item.description)
            context.insert(lineItem)
            lineItem.quantity = Double(item.quantity)
            lineItem.rate = item.unitPrice
            lineItem.invoice = invoice
            lineItem.serviceDate = invoice.issueDate
            
            // Try to find a matching ClientServiceEntity for the invoice's client
            if let client = invoice.client {
                let clientServices = client.clientServices
                if clientServices.first(where: { $0.serviceName.caseInsensitiveCompare(item.description) == .orderedSame }) != nil {
                    // Relationship is managed through the invoice's client
                } else {
                    // Create a new ClientServiceEntity for this client
                    let newClientService = ClientServiceEntity(id: UUID(), serviceName: item.description, unit: "", rate: item.unitPrice)
                    context.insert(newClientService)
                    newClientService.client = client // Link to the invoice's client
                    newClientService.isActive = true
                    newClientService.startDate = invoice.issueDate // Use invoice issue date as default start
                    
                    print("Created new ClientService '\(item.description)' for client '\(client.fullName)' during invoice import.")
                }
            }
        }
    }

    private static func parseInvoiceStatus(_ status: String?, invoiceNumber: String) throws -> InvoiceStatus {
        guard let token = canonicalInvoiceStatusToken(status) else { return .reviewDraft }
        guard let parsedStatus = InvoiceStatus(rawValue: token) else {
            throw NSError(
                domain: "InvoiceImportError",
                code: 1003,
                userInfo: [
                    NSLocalizedDescriptionKey: "Invoice \(invoiceNumber) has unsupported status '\(status ?? "")'."
                ]
            )
        }
        return parsedStatus
    }

    private static func canonicalInvoiceStatusToken(_ rawStatus: String?) -> String? {
        guard let rawStatus else { return nil }
        let normalized = rawStatus
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        guard !normalized.isEmpty else { return nil }

        switch normalized {
        case "draft", "reviewdraft", "review_draft", "review_drafts":
            return InvoiceStatus.reviewDraft.rawValue
        case "readytosend", "ready_to_send":
            return InvoiceStatus.readyToSend.rawValue
        case "sent":
            return InvoiceStatus.pending.rawValue
        case "paid", "completed", "payment_received":
            return InvoiceStatus.received.rawValue
        case "pending":
            return InvoiceStatus.pending.rawValue
        case "received":
            return InvoiceStatus.received.rawValue
        case "overdue":
            return InvoiceStatus.overdue.rawValue
        case "cancelled", "canceled":
            return InvoiceStatus.cancelled.rawValue
        case "void", "voided":
            return InvoiceStatus.voided.rawValue
        default:
            return normalized
        }
    }
}
