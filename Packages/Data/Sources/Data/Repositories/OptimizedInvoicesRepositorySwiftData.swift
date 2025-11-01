import Foundation
import SwiftData
import Core

/// Optimized SwiftData implementation of InvoicesRepository with caching and performance monitoring
public final class OptimizedInvoicesRepositorySwiftData: InvoicesRepository, OptimizedRepository, @unchecked Sendable {
    private let modelContext: ModelContext
    private let cache: QueryOptimizationGuide.QueryCache
    private var queryMetrics: [QueryOptimizationGuide.QueryMetrics] = []
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.cache = QueryOptimizationGuide.QueryCache(maxAge: 300, maxSize: 100) // 5 minutes, 100 items
    }
    
    // MARK: - Optimized Query Methods
    
    public func fetchAll() async throws -> [Invoice] {
        let cacheKey = "fetchAll_invoices"
        
        // Check cache first
        if let cached: [Invoice] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchAll_invoices") {
            let descriptor = FetchDescriptor<InvoiceEntity>(
                sortBy: [SortDescriptor(\InvoiceEntity.issueDate, order: .reverse)]
            ).withLimit(100) // Limit to prevent memory issues
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetch(by clientId: UUID) async throws -> [Invoice] {
        let cacheKey = "fetchByClientId_\(clientId.uuidString)"
        
        // Check cache first
        if let cached: [Invoice] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchByClientId_\(clientId.uuidString)") {
            let predicate = #Predicate<InvoiceEntity> { invoice in
                invoice.client?.id == clientId
            }
            let descriptor = FetchDescriptor<InvoiceEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\InvoiceEntity.issueDate, order: .reverse)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetch(by status: String) async throws -> [Invoice] {
        let cacheKey = "fetchByStatus_\(status)"
        
        // Check cache first
        if let cached: [Invoice] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchByStatus_\(status)") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.byStatus(
                InvoiceStatus(rawValue: status) ?? .draft,
                statusProperty: \InvoiceEntity.status,
                sortBy: [SortDescriptor(\InvoiceEntity.issueDate, order: .reverse)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetch(by billingStatus: BillingStatus) async throws -> [Invoice] {
        let statusString = mapBillingStatusToInvoiceStatus(billingStatus)
        return try await fetch(by: statusString)
    }
    
    public func fetch(by id: UUID) async throws -> Invoice? {
        let cacheKey = "fetchById_\(id.uuidString)"
        
        // Check cache first
        if let cached: Invoice? = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchById_\(id.uuidString)") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.byId(id, for: InvoiceEntity.self)
            guard let entity = try modelContext.fetch(descriptor).first else { return nil as Invoice? }
            return Invoice(fromEntity: entity)
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    public func fetch(by invoiceNumber: String) async throws -> Invoice? {
        let cacheKey = "fetchByInvoiceNumber_\(invoiceNumber)"
        
        // Check cache first
        if let cached: Invoice? = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchByInvoiceNumber_\(invoiceNumber)") {
            let predicate = #Predicate<InvoiceEntity> { invoice in
                invoice.invoiceNumber == invoiceNumber
            }
            let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
            guard let entity = try modelContext.fetch(descriptor).first else { return nil as Invoice? }
            return Invoice(fromEntity: entity)
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    // MARK: - Date Range Queries
    
    /// Fetch invoices within a date range
    /// - Parameters:
    ///   - startDate: Start of date range
    ///   - endDate: End of date range
    /// - Returns: Invoices within the date range
    public func fetch(from startDate: Date, to endDate: Date) async throws -> [Invoice] {
        let cacheKey = "fetchByDateRange_\(startDate.timeIntervalSince1970)_\(endDate.timeIntervalSince1970)"
        
        // Check cache first
        if let cached: [Invoice] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized date range query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchByDateRange_\(startDate.timeIntervalSince1970)_\(endDate.timeIntervalSince1970)") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.dateRange(
                from: startDate,
                to: endDate,
                dateProperty: \InvoiceEntity.issueDate,
                sortBy: [SortDescriptor(\InvoiceEntity.issueDate, order: .reverse)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    /// Fetch overdue invoices
    /// - Returns: Invoices that are past their due date and not paid
    public func fetchOverdue() async throws -> [Invoice] {
        let cacheKey = "fetchOverdue_invoices"
        
        // Check cache first
        if let cached: [Invoice] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute optimized overdue query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchOverdue_invoices") {
            let now = Date()
            let predicate = #Predicate<InvoiceEntity> { invoice in
                invoice.dueDate != nil && invoice.dueDate! < now && invoice.status?.rawValue != "Paid"
            }
            let descriptor = FetchDescriptor<InvoiceEntity>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.dueDate, order: .forward)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    // MARK: - Paginated Queries
    
    /// Fetch invoices with pagination
    /// - Parameters:
    ///   - offset: Number of invoices to skip
    ///   - limit: Maximum number of invoices to return
    /// - Returns: Paginated list of invoices
    public func fetchPaginated(offset: Int = 0, limit: Int = 50) async throws -> [Invoice] {
        let cacheKey = "fetchPaginated_\(offset)_\(limit)"
        
        // Check cache first
        if let cached: [Invoice] = cache.get(cacheKey) {
            return cached
        }
        
        // Execute paginated query with monitoring
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("fetchPaginated_\(offset)_\(limit)") {
            let descriptor = QueryOptimizationGuide.OptimizedDescriptors.paginated(
                offset: offset,
                limit: limit,
                sortBy: [SortDescriptor(\InvoiceEntity.issueDate, order: .reverse)]
            )
            let entities = try modelContext.fetch(descriptor)
            return entities.map { Invoice(fromEntity: $0) }
        }
        
        // Cache result and store metrics
        cache.set(cacheKey, value: result)
        queryMetrics.append(metrics)
        
        return result
    }
    
    // MARK: - CRUD Operations
    
    public func create(_ invoice: Invoice) async throws -> Invoice {
        // Clear relevant cache entries
        cache.clear()
        
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("create_invoice") {
            let entity = InvoiceEntity(id: invoice.id, invoiceNumber: invoice.invoiceNumber)
            entity.update(from: invoice)
            modelContext.insert(entity)
            try modelContext.save()
            return Invoice(fromEntity: entity)
        }
        
        queryMetrics.append(metrics)
        return result
    }
    
    public func update(_ invoice: Invoice) async throws -> Invoice {
        // Clear relevant cache entries
        cache.clear()
        
        guard let entity = try await fetchEntity(by: invoice.id) else {
            throw RepositoryError.entityNotFound
        }
        
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("update_invoice") {
            entity.update(from: invoice)
            try modelContext.save()
            return Invoice(fromEntity: entity)
        }
        
        queryMetrics.append(metrics)
        return result
    }
    
    public func delete(id: UUID) async throws {
        // Clear relevant cache entries
        cache.clear()
        
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        
        let (_, metrics) = try QueryOptimizationGuide.monitorQuery("delete_invoice") {
            modelContext.delete(entity)
            try modelContext.save()
        }
        
        queryMetrics.append(metrics)
    }
    
    // MARK: - Status Update Operations
    
    public func updateStatus(id: UUID, status: String) async throws {
        // Clear relevant cache entries
        cache.clear()
        
        guard let entity = try await fetchEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        
        let (_, metrics) = try QueryOptimizationGuide.monitorQuery("updateStatus_\(status)") {
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
        
        queryMetrics.append(metrics)
    }
    
    public func updateBillingStatus(id: UUID, status: BillingStatus) async throws {
        let statusString = mapBillingStatusToInvoiceStatus(status)
        try await updateStatus(id: id, status: statusString)
    }
    
    // MARK: - Invoice Item Operations
    
    public func addItem(_ item: InvoiceItem) async throws -> InvoiceItem {
        // Clear relevant cache entries
        cache.clear()
        
        // Set relationships
        let invoiceEntity = try await fetchEntity(by: item.invoiceId)
        
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("addItem") {
            let itemEntity = InvoiceItemEntity(id: item.id, itemDescription: item.itemDescription)
            itemEntity.itemDescription = item.itemDescription
            itemEntity.quantity = item.quantity
            itemEntity.rate = item.rate
            itemEntity.position = item.position
            // itemEntity.date = item.date // InvoiceItem doesn't have a date property
            
            // Set relationships
            if let invoiceEntity = invoiceEntity {
                itemEntity.invoice = invoiceEntity
            }
            
            modelContext.insert(itemEntity)
            try modelContext.save()
            return InvoiceItem(from: itemEntity)
        }
        
        queryMetrics.append(metrics)
        return result
    }
    
    public func updateItem(_ item: InvoiceItem) async throws -> InvoiceItem {
        // Clear relevant cache entries
        cache.clear()
        
        guard let entity = try await fetchItemEntity(by: item.id) else {
            throw RepositoryError.entityNotFound
        }
        
        let (result, metrics) = try QueryOptimizationGuide.monitorQuery("updateItem") {
            entity.itemDescription = item.itemDescription
            entity.quantity = item.quantity
            entity.rate = item.rate
            entity.position = item.position
            // Note: InvoiceItem doesn't have a date property
            try modelContext.save()
            return InvoiceItem(from: entity)
        }
        
        queryMetrics.append(metrics)
        return result
    }
    
    public func deleteItem(id: UUID) async throws {
        // Clear relevant cache entries
        cache.clear()
        
        guard let entity = try await fetchItemEntity(by: id) else {
            throw RepositoryError.entityNotFound
        }
        
        let (_, metrics) = try QueryOptimizationGuide.monitorQuery("deleteItem") {
            modelContext.delete(entity)
            try modelContext.save()
        }
        
        queryMetrics.append(metrics)
    }
    
    // MARK: - OptimizedRepository Protocol
    
    public func getQueryMetrics() -> [QueryOptimizationGuide.QueryMetrics] {
        return queryMetrics
    }
    
    public func clearCache() {
        cache.clear()
    }
    
    public func getCacheStats() -> (hitRate: Double, size: Int, maxSize: Int) {
        // This would need to be implemented with actual cache hit/miss tracking
        return (hitRate: 0.0, size: 0, maxSize: 100)
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
        case .completed:
            return "completed"
        case .grouped:
            return "grouped"
        case .assignServices:
            return "needs_services"
        case .addTravel:
            return "needs_travel"
        case .reviewDrafts:
            return "review_draft"
        case .readyToSend:
            return "ready_to_send"
        case .pending:
            return "pending"
        case .received:
            return "received"
        }
    }
}

// MARK: - Performance Monitoring Extensions

extension OptimizedInvoicesRepositorySwiftData {
    
    /// Get performance summary
    public func getPerformanceSummary() -> String {
        let totalQueries = queryMetrics.count
        let totalTime = queryMetrics.reduce(0) { $0 + $1.executionTime }
        let avgTime = totalQueries > 0 ? totalTime / Double(totalQueries) : 0
        let slowestQuery = queryMetrics.max { $0.executionTime < $1.executionTime }
        
        var summary = "Invoice Repository Performance Summary:\n"
        summary += "Total Queries: \(totalQueries)\n"
        summary += "Total Time: \(String(format: "%.3f", totalTime))s\n"
        summary += "Average Time: \(String(format: "%.3f", avgTime))s\n"
        
        if let slowest = slowestQuery {
            summary += "Slowest Query: \(slowest.queryName) (\(String(format: "%.3f", slowest.executionTime))s)\n"
        }
        
        return summary
    }
    
    /// Clear performance metrics
    public func clearMetrics() {
        queryMetrics.removeAll()
    }
    
    // MARK: - Missing Protocol Methods
    
    public func createFromSessions(_ sessionIds: [UUID], clientId: UUID) async throws -> Invoice {
        // Create a basic invoice from sessions
        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: try await generateInvoiceNumber(),
            totalAmount: 0.0,
            taxRate: 0.0,
            creditApplied: 0.0,
            discount: 0.0,
            date: Date(),
            dueDate: nil,
            invoiceID: nil,
            issueDate: Date(),
            notes: nil,
            paidDate: nil,
            paymentTerms: nil,
            status: "draft",
            sentDate: nil,
            currencyCode: "AUD",
            businessName: nil,
            businessABN: nil,
            businessEmail: nil,
            businessAddress: nil,
            businessPhone: nil,
            clientName: nil,
            clientNDISNumber: nil,
            clientEmail: nil,
            clientPhone: nil,
            clientAddress: nil,
            billingAuthority: nil,
            billToName: nil,
            billToEmail: nil,
            billToAddress: nil,
            payeeName: nil,
            payeeEmail: nil,
            payeePhone: nil,
            payeeAddress: nil,
            bankName: nil,
            bankAccountName: nil,
            bankBSB: nil,
            bankAccountNumber: nil,
            // items: [] // Invoice initializer doesn't have items parameter
        )
        
        let entity = InvoiceEntity(id: invoice.id, invoiceNumber: invoice.invoiceNumber)
        entity.update(from: invoice)
        modelContext.insert(entity)
        try modelContext.save()
        
        return invoice
    }
    
    public func removeItem(id: UUID) async throws {
        let predicate = #Predicate<InvoiceItemEntity> { item in
            item.id == id
        }
        let descriptor = FetchDescriptor<InvoiceItemEntity>(predicate: predicate)
        if let entity = try modelContext.fetch(descriptor).first {
            modelContext.delete(entity)
            try modelContext.save()
        }
    }
    
    public func search(query: String) async throws -> [Invoice] {
        let predicate = #Predicate<InvoiceEntity> { invoice in
            invoice.invoiceNumber.localizedStandardContains(query) ||
            invoice.status?.rawValue.localizedStandardContains(query) == true
        }
        let descriptor = FetchDescriptor<InvoiceEntity>(predicate: predicate)
        let entities = try modelContext.fetch(descriptor)
        return entities.map { Invoice(fromEntity: $0) }
    }
    
    public func fetch(limit: Int, offset: Int) async throws -> [Invoice] {
        var descriptor = FetchDescriptor<InvoiceEntity>(
            sortBy: [SortDescriptor(\InvoiceEntity.date, order: .reverse)]
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
        let count = try await count()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        return "INV-\(dateString)-\(String(format: "%04d", count + 1))"
    }
}
