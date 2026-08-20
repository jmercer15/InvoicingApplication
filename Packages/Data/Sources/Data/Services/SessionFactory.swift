import os
import Core
import PersistenceModels
import Foundation
import SwiftData

/// Centralized factory for creating Session instances with guaranteed consistent initialization.
/// This eliminates the decentralized and inconsistent creation logic found across the application.
public class SessionFactory {

    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Base Creation Method

    /// Creates a base Session with guaranteed default values for all non-optional attributes.
    /// This serves as the foundation for all session creation operations.
    private func createBaseSession() -> Session {
        let session = Session(id: UUID())
        context.insert(session) // Explicitly insert new entity

        // Core attributes with sensible defaults
        session.title = ""
        session.status = .scheduled

        // Boolean flags with explicit defaults
        session.isAllDay = false
        session.isDetached = false
        session.isTravel = false

        // Numeric attributes with explicit defaults
        session.sessionLatitude = 0.0
        session.sessionLongitude = 0.0

        Logger.data.info("[SessionFactory] Created base session with id: \(session.id.uuidString)")
        return session
    }

    /// Creates a detached instance for recurring event modifications
    /// - Parameters:
    ///   - masterSession: The original recurring session
    ///   - occurrenceDate: The date of the occurrence to modify
    ///   - changes: Closure to apply specific changes to the detached instance
    /// - Returns: A new detached Session
    public func createDetachedInstance(
        from masterSnapshot: SessionSnapshot,
        at occurrenceDate: Date,
        withChanges changes: (Session) -> Void
    ) -> Session {
        let session = createBaseSession()

        // Set detached-specific properties
        session.isDetached = true
        session.occurrenceDate = occurrenceDate
        session.derivedFromEKEventID = masterSnapshot.id.uuidString

        // Copy properties from master
        session.title = masterSnapshot.title
        session.startTime = masterSnapshot.startTime
        session.endTime = masterSnapshot.endTime
        session.isAllDay = masterSnapshot.isAllDay
        session.location = masterSnapshot.location
        session.notes = masterSnapshot.notes
        session.status = masterSnapshot.status
        session.isTravel = masterSnapshot.isTravel

        // Copy relationships (via ID resolution)
        let resolver = EntityResolutionService(context: context)
        if let clientId = masterSnapshot.clientId {
            session.client = try? resolver.resolveClient(id: clientId)
        }
        if let serviceId = masterSnapshot.clientServiceId {
            session.clientService = try? resolver.resolveClientService(id: serviceId)
        }

        // Copy metadata
        session.googleColorId = masterSnapshot.googleColorId

        // Explicitly nullify recurrence (detached instances don't recur)
        session.recurrenceRuleData = nil
        session.ekRecurrenceRuleDescription = nil
        session.eventExternalIdentifier = masterSnapshot.eventExternalIdentifier

        // Apply specific changes (e.g., new times)
        changes(session)

        Logger.data.info("[SessionFactory] Created detached instance for master: \(masterSnapshot.id.uuidString) at date: \(occurrenceDate)")
        return session
    }
}
