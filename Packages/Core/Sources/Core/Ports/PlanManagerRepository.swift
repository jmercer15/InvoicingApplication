import Foundation

/// Protocol for plan manager data operations
public protocol PlanManagerRepository: Sendable {
    /// Fetch all plan managers
    func fetchAll() async throws -> [PlanManager]
    
    /// Fetch a single plan manager by ID
    func fetch(by id: UUID) async throws -> PlanManager?
    
    /// Fetch plan manager by ABN
    func fetch(by abn: String) async throws -> PlanManager?
    
    /// Create a new plan manager
    func create(_ planManager: PlanManager) async throws -> PlanManager
    
    /// Update an existing plan manager
    func update(_ planManager: PlanManager) async throws -> PlanManager
    
    /// Delete a plan manager
    func delete(id: UUID) async throws
    
    /// Search plan managers by query
    func search(query: String) async throws -> [PlanManager]
    
    /// Count total plan managers
    func count() async throws -> Int
}

