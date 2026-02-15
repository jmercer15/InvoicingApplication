import Foundation
import SwiftData
import Core

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
    
    /// Resolves a Client UUID to a ClientEntity
    public func resolveClient(id: UUID) throws -> ClientEntity? {
        let descriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }

    /// Resolves a Client UUID to a ClientEntity asynchronously
    @MainActor
    public func resolveClientAsync(id: UUID) async throws -> ClientEntity? {
        let descriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
    
    /// Resolves a Session UUID to a SessionEntity
    public func resolveSession(id: UUID) throws -> SessionEntity? {
        let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
    
    /// Resolves a ClientService UUID to a ClientServiceEntity
    public func resolveClientService(id: UUID) throws -> ClientServiceEntity? {
        let descriptor = FetchDescriptor<ClientServiceEntity>(predicate: #Predicate { $0.id == id })
        return try context.fetch(descriptor).first
    }
    
    /// Resolves generic Business Entity (usually singleton, but fetches first found)
    public func resolveBusiness() throws -> BusinessEntity? {
        let descriptor = FetchDescriptor<BusinessEntity>()
        return try context.fetch(descriptor).first
    }
    
    /// Resolves an entity by its PersistentIdentifier
    public func resolve<T: PersistentModel>(persistentModelID: PersistentIdentifier) -> T? {
        // SwiftData's model(for:) returns any PersistentModel?
        return context.model(for: persistentModelID) as? T
    }
    
    /// Resolves sessions that have an event identifier, within a date range (performed in memory filtering after fetching candidates)
    public func resolveSessionsWithEventIdentifier(start: Date, end: Date) -> [SessionEntity] {
        let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate {
            $0.eventIdentifier != "" || $0.eventExternalIdentifier != nil
        })
        
        let sessions = (try? context.fetch(descriptor)) ?? []
        return sessions.filter {
            let sessionStart = $0.startTime ?? Date.distantPast
            let sessionEnd = $0.endTime ?? sessionStart
            return sessionStart < end && sessionEnd > start
        }
    }
    
    /// Resolves an NDIS Item Entity by its item number
    public func resolveNDISItem(byItemNumber itemNumber: String) throws -> NDISItemEntity? {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: #Predicate<NDISItemEntity> { item in
                item.itemNumber == itemNumber
            }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Resolves all NDIS Item Entities (Entity level access)
    public func resolveAllNDISItems() throws -> [NDISItemEntity] {
        let descriptor = FetchDescriptor<NDISItemEntity>()
        return try context.fetch(descriptor)
    }
    
    /// Resolves NDIS Item Entities by composite key (item number + name)
    public func resolveNDISItems(itemNumber: String, name: String) throws -> [NDISItemEntity] {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: #Predicate {
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
    public func resolveNDISItems(itemNumber: String) throws -> [NDISItemEntity] {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: #Predicate {
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
    
    /// Resolves all current NDIS Item Entities
    public func resolveCurrentNDISItems() throws -> [NDISItemEntity] {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: #Predicate {
                $0.isCurrent == true
            },
            sortBy: [SortDescriptor(\.itemNumber, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Resolves sessions for a client on a specific date (UTC day comparison)
    public func resolveSessions(forClient clientID: UUID, onDate date: Date) -> [SessionEntity] {
        // SwiftData predicates have limitations with complex date math.
        // Fetching all client sessions and filtering in memory is the safest option
        // unless we have specific day fields.
        let descriptor = FetchDescriptor<SessionEntity>(
            predicate: #Predicate {
                $0.client?.id == clientID
            }
        )
        
        let clientSessions = (try? context.fetch(descriptor)) ?? []
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        
        return clientSessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= startOfDay && startTime < endOfDay
        }
    }
    
    /// Resolves Travel Charge Review Items
    public func resolveReviewItems(pendingOnly: Bool = false) throws -> [TravelChargeReviewItemEntity] {
        let descriptor: FetchDescriptor<TravelChargeReviewItemEntity>
        if pendingOnly {
            descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(
                predicate: #Predicate<TravelChargeReviewItemEntity> { $0.status == "pending" },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }
    
    /// Resolves a single Review Item by ID
    public func resolveReviewItem(id: UUID) throws -> TravelChargeReviewItemEntity? {
        let descriptor = FetchDescriptor<TravelChargeReviewItemEntity>(
            predicate: #Predicate<TravelChargeReviewItemEntity> { $0.id == id }
        )
        return try context.fetch(descriptor).first
    }
    
    /// Resolves Travel Charge Audit Logs
    public func resolveAuditLogs() throws -> [TravelChargeAuditLog] {
        let descriptor = FetchDescriptor<TravelChargeAuditLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
