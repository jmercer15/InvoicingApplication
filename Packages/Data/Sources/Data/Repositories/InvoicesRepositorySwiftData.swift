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
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
    }
    
    public func fetch(byClientId clientId: UUID) async throws -> [Invoice] {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.client?.id == clientId
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
    }
    
    public func fetch(by status: String) async throws -> [Invoice] {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.status?.rawValue == status
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
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
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return Invoice(fromEntity: entity)
        }
    }
    
    public func fetch(by invoiceNumber: String) async throws -> Invoice? {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.invoiceNumber == invoiceNumber
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return Invoice(fromEntity: entity)
        }
    }
    
    public func create(_ invoice: Invoice) async throws -> Invoice {
        return try await MainActor.run {
            let entity = InvoiceEntity(id: invoice.id, invoiceNumber: invoice.invoiceNumber)
            entity.update(from: invoice)
            
            // Set or clear client relationship
            if let clientId = invoice.clientId {
                let clientPredicate = #Predicate<ClientEntity> { $0.id == clientId }
                let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: clientPredicate)
                if let clientEntity = try modelContext.fetch(clientDescriptor).first {
                    entity.client = clientEntity
                } else {
                    // Client not found, clear relationship
                    entity.client = nil
                }
            } else {
                // Explicitly clear relationship if no clientId provided
                entity.client = nil
            }
            
            // Set or clear payee relationship
            if let payeeId = invoice.payeeId {
                let payeePredicate = #Predicate<PayeeEntity> { $0.id == payeeId }
                let payeeDescriptor = FetchDescriptor<PayeeEntity>(predicate: payeePredicate)
                if let payeeEntity = try modelContext.fetch(payeeDescriptor).first {
                    entity.payee = payeeEntity
                } else {
                    // Payee not found, clear relationship
                    entity.payee = nil
                }
            } else {
                // Explicitly clear relationship if no payeeId provided
                // However, if client has payee and billing authority is parent/guardian, 
                // derive payee from client relationship
                if let client = entity.client,
                   client.billingAuthority == .parentGuardian,
                   let clientPayee = client.payee {
                    entity.payee = clientPayee
                } else {
                    entity.payee = nil
                }
            }
            
            // Set or clear business relationship
            if let businessId = invoice.businessId {
                let businessPredicate = #Predicate<BusinessEntity> { $0.id == businessId }
                let businessDescriptor = FetchDescriptor<BusinessEntity>(predicate: businessPredicate)
                if let businessEntity = try modelContext.fetch(businessDescriptor).first {
                    entity.business = businessEntity
                } else {
                    // Business not found, clear relationship
                    entity.business = nil
                }
            } else {
                // Explicitly clear relationship if no businessId provided
                entity.business = nil
            }
            
            // Always populate snapshot fields from relationships after setting them
            // This ensures payee data is populated from client.payee when billing authority is Parent/Guardian
            entity.snapshotRelatedData()
            
            if entity.modelContext == nil {
                modelContext.insert(entity)
            }
            
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            
            return Invoice(fromEntity: entity)
        }
    }
    
    public func update(_ invoice: Invoice) async throws -> Invoice {
        return try await MainActor.run {
            let predicate = #Predicate<InvoiceEntity> { i in i.id == invoice.id }
            let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.update(from: invoice)
            
            // Set or clear client relationship
            if let clientId = invoice.clientId {
                let clientPredicate = #Predicate<ClientEntity> { $0.id == clientId }
                let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: clientPredicate)
                if let clientEntity = try modelContext.fetch(clientDescriptor).first {
                    entity.client = clientEntity
                } else {
                    // Client not found, clear relationship
                    entity.client = nil
                }
            } else {
                // Explicitly clear relationship if no clientId provided
                entity.client = nil
            }
            
            // Set or clear payee relationship
            if let payeeId = invoice.payeeId {
                let payeePredicate = #Predicate<PayeeEntity> { $0.id == payeeId }
                let payeeDescriptor = FetchDescriptor<PayeeEntity>(predicate: payeePredicate)
                if let payeeEntity = try modelContext.fetch(payeeDescriptor).first {
                    entity.payee = payeeEntity
                } else {
                    // Payee not found, clear relationship
                    entity.payee = nil
                }
            } else {
                // Explicitly clear relationship if no payeeId provided
                // However, if client has payee and billing authority is parent/guardian, 
                // derive payee from client relationship
                if let client = entity.client,
                   client.billingAuthority == .parentGuardian,
                   let clientPayee = client.payee {
                    entity.payee = clientPayee
                } else {
                    entity.payee = nil
                }
            }
            
            // Set or clear business relationship
            if let businessId = invoice.businessId {
                let businessPredicate = #Predicate<BusinessEntity> { $0.id == businessId }
                let businessDescriptor = FetchDescriptor<BusinessEntity>(predicate: businessPredicate)
                if let businessEntity = try modelContext.fetch(businessDescriptor).first {
                    entity.business = businessEntity
                } else {
                    // Business not found, clear relationship
                    entity.business = nil
                }
            } else {
                // Explicitly clear relationship if no businessId provided
                entity.business = nil
            }
            
            // Always populate snapshot fields from relationships after setting them
            // This ensures payee data is populated from client.payee when billing authority is Parent/Guardian
            entity.snapshotRelatedData()
            
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            
            return Invoice(fromEntity: entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<InvoiceEntity> { i in i.id == id }
            let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            modelContext.delete(entity)
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        try await MainActor.run {
            let predicate = #Predicate<InvoiceEntity> { i in i.id == id }
            let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
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
            
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
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
        return try await MainActor.run {
            let invoicePredicate = #Predicate<InvoiceEntity> { i in i.id == item.invoiceId }
            let invoiceDescriptor = FetchDescriptor<InvoiceEntity>(predicate: invoicePredicate)
            guard let invoiceEntity = try modelContext.fetch(invoiceDescriptor).first else {
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
            
            if itemEntity.modelContext == nil {
                modelContext.insert(itemEntity)
            }
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return InvoiceItem(from: itemEntity)
        }
    }
    
    public func updateItem(_ item: InvoiceItem) async throws -> InvoiceItem {
        return try await MainActor.run {
            let predicate = #Predicate<InvoiceItemEntity> { i in i.id == item.id }
            let descriptor = FetchDescriptor<InvoiceItemEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.itemDescription = item.itemDescription
            entity.quantity = item.quantity
            entity.rate = item.rate
            entity.position = item.position
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return InvoiceItem(from: entity)
        }
    }
    
    public func removeItem(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<InvoiceItemEntity> { i in i.id == id }
            let descriptor = FetchDescriptor<InvoiceItemEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            modelContext.delete(entity)
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
        }
    }
    
    public func fetchItems(by invoiceId: UUID) async throws -> [InvoiceItem] {
        let predicate = #Predicate<InvoiceItemEntity> { item in
            item.invoice?.id == invoiceId
        }
        let descriptor = FetchDescriptor<InvoiceItemEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.position, order: .forward)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { InvoiceItem(from: $0) }
        }
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
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Invoice] {
        var descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<InvoiceEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func count(by status: String) async throws -> Int {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.status?.rawValue == status
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func generateInvoiceNumber() async throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        
        let count = try await count()
        return "INV-\(dateString)-\(String(format: "%04d", count + 1))"
    }
    
    // MARK: - Private Helpers
    // Note: fetchEntity and fetchItemEntity helpers removed - all entity operations now happen directly within MainActor.run blocks
    // to avoid Sendable conformance issues with InvoiceEntity and InvoiceItemEntity
    
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
