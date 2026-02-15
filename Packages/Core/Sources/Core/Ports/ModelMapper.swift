import Foundation

/// A protocol defining the contract for mapping between Domain models (value types)
/// and Persistence entities (SwiftData classes).
public protocol ModelMapper {
    /// The domain model type (typically a struct).
    associatedtype DomainModel
    /// The persistence entity type (typically a SwiftData @Model class).
    associatedtype PersistenceEntity
    
    /// Maps a persistence entity to its corresponding domain model.
    /// - Parameter entity: The SwiftData entity to convert.
    /// - Returns: A domain model representation.
    func mapToDomain(_ entity: PersistenceEntity) -> DomainModel
    
    /// Creates a new persistence entity from a domain model.
    /// - Parameters:
    ///   - domain: The domain model to convert.
    /// - Returns: A new SwiftData entity ready for insertion.
    func mapToEntity(_ domain: DomainModel) -> PersistenceEntity
    
    /// Updates an existing persistence entity with values from a domain model.
    /// - Parameters:
    ///   - entity: The existing SwiftData entity to update.
    ///   - domain: The domain model containing new values.
    func updateEntity(_ entity: inout PersistenceEntity, from domain: DomainModel)
}

/// A type-erased wrapper for ModelMapper to enable heterogeneous collections.
public struct AnyModelMapper<D, E>: ModelMapper {
    public typealias DomainModel = D
    public typealias PersistenceEntity = E
    
    private let _mapToDomain: (E) -> D
    private let _mapToEntity: (D) -> E
    private let _updateEntity: (inout E, D) -> Void
    
    public init<M: ModelMapper>(_ mapper: M) where M.DomainModel == D, M.PersistenceEntity == E {
        _mapToDomain = mapper.mapToDomain
        _mapToEntity = mapper.mapToEntity
        _updateEntity = mapper.updateEntity
    }
    
    public func mapToDomain(_ entity: E) -> D {
        _mapToDomain(entity)
    }
    
    public func mapToEntity(_ domain: D) -> E {
        _mapToEntity(domain)
    }
    
    public func updateEntity(_ entity: inout E, from domain: D) {
        _updateEntity(&entity, domain)
    }
}
