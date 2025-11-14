import Foundation

/// Protocol for invoice data operations
public protocol InvoicesRepository: Sendable {
    /// Fetch all invoices
    func fetchAll() async throws -> [Invoice]
    
    /// Fetch invoices by client ID
    func fetch(byClientId clientId: UUID) async throws -> [Invoice]
    
    /// Fetch invoices by status
    func fetch(by status: String) async throws -> [Invoice]
    
    /// Fetch invoices by billing status
    func fetch(by billingStatus: BillingStatus) async throws -> [Invoice]
    
    /// Fetch a single invoice by ID
    func fetch(by id: UUID) async throws -> Invoice?
    
    /// Fetch invoice by invoice number
    func fetch(by invoiceNumber: String) async throws -> Invoice?
    
    /// Create a new invoice
    func create(_ invoice: Invoice) async throws -> Invoice
    
    /// Update an existing invoice
    func update(_ invoice: Invoice) async throws -> Invoice
    
    /// Delete an invoice
    func delete(id: UUID) async throws
    
    /// Update invoice status
    func updateStatus(id: UUID, status: String) async throws
    
    /// Update invoice billing status
    func updateBillingStatus(id: UUID, status: BillingStatus) async throws
    
    /// Create invoice from sessions
    func createFromSessions(_ sessionIds: [UUID], clientId: UUID) async throws -> Invoice
    
    /// Add invoice item
    func addItem(_ item: InvoiceItem) async throws -> InvoiceItem
    
    /// Update invoice item
    func updateItem(_ item: InvoiceItem) async throws -> InvoiceItem
    
    /// Remove invoice item
    func removeItem(id: UUID) async throws
    
    /// Fetch invoice items for a specific invoice
    func fetchItems(by invoiceId: UUID) async throws -> [InvoiceItem]
    
    /// Search invoices by query
    func search(query: String) async throws -> [Invoice]
    
    /// Fetch invoices with pagination
    func fetch(limit: Int, offset: Int) async throws -> [Invoice]
    
    /// Count total invoices
    func count() async throws -> Int
    
    /// Count invoices by status
    func count(by status: String) async throws -> Int
    
    /// Generate next invoice number
    func generateInvoiceNumber() async throws -> String
}
