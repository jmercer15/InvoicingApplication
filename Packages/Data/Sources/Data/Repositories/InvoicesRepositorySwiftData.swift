import Foundation
import SwiftData
import Core

/// SwiftData implementation of InvoicesRepository
public final class InvoicesRepositorySwiftData: InvoicesRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    public func fetchAll() async throws -> [Invoice] {
        let descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Invoice(fromEntity: $0) }
    }
    
    public func fetch(by clientId: UUID) async throws -> [Invoice] {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.client?.id == clientId
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Invoice(fromEntity: $0) }
    }
    
    public func fetch(by status: String) async throws -> [Invoice] {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.status?.rawValue == status
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Invoice(fromEntity: $0) }
    }
    
    public func fetch(by billingStatus: BillingStatus) async throws -> [Invoice] {
        let statusString = mapBillingStatusToInvoiceStatus(billingStatus)
        return try await fetch(by: statusString)
    }
    
    public func fetch(by id: UUID) async throws -> Invoice? {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.id == id
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return Invoice(fromEntity: entity)
    }
    
    public func fetch(by invoiceNumber: String) async throws -> Invoice? {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.invoiceNumber == invoiceNumber
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        guard let entity = try modelContext.fetch(descriptor).first else { return nil }
        return Invoice(fromEntity: entity)
    }
    
    public func create(_ invoice: Invoice) async throws -> Invoice {
        let entity = InvoiceEntity(id: invoice.id, invoiceNumber: invoice.invoiceNumber)
        entity.update(from: invoice)
        modelContext.insert(entity)
        try modelContext.save()
        return Invoice(fromEntity: entity)
    }
    
    public func update(_ invoice: Invoice) async throws -> Invoice {
        guard let entity = try await fetchEntity(by: invoice.id) else {
            throw RepositoryError.entityNotFound
        }
        entity.update(from: invoice)
        try modelContext.save()
        return Invoice(fromEntity: entity)
    }
    
    public func delete(id: UUID) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        entity.status = InvoiceStatus(rawValue: status) ?? .draft
        
        // Set appropriate date fields based on status
        switch status {
        case "sent":
            entity.sentDate = Date()
        case "paid":
            entity.paidDate = Date()
        default:
            break
        }
        
        try modelContext.save()
    }
    
    public func updateBillingStatus(id: UUID, status: BillingStatus) async throws {
        let statusString = mapBillingStatusToInvoiceStatus(status)
        try await updateStatus(id: id, status: statusString)
    }
    
    public func createFromSessions(_ sessionIds: [UUID], clientId: UUID) async throws -> Invoice {
        // This would be implemented to create an invoice from sessions
        // For now, return a placeholder
        let invoiceNumber = try await generateInvoiceNumber()
        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: invoiceNumber,
            dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            issueDate: Date(),
            status: "draft",
            clientId: clientId,
            sessionIds: sessionIds
        )
        return try await create(invoice)
    }
    
    public func addItem(_ item: InvoiceItem) async throws -> InvoiceItem {
        guard let invoiceEntity = try await fetchEntity(by: item.invoiceId) else {
            throw RepositoryError.entityNotFound
        }
        
        let itemEntity = InvoiceItemEntity(
            id: item.id,
            itemDescription: item.itemDescription
        )
        itemEntity.invoice = invoiceEntity
        itemEntity.quantity = item.quantity
        itemEntity.rate = item.rate
        itemEntity.position = item.position
        
        modelContext.insert(itemEntity)
        try modelContext.save()
        return InvoiceItem(from: itemEntity)
    }
    
    public func updateItem(_ item: InvoiceItem) async throws -> InvoiceItem {
        guard let entity = try await fetchItemEntity(by: item.id) else {
            throw RepositoryError.entityNotFound
        }
        entity.itemDescription = item.itemDescription
        entity.quantity = item.quantity
        entity.rate = item.rate
        entity.position = item.position
        try modelContext.save()
        return InvoiceItem(from: entity)
    }
    
    public func removeItem(id: UUID) async throws {
        guard let entity = try await fetchItemEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        modelContext.delete(entity)
        try modelContext.save()
    }
    
    public func search(query: String) async throws -> [Invoice] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.invoiceNumber.localizedStandardContains(trimmedQuery) ||
            invoice.client?.fullName.localizedStandardContains(trimmedQuery) == true ||
            invoice.clientName?.localizedStandardContains(trimmedQuery) == true
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Invoice(fromEntity: $0) }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Invoice] {
        var descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Invoice(fromEntity: $0) }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<InvoiceEntity>()
        return try modelContext.fetchCount(descriptor)
    }
    
    public func count(by status: String) async throws -> Int {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.status?.rawValue == status
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        return try modelContext.fetchCount(descriptor)
    }
    
    public func generateInvoiceNumber() async throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        let count = try await count()
        return "INV-\(dateString)-\(String(format: "%04d", count + 1))"
    }
    
    // MARK: - Private Helpers
    
    private func fetchEntity(by id: UUID) async throws -> InvoiceEntity? {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.id == id
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    private func fetchItemEntity(by id: UUID) async throws -> InvoiceItemEntity? {
        let predicate = #Predicate<InvoiceItemEntity> { item in
            item.id == id
        }
        let descriptor = FetchDescriptor<InvoiceItemEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    private func mapBillingStatusToInvoiceStatus(_ billingStatus: BillingStatus) -> String {
        switch billingStatus {
        case .reviewDrafts: return "draft"
        case .readyToSend: return "ready"
        case .pending: return "sent"
        case .received: return "paid"
        default: return "draft"
        }
    }
}
