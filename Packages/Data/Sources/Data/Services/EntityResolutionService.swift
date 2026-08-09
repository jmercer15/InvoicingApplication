import PersistenceModels
import Foundation
import SwiftData

/// Service for resolving domain IDs to Core Data entities.
/// This bridges the gap between the Domain layer (UUIDs) and the Data layer (Entities),
/// allowing services to perform operations that require direct entity manipulation (like setting relationships)
/// without manually constructing FetchDescriptors everywhere.
///
/// This service is designed to be transient and initialized with a specific ModelContext context.
public struct EntityResolutionService {
    private let context: ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    /// Resolves a Session UUID to a Session
    public func resolveSession(id: UUID) throws -> Session? {
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> { $0.id == id })
        return try context.fetch(descriptor).first
    }
    
    /// Resolves a ClientService UUID to a ClientService
    public func resolveClientService(id: UUID) throws -> ClientService? {
        let descriptor = FetchDescriptor<ClientService>(predicate: #Predicate<ClientService> { $0.id == id })
        return try context.fetch(descriptor).first
    }

    /// Resolves a Client UUID to a Client
    public func resolveClient(id: UUID) throws -> Client? {
        let descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.id == id })
        return try context.fetch(descriptor).first
    }
    
    /// Resolves generic Business Entity (usually singleton, but fetches first found)
    public func resolveBusiness() throws -> Business? {
        let descriptor = FetchDescriptor<Business>()
        return try context.fetch(descriptor).first
    }
    
    /// Resolves an entity by its PersistentIdentifier
    public func resolve<T: PersistentModel>(persistentModelID: PersistentIdentifier) -> T? {
        var descriptor = FetchDescriptor<T>(
            predicate: #Predicate<T> { $0.persistentModelID == persistentModelID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
    
    /// Resolves sessions that have an event identifier, within a date range (performed in memory filtering after fetching candidates)
    public func resolveSessionsWithEventIdentifier(start: Date, end: Date) throws -> [Session] {
        let descriptor = FetchDescriptor<Session>(predicate: #Predicate<Session> {
            $0.eventIdentifier != "" || $0.eventExternalIdentifier != nil
        })
        
        let sessions = try context.fetch(descriptor)
        return sessions.filter {
            let sessionStart = $0.startTime ?? Date.distantPast
            let sessionEnd = $0.endTime ?? sessionStart
            return sessionStart < end && sessionEnd > start
        }
    }
    
    /// Resolves an NDIS Item Entity by its item number
    public func resolveNDISItem(byItemNumber itemNumber: String) throws -> NDISItem? {
        let descriptor = FetchDescriptor<NDISItem>(
            predicate: #Predicate<NDISItem> { item in
                item.itemNumber == itemNumber
            }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Resolves all NDIS Item Entities (Entity level access)
    public func resolveAllNDISItems() throws -> [NDISItem] {
        let descriptor = FetchDescriptor<NDISItem>()
        return try context.fetch(descriptor)
    }
    
    /// Resolves NDIS Item Entities by composite key (item number + name)
    public func resolveNDISItems(itemNumber: String, name: String) throws -> [NDISItem] {
        let descriptor = FetchDescriptor<NDISItem>(
            predicate: #Predicate<NDISItem> {
                $0.itemNumber == itemNumber && $0.name == name
            },
            sortBy: [
                SortDescriptor(\.effectiveStartDate, order: .reverse),
                SortDescriptor(\.effectiveEndDate, order: .reverse)
            ]
        )
        return try context.fetch(descriptor)
    }
    
    /// Resolves NDIS Item Entities by item number
    public func resolveNDISItems(itemNumber: String) throws -> [NDISItem] {
        let descriptor = FetchDescriptor<NDISItem>(
            predicate: #Predicate<NDISItem> {
                $0.itemNumber == itemNumber
            },
            sortBy: [
                SortDescriptor(\.name, order: .forward),
                SortDescriptor(\.effectiveStartDate, order: .reverse),
                SortDescriptor(\.effectiveEndDate, order: .reverse)
            ]
        )
        return try context.fetch(descriptor)
    }
}
