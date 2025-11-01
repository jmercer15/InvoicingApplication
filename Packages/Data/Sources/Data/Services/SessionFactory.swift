import Foundation
import EventKit
import SwiftData // Import SwiftData

/// Centralized factory for creating SessionEntity instances with guaranteed consistent initialization.
/// This eliminates the decentralized and inconsistent creation logic found across the application.
public class SessionFactory {

    // Session status constants
    static let sessionStatusPlanned = "Planned"
    static let sessionStatusCancelled = "Cancelled"
    
    private let context: ModelContext // Change to ModelContext
    
    public init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - Base Creation Method
    
    /// Creates a base SessionEntity with guaranteed default values for all non-optional attributes.
    /// This serves as the foundation for all session creation operations.
    private func createBaseSession() -> SessionEntity {
        let session = SessionEntity(id: UUID())
        context.insert(session) // Explicitly insert new entity
        
        // Core identifiers
        // session.id is already set in the initializer
        
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
        
        // Optional attributes remain nil (Core Data will handle defaults)
        // location, notes, recurrenceRuleData, etc.
        
        print("[SessionFactory] Created base session with id: \(session.id.uuidString)")
        return session
    }
    
    // MARK: - Public Factory Methods
    
    /// Creates a new session for user interface creation
    /// - Parameters:
    ///   - startTime: The start time for the session
    ///   - endTime: The end time for the session
    /// - Returns: A new SessionEntity with basic initialization
    public func createNewSession(startTime: Date, endTime: Date) -> SessionEntity {
        let session = createBaseSession()
        session.startTime = startTime
        session.endTime = endTime
        print("[SessionFactory] Created new session: \(session.id.uuidString)")
        return session
    }
    
    /// Creates a duplicate of an existing session
    /// - Parameter sourceSession: The session to duplicate
    /// - Returns: A new SessionEntity with copied properties
    public func createDuplicate(of sourceSession: SessionEntity) -> SessionEntity {
        let session = createBaseSession()
        
        // Copy core properties
        session.title = sourceSession.title + " (Copy)"
        session.startTime = sourceSession.startTime
        session.endTime = sourceSession.endTime
        session.isAllDay = sourceSession.isAllDay
        session.location = sourceSession.location
        session.notes = sourceSession.notes
        session.isTravel = sourceSession.isTravel
        
        // Copy relationships
        session.client = sourceSession.client
        session.clientService = sourceSession.clientService
        
        // Copy metadata
        session.googleColorId = sourceSession.googleColorId
        
        // Intentionally NOT copied (correct for duplicates):
        // - recurrenceRuleData (duplicates should not inherit recurrence)
        // - eventIdentifier (duplicates are new events)
        // - invoice (duplicates are not invoiced)
        // - isDetached, occurrenceDate (not applicable to duplicates)
        
        print("[SessionFactory] Created duplicate of session: \(sourceSession.id.uuidString)")
        return session
    }
    
    /// Creates a detached instance for recurring event modifications
    /// - Parameters:
    ///   - masterSession: The original recurring session
    ///   - occurrenceDate: The date of the occurrence to modify
    ///   - changes: Closure to apply specific changes to the detached instance
    /// - Returns: A new detached SessionEntity
    public func createDetachedInstance(
        from masterSession: SessionEntity,
        at occurrenceDate: Date,
        withChanges changes: (SessionEntity) -> Void
    ) -> SessionEntity {
        let session = createBaseSession()
        
        // Set detached-specific properties
        session.isDetached = true
        session.occurrenceDate = occurrenceDate
        session.derivedFromEKEventID = masterSession.id.uuidString
        
        // Copy properties from master
        session.title = masterSession.title
        session.startTime = masterSession.startTime
        session.endTime = masterSession.endTime
        session.isAllDay = masterSession.isAllDay
        session.location = masterSession.location
        session.notes = masterSession.notes
        session.status = masterSession.status
        session.isTravel = masterSession.isTravel
        
        // Copy relationships
        session.client = masterSession.client
        session.clientService = masterSession.clientService
        
        // Copy metadata
        session.googleColorId = masterSession.googleColorId
        
        // Explicitly nullify recurrence (detached instances don't recur)
        session.recurrenceRuleData = nil
        session.ekRecurrenceRuleDescription = nil
        
        // Apply specific changes (e.g., new times)
        changes(session)
        
        print("[SessionFactory] Created detached instance for master: \(masterSession.id.uuidString) at date: \(occurrenceDate)")
        return session
    }
    
    /// Creates a cancelled detached instance to represent a deleted occurrence
    /// - Parameters:
    ///   - masterSession: The original recurring session
    ///   - occurrenceDate: The date of the occurrence to delete
    /// - Returns: A new cancelled detached SessionEntity
    public func createCancelledDetachedInstance(
        from masterSession: SessionEntity,
        at occurrenceDate: Date
    ) -> SessionEntity {
        let session = createDetachedInstance(from: masterSession, at: occurrenceDate) { detached in
            // Mark as cancelled to represent deletion
            detached.status = .cancelled
        }
        
        print("[SessionFactory] Created cancelled detached instance for master: \(masterSession.id.uuidString) at date: \(occurrenceDate)")
        return session
    }
    
    /// Creates a travel charge session
    /// - Parameters:
    ///   - client: The client for the travel charge
    ///   - service: The service being charged
    ///   - linkedSession: The main session this travel charge is linked to
    ///   - startTime: Travel start time
    ///   - endTime: Travel end time
    ///   - location: Travel location
    ///   - distance: Travel distance in kilometers
    ///   - duration: Travel duration in minutes
    ///   - chargeType: Type of charge (labour, non-labour, activity-based)
    ///   - travelDirection: Direction of travel (before/after)
    /// - Returns: A new TravelChargeEntity
    public func createTravelSession(
        client: ClientEntity,
        service: ClientServiceEntity?,
        linkedSession: SessionEntity,
        startTime: Date?,
        endTime: Date?,
        location: String?,
        distance: Double,
        duration: Double,
        chargeType: String,
        travelDirection: String,
        notes: String? = nil,
        mmmZoneName: String? = nil,
        vehicleType: String? = nil,
        parkingCost: Double = 0.0,
        tollCost: Double = 0.0,
        participantCount: Int = 1,
        splitCosts: Bool = false
    ) -> TravelChargeEntity {
        let travelCharge = TravelChargeEntity(id: UUID())
        context.insert(travelCharge) // Explicitly insert new entity
        
        // Set core properties
        travelCharge.id = UUID()
        travelCharge.title = "Travel (\(chargeType)) \(travelDirection) session"
        travelCharge.startTime = startTime
        travelCharge.endTime = endTime
        travelCharge.location = location
        travelCharge.notes = notes
        travelCharge.isAllDay = false
        
        // Set travel-specific properties
        travelCharge.travelDistance = distance
        travelCharge.travelDuration = duration
        travelCharge.chargeType = TravelChargeType(rawValue: chargeType) ?? .standard
        travelCharge.travelDirection = TravelChargeDirection(rawValue: travelDirection) ?? .toClient
        travelCharge.mmmZoneName = mmmZoneName
        travelCharge.vehicleType = vehicleType.map { VehicleType(rawValue: $0) ?? .car }
        travelCharge.parkingCost = parkingCost
        travelCharge.tollCost = tollCost
        travelCharge.participantCount = Int16(participantCount)
        travelCharge.splitCosts = splitCosts
        
        // Set relationships
        travelCharge.client = client
        travelCharge.service = service
        travelCharge.linkedSession = linkedSession
        
        print("[SessionFactory] Created travel session for client: \(client.fullName) linked to session: \(linkedSession.id.uuidString)")
        return travelCharge
    }
    
    /// Creates a session from an EKEvent (external calendar import)
    /// - Parameter event: The EKEvent to convert
    /// - Returns: A new SessionEntity with data from the EKEvent
    func createSessionFromEKEvent(_ event: EKEvent) -> SessionEntity {
        let session = createBaseSession()
        
        // Copy core properties from EKEvent
        session.title = event.title ?? "New Session"
        session.startTime = event.startDate
        session.endTime = event.endDate
        session.isAllDay = event.isAllDay
        
        // Normalize location: replace newlines with ', '
        let normalizedLocation = (event.location ?? "").replacingOccurrences(of: "\n", with: ", ")
        session.location = normalizedLocation
        session.notes = event.notes ?? ""
        
        // Set sync properties
        session.eventIdentifier = event.eventIdentifier
        session.calendarIdentifier = event.calendar.calendarIdentifier
        
        // Set derivedFromEKEventID to track the source EKEvent
        if let eventIdentifier = event.eventIdentifier, !eventIdentifier.isEmpty {
            session.derivedFromEKEventID = eventIdentifier
            print("[SessionFactory] Set derivedFromEKEventID to \(eventIdentifier) for session created from EKEvent")
        }
        
        // Handle Google Calendar color
        if let colorId = GoogleCalendarColors.getGoogleEventColorId(event) {
            session.googleColorId = colorId
        }
        
        // Handle recurrence
        if let ekRule = event.recurrenceRules?.first {
            if let data = RecurrenceRuleManager.shared.serialize(ekRule) {
                session.recurrenceRuleData = data
                session.ekRecurrenceRuleDescription = ekRule.description
            }
        }
        
        print("[SessionFactory] Created session from EKEvent: \(event.eventIdentifier ?? "unknown")")
        return session
    }
    
    /// Creates a session for import operations
    /// - Parameters:
    ///   - title: Session title
    ///   - startTime: Start time
    ///   - endTime: End time
    ///   - client: Associated client
    ///   - location: Session location
    ///   - notes: Session notes
    ///   - status: Session status
    /// - Returns: A new SessionEntity for import
    func createSessionForImport(
        title: String,
        startTime: Date,
        endTime: Date,
        client: ClientEntity?,
        location: String?,
        notes: String?,
        status: String?
    ) -> SessionEntity {
        let session = createBaseSession()
        
        // Set basic properties
        session.title = title
        session.isAllDay = false // Assuming default for import
        session.startTime = startTime
        session.endTime = endTime
        session.status = SessionStatus(rawValue: status ?? "") ?? .scheduled
        session.client = client
        session.location = location
        session.notes = notes
        
        print("[SessionFactory] Created session for import: \(title)")
        return session
    }
}

// MARK: - Convenience Extensions

// createTestSession removed - test utility function located in the main application source set 
