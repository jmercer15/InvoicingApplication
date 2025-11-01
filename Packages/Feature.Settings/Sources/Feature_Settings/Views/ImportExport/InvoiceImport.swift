import Foundation
import SwiftUI
import SwiftData // Import SwiftData
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
    func toInvoiceJSON() -> ImportExportView.InvoiceJSON {
        // Parse dates properly
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let issueDateParsed = issueDate.flatMap { dateFormatter.date(from: $0) }
        let dueDateParsed = dueDate.flatMap { dateFormatter.date(from: $0) }
        
        return ImportExportView.InvoiceJSON(
            invoiceNumber: invoiceNumber,
            dateIssued: issueDateParsed,
            dateIssuedString: issueDate,
            dateDue: dueDateParsed,
            dateDueString: dueDate,
            totalAmount: totalAmount,
            totalAmountString: totalAmount != nil ? String(totalAmount!) : nil,
            status: status,
            clientName: clientName,
            userData: self
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
    static func importInvoices(data: Data, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
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
                    let invoices = try decoder.decode([ImportExportView.InvoiceJSON].self, from: data)
                    return try processInvoices(invoices, fileName: fileName, context: context)
                } catch {
                    // Try as single invoice
                    do {
                        let invoice = try decoder.decode(ImportExportView.InvoiceJSON.self, from: data)
                        return try processInvoices([invoice], fileName: fileName, context: context)
                    } catch {
                        // If both formats fail, try with adapter
                        return try importInvoicesWithAdapter(data: data, fileName: fileName, context: context)
                    }
                }
            }
        }
    }
    
    private static func importInvoicesWithAdapter(data: Data, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
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
    
    private static func processActualInvoices(_ invoices: [ActualInvoiceJSON], fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
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
        
        let convertedInvoices = invoices.map { invoice -> ImportExportView.InvoiceJSON in
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
                
                print("DEBUG: Looking for client with surname ending in '\(surnamePrefix)' and first name starting with '\(firstInitial)'")
                print("DEBUG: Available clients: \(allClients.map { $0.fullName })")
                
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
                        
                        print("DEBUG: Checking client '\(client.fullName)' -> lastName: '\(lastName)', lastNamePrefix: '\(lastNamePrefix)', firstName: '\(firstName)', firstNameInitial: '\(firstNameInitial)'")
                        
                        return lastNamePrefix == surnamePrefix && firstNameInitial == firstInitial
                    }
                    return false
                }) {
                    clientName = matchedClient.fullName
                    print("DEBUG: Found matching client: \(matchedClient.fullName)")
                } else {
                    print("DEBUG: No matching client found for invoice \(invoice.invoiceNumber)")
                }
            }
            
            let invoiceJSON = ImportExportView.InvoiceJSON(
                invoiceNumber: invoice.invoiceNumber,
                dateIssued: issueDate,
                dateIssuedString: issueDate != nil ? displayFormatter.string(from: issueDate!) : invoice.issueDate,
                dateDue: dueDate,
                dateDueString: dueDate != nil ? displayFormatter.string(from: dueDate!) : invoice.dueDate,
                totalAmount: invoice.totalAmount,
                totalAmountString: invoice.totalAmount != nil ? String(invoice.totalAmount!) : nil,
                status: invoice.status,
                clientName: clientName,
                userData: invoice
            )
            
            return invoiceJSON
        }
        
        // Use regular processor to handle the converted data
        return try processInvoices(convertedInvoices, fileName: fileName, context: context)
    }
    
    private static func processInvoices(_ invoices: [ImportExportView.InvoiceJSON], fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var errorMessages: [String] = []
        
        // Dictionary to track processed invoices and their original data
        var processedInvoicesData: [String: Any] = [:]
        
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
                
                invoiceEntity.status = InvoiceStatus(rawValue: invoice.status ?? "Draft") ?? .draft
                
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
        for (invoiceNumber, userData) in processedInvoicesData {
            if let actualInvoice = userData as? ActualInvoiceJSON, let items = actualInvoice.items, !items.isEmpty {
                try addLineItemsToInvoice(invoiceNumber: invoiceNumber, items: items, context: context)
            } else if let newFormatInvoice = userData as? InvoiceImportJSON, let items = newFormatInvoice.items, !items.isEmpty {
                try addLineItemsFromNewFormat(invoiceNumber: invoiceNumber, items: items, context: context)
            }
        }
        
        // No explicit save needed here, changes are tracked by ModelContext
        
        return ImportExportView.ImportResults(
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
            lineItem.amount = lineItem.quantity * lineItem.rate
            lineItem.invoice = invoice
            lineItem.date = invoice.issueDate
            
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
                    // Assign a unique clientServiceID
                    let maxID = clientServices.compactMap { $0.clientServiceID }.max() ?? 0
                    newClientService.clientServiceID = maxID + 1
                    
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
            lineItem.amount = lineItem.quantity * lineItem.rate
            lineItem.invoice = invoice
            lineItem.date = invoice.issueDate
            
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
                    // Assign a unique clientServiceID
                    let maxID = clientServices.compactMap { $0.clientServiceID }.max() ?? 0
                    newClientService.clientServiceID = maxID + 1
                    
                    print("Created new ClientService '\(item.description)' for client '\(client.fullName)' during invoice import.")
                }
            }
        }
    }
}
