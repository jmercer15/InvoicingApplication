import Foundation
import Core

/// Decorator for adding performance logging to mapping operations
public struct MappingPerformanceDecorator: @unchecked Sendable {
    
    private let logger = MappingPerformanceLogger.shared
    
    // MARK: - Entity to Domain Mapping
    
    /// Execute entity to domain mapping with performance logging
    /// - Parameters:
    ///   - entity: The entity to map
    ///   - domainType: The domain type being mapped to
    ///   - mapping: The mapping closure
    /// - Returns: The mapped domain object
    public func mapEntityToDomain<T, U>(
        entity: T,
        domainType: U.Type,
        mapping: () throws -> U
    ) rethrows -> U {
        let operationId = UUID().uuidString
        let entityType = String(describing: T.self)
        let domainTypeName = String(describing: U.self)
        
        logger.logMappingStart(
            operation: .entityToDomain,
            entityType: entityType,
            domainType: domainTypeName,
            operationId: operationId
        )
        
        do {
            let result = try mapping()
            logger.logMappingCompletion(operationId: operationId, success: true)
            return result
        } catch {
            logger.logMappingCompletion(operationId: operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Execute batch entity to domain mapping with performance logging
    /// - Parameters:
    ///   - entities: The entities to map
    ///   - domainType: The domain type being mapped to
    ///   - mapping: The mapping closure
    /// - Returns: The mapped domain objects
    public func mapEntitiesToDomain<T, U>(
        entities: [T],
        domainType: U.Type,
        mapping: () throws -> [U]
    ) rethrows -> [U] {
        let operationId = UUID().uuidString
        let entityType = String(describing: T.self)
        let domainTypeName = String(describing: U.self)
        
        logger.logBatchMappingStart(
            operation: .batchEntityToDomain,
            entityType: entityType,
            domainType: domainTypeName,
            count: entities.count,
            operationId: operationId
        )
        
        do {
            let results = try mapping()
            logger.logBatchMappingCompletion(
                operationId: operationId,
                success: true,
                processedCount: results.count
            )
            return results
        } catch {
            logger.logBatchMappingCompletion(
                operationId: operationId,
                success: false,
                processedCount: 0,
                error: error
            )
            throw error
        }
    }
    
    // MARK: - Domain to Entity Mapping
    
    /// Execute domain to entity mapping with performance logging
    /// - Parameters:
    ///   - domain: The domain object to map
    ///   - entityType: The entity type being mapped to
    ///   - mapping: The mapping closure
    /// - Returns: The mapped entity
    public func mapDomainToEntity<T, U>(
        domain: T,
        entityType: U.Type,
        mapping: () throws -> U
    ) rethrows -> U {
        let operationId = UUID().uuidString
        let domainTypeName = String(describing: T.self)
        let entityTypeName = String(describing: U.self)
        
        logger.logMappingStart(
            operation: .domainToEntity,
            entityType: entityTypeName,
            domainType: domainTypeName,
            operationId: operationId
        )
        
        do {
            let result = try mapping()
            logger.logMappingCompletion(operationId: operationId, success: true)
            return result
        } catch {
            logger.logMappingCompletion(operationId: operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Execute batch domain to entity mapping with performance logging
    /// - Parameters:
    ///   - domains: The domain objects to map
    ///   - entityType: The entity type being mapped to
    ///   - mapping: The mapping closure
    /// - Returns: The mapped entities
    public func mapDomainsToEntity<T, U>(
        domains: [T],
        entityType: U.Type,
        mapping: () throws -> [U]
    ) rethrows -> [U] {
        let operationId = UUID().uuidString
        let domainTypeName = String(describing: T.self)
        let entityTypeName = String(describing: U.self)
        
        logger.logBatchMappingStart(
            operation: .batchDomainToEntity,
            entityType: entityTypeName,
            domainType: domainTypeName,
            count: domains.count,
            operationId: operationId
        )
        
        do {
            let results = try mapping()
            logger.logBatchMappingCompletion(
                operationId: operationId,
                success: true,
                processedCount: results.count
            )
            return results
        } catch {
            logger.logBatchMappingCompletion(
                operationId: operationId,
                success: false,
                processedCount: 0,
                error: error
            )
            throw error
        }
    }
    
    // MARK: - Round Trip Mapping
    
    /// Execute round trip mapping (entity -> domain -> entity) with performance logging
    /// - Parameters:
    ///   - entity: The original entity
    ///   - domainType: The domain type
    ///   - entityType: The entity type
    ///   - mapping: The round trip mapping closure
    /// - Returns: The final entity
    public func mapRoundTrip<T, U, V>(
        entity: T,
        domainType: U.Type,
        entityType: V.Type,
        mapping: () throws -> V
    ) rethrows -> V {
        let operationId = UUID().uuidString
        let originalEntityType = String(describing: T.self)
        let domainTypeName = String(describing: U.self)
        let finalEntityType = String(describing: V.self)
        
        logger.logMappingStart(
            operation: .roundTrip,
            entityType: "\(originalEntityType) -> \(domainTypeName) -> \(finalEntityType)",
            domainType: "Round Trip",
            operationId: operationId
        )
        
        do {
            let result = try mapping()
            logger.logMappingCompletion(operationId: operationId, success: true)
            return result
        } catch {
            logger.logMappingCompletion(operationId: operationId, success: false, error: error)
            throw error
        }
    }
    
    // MARK: - Error Logging
    
    /// Log a mapping error with context
    /// - Parameters:
    ///   - operation: The mapping operation
    ///   - entityType: The entity type
    ///   - domainType: The domain type
    ///   - error: The error that occurred
    ///   - context: Additional context
    public func logError(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        error: Error,
        context: String? = nil
    ) {
        logger.logMappingError(
            operation: operation,
            entityType: entityType,
            domainType: domainType,
            error: error,
            context: context
        )
    }
    
    /// Log a data integrity issue
    /// - Parameters:
    ///   - issue: The type of integrity issue
    ///   - entityType: The entity type
    ///   - entityId: The entity ID
    ///   - details: Additional details
    public func logDataIntegrityIssue(
        issue: DataIntegrityIssue,
        entityType: String,
        entityId: String,
        details: String? = nil
    ) {
        logger.logDataIntegrityIssue(
            issue: issue,
            entityType: entityType,
            entityId: entityId,
            details: details
        )
    }
}

// MARK: - Global Instance

/// Global instance of the mapping performance decorator
public let mappingPerformance = MappingPerformanceDecorator()

// MARK: - Convenience Extensions

extension MappingPerformanceDecorator {
    
    /// Execute a mapping operation with automatic error handling and logging
    /// - Parameters:
    ///   - operation: The mapping operation
    ///   - entityType: The entity type
    ///   - domainType: The domain type
    ///   - mapping: The mapping closure
    /// - Returns: The result of the mapping operation
    public func executeWithLogging<T>(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        mapping: () throws -> T
    ) rethrows -> T {
        let operationId = UUID().uuidString
        
        logger.logMappingStart(
            operation: operation,
            entityType: entityType,
            domainType: domainType,
            operationId: operationId
        )
        
        do {
            let result = try mapping()
            logger.logMappingCompletion(operationId: operationId, success: true)
            return result
        } catch {
            logger.logMappingCompletion(operationId: operationId, success: false, error: error)
            throw error
        }
    }
    
    /// Execute a batch mapping operation with automatic error handling and logging
    /// - Parameters:
    ///   - operation: The mapping operation
    ///   - entityType: The entity type
    ///   - domainType: The domain type
    ///   - count: The number of items to process
    ///   - mapping: The mapping closure
    /// - Returns: The result of the mapping operation
    public func executeBatchWithLogging<T>(
        operation: MappingOperation,
        entityType: String,
        domainType: String,
        count: Int,
        mapping: () throws -> T
    ) rethrows -> T {
        let operationId = UUID().uuidString
        
        logger.logBatchMappingStart(
            operation: operation,
            entityType: entityType,
            domainType: domainType,
            count: count,
            operationId: operationId
        )
        
        do {
            let result = try mapping()
            logger.logBatchMappingCompletion(
                operationId: operationId,
                success: true,
                processedCount: count
            )
            return result
        } catch {
            logger.logBatchMappingCompletion(
                operationId: operationId,
                success: false,
                processedCount: 0,
                error: error
            )
            throw error
        }
    }
}
