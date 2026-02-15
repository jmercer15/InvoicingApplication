import Foundation

/// Use case for updating invoice status
public struct UpdateInvoiceStatus: Sendable {
    private let repository: InvoicesRepository
    
    public init(repository: InvoicesRepository) {
        self.repository = repository
    }
    
    /// Update invoice status
    public func callAsFunction(id: UUID, status: String) async throws -> Invoice {
        try await repository.updateStatus(id: id, status: status)
        guard let invoice = try await repository.fetch(by: id) else {
            throw InvoiceError.invoiceNotFound
        }
        return invoice
    }
    
    /// Update invoice billing status
    public func callAsFunction(id: UUID, billingStatus: BillingStatus) async throws -> Invoice {
        try await repository.updateBillingStatus(id: id, status: billingStatus)
        guard let invoice = try await repository.fetch(by: id) else {
            throw InvoiceError.invoiceNotFound
        }
        return invoice
    }
    
    /// Mark invoice as sent
    public func callAsFunction(markAsSent id: UUID) async throws -> Invoice {
        try await repository.updateBillingStatus(id: id, status: .pending)
        
        // Fetch and return the updated invoice
        guard let invoice = try await repository.fetch(by: id) else {
            throw InvoiceError.invoiceNotFound
        }
        
        return invoice
    }
    
    /// Mark invoice as paid
    public func callAsFunction(markAsPaid id: UUID) async throws -> Invoice {
        try await repository.updateBillingStatus(id: id, status: .received)
        
        // Fetch and return the updated invoice
        guard let invoice = try await repository.fetch(by: id) else {
            throw InvoiceError.invoiceNotFound
        }
        
        return invoice
    }
}
