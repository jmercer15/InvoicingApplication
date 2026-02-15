//
//  SwiftDataUnitOfWork.swift
//  Data
//
//  SwiftData implementation of UnitOfWorkService
//

import Foundation
import SwiftData
import Core

/// SwiftData implementation of UnitOfWorkService.
/// Aggregates all repositories and provides transaction control.
public final class SwiftDataUnitOfWork: UnitOfWorkService, @unchecked Sendable {
    
    // MARK: - Private Properties
    
    private let modelContext: ModelContext
    private let modelContainer: ModelContainer
    
    // MARK: - Lazy Repository Instances
    
    private lazy var _clients: ClientsRepositorySwiftData = ClientsRepositorySwiftData(modelContext: modelContext)
    private lazy var _sessions: SessionsRepositorySwiftData = SessionsRepositorySwiftData(modelContext: modelContext)
    private lazy var _invoices: InvoicesRepositorySwiftData = InvoicesRepositorySwiftData(modelContext: modelContext)
    private lazy var _clientServices: ClientServicesRepositorySwiftData = ClientServicesRepositorySwiftData(modelContext: modelContext)
    private lazy var _ndisItems: NDISItemRepositorySwiftData = NDISItemRepositorySwiftData(modelContext: modelContext)
    private lazy var _payees: PayeeRepositorySwiftData = PayeeRepositorySwiftData(modelContext: modelContext)
    private lazy var _planManagers: PlanManagerRepositorySwiftData = PlanManagerRepositorySwiftData(modelContext: modelContext)
    private lazy var _business: BusinessRepositorySwiftData = BusinessRepositorySwiftData(modelContext: modelContext)
    private lazy var _addresses: AddressRepositorySwiftData = AddressRepositorySwiftData(modelContext: modelContext)
    private lazy var _travelCharges: TravelChargeRepositorySwiftData = TravelChargeRepositorySwiftData(modelContext: modelContext)
    private lazy var _travelChargeReviewItems: TravelChargeReviewRepositorySwiftData = TravelChargeReviewRepositorySwiftData(modelContext: modelContext)
    private lazy var _serviceAgreements: ServiceAgreementRepositorySwiftData = ServiceAgreementRepositorySwiftData(modelContext: modelContext)
    private lazy var _supportLogs: SupportLogRepositorySwiftData = SupportLogRepositorySwiftData(modelContext: modelContext)
    private lazy var _bulkClaims: BulkClaimRepositorySwiftData = BulkClaimRepositorySwiftData(modelContext: modelContext)
    
    // MARK: - Initialization
    
    /// Initialize with a ModelContainer.
    /// Creates a new ModelContext for this unit of work.
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.modelContext = ModelContext(modelContainer)
        self.modelContext.autosaveEnabled = false
    }
    
    /// Initialize with an existing ModelContext.
    /// Useful for child contexts or testing.
    public init(modelContext: ModelContext, modelContainer: ModelContainer) {
        self.modelContext = modelContext
        self.modelContainer = modelContainer
    }
    
    // MARK: - UnitOfWorkService Protocol
    
    public var clients: any ClientsRepository { _clients }
    public var sessions: any SessionsRepository { _sessions }
    public var invoices: any InvoicesRepository { _invoices }
    public var clientServices: any ClientServicesRepository { _clientServices }
    public var ndisItems: any NDISItemRepository { _ndisItems }
    public var payees: any PayeeRepository { _payees }
    public var planManagers: any PlanManagerRepository { _planManagers }
    public var business: any BusinessRepository { _business }
    public var addresses: any AddressRepository { _addresses }
    public var travelCharges: any TravelChargeRepository { _travelCharges }
    public var travelChargeReviewItems: any TravelChargeReviewRepository { _travelChargeReviewItems }
    public var serviceAgreements: any ServiceAgreementRepository { _serviceAgreements }
    public var supportLogs: any SupportLogRepository { _supportLogs }
    public var bulkClaims: any BulkClaimRepository { _bulkClaims }
    
    // MARK: - Transaction Control
    
    public func saveChanges() async throws {
        if modelContext.hasChanges {
            try modelContext.save()
        }
    }
    
    public func rollback() async {
        modelContext.rollback()
    }
    
    // MARK: - Context Management
    
    public func createChildContext() -> any UnitOfWorkService {
        let childContext = ModelContext(modelContainer)
        childContext.autosaveEnabled = false
        return SwiftDataUnitOfWork(modelContext: childContext, modelContainer: modelContainer)
    }
    
    // MARK: - Maintenance Operations
    
    public func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int]) {
        var deletedCounts: [String: Int] = [:]
        var totalDeleted = 0
        
        // Helper to delete and count
        func deleteAndCount<T: PersistentModel>(_ modelType: T.Type, name: String) throws {
            let descriptor = FetchDescriptor<T>()
            let count = try modelContext.fetchCount(descriptor)
            if count > 0 {
                try modelContext.delete(model: modelType)
                deletedCounts[name] = count
                totalDeleted += count
            }
        }
        
        // Delete in order to respect potential relationships (leaves first)
        try deleteAndCount(InvoiceItemEntity.self, name: "InvoiceItem")
        try deleteAndCount(BulkClaimLineEntity.self, name: "BulkClaimLine")
        try deleteAndCount(BulkClaimBatchEntity.self, name: "BulkClaimBatch")
        try deleteAndCount(InvoiceEntity.self, name: "Invoice")
        try deleteAndCount(ServiceAgreementEntity.self, name: "ServiceAgreement")
        try deleteAndCount(SupportLogEntity.self, name: "SupportLog")
        try deleteAndCount(SessionEntity.self, name: "Session")
        try deleteAndCount(ClientServiceEntity.self, name: "ClientService")
        try deleteAndCount(CreditHistoryEntryEntity.self, name: "CreditHistory")
        try deleteAndCount(ClientEntity.self, name: "Client")
        try deleteAndCount(PayeeEntity.self, name: "Payee")
        try deleteAndCount(PlanManagerEntity.self, name: "PlanManager")
        try deleteAndCount(RegionalPriceEntity.self, name: "RegionalPrice")
        try deleteAndCount(NDISItemEntity.self, name: "NDISItem")
        try deleteAndCount(TravelChargeEntity.self, name: "TravelCharge")
        try deleteAndCount(TravelChargeReviewItemEntity.self, name: "TravelChargeReviewItem")
        try deleteAndCount(BusinessEntity.self, name: "Business")
        try deleteAndCount(AddressEntity.self, name: "Address")
        
        try modelContext.save()
        
        return (totalDeleted: totalDeleted, deletedByEntity: deletedCounts)
    }
}

// MARK: - Convenience Extensions

public extension SwiftDataUnitOfWork {
    /// Internal bridge for Data-layer services that still require ModelContext-backed operations.
    var eventKitModelContext: ModelContext {
        modelContext
    }

    /// Direct access to the underlying ModelContext for legacy code migration.
    /// This should only be used during the refactoring phase and removed afterwards.
    @available(*, deprecated, message: "Use repository methods instead of direct context access")
    var legacyModelContext: ModelContext {
        modelContext
    }
}
