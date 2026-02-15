//
//  Repository.swift
//  Core
//
//  Generic Repository Protocol for DAL Standardization
//

import Foundation

// MARK: - Generic Repository Protocol

/// Base protocol for all repositories providing standard CRUD operations.
/// Concrete repositories extend this with domain-specific query methods.
public protocol Repository<T>: Sendable {
    associatedtype T: Sendable
    
    // MARK: - Read Operations
    
    /// Fetch a single entity by its unique identifier.
    func fetch(id: UUID) async throws -> T?
    
    /// Fetch all entities of this type.
    func fetchAll() async throws -> [T]
    
    /// Fetch entities matching optional predicate, sort, and limit.
    func fetch(
        predicate: (@Sendable (T) -> Bool)?,
        sort: (@Sendable (T, T) -> Bool)?,
        limit: Int?
    ) async throws -> [T]
    
    /// Count entities matching optional predicate.
    func count(predicate: (@Sendable (T) -> Bool)?) async throws -> Int
    
    // MARK: - Write Operations
    
    /// Add a new entity and return the persisted instance.
    @discardableResult
    func add(_ item: T) async throws -> T
    
    /// Update an existing entity and return the updated instance.
    @discardableResult
    func update(_ item: T) async throws -> T
    
    /// Delete an entity by its unique identifier.
    func delete(id: UUID) async throws
}

// MARK: - Default Implementations

public extension Repository {
    /// Default fetchAll implementation using fetch with nil parameters.
    func fetchAll() async throws -> [T] {
        try await fetch(predicate: nil, sort: nil, limit: nil)
    }
    
    /// Default count implementation with nil predicate.
    func count() async throws -> Int {
        try await count(predicate: nil)
    }
}

// MARK: - Repository Error

/// Errors that can occur during repository operations.
public enum RepositoryError: Error, Sendable {
    case notFound(id: UUID)
    case duplicateEntry(message: String)
    case persistenceFailure(underlying: Error)
    case validationFailed(message: String)
    case concurrencyConflict
    // Compatibility cases
    case entityNotFound
    case saveFailed
    
    public var localizedDescription: String {
        switch self {
        case .notFound(let id):
            return "Entity with id \(id) not found"
        case .duplicateEntry(let message):
            return "Duplicate entry: \(message)"
        case .persistenceFailure(let underlying):
            return "Persistence failure: \(underlying.localizedDescription)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .concurrencyConflict:
            return "Concurrency conflict detected"
        case .entityNotFound:
            return "Entity not found"
        case .saveFailed:
            return "Failed to save data"
        }
    }
}
