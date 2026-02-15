import Foundation
import SwiftData
import Core

/// SwiftData implementation of InvoicesRepository
public final class InvoicesRepositorySwiftData: InvoicesRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let invoiceMapper: InvoiceMapper
    private let invoiceItemMapper: InvoiceItemMapper
    
    public init(
        modelContext: ModelContext, 
        invoiceMapper: InvoiceMapper = InvoiceMapper(),
        invoiceItemMapper: InvoiceItemMapper = InvoiceItemMapper()
    ) {
        self.modelContext = modelContext
        self.invoiceMapper = invoiceMapper
        self.invoiceItemMapper = invoiceItemMapper
    }
    
    public func fetchAll() async throws -> [Invoice] {
        let descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.map { self.invoiceMapper.mapToDomain($0) }
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
            return entities.map { self.invoiceMapper.mapToDomain($0) }
        }
    }
    
    public func fetch(by status: String) async throws -> [Invoice] {
        guard let normalizedStatus = InvoiceStatus(normalized: status) else {
            throw RepositoryError.validationFailed(message: "Unsupported invoice status: \(status)")
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
        )
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities
                .filter { matchesStatus($0.status, target: normalizedStatus) }
                .map { self.invoiceMapper.mapToDomain($0) }
        }
    }
    
    public func fetch(by billingStatus: BillingStatus) async throws -> [Invoice] {
        guard let statusString = mapBillingStatusToInvoiceStatus(billingStatus) else {
            throw RepositoryError.validationFailed(
                message: "Billing status \(billingStatus.rawValue) is not valid for invoices."
            )
        }
        return try await fetch(by: statusString)
    }
    
    public func fetch(by id: UUID) async throws -> Invoice? {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.id == id
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return self.invoiceMapper.mapToDomain(entity)
        }
    }
    
    public func fetch(by invoiceNumber: String) async throws -> Invoice? {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.invoiceNumber == invoiceNumber
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else { return nil }
            return self.invoiceMapper.mapToDomain(entity)
        }
    }
    
    public func create(_ invoice: Invoice) async throws -> Invoice {
        try validateInvoiceStatus(invoice.status)
        return try await MainActor.run {
            var entity = InvoiceEntity(id: invoice.id, invoiceNumber: invoice.invoiceNumber)
            self.invoiceMapper.updateEntity(&entity, from: invoice)
            self.applyWorkflowDates(for: entity)
            
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
            
            // Set session relationships
            if !invoice.sessionIds.isEmpty {
                let sessionIds = invoice.sessionIds
                let sessionPredicate = #Predicate<SessionEntity> { sessionIds.contains($0.id) }
                let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: sessionPredicate)
                let sessions = try modelContext.fetch(sessionDescriptor)
                entity.sessions = sessions
            } else {
                entity.sessions = []
            }
            syncLinkedSessionStatuses(for: entity)
            
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
            self.notifySessionsRefreshIfNeeded(for: entity)
            
            return self.invoiceMapper.mapToDomain(entity)
        }
    }
    
    public func update(_ invoice: Invoice) async throws -> Invoice {
        try validateInvoiceStatus(invoice.status)
        return try await MainActor.run {
            let predicate = #Predicate<InvoiceEntity> { i in i.id == invoice.id }
            let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            var mutableEntity = entity
            self.invoiceMapper.updateEntity(&mutableEntity, from: invoice)
            self.applyWorkflowDates(for: entity)
            
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
            
            // Set session relationships
            if !invoice.sessionIds.isEmpty {
                let sessionIds = invoice.sessionIds
                let sessionPredicate = #Predicate<SessionEntity> { sessionIds.contains($0.id) }
                let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: sessionPredicate)
                let sessions = try modelContext.fetch(sessionDescriptor)
                entity.sessions = sessions
            } else {
                entity.sessions = []
            }
            syncLinkedSessionStatuses(for: entity)
            
            // Always populate snapshot fields from relationships after setting them
            // This ensures payee data is populated from client.payee when billing authority is Parent/Guardian
            entity.snapshotRelatedData()
            
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            self.notifySessionsRefreshIfNeeded(for: entity)
            
            return self.invoiceMapper.mapToDomain(entity)
        }
    }
    
    public func delete(id: UUID) async throws {
        try await MainActor.run {
            let predicate = #Predicate<InvoiceEntity> { i in i.id == id }
            let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            let hadLinkedSessions = !(entity.sessions?.isEmpty ?? true)

            resetLinkedSessionStatusesOnDelete(for: entity)
            modelContext.delete(entity)
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            if hadLinkedSessions {
                SessionChangePublisher.shared.notifyRefreshNeeded()
            }
        }
    }
    
    public func updateStatus(id: UUID, status: String) async throws {
        guard let normalizedStatus = InvoiceStatus(normalized: status) else {
            throw RepositoryError.validationFailed(message: "Unsupported invoice status: \(status)")
        }

        try await MainActor.run {
            let predicate = #Predicate<InvoiceEntity> { i in i.id == id }
            let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            entity.status = normalizedStatus
            applyWorkflowDates(for: entity)
            syncLinkedSessionStatuses(for: entity)
            
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            self.notifySessionsRefreshIfNeeded(for: entity)
        }
    }
    
    public func updateBillingStatus(id: UUID, status: BillingStatus) async throws {
        guard let statusString = mapBillingStatusToInvoiceStatus(status) else {
            throw RepositoryError.validationFailed(
                message: "Billing status \(status.rawValue) is not valid for invoices."
            )
        }
        try await updateStatus(id: id, status: statusString)
    }
    
    public func createFromSessions(_ sessionIds: [UUID], clientId: UUID) async throws -> Invoice {
        // Create invoice from sessions with generated invoice number and default payment terms
        let invoiceNumber = try await generateInvoiceNumber()
        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: invoiceNumber,
            dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            issueDate: Date(),
            status: InvoiceStatus.reviewDraft.rawValue,
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
            itemEntity.serviceDate = item.serviceDate
            itemEntity.ndisItemNumber = item.ndisItemNumber
            itemEntity.unit = item.unit
            itemEntity.gstCode = item.gstCode
            if let claimTypeStr = item.claimType {
                itemEntity.claimType = NDISClaimType(rawValue: claimTypeStr)
            }
            
            // Map new NDIS fields
            itemEntity.taxRate = item.taxRate
            itemEntity.ndisSupportCategory = item.ndisSupportCategory
            itemEntity.ndisRegistrationGroup = item.ndisRegistrationGroup
            itemEntity.ndisOutcomeDomain = item.ndisOutcomeDomain
            itemEntity.ndisSupportPurpose = item.ndisSupportPurpose
            itemEntity.isComplexBehaviour = item.isComplexBehaviour
            itemEntity.isHighIntensity = item.isHighIntensity
            itemEntity.geographicLoading = item.geographicLoading
            itemEntity.timeModifier = item.timeModifier
            itemEntity.groupModifier = item.groupModifier
            itemEntity.finalRateLimit = item.finalRateLimit
            
            if itemEntity.modelContext == nil {
                modelContext.insert(itemEntity)
            }
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return self.invoiceItemMapper.mapToDomain(itemEntity)
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
            entity.serviceDate = item.serviceDate
            entity.ndisItemNumber = item.ndisItemNumber
            entity.unit = item.unit
            entity.gstCode = item.gstCode
            if let claimTypeStr = item.claimType {
                entity.claimType = NDISClaimType(rawValue: claimTypeStr)
            } else {
                entity.claimType = nil
            }
            
            // Map new NDIS fields for update
            entity.taxRate = item.taxRate
            entity.ndisSupportCategory = item.ndisSupportCategory
            entity.ndisRegistrationGroup = item.ndisRegistrationGroup
            entity.ndisOutcomeDomain = item.ndisOutcomeDomain
            entity.ndisSupportPurpose = item.ndisSupportPurpose
            entity.isComplexBehaviour = item.isComplexBehaviour
            entity.isHighIntensity = item.isHighIntensity
            entity.geographicLoading = item.geographicLoading
            entity.timeModifier = item.timeModifier
            entity.groupModifier = item.groupModifier
            entity.finalRateLimit = item.finalRateLimit
            do {
            try modelContext.save()
            } catch {
                modelContext.rollback()
                throw RepositoryError.saveFailed
            }
            return self.invoiceItemMapper.mapToDomain(entity)
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
            return entities.map { self.invoiceItemMapper.mapToDomain($0) }
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
            return entities.map { self.invoiceMapper.mapToDomain($0) }
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
            return entities.map { self.invoiceMapper.mapToDomain($0) }
        }
    }
    
    public func count() async throws -> Int {
        let descriptor = FetchDescriptor<InvoiceEntity>()
        return try await MainActor.run {
            try modelContext.fetchCount(descriptor)
        }
    }
    
    public func count(by status: String) async throws -> Int {
        guard let normalizedStatus = InvoiceStatus(normalized: status) else {
            throw RepositoryError.validationFailed(message: "Unsupported invoice status: \(status)")
        }
        let descriptor = FetchDescriptor<InvoiceEntity>()
        return try await MainActor.run {
            let entities = try modelContext.fetch(descriptor)
            return entities.reduce(into: 0) { count, entity in
                if matchesStatus(entity.status, target: normalizedStatus) {
                    count += 1
                }
            }
        }
    }
    
    public func generateInvoiceNumber() async throws -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        let prefix = "INV-\(dateString)-"

        return try await MainActor.run {
            let descriptor = FetchDescriptor<InvoiceEntity>()
            let invoices = try modelContext.fetch(descriptor)

            let maxSequence = invoices
                .map(\.invoiceNumber)
                .compactMap { number -> Int? in
                    guard number.hasPrefix(prefix) else { return nil }
                    return Int(number.dropFirst(prefix.count))
                }
                .max() ?? 0

            var nextSequence = maxSequence + 1
            while true {
                let candidate = "\(prefix)\(String(format: "%04d", nextSequence))"
                let predicate = #Predicate<InvoiceEntity> { invoice in
                    invoice.invoiceNumber == candidate
                }
                let existsDescriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
                if try modelContext.fetch(existsDescriptor).isEmpty {
                    return candidate
                }
                nextSequence += 1
            }
        }
    }
    
    // MARK: - Private Helpers
    // Note: fetchEntity and fetchItemEntity helpers removed - all entity operations now happen directly within MainActor.run blocks
    // to avoid Sendable conformance issues with InvoiceEntity and InvoiceItemEntity
    
    private func mapBillingStatusToInvoiceStatus(_ billingStatus: BillingStatus) -> String? {
        switch billingStatus {
        case .reviewDrafts:
            return InvoiceStatus.reviewDraft.rawValue
        case .readyToSend:
            return InvoiceStatus.readyToSend.rawValue
        case .pending:
            return InvoiceStatus.pending.rawValue
        case .received:
            return InvoiceStatus.received.rawValue
        case .completed, .grouped, .addTravel:
            return nil
        }
    }

    private func matchesStatus(_ candidate: InvoiceStatus, target: InvoiceStatus) -> Bool {
        candidate == target
    }

    private func validateInvoiceStatus(_ status: String) throws {
        guard InvoiceStatus(normalized: status) != nil else {
            throw RepositoryError.validationFailed(message: "Unsupported invoice status: \(status)")
        }
    }

    private func applyWorkflowDates(for invoice: InvoiceEntity) {
        switch invoice.status {
        case .reviewDraft, .readyToSend:
            invoice.sentDate = nil
            invoice.paidDate = nil
        case .pending, .overdue:
            if invoice.sentDate == nil {
                invoice.sentDate = Date()
            }
            invoice.paidDate = nil
        case .received:
            if invoice.sentDate == nil {
                invoice.sentDate = Date()
            }
            if invoice.paidDate == nil {
                invoice.paidDate = Date()
            }
        case .cancelled, .voided:
            break
        }
    }

    private func syncLinkedSessionStatuses(for invoice: InvoiceEntity) {
        guard let sessionStatus = linkedSessionStatus(for: invoice.status),
              let sessions = invoice.sessions else {
            return
        }
        for session in sessions {
            session.status = sessionStatus
        }
    }

    private func resetLinkedSessionStatusesOnDelete(for invoice: InvoiceEntity) {
        guard let sessions = invoice.sessions else { return }
        let target: SessionStatus?
        switch invoice.status {
        case .reviewDraft, .readyToSend:
            target = .needsTravel
        case .pending, .overdue, .received:
            target = .completed
        case .cancelled, .voided:
            target = nil
        }

        guard let target else { return }
        for session in sessions {
            session.status = target
        }
    }

    private func linkedSessionStatus(for invoiceStatus: InvoiceStatus) -> SessionStatus? {
        switch invoiceStatus {
        case .reviewDraft:
            return .reviewDraft
        case .readyToSend:
            return .readyToSend
        case .pending, .overdue:
            return .pending
        case .received:
            return .received
        case .cancelled, .voided:
            return nil
        }
    }

    @MainActor
    private func notifySessionsRefreshIfNeeded(for invoice: InvoiceEntity) {
        guard let sessions = invoice.sessions, !sessions.isEmpty else { return }
        SessionChangePublisher.shared.notifyRefreshNeeded()
    }
}
