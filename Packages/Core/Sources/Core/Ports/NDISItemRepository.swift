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
    
    // MARK: - Maintenance Operations
    
    /// Recalculates 'isCurrent' flags for all items based on effective dates
    @discardableResult
    func recalculateAllCurrentFlags() async throws -> Int
    
    /// Removes all NDIS items and related data (e.g., regional prices)
    /// Returns a breakdown of deleted counts (items, prices)
    @discardableResult
    func removeAll() async throws -> (deletedItems: Int, deletedPrices: Int)
}

// MARK: - Type Alias for Naming Consistency

/// Type alias for consistent naming convention across repository protocols.
public typealias NDISItemRepositoryProtocol = NDISItemRepository
