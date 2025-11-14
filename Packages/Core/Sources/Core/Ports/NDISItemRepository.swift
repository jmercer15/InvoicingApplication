import Foundation

/// Protocol for NDIS item data operations
public protocol NDISItemRepository: Sendable {
    /// Fetch all NDIS items
    func fetchAll() async throws -> [NDISItem]
    
    /// Fetch current NDIS items only
    func fetchCurrent() async throws -> [NDISItem]
    
    /// Fetch effective NDIS items (those currently active based on date range)
    func fetchEffective() async throws -> [NDISItem]
    
    /// Fetch a single NDIS item by ID
    func fetch(by id: UUID) async throws -> NDISItem?
    
    /// Fetch NDIS item by item number
    func fetch(by itemNumber: String) async throws -> NDISItem?
    
    /// Search NDIS items by query
    func search(query: String) async throws -> [NDISItem]
    
    /// Fetch NDIS items by category
    func fetch(by category: String) async throws -> [NDISItem]
    
    /// Count total NDIS items
    func count() async throws -> Int
    
    /// Count current NDIS items
    func countCurrent() async throws -> Int
}

