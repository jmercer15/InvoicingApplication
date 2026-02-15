//
//  UnitOfWorkService.swift
//  Core
//
//  Unit of Work Protocol for DAL Standardization
//

import Foundation

// MARK: - Unit of Work Service Protocol

/// Aggregates all repositories and provides transaction control.
/// This is the main entry point for data access in ViewModels.
public protocol UnitOfWorkService: Sendable {
    
    // MARK: - Repository Accessors
    
    /// Clients repository for Client entity operations.
    var clients: any ClientsRepository { get }
    
    /// Sessions repository for Session entity operations.
    var sessions: any SessionsRepository { get }
    
    /// Invoices repository for Invoice entity operations.
    var invoices: any InvoicesRepository { get }
    
    /// Client services repository for ClientService entity operations.
    var clientServices: any ClientServicesRepository { get }
    
    /// NDIS items repository for NDISItem entity operations.
    var ndisItems: any NDISItemRepository { get }
    
    /// Payees repository for Payee entity operations.
    var payees: any PayeeRepository { get }
    
    /// Plan managers repository for PlanManager entity operations.
    var planManagers: any PlanManagerRepository { get }
    
    /// Business repository for Business entity operations.
    var business: any BusinessRepository { get }
    
    /// Addresses repository for Address entity operations.
    var addresses: any AddressRepository { get }
    
    /// Travel charges repository for TravelCharge entity operations.
    var travelCharges: any TravelChargeRepository { get }
    
    /// Travel charge review items repository for TravelChargeReviewItem entity operations.
    var travelChargeReviewItems: any TravelChargeReviewRepository { get }

    /// Service agreements repository.
    var serviceAgreements: any ServiceAgreementRepository { get }

    /// Support logs repository.
    var supportLogs: any SupportLogRepository { get }

    /// Bulk claim batches and lines repository.
    var bulkClaims: any BulkClaimRepository { get }
    
    // MARK: - Transaction Control
    
    /// Persist all pending changes to the data store.
    func saveChanges() async throws
    
    /// Discard all pending changes since last save.
    func rollback() async
    
    // MARK: - Context Management
    
    /// Create a child context for isolated operations.
    /// Changes in child context don't affect parent until merged.
    /// Create a child context for isolated operations.
    /// Changes in child context don't affect parent until merged.
    func createChildContext() -> any UnitOfWorkService
    
    // MARK: - Maintenance Operations
    
    /// Wipes all data from the persistent store.
    /// Returns the total count of deleted items.
    @discardableResult
    func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int])
}

// MARK: - Unit of Work Error

/// Errors that can occur during unit of work operations.
public enum UnitOfWorkError: Error, Sendable {
    case saveFailure(underlying: Error)
    case rollbackFailure(underlying: Error)
    case childContextCreationFailed
    case transactionConflict
    
    public var localizedDescription: String {
        switch self {
        case .saveFailure(let underlying):
            return "Failed to save changes: \(underlying.localizedDescription)"
        case .rollbackFailure(let underlying):
            return "Failed to rollback: \(underlying.localizedDescription)"
        case .childContextCreationFailed:
            return "Failed to create child context"
        case .transactionConflict:
            return "Transaction conflict detected"
        }
    }
}
