import Core
import PersistenceModels
import Foundation
import SwiftData

/// Handles import functionality for invoice data from JSON files
struct InvoiceImport {
    static func importInvoices(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        
        do {
            let newFormatInvoices = try decoder.decode([TabularInvoicePayload].self, from: data)
            let convertedInvoices = newFormatInvoices.map { $0.toImportPayload() }
            return try processInvoices(convertedInvoices, fileName: fileName, context: context)
        } catch {
            do {
                let newFormatInvoice = try decoder.decode(TabularInvoicePayload.self, from: data)
                return try processInvoices([newFormatInvoice.toImportPayload()], fileName: fileName, context: context)
            } catch {
                do {
                    let invoices = try decoder.decode([InvoiceImportPayload].self, from: data)
                    return try processInvoices(invoices, fileName: fileName, context: context)
                } catch {
                    do {
                        let invoice = try decoder.decode(InvoiceImportPayload.self, from: data)
                        return try processInvoices([invoice], fileName: fileName, context: context)
                    } catch {
                        return try importInvoicesWithAdapter(data: data, fileName: fileName, context: context)
                    }
                }
            }
        }
    }
    
    private static func importInvoicesWithAdapter(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        let decoder = JSONDecoder()
        
        do {
            let invoiceData = try decoder.decode(LegacyInvoiceEnvelope.self, from: data)
            if let invoices = invoiceData.invoices {
                return try processActualInvoices(invoices, fileName: fileName, context: context)
            }
        } catch {
            do {
                let invoices = try decoder.decode([LegacyInvoicePayload].self, from: data)
                return try processActualInvoices(invoices, fileName: fileName, context: context)
            } catch {
                throw error
            }
        }
        
        throw NSError(
            domain: "InvoiceImportError",
            code: 1002,
            userInfo: [NSLocalizedDescriptionKey: "Could not find valid invoice data in the JSON file"]
        )
    }
    
    private static func processActualInvoices(_ invoices: [LegacyInvoicePayload], fileName: String, context: ModelContext) throws -> ImportResult {
        let dateFormatter = ISO8601DateFormatter()
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd"
        
        let clientFetchDescriptor = FetchDescriptor<Client>()
        let allClients = try context.fetch(clientFetchDescriptor)
        
        let convertedInvoices = invoices.map { invoice -> InvoiceImportPayload in
            let issueDate: Date? = invoice.issueDate.flatMap { dateFormatter.date(from: $0) }
            let dueDate: Date? = invoice.dueDate.flatMap { dateFormatter.date(from: $0) }
            
            var clientName: String? = nil
            let invoiceParts = invoice.invoiceNumber.split(separator: "-")
            if invoiceParts.count >= 2 {
                let surnamePrefix = String(invoiceParts[0])
                let firstInitial = String(invoiceParts[1])
                
                if let matchedClient = allClients.first(where: { client in
                    let fullName = client.fullName.uppercased()
                    let nameParts = fullName.split(separator: " ")
                    
                    if nameParts.count >= 2 {
                        let lastName = String(nameParts.last!)
                        let firstName = String(nameParts.first!)
                        let lastNamePrefix = String(lastName.prefix(surnamePrefix.count))
                        let firstNameInitial = String(firstName.prefix(1))
                        return lastNamePrefix == surnamePrefix && firstNameInitial == firstInitial
                    }
                    return false
                }) {
                    clientName = matchedClient.fullName
                }
            }
            
            let userData = try? JSONEncoder().encode(invoice)
            
            return InvoiceImportPayload(
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
        }
        
        return try processInvoices(convertedInvoices, fileName: fileName, context: context)
    }
    
    private static func processInvoices(_ invoices: [InvoiceImportPayload], fileName: String, context: ModelContext) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var errorMessages: [String] = []
        var processedInvoicesData: [String: Data] = [:]

        let invoiceNumbers = Set(invoices.map(\.invoiceNumber).filter { !$0.isEmpty })
        let invoiceFetchDescriptor = FetchDescriptor<Invoice>(predicate: #Predicate<Invoice> { invoiceNumbers.contains($0.invoiceNumber) })
        let existingInvoices = try context.fetch(invoiceFetchDescriptor)
        var invoicesByNumber = Dictionary(uniqueKeysWithValues: existingInvoices.map { ($0.invoiceNumber, $0) })

        let clientFetchDescriptor = FetchDescriptor<Client>()
        let allClients = try context.fetch(clientFetchDescriptor)

        for invoice in invoices {
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
                let invoiceNum = invoice.invoiceNumber
                let invoiceModel: Invoice
                let isExistingInvoice: Bool
                if let existingInvoice = invoicesByNumber[invoiceNum] {
                    invoiceModel = existingInvoice
                    isExistingInvoice = true
                } else {
                    invoiceModel = Invoice(id: UUID(), invoiceNumber: invoice.invoiceNumber)
                    context.insert(invoiceModel)
                    invoicesByNumber[invoiceNum] = invoiceModel
                    isExistingInvoice = false
                }
                
                let matchingClient = allClients.first(where: { $0.fullName.localizedStandardContains(clientName) })
                
                if let client = matchingClient {
                    invoiceModel.client = client
                    if client.billingAuthority == .parentGuardian, let clientPayee = client.payee {
                        invoiceModel.payee = clientPayee
                    } else {
                        invoiceModel.payee = nil
                    }
                } else {
                    invoiceModel.client = nil
                    invoiceModel.payee = nil
                }
                
                if let issueDate = invoice.dateIssued {
                    invoiceModel.date = issueDate
                    invoiceModel.issueDate = issueDate
                } else if let dateString = invoice.dateIssuedString {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: dateString) {
                        invoiceModel.date = date
                        invoiceModel.issueDate = date
                    }
                }
                
                if let dueDate = invoice.dateDue {
                    invoiceModel.dueDate = dueDate
                } else if let dateString = invoice.dateDueString {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    if let date = dateFormatter.date(from: dateString) {
                        invoiceModel.dueDate = date
                    }
                }
                
                if let amount = invoice.totalAmount {
                    invoiceModel.totalAmount = MoneyDecimalImport.decimal(from: amount)
                } else if let amountString = invoice.totalAmountString, let amount = Double(amountString) {
                    invoiceModel.totalAmount = MoneyDecimalImport.decimal(from: amount)
                }
                
                invoiceModel.status = try parseInvoiceStatus(invoice.status, invoiceNumber: invoice.invoiceNumber)
                invoiceModel.snapshotRelatedData()
                invoiceModel.clientName = clientName
                applyTransferFields(invoice, to: invoiceModel)

                if let items = invoice.items {
                    replaceLineItems(invoice: invoiceModel, items: items, context: context)
                } else if invoice.userData == nil, invoiceModel.itemsArray.isEmpty,
                          let importedTotal = invoice.totalAmount, importedTotal > 0 {
                    replaceLineItems(
                        invoice: invoiceModel,
                        items: [InvoiceTransferItemJSON(
                            id: nil,
                            position: 0,
                            itemDescription: "Imported invoice balance",
                            serviceDate: invoiceModel.issueDate,
                            itemCode: nil,
                            quantity: 1,
                            unit: "each",
                            unitPrice: importedTotal,
                            taxRate: 0,
                            gstCode: nil
                        )],
                        context: context
                    )
                }

                if isExistingInvoice {
                    invoiceModel.markContentChanged()
                }
                
                if let userData = invoice.userData {
                    processedInvoicesData[invoice.invoiceNumber] = userData
                }
                
                successful += 1
            } catch {
                failed += 1
                errorMessages.append("Error importing invoice \(invoice.invoiceNumber): \(error.localizedDescription)")
            }
        }
        
        let decoder = JSONDecoder()
        for (invoiceNumber, userData) in processedInvoicesData {
            guard let invoice = invoicesByNumber[invoiceNumber] else { continue }
            if let actualInvoice = try? decoder.decode(LegacyInvoicePayload.self, from: userData), let items = actualInvoice.items, !items.isEmpty {
                try addLineItemsToInvoice(invoice: invoice, items: items, context: context)
            } else if let newFormatInvoice = try? decoder.decode(TabularInvoicePayload.self, from: userData), let items = newFormatInvoice.items, !items.isEmpty {
                try addLineItemsFromNewFormat(invoice: invoice, items: items, context: context)
            }
        }
        
        return ImportResult(
            source: .invoices,
            successful: successful,
            failed: failed,
            messages: errorMessages,
            fileName: fileName
        )
    }
    
    private static func addLineItemsToInvoice(invoice: Invoice, items: [LegacyInvoiceItemPayload], context: ModelContext) throws {
        let existingItems = invoice.items ?? []
        for item in existingItems { context.delete(item) }
        invoice.items = []

        var importedItems: [InvoiceItem] = []
        for (index, item) in items.enumerated() {
            let lineItem = InvoiceItem(id: UUID(), itemDescription: item.name)
            context.insert(lineItem)
            lineItem.position = Int32(index)
            lineItem.quantity = MoneyDecimalImport.decimal(from: Double(item.quantity))
            lineItem.rate = MoneyDecimalImport.decimal(from: item.unitPrice)
            lineItem.invoice = invoice
            lineItem.serviceDate = invoice.issueDate
            importedItems.append(lineItem)
            
            if let client = invoice.client {
                let clientServices = client.clientServices ?? []
                if clientServices.first(where: { $0.serviceName.caseInsensitiveCompare(item.name) == .orderedSame }) == nil {
                    let newClientService = ClientService(id: UUID(), serviceName: item.name, unit: "", rate: MoneyDecimalImport.decimal(from: item.unitPrice))
                    context.insert(newClientService)
                    newClientService.client = client
                    newClientService.isActive = true
                    newClientService.startDate = invoice.issueDate
                }
            }
        }
        invoice.items = importedItems
    }
    
    private static func addLineItemsFromNewFormat(invoice: Invoice, items: [TabularInvoiceItemPayload], context: ModelContext) throws {
        let existingItems = invoice.items ?? []
        for item in existingItems { context.delete(item) }
        invoice.items = []

        var importedItems: [InvoiceItem] = []
        for (index, item) in items.enumerated() {
            let lineItem = InvoiceItem(id: UUID(), itemDescription: item.description)
            context.insert(lineItem)
            lineItem.position = Int32(index)
            lineItem.quantity = MoneyDecimalImport.decimal(from: Double(item.quantity))
            lineItem.rate = MoneyDecimalImport.decimal(from: item.unitPrice)
            lineItem.invoice = invoice
            lineItem.serviceDate = invoice.issueDate
            importedItems.append(lineItem)
            
            if let client = invoice.client {
                let clientServices = client.clientServices ?? []
                if clientServices.first(where: { $0.serviceName.caseInsensitiveCompare(item.description) == .orderedSame }) == nil {
                    let newClientService = ClientService(id: UUID(), serviceName: item.description, unit: "", rate: MoneyDecimalImport.decimal(from: item.unitPrice))
                    context.insert(newClientService)
                    newClientService.client = client
                    newClientService.isActive = true
                    newClientService.startDate = invoice.issueDate
                }
            }
        }
        invoice.items = importedItems
    }

    private static func applyTransferFields(_ source: InvoiceImportPayload, to invoice: Invoice) {
        if let value = source.currencyCode { invoice.currencyCode = value.uppercased() }
        if let value = source.taxRate { invoice.taxRate = MoneyDecimalImport.decimal(from: value) }
        if let value = source.discount { invoice.discount = MoneyDecimalImport.decimal(from: value) }
        if let value = source.creditApplied { invoice.creditApplied = MoneyDecimalImport.decimal(from: value) }
        if let value = source.paymentTerms { invoice.paymentTerms = value }
        if let value = source.notes { invoice.notes = value }
        if let value = source.paidDate { invoice.paidDate = value }
        if let value = source.sentDate { invoice.sentDate = value }
        if let value = source.businessName { invoice.businessName = value }
        if let value = source.businessABN { invoice.businessABN = value }
        if let value = source.businessEmail { invoice.businessEmail = value }
        if let value = source.businessPhone { invoice.businessPhone = value }
        if let value = source.businessAddress { invoice.businessAddressSnapshot = value }
        if let value = source.clientNDISNumber { invoice.clientNDISNumber = value }
        if let value = source.clientEmail { invoice.clientEmail = value }
        if let value = source.clientPhone { invoice.clientPhone = value }
        if let value = source.clientAddress { invoice.clientAddressSnapshot = value }
        if let value = source.billingAuthority { invoice.billingAuthority = BillingAuthority(rawValue: value) }
        if let value = source.billToName { invoice.billToName = value }
        if let value = source.billToEmail { invoice.billToEmail = value }
        if let value = source.billToAddress { invoice.billToAddressSnapshot = value }
        if let value = source.bankName { invoice.bankName = value }
        if let value = source.bankAccountName { invoice.bankAccountName = value }
        if let value = source.bankBSB { invoice.bankBSB = value }
        if let value = source.bankAccountNumber { invoice.bankAccountNumber = value }
        if let value = source.editorConfiguration { invoice.invoiceEditorStateData = value }
    }

    private static func replaceLineItems(
        invoice: Invoice,
        items: [InvoiceTransferItemJSON],
        context: ModelContext
    ) {
        for existingItem in invoice.items ?? [] { context.delete(existingItem) }

        let importedItems = items.enumerated().map { index, source in
            let item = InvoiceItem(
                id: source.id ?? UUID(),
                itemDescription: source.itemDescription
            )
            item.position = source.position ?? Int32(index)
            item.serviceDate = source.serviceDate ?? invoice.issueDate
            item.ndisItemNumber = source.itemCode
            item.quantity = MoneyDecimalImport.decimal(from: source.quantity)
            item.unit = source.unit
            item.rate = MoneyDecimalImport.decimal(from: source.unitPrice)
            item.taxRate = MoneyDecimalImport.decimal(from: source.taxRate ?? 0)
            item.gstCode = source.gstCode
            item.invoice = invoice
            context.insert(item)
            return item
        }
        invoice.items = importedItems.sorted { $0.position < $1.position }
    }
}
