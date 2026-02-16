import Foundation
import SwiftData // Use SwiftData
@preconcurrency import MapKit
@preconcurrency import Dispatch
import Core

struct ClientDayKey: Hashable {
    let clientId: UUID
    let day: Date
}

/// Result of compliance checking with detailed violations
struct ComplianceResult {
    let isCompliant: Bool
    let violations: [Core.ComplianceViolation]
    let warnings: [Core.ComplianceViolation]
    
    var hasErrors: Bool {
        violations.contains { $0.severity == .error || $0.severity == .critical }
    }
    
    var hasWarnings: Bool {
        warnings.contains { $0.severity == .warning }
    }
}

// Compliance models have been moved to Core package to be shared with features.
// Use Core.ComplianceViolation and Core.DetailedReviewItem.

/// Service for automated creation of travel charge sessions based on session data, business rules, and user preferences.
public final class TravelChargeAutomationService: @unchecked Sendable {
    let context: ModelContext // Change to ModelContext
    let businessRules: BusinessRules // Business rule configuration
    let userPreferences: UserPreferences // User preferences
    let mmmZoneTable: MMMZoneTable // MMM zone lookup
    var testingMode: Bool = false
    // For testing mode: store results instead of saving
    private(set) var testTravelChargeSummaries: [String] = []
    private(set) var testReviewSummaries: [String] = []
    private(set) var testDetailedReviewItems: [DetailedReviewItem] = []
    
    private var unitOfWork: UnitOfWorkService?
    
    public init(context: ModelContext, businessRules: BusinessRules, userPreferences: UserPreferences, mmmZoneTable: MMMZoneTable, testingMode: Bool = false) {
        self.context = context
        self.businessRules = businessRules
        self.userPreferences = userPreferences
        self.mmmZoneTable = mmmZoneTable
        self.testingMode = testingMode
        self.unitOfWork = nil
    }
    
    public init(unitOfWork: UnitOfWorkService, context: ModelContext, businessRules: BusinessRules, userPreferences: UserPreferences, mmmZoneTable: MMMZoneTable, testingMode: Bool = false) {
        self.unitOfWork = unitOfWork
        self.context = context
        self.businessRules = businessRules
        self.userPreferences = userPreferences
        self.mmmZoneTable = mmmZoneTable
        self.testingMode = testingMode
    }
    
    /// Preferred initializer using UnitOfWorkService only.
    /// Extracts ModelContext internally for legacy code paths.
    /// Must be called on MainActor since SwiftDataUnitOfWork is MainActor-isolated.
    @MainActor
    public init(unitOfWork: UnitOfWorkService, businessRules: BusinessRules, userPreferences: UserPreferences, mmmZoneTable: MMMZoneTable, testingMode: Bool = false) {
        self.unitOfWork = unitOfWork
        // Extract context from UoW for legacy code paths
        if let swiftDataUoW = unitOfWork as? SwiftDataUnitOfWork {
            self.context = swiftDataUoW.legacyModelContext
        } else {
            fatalError("TravelChargeAutomationService requires SwiftDataUnitOfWork")
        }
        self.businessRules = businessRules
        self.userPreferences = userPreferences
        self.mmmZoneTable = mmmZoneTable
        self.testingMode = testingMode
    }
    
    // MARK: - Domain Model Methods (Preferred)
    
    /// Automate travel charges using domain models (preferred over entity-based method)
    /// This method accepts Session domain models and fetches entities internally
    public func automateTravelCharges(for sessions: [Session], dateRange: ClosedRange<Date>? = nil, completion: @escaping () -> Void = {}) throws {
        // Fetch SessionEntity instances from database for the given session IDs
        let sessionEntities = try fetchSessionEntities(for: sessions.map { $0.id })
        
        guard sessionEntities.count == sessions.count else {
            throw TravelChargeError.invalidSession
        }
        
        // Call the entity-based method
        automateTravelCharges(for: sessionEntities, dateRange: dateRange, completion: completion)
    }
    
    /// Fetch SessionEntity instances by IDs (internal helper)
    private func fetchSessionEntities(for sessionIds: [UUID]) throws -> [SessionEntity] {
        let resolver = EntityResolutionService(context: context)
        var entities: [SessionEntity] = []
        for sessionId in sessionIds {
            guard let entity = try resolver.resolveSession(id: sessionId) else {
                continue // Skip missing sessions rather than failing
            }
            entities.append(entity)
        }
        return entities
    }
    
    // MARK: - Entity-Based Methods (Legacy)
    
    /// Main entry point: Automate travel charges for a batch of sessions (legacy - use domain model version)
    /// This method is kept for backward compatibility but prefer `automateTravelCharges(for:dateRange:completion:)` with domain models
    public func automateTravelCharges(for sessions: [SessionEntity], dateRange: ClosedRange<Date>? = nil, completion: @escaping () -> Void = {}) {
        print("DEBUG: Starting travel charge automation for \(sessions.count) sessions")
        
        // Capture completion in local variable for use in nested closures
        let _ = completion
        
        // Use DispatchGroup to track when all async operations are complete
        let group = DispatchGroup()
        
        // Convert sessions to instances (handles recurring sessions)
        let sessionInstances = expandSessionsToInstances(sessions, dateRange: dateRange)
        print("DEBUG: Expanded to \(sessionInstances.count) session instances")
        
        // Fetch the business address (singleton)
        // Fetch the business address (singleton)
        let resolver = EntityResolutionService(context: context)
        let business: BusinessEntity? = try? resolver.resolveBusiness()
        let businessAddress: String? = business?.address?.fullFormattedAddress ?? business?.address?.fullAddressText
        
        
        
        let sessionsByClientDay = groupSessionsByClientAndDay(sessionInstances)
        
        for (key, daySessions) in sessionsByClientDay {
            let _ = key.clientId
            let _ = key.day
            let sortedSessions = sortSessionsChronologically(daySessions)
            
            // Chain sessions for this date group
            for (i, sessionInstance) in sortedSessions.enumerated() {
                let session = sessionInstance.session
                guard isEligibleForTravelCharge(session) else {
                    continue
                }
                if i == 0 {
                    // First session: use business address as 'from' location
                    let fromLocation = businessAddress
                    let _ = session.location
                    let fromTime: Date? = nil
                    let toTime = sessionInstance.instanceStart
                    
                    // Debug: Log session location information
                    print("DEBUG: Session location check for '\(session.title)':")
                    print("  - session.location: '\(session.location ?? "nil")'")
                    print("  - session.address exists: \(session.address != nil)")
                    if let address = session.address {
                        print("  - session.address.fullFormattedAddress: '\(address.fullFormattedAddress)'")
                        print("  - session.address.fullAddressText: '\(address.fullAddressText)'")
                    }
                    print("  - businessAddress: '\(businessAddress ?? "nil")'")
                    // Get the session's location (check both string and address entity)
                    let sessionLocation: String? = {
                        if let loc = session.location, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            return loc
                        } else if let address = session.address {
                            return address.fullFormattedAddress
                        }
                        return nil
                    }()
                    
                    if let fromLoc = fromLocation, !fromLoc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let toLoc = sessionLocation {
                        group.enter()
                        geocodeAddress(fromLoc) { fromCoord in
                            guard let fromCoord = fromCoord else {
                                self.queueForUserReview(session: session, reason: "Geocoding failed for business address (fromLocation)")
                                group.leave()
                                return
                            }
                            self.geocodeAddress(toLoc) { toCoord in
                                guard let toCoord = toCoord else {
                                    self.queueForUserReview(session: session, reason: "Geocoding failed for toLocation")
                                    group.leave()
                                    return
                                }
                                self.calculateDrivingDistance(from: fromCoord, to: toCoord) { distance in
                                    guard let distance = distance else {
                                        self.queueForUserReview(session: session, reason: "Distance calculation failed")
                                        group.leave()
                                        return
                                    }
                                    let travelTime = self.estimateTravelTime(distance: distance) ?? self.businessRules.defaultTravelTime
                                    let mmmZone = self.lookupMMMZone(for: session) ?? self.businessRules.defaultMMMZone
                                    let chargeTypes = self.determineChargeTypes(session: session)
                                    var processedAnyChargeType = false
                                    var groupLeft = false
                                    for chargeType in chargeTypes {
                                        if self.travelChargeExists(client: session.client!, session: session, direction: .before, chargeType: chargeType, daySessions: sortedSessions) {
                                            continue
                                        }
                                        let complianceResult = self.isCompliantWithRules(travelTime: travelTime, mmmZone: mmmZone, businessRules: self.businessRules, chargeType: chargeType, distance: distance, daySessions: sortedSessions, session: session)
                                        if !complianceResult.isCompliant {
                                            let suggestedActions = ["Override and Create Charge", "Skip This Charge", "Review Session Location"]
                                            let overrideOptions = ["MMM Zone Override", "Distance Override", "Time Override"]
                                            
                                            self.queueForUserReview(
                                                session: session,
                                                reason: "Non-compliant travel charge",
                                                violations: complianceResult.violations,
                                                suggestedActions: suggestedActions,
                                                overrideOptions: overrideOptions
                                            )
                                            print("DEBUG: Leaving dispatch group (non-compliant)")
                                            group.leave()
                                            groupLeft = true
                                            continue
                                        }
                                        processedAnyChargeType = true
                                        let service = self.findTravelService(client: session.client, session: session, chargeType: chargeType)
                                        self.detectSharedTravelParticipants(session: session, daySessions: sortedSessions, direction: .before) { sharedParticipants in
                                            let participantCount = self.determineParticipantCount(session: session, sharedParticipants: sharedParticipants)
                                            let splitCosts = participantCount > 1
                                            let vehicleType = self.determineVehicleType(session: session, chargeType: chargeType)
                                            let parking: Double? = nil // Manual entry only
                                            let tolls: Double? = nil // Manual entry only
                                            let travelCharge = self.buildTravelChargeEntity(
                                                client: session.client!,
                                                session: session,
                                                service: service,
                                                direction: .before,
                                                startTime: fromTime,
                                                endTime: toTime,
                                                location: toLoc,
                                                mmmZone: mmmZone,
                                                distance: distance,
                                                travelTime: travelTime,
                                                vehicleType: vehicleType,
                                                parking: parking,
                                                tolls: tolls,
                                                participantCount: participantCount,
                                                chargeType: chargeType,
                                                splitCosts: splitCosts
                                            )
                                            self.saveTravelCharge(travelCharge)
                                            self.logAllCreatedTravelCharges()
                                            print("DEBUG: Leaving dispatch group (success)")
                                            group.leave()
                                        }
                                    }
                                    // If no charge types were processed and we haven't left the group yet, still need to leave the group
                                    if !processedAnyChargeType && !groupLeft {
                                        print("DEBUG: Leaving dispatch group (no charge types processed)")
                                        group.leave()
                                    } else if processedAnyChargeType {
                                        print("DEBUG: Charge types were processed, group.leave() already called")
                                    } else if groupLeft {
                                        print("DEBUG: Group already left due to non-compliance")
                                    }
                                }
                            }
                        }
                    } else {
                        let businessAddressDebug = businessAddress ?? "nil"
                        let sessionLocationDebug = sessionLocation ?? "nil"
                        
                        // Determine the specific issue
                        let reason: String
                        if sessionLocationDebug == "nil" {
                            reason = "Session has no location set. Session: '\(session.title)', Business address: '\(businessAddressDebug)'. Please set a location for this session."
                        } else if businessAddressDebug == "nil" {
                            reason = "Business address is not set. Please configure the business address in Settings → Company Details."
                        } else {
                            reason = "Missing business address for first session of the day. Business address: '\(businessAddressDebug)', Session location: '\(sessionLocationDebug)'"
                        }
                        
                        self.queueForUserReview(session: session, reason: reason)
                        group.leave()
                    }
                    continue
                }
                let prevSessionInstance = sortedSessions[i - 1]
                let prevSession = prevSessionInstance.session
                
                // Get locations (check both string and address entity for both sessions)
                let fromLocation: String? = {
                    if let loc = prevSession.location, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return loc
                    } else if let address = prevSession.address {
                        return address.fullFormattedAddress
                    }
                    return nil
                }()
                
                let toLocation: String? = {
                    if let loc = session.location, !loc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        return loc
                    } else if let address = session.address {
                        return address.fullFormattedAddress
                    }
                    return nil
                }()
                
                let fromTime = prevSessionInstance.instanceEnd
                let toTime = sessionInstance.instanceStart
                
                guard let fromLoc = fromLocation, let toLoc = toLocation else {
                    let fromDebug = fromLocation ?? "nil"
                    let toDebug = toLocation ?? "nil"
                    self.queueForUserReview(session: session, reason: "Missing from/to location. From: '\(fromDebug)', To: '\(toDebug)'")
                    group.leave()
                    continue
                }
                // Geocode both addresses (async)
                group.enter()
                geocodeAddress(fromLoc) { fromCoord in
                    guard let fromCoord = fromCoord else {
                        self.queueForUserReview(session: session, reason: "Geocoding failed for fromLocation")
                        group.leave()
                        return
                    }
                    self.geocodeAddress(toLoc) { toCoord in
                        guard let toCoord = toCoord else {
                            self.queueForUserReview(session: session, reason: "Geocoding failed for toLocation")
                            group.leave()
                            return
                        }
                        // Calculate driving distance (async)
                        self.calculateDrivingDistance(from: fromCoord, to: toCoord) { distance in
                            guard let distance = distance else {
                                self.queueForUserReview(session: session, reason: "Distance calculation failed")
                                group.leave()
                                return
                            }
                            // Estimate travel time
                            let travelTime = self.estimateTravelTime(distance: distance) ?? self.businessRules.defaultTravelTime
                            // Lookup MMM zone
                            let mmmZone = self.lookupMMMZone(for: session) ?? self.businessRules.defaultMMMZone
                            // Determine charge types
                            let chargeTypes = self.determineChargeTypes(session: session)
                            var processedAnyChargeType = false
                            var groupLeft = false
                            for chargeType in chargeTypes {
                                // Check for duplicate
                                if self.travelChargeExists(client: session.client!, session: session, direction: .before, chargeType: chargeType, daySessions: sortedSessions) {
                                    continue
                                }
                                // Compliance check
                                let complianceResult = self.isCompliantWithRules(travelTime: travelTime, mmmZone: mmmZone, businessRules: self.businessRules, chargeType: chargeType, distance: distance, daySessions: sortedSessions, session: session)
                                if !complianceResult.isCompliant {
                                    let suggestedActions = ["Override and Create Charge", "Skip This Charge", "Review Session Location"]
                                    let overrideOptions = ["MMM Zone Override", "Distance Override", "Time Override"]
                                    
                                    self.queueForUserReview(
                                        session: session,
                                        reason: "Non-compliant travel charge",
                                        violations: complianceResult.violations,
                                        suggestedActions: suggestedActions,
                                        overrideOptions: overrideOptions
                                    )
                                    group.leave()
                                    groupLeft = true
                                    continue
                                }
                                processedAnyChargeType = true
                                // Find service
                                let service = self.findTravelService(client: session.client, session: session, chargeType: chargeType)
                                // Shared travel detection and participant count
                                self.detectSharedTravelParticipants(session: session, daySessions: sortedSessions, direction: .before) { sharedParticipants in
                                    let participantCount = self.determineParticipantCount(session: session, sharedParticipants: sharedParticipants)
                                    let splitCosts = participantCount > 1
                                    // Vehicle, parking, tolls
                                    let vehicleType = self.determineVehicleType(session: session, chargeType: chargeType)
                                    let parking: Double? = nil // Manual entry only
                                    let tolls: Double? = nil // Manual entry only
                                    let travelCharge = self.buildTravelChargeEntity(
                                        client: session.client!,
                                        session: session,
                                        service: service,
                                        direction: .before,
                                        startTime: fromTime,
                                        endTime: toTime,
                                        location: toLoc,
                                        mmmZone: mmmZone,
                                        distance: distance,
                                        travelTime: travelTime,
                                        vehicleType: vehicleType,
                                        parking: parking,
                                        tolls: tolls,
                                        participantCount: participantCount,
                                        chargeType: chargeType,
                                        splitCosts: splitCosts
                                    )
                                    self.saveTravelCharge(travelCharge)
                                    self.logAllCreatedTravelCharges()
                                    group.leave()
                                }
                            }
                            // If no charge types were processed and we haven't left the group yet, still need to leave the group
                            if !processedAnyChargeType && !groupLeft {
                                print("DEBUG: Leaving dispatch group (no charge types processed)")
                                group.leave()
                            } else if processedAnyChargeType {
                                print("DEBUG: Charge types were processed, group.leave() already called")
                            } else if groupLeft {
                                print("DEBUG: Group already left due to non-compliance")
                            }
                        }
                    }
                }
            }
        }
        
        // Call completion when all async operations are done
        group.notify(queue: DispatchQueue.main) {
            completion()
        }
    }
    
    
    
    /// Stores created travel charges in the current batch for audit logging
    private var createdTravelCharges: [TravelChargeEntity] = []
    
    /// Saves a travel charge entity to Core Data and tracks it for audit logging.
    private func saveTravelCharge(_ travelCharge: TravelChargeEntity) {
        if testingMode {
            let clientName = travelCharge.client?.fullName ?? "Unknown Client"
            let sessionTitle = travelCharge.linkedSession?.title ?? "Unknown Session"
            let type = travelCharge.chargeType?.rawValue ?? "Unknown Type"
            let dist = String(format: "%.1f", travelCharge.travelDistance ?? 0.0)
            let dir = travelCharge.travelDirection?.rawValue ?? "?"
            let notes = travelCharge.notes ?? ""
            
            // Create detailed summary with all attributes
            var details: [String] = []
            details.append("Client: \(clientName)")
            details.append("Linked Session: \(sessionTitle)")
            details.append("Charge Type: \(type)")
            details.append("Travel Direction: \(dir)")
            details.append("Distance: \(dist) km")
            
            if let duration = travelCharge.travelDuration {
                details.append("Duration: \(String(format: "%.1f", duration)) min")
            }

            if let amount = travelCharge.calculatedAmount {
                details.append("Amount/Participant: \(amount.formatted(.currency(code: "AUD")))")
            }
            
            if let mmmZone = travelCharge.mmmZoneName {
                details.append("MMM Zone: \(mmmZone)")
            }
            
            if let vehicleType = travelCharge.vehicleType {
                details.append("Vehicle Type: \(vehicleType)")
            }
            
            if let parkingCost = travelCharge.parkingCost, parkingCost > 0 {
                details.append("Parking Cost: $\(String(format: "%.2f", parkingCost))")
            }
            
            if let tollCost = travelCharge.tollCost, tollCost > 0 {
                details.append("Toll Cost: $\(String(format: "%.2f", tollCost))")
            }
            
            if let participantCount = travelCharge.participantCount, participantCount > 1 {
                details.append("Participant Count: \(participantCount)")
            }
            
            if let splitCosts = travelCharge.splitCosts, splitCosts {
                details.append("Split Costs: Yes")
            }
            
            if let startTime = travelCharge.startTime {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                details.append("Start Time: \(formatter.string(from: startTime))")
            }
            
            if let endTime = travelCharge.endTime {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                details.append("End Time: \(formatter.string(from: endTime))")
            }
            
            if let location = travelCharge.location {
                details.append("Location: \(location)")
            }
            
            if let service = travelCharge.service {
                details.append("Service: \(service.serviceName)")
                if let ndisItem = service.ndisItem {
                    details.append("NDIS Item: \(ndisItem.name) (\(ndisItem.itemNumber))")
                }
            }
            
            if !notes.isEmpty {
                details.append("Notes: \(notes)")
            }
            
            let summary = details.joined(separator: "\n")
            testTravelChargeSummaries.append(summary)
            return
        }
        
        createdTravelCharges.append(travelCharge)
    }
    
    // MARK: - Helper Methods (Stubs)
    
    // MARK: - Session Instance Type
    
    /// Extended session instance that includes the session entity
    public struct SessionInstance: @unchecked Sendable {
        public let session: SessionEntity
        public let instanceStart: Date
        public let instanceEnd: Date
        
        public init(session: SessionEntity, instanceStart: Date, instanceEnd: Date) {
            self.session = session
            self.instanceStart = instanceStart
            self.instanceEnd = instanceEnd
        }
        
        public var uniqueInstanceId: String {
            "\(session.id.uuidString)-\(instanceStart.timeIntervalSince1970)"
        }
    }
    
    /// Expands sessions into instances (handles recurring sessions)
    private func expandSessionsToInstances(_ sessions: [SessionEntity], dateRange: ClosedRange<Date>? = nil) -> [SessionInstance] {
        var instances: [SessionInstance] = []
        let calendar = Calendar.current
        
        // Use provided date range or default to today
        let (rangeStart, rangeEnd): (Date, Date)
        if let dateRange = dateRange {
            rangeStart = dateRange.lowerBound
            rangeEnd = dateRange.upperBound
        } else {
            let today = Date()
            let startOfDay = calendar.startOfDay(for: today)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            rangeStart = startOfDay
            rangeEnd = endOfDay
        }
        
        for session in sessions {
            if session.recurrenceRuleData == nil {
                // Non-recurring session
                if let startTime = session.startTime {
                    instances.append(SessionInstance(session: session, instanceStart: startTime, instanceEnd: session.endTime ?? startTime))
                }
            } else {
                // Recurring session - expand it
                if let ruleData = session.recurrenceRuleData,
                   let rule = RecurrenceRuleManager.shared.deserialize(ruleData),
                   let sessionStartTime = session.startTime,
                   let sessionEndTime = session.endTime {
                    
                    let expanded = RecurrenceExpansion.expandInstances(
                        for: session,
                        rule: rule,
                        masterStartTime: sessionStartTime,
                        masterEndTime: sessionEndTime,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd
                    )
                    
                    for instance in expanded {
                        instances.append(SessionInstance(session: session, instanceStart: instance.instanceStart, instanceEnd: instance.instanceEnd))
                    }
                }
            }
        }
        
        return instances
    }
    
    /// Groups sessions by (client, calendar day)
    private func groupSessionsByClientAndDay(_ sessions: [SessionInstance]) -> [ClientDayKey: [SessionInstance]] {
        var result: [ClientDayKey: [SessionInstance]] = [:]
        let calendar = Calendar.current
        for sessionInstance in sessions {
            guard let client = sessionInstance.session.client else { continue }
            let day = calendar.startOfDay(for: sessionInstance.instanceStart)
            let key = ClientDayKey(clientId: client.id, day: day)
            result[key, default: []].append(sessionInstance)
        }
        return result
    }
    
    /// Sorts sessions chronologically by startTime (ascending)
    private func sortSessionsChronologically(_ sessions: [SessionInstance]) -> [SessionInstance] {
        return sessions.sorted { $0.instanceStart < $1.instanceStart }
    }
    
    /// Checks if a session is eligible for travel charge automation
    private func isEligibleForTravelCharge(_ session: SessionEntity) -> Bool {
        // Exclude travel sessions
        if session.isTravel { return false }
        // Exclude sessions without client or service
        if session.client == nil || session.clientService == nil { return false }
        // Exclude sessions with missing or invalid start time
        if session.startTime == nil { return false }
        // Exclude sessions with non-billable status (case-insensitive, trimmed)
        if let status = session.status?.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           businessRules.nonBillableStatuses.contains(status) {
            return false
        }
        
        // Check if the primary support is eligible for travel claims according to NDIS rules
        guard isPrimarySupportEligibleForTravel(session) else {
            print("DEBUG: Primary support is not eligible for travel claims")
            return false
        }
        
        return true
    }
    
    /// Checks if the primary support is eligible for travel claims according to NDIS rules.
    private func isPrimarySupportEligibleForTravel(_ session: SessionEntity) -> Bool {
        print("DEBUG: Checking eligibility for session: '\(session.title)'")
        print("DEBUG: Session has clientService: \(session.clientService != nil)")
        
        guard let clientService = session.clientService else {
            print("DEBUG: Session has no clientService")
            return false
        }
        
        print("DEBUG: ClientService found: '\(clientService.serviceName)'")
        print("DEBUG: ClientService has ndisItem: \(clientService.ndisItem != nil)")
        
        guard let ndisItem = clientService.ndisItem else {
            print("DEBUG: ClientService has no ndisItem")
            print("DEBUG: ClientService details:")
            print("  - serviceName: '\(clientService.serviceName)'")
            print("  - ndisItem: \(clientService.ndisItem?.name ?? "nil")")
            return false
        }
        
        print("DEBUG: NDIS Item found: '\(ndisItem.name)' (itemNumber: \(ndisItem.itemNumber))")
        
        // Check if the NDIS item is eligible for travel claims using the providerTravel property
        let isEligible = ndisItem.providerTravel == true
        
        if isEligible {
            print("DEBUG: Primary support is eligible for travel claims: \(ndisItem.name) (providerTravel: true)")
        } else {
            print("DEBUG: Primary support is not eligible for travel claims: \(ndisItem.name) (providerTravel: \(ndisItem.providerTravel?.description ?? "nil"))")
        }
        
        return isEligible
    }
    
    /// Determines which travel directions (before/after) are needed for a session, based on its position and location differences.
    private func determineTravelDirections(i: Int, daySessions: [SessionInstance]) -> [TravelDirection] {
        var directions: [TravelDirection] = []
        let sessionInstance = daySessions[i]
        let session = sessionInstance.session
        // Helper to normalize locations for comparison
        func normalizedLocation(_ session: SessionEntity?) -> String? {
            guard let loc = session?.location else { return nil }
            return loc.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        // First non-travel session of the day: always consider 'before'
        if isFirstNonTravelSession(i: i, daySessions: daySessions) {
            directions.append(.before)
        }
        // Last non-travel session of the day: always consider 'after'
        if isLastNonTravelSession(i: i, daySessions: daySessions) {
            directions.append(.after)
        }
        // Middle sessions: check if location differs from previous/next non-travel session
        if i > 0 {
            let prev = previousNonTravelSession(i: i, daySessions: daySessions)
            if let prev = prev, normalizedLocation(prev.session) != normalizedLocation(session) {
                directions.append(.before)
            }
        }
        if i < daySessions.count - 1 {
            let next = nextNonTravelSession(i: i, daySessions: daySessions)
            if let next = next, normalizedLocation(next.session) != normalizedLocation(session) {
                directions.append(.after)
            }
        }
        return Array(Set(directions))
    }
    
    /// Returns true if this is the first non-travel session of the day
    private func isFirstNonTravelSession(i: Int, daySessions: [SessionInstance]) -> Bool {
        for j in 0..<i {
            if !daySessions[j].session.isTravel { return false }
        }
        return true
    }
    
    /// Returns true if this is the last non-travel session of the day
    private func isLastNonTravelSession(i: Int, daySessions: [SessionInstance]) -> Bool {
        for j in (i+1)..<daySessions.count {
            if !daySessions[j].session.isTravel { return false }
        }
        return true
    }
    
    /// Finds the previous non-travel session before index i
    private func previousNonTravelSession(i: Int, daySessions: [SessionInstance]) -> SessionInstance? {
        for j in stride(from: i-1, through: 0, by: -1) {
            if !daySessions[j].session.isTravel { return daySessions[j] }
        }
        return nil
    }
    
    /// Finds the next non-travel session after index i
    private func nextNonTravelSession(i: Int, daySessions: [SessionInstance]) -> SessionInstance? {
        for j in (i+1)..<daySessions.count {
            if !daySessions[j].session.isTravel { return daySessions[j] }
        }
        return nil
    }
    
    /// Geocodes an address string to CLLocationCoordinate2D using MapKit with retry logic. Returns nil if geocoding fails.
    private func geocodeAddress(_ address: String?, completion: @escaping @Sendable (CLLocationCoordinate2D?) -> Void) {
        geocodeAddressWithRetry(address, retries: 2, completion: completion)
    }
    
    /// Geocodes an address with retry logic and exponential backoff.
    private func geocodeAddressWithRetry(_ address: String?, retries: Int, completion: @escaping @Sendable (CLLocationCoordinate2D?) -> Void) {
        guard let address = address, !address.isEmpty else {
            completion(nil)
            return
        }
        
        // Use the new MapKit geocoding API
        Task {
            do {
                guard let request = MKGeocodingRequest(addressString: address) else {
                    if retries > 0 {
                        // Retry with exponential backoff
                        let delay = Double(3 - retries) * 1.5 // 1.5s, 3s delays
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.geocodeAddressWithRetry(address, retries: retries - 1, completion: completion)
                        }
                    } else {
                        completion(nil)
                    }
                    return
                }
                let mapItems = try await request.mapItems
                
                if let firstItem = mapItems.first {
                    let location = firstItem.location
                    completion(location.coordinate)
                } else {
                    if retries > 0 {
                        // Retry with exponential backoff
                        let delay = Double(3 - retries) * 1.5 // 1.5s, 3s delays
                        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                            self.geocodeAddressWithRetry(address, retries: retries - 1, completion: completion)
                        }
                    } else {
                        completion(nil)
                    }
                }
            } catch {
                if retries > 0 {
                    // Retry with exponential backoff
                    let delay = Double(3 - retries) * 1.5 // 1.5s, 3s delays
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.geocodeAddressWithRetry(address, retries: retries - 1, completion: completion)
                    }
                } else {
                    completion(nil)
                }
            }
        }
    }
    
    /// Calculates driving distance (in km) between two coordinates using MapKit Directions with retry logic and fallback.
    private func calculateDrivingDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, completion: @escaping @Sendable (Double?) -> Void) {
        calculateDrivingDistanceWithRetry(from: from, to: to, retries: 3, completion: completion)
    }
    
    /// Calculates driving distance with exponential backoff retry logic.
    private func calculateDrivingDistanceWithRetry(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, retries: Int, completion: @escaping @Sendable (Double?) -> Void) {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        request.transportType = .automobile
        let directions = MKDirections(request: request)
        
        // Add timeout to prevent hanging
        let timeoutTask = DispatchWorkItem {
            if retries > 0 {
                // Retry with exponential backoff
                let delay = Double(4 - retries) * 2.0 // 2s, 4s, 6s delays
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.calculateDrivingDistanceWithRetry(from: from, to: to, retries: retries - 1, completion: completion)
                }
            } else {
                // All retries failed, try fallback calculation
                let fallbackDistance = self.calculateDirectLineDistance(from: from, to: to)
                completion(fallbackDistance)
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0, execute: timeoutTask)
        
        directions.calculate { response, error in
            timeoutTask.cancel() // Cancel timeout if calculation completes
            if let route = response?.routes.first {
                completion(route.distance / 1000.0) // Convert meters to km
            } else {
                if retries > 0 {
                    // Retry with exponential backoff
                    let delay = Double(4 - retries) * 2.0 // 2s, 4s, 6s delays
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.calculateDrivingDistanceWithRetry(from: from, to: to, retries: retries - 1, completion: completion)
                    }
                } else {
                    // All retries failed, try fallback calculation
                    let fallbackDistance = self.calculateDirectLineDistance(from: from, to: to)
                    completion(fallbackDistance)
                }
            }
        }
    }
    
    /// Calculates direct-line distance as fallback when routing fails.
    private nonisolated func calculateDirectLineDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double? {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        let distance = fromLocation.distance(from: toLocation) / 1000.0 // Convert meters to km
        return distance
    }
    
    /// Looks up the MMM zone for a session using coordinates.
    /// If coordinates are not available, geocodes the address first.
    private func lookupMMMZone(for session: SessionEntity) -> MMMZone? {
        // Prefer explicit session coordinates first.
        if session.sessionLatitude != 0.0 && session.sessionLongitude != 0.0 {
            let coordinate = CLLocationCoordinate2D(
                latitude: session.sessionLatitude,
                longitude: session.sessionLongitude
            )
            if let zone = mmmZoneTable.lookup(byCoordinate: coordinate) {
                return zone
            }
        }

        // Fallback to any related entity coordinates before postcode/default fallbacks.
        let fallbackCoordinates: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(
                latitude: session.address?.latitude ?? 0.0,
                longitude: session.address?.longitude ?? 0.0
            ),
            CLLocationCoordinate2D(
                latitude: session.client?.address?.latitude ?? 0.0,
                longitude: session.client?.address?.longitude ?? 0.0
            )
        ]

        for coordinate in fallbackCoordinates where coordinate.latitude != 0.0 && coordinate.longitude != 0.0 {
            if let zone = mmmZoneTable.lookup(byCoordinate: coordinate) {
                return zone
            }
        }

        // Last non-network fallback: postcode-derived lookup (cache-backed).
        if let postcode = session.address?.postcode, !postcode.isEmpty,
           let zone = mmmZoneTable.lookup(byPostcode: postcode) {
            return zone
        }
        if let postcode = session.client?.address?.postcode, !postcode.isEmpty,
           let zone = mmmZoneTable.lookup(byPostcode: postcode) {
            return zone
        }

        return businessRules.defaultMMMZone
    }
    
    /// Returns the adjusted distance and any warnings about adjustments
    private func checkAndAdjustDistance(_ distance: Double?, businessRules: BusinessRules) -> (adjustedDistance: Double?, warnings: [ComplianceViolation]) {
        guard let distance = distance, distance > 0 else {
            return (nil, [])
        }
        
        var warnings: [ComplianceViolation] = []
        
        // Check if distance exceeds maximum allowed
        if let maxDistance = businessRules.maxTravelDistance, distance > maxDistance {
            let warning = ComplianceViolation(
                rule: "Distance Adjustment",
                currentValue: String(format: "%.1f km", distance),
                limit: String(format: "%.1f km", maxDistance),
                description: "Travel distance automatically adjusted to comply with maximum billable amount",
                severity: .warning
            )
            warnings.append(warning)
            
            // Log the distance adjustment for audit purposes
            logDistanceAdjustment(originalDistance: distance, adjustedDistance: maxDistance, reason: "Exceeded maximum billable amount")
            
            // Return the adjusted distance (capped at maximum)
            return (maxDistance, warnings)
        }
        
        return (distance, warnings)
    }
    
    /// Returns the adjusted travel time and any warnings about adjustments
    private func checkAndAdjustTravelTime(_ travelTime: Double, mmmZone: MMMZone) -> (adjustedTravelTime: Double, warnings: [ComplianceViolation]) {
        var warnings: [ComplianceViolation] = []
        
        // Check if travel time exceeds MMM zone maximum
        if travelTime > mmmZone.maxTime {
            let warning = ComplianceViolation(
                rule: "Travel Time Adjustment",
                currentValue: String(format: "%.1f minutes", travelTime),
                limit: String(format: "%.1f minutes", mmmZone.maxTime),
                description: "Travel time automatically adjusted to comply with MMM zone maximum",
                severity: .warning
            )
            warnings.append(warning)
            
            // Log the travel time adjustment for audit purposes
            logTravelTimeAdjustment(originalTime: travelTime, adjustedTime: mmmZone.maxTime, reason: "Exceeded MMM zone maximum")
            
            // Return the adjusted travel time (capped at maximum)
            return (mmmZone.maxTime, warnings)
        }
        
        return (travelTime, warnings)
    }
    
    /// Estimates travel time (in minutes) given a distance (km), using user preferences or business rules for average speed.
    private func estimateTravelTime(distance: Double?) -> Double? {
        guard let distance = distance, distance > 0 else { return nil }
        // Use user preference or business rule for average speed (km/h)
        let avgSpeed = userPreferences.averageSpeed ?? businessRules.defaultTravelTime // Assuming defaultTravelTime is a reasonable default for avgSpeed
        guard avgSpeed > 0 else { return nil }
        return (distance / avgSpeed) * 60.0 // minutes
    }
    
    /// Determines which charge types (labour, non-labour, activity-based) should be created for a session.
    private func determineChargeTypes(session: SessionEntity) -> [String] {
        var types: [String] = []
        // Always add labour
        types.append("labour")
        // Add non-labour if client has a matching service
        if findTravelService(client: session.client, session: session, chargeType: "non-labour") != nil {
            types.append("non-labour")
        }
        // Add activity-based if the linked service/item indicates participant transport support.
        if isActivityBasedEligible(session: session) {
            types.append("activity-based")
        }
        return types
    }
    
    /// Determines if a session/service is eligible for activity-based travel charges.
    private func isActivityBasedEligible(session: SessionEntity) -> Bool {
        let transportKeywords = [
            "activity based transport",
            "community access transport",
            "transport",
            "community participation transport"
        ]

        let item = session.clientService?.ndisItem
        let itemName = item?.name.lowercased() ?? ""
        let itemDescription = item?.itemDescription?.lowercased() ?? ""
        let itemFeatures = item?.features?.lowercased() ?? ""
        let serviceName = session.clientService?.serviceName.lowercased() ?? ""
        let ndisCode = session.clientService?.ndisCode?.lowercased() ?? item?.itemNumber.lowercased() ?? ""

        if containsAnyKeyword(in: itemName, keywords: transportKeywords) { return true }
        if containsAnyKeyword(in: itemDescription, keywords: transportKeywords) { return true }
        if containsAnyKeyword(in: itemFeatures, keywords: transportKeywords) { return true }
        if containsAnyKeyword(in: serviceName, keywords: transportKeywords) { return true }

        // Common transport coding pattern in line-item codes (e.g. 04_590_0104_6_1).
        if ndisCode.range(of: #"^\d{2}_\d{3,4}_\d{4}.*$"#, options: .regularExpression) != nil,
           containsAnyKeyword(in: "\(itemName) \(itemDescription) \(serviceName)", keywords: ["transport", "travel"]) {
            return true
        }

        return false
    }

    private func containsAnyKeyword(in source: String, keywords: [String]) -> Bool {
        guard !source.isEmpty else { return false }
        return keywords.contains { source.contains($0) }
    }
    
    
    
    /// Checks if a travel charge already exists for the same client, session, direction, and charge type in the day's sessions.
    private func travelChargeExists(client: ClientEntity, session: SessionEntity, direction: TravelDirection, chargeType: String, daySessions: [SessionInstance]) -> Bool {
        for s in daySessions {
            // Skip travel charges - we're only processing regular sessions
            if s.session.isTravel { continue }
            
            // Check if this session has any existing travel charges that match our criteria
            let travelCharges = s.session.travelCharges
            for travelCharge in travelCharges {
                if travelCharge.client == client,
                   travelCharge.linkedSession == session,
                   travelCharge.chargeType?.rawValue == chargeType,
                   travelCharge.travelDirection?.rawValue == direction.rawValue {
                    return true
                }
            }
        }
        return false
    }
    
    /// Checks if a travel charge is compliant with business rules and returns detailed violation information.
    private func isCompliantWithRules(travelTime: Double, mmmZone: MMMZone, businessRules: BusinessRules, chargeType: String, distance: Double? = nil, daySessions: [SessionInstance]? = nil, session: SessionEntity? = nil, proposedStart: Date? = nil, proposedEnd: Date? = nil) -> ComplianceResult {
        print("DEBUG: isCompliantWithRules - travelTime: \(travelTime), mmmZone.maxTime: \(mmmZone.maxTime), distance: \(distance ?? 0)")
        
        var violations: [ComplianceViolation] = []
        var warnings: [ComplianceViolation] = []
        
        // 1. Travel time is now automatically adjusted to maximum allowed (no violation check needed)
        // Travel time adjustments are handled in checkAndAdjustTravelTime() method
        
        // 2. Distance is now automatically adjusted to maximum allowed (no violation check needed)
        // Distance adjustments are handled in checkAndAdjustDistance() method
        
        // 3. Charge type must be allowed (if set)
        if let allowed = businessRules.allowedChargeTypes, !allowed.contains(chargeType) {
            let violation = ComplianceViolation(
                rule: "Allowed Charge Types",
                currentValue: chargeType,
                limit: allowed.joined(separator: ", "),
                description: "Charge type is not in the list of allowed types",
                severity: .error
            )
            violations.append(violation)
            print("DEBUG: Non-compliant: charge type \(chargeType) not in allowed types \(allowed)")
        }
        
        // 4. No overlap with other billable sessions for the same client
        if let daySessions = daySessions, let session = session {
            let start = proposedStart ?? session.startTime
            let end = proposedEnd ?? session.endTime
            for otherInstance in daySessions {
                let other = otherInstance.session
                guard other != session, !other.isTravel, other.client == session.client else { continue }
                // Exclude non-billable sessions
                if let status = other.status?.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                   businessRules.nonBillableStatuses.contains(status) {
                    continue
                }
                // Check for time overlap using instance times
                let oStart = otherInstance.instanceStart
                let oEnd = otherInstance.instanceEnd
                if let s = start, let e = end {
                    if s < oEnd && e > oStart {
                        let violation = ComplianceViolation(
                            rule: "Time Overlap Prevention",
                            currentValue: "\(s) to \(e)",
                            limit: "No overlap with \(other.title) (\(oStart) to \(oEnd))",
                            description: "Travel charge would create a time overlap with another session",
                            severity: .error
                        )
                        violations.append(violation)
                        print("DEBUG: Non-compliant: time overlap detected")
                    }
                }
            }
        }
        
        // 5. Warning for long travel times (even if within limits)
        if travelTime > mmmZone.maxTime * 0.8 {
            let warning = ComplianceViolation(
                rule: "Travel Time Warning",
                currentValue: String(format: "%.1f minutes", travelTime),
                limit: String(format: "%.1f minutes", mmmZone.maxTime * 0.8),
                description: "Travel time is approaching the MMM zone limit",
                severity: .warning
            )
            warnings.append(warning)
        }
        
        // 6. Warning for long distances (even if within limits)
        if let maxDist = businessRules.maxTravelDistance, let d = distance, d > maxDist * 0.8 {
            let warning = ComplianceViolation(
                rule: "Distance Warning",
                currentValue: String(format: "%.1f km", d),
                limit: String(format: "%.1f km", maxDist * 0.8),
                description: "Travel distance is approaching the business limit",
                severity: .warning
            )
            warnings.append(warning)
        }
        
        let isCompliant = violations.isEmpty
        if isCompliant {
            print("DEBUG: Travel charge is compliant")
        }
        
        return ComplianceResult(
            isCompliant: isCompliant,
            violations: violations,
            warnings: warnings
        )
    }
    
    /// Creates a new travel charge entity with all required attributes.
    private func createTravelSession(
        client: ClientEntity,
        service: ClientServiceEntity?,
        startTime: Date?,
        endTime: Date?,
        location: String?,
        mmmZone: MMMZone?,
        distance: Double?,
        duration: Double?,
        vehicleType: String?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int?,
        notes: String?,
        calculatedAmount: Double?,
        linkedSession: SessionEntity?,
        chargeType: String,
        splitCosts: Bool,
        travelDirection: String? = nil
    ) -> TravelChargeEntity {
        // Use SessionFactory for consistent travel session creation
        let sessionFactory = SessionFactory(context: context)
        return sessionFactory.createTravelSession(
            client: client,
            service: service,
            linkedSession: linkedSession!,
            startTime: startTime,
            endTime: endTime,
            location: location,
            distance: distance ?? 0,
            duration: duration ?? 0,
            chargeType: chargeType,
            travelDirection: travelDirection ?? "unknown",
            notes: notes,
            calculatedAmount: calculatedAmount,
            mmmZoneName: mmmZone?.name,
            vehicleType: vehicleType,
            parkingCost: parking ?? 0,
            tollCost: tolls ?? 0,
            participantCount: participantCount ?? 1,
            splitCosts: splitCosts
        )
    }
    
    /// Detects other sessions that share travel with the given session in the specified direction, using geocoding for proximity.
    private func detectSharedTravelParticipants(session: SessionEntity, daySessions: [SessionInstance], direction: TravelDirection, completion: @escaping @Sendable ([SessionEntity]) -> Void) {
        let timeThreshold: TimeInterval = 15 * 60 // 15 minutes
        let distanceThreshold: Double = 100 // meters
        var locationCache: [UUID: CLLocationCoordinate2D] = [:]
        let cacheQueue = DispatchQueue(label: "locationCache", attributes: .concurrent)
        let group = DispatchGroup()
        
        // Helper to geocode and cache
        func geocodeSession(_ s: SessionEntity, completion: @escaping @Sendable (CLLocationCoordinate2D?) -> Void) {
            var cached: CLLocationCoordinate2D?
            cacheQueue.sync {
                cached = locationCache[s.id]
            }
            
            if let cached = cached {
                completion(cached)
                return
            }
            
            geocodeAddress(s.location) { coord in
                if let coord = coord {
                    cacheQueue.async(flags: .barrier) {
                        locationCache[s.id] = coord
                    }
                }
                completion(coord)
            }
        }
        
        // Geocode all sessions in parallel
        for s in daySessions {
            group.enter()
            geocodeSession(s.session) { _ in group.leave() }
        }
        
        group.notify(queue: .main) {
            // Geocode target session
            geocodeSession(session) { targetCoord in
                guard let tCoord = targetCoord else { completion([session]); return }
                
                let targetTime: Date? = (direction == .before) ? session.startTime : session.endTime
                guard let tTime = targetTime else { completion([session]); return }
                
                let matches = daySessions.filter { otherInstance in
                    let other = otherInstance.session
                    // Exclude self and travel sessions
                    guard other.id != session.id, !other.isTravel else { return false }
                    
                    let otherTime: Date = (direction == .before) ? otherInstance.instanceStart : otherInstance.instanceEnd
                    let timeDiff = abs(otherTime.timeIntervalSince(tTime))
                    
                    guard timeDiff <= timeThreshold else { return false }
                    
                    var oCoord: CLLocationCoordinate2D?
                    cacheQueue.sync {
                        oCoord = locationCache[other.id]
                    }
                    
                    guard let oCoord = oCoord else { return false }
                    
                    let loc1 = CLLocation(latitude: tCoord.latitude, longitude: tCoord.longitude)
                    let loc2 = CLLocation(latitude: oCoord.latitude, longitude: oCoord.longitude)
                    let dist = loc1.distance(from: loc2)
                    
                    return dist <= distanceThreshold
                }
                
                completion([session] + matches.map { $0.session })
            }
        }
    }
    
    /// Determines the vehicle type for the travel charge, including business-specific logic.
    private func determineVehicleType(session: SessionEntity, chargeType: String) -> String? {
        // 1. Check user preferences
        if let preferred = userPreferences.preferredVehicleType {
            return preferred
        }
        // 2. Check client profile for mobility needs (business-specific logic)
        
        // 5. Default
        return "Standard Car"
    }
    
    
    
    /// Determines the participant count for cost splitting, including business-specific logic.
    private func determineParticipantCount(session: SessionEntity, sharedParticipants: [SessionEntity]) -> Int {
        // Use the count of shared participants (sessions sharing the same travel)
        let count = sharedParticipants.count
        // If group session info is available, use the maximum
        
        return max(count, 1)
    }

    private func calculatePricingBreakdown(
        session: SessionEntity,
        service: ClientServiceEntity?,
        chargeType: String,
        mmmZone: MMMZone,
        travelTime: Double,
        distance: Double?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int,
        splitCosts: Bool
    ) -> NDISTravelChargeBreakdown {
        let effectiveParticipants = splitCosts ? max(participantCount, 1) : 1
        let primaryService = session.clientService ?? service
        let providerType = NDISTravelChargeCalculator.inferredProviderType(
            itemName: primaryService?.serviceName,
            itemDescription: primaryService?.ndisItem?.itemDescription,
            ndisCode: primaryService?.ndisCode
        )
        let ancillary = (parking ?? 0) + (tolls ?? 0)
        let hourlyRate = max(primaryService?.rate ?? 0, 0)

        return NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: hourlyRate,
            mmmZoneDescriptor: mmmZone.name,
            minutesTravelled: travelTime,
            kilometresTravelled: distance ?? 0,
            ancillaryCosts: ancillary,
            participantCount: effectiveParticipants
        )
    }

    private func buildTravelChargeEntity(
        client: ClientEntity,
        session: SessionEntity,
        service: ClientServiceEntity?,
        direction: TravelDirection,
        startTime: Date?,
        endTime: Date?,
        location: String,
        mmmZone: MMMZone,
        distance: Double,
        travelTime: Double,
        vehicleType: String?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int,
        chargeType: String,
        splitCosts: Bool,
        notesSuffix: String? = nil
    ) -> TravelChargeEntity {
        let (adjustedDistance, distanceWarnings) = checkAndAdjustDistance(distance, businessRules: businessRules)
        let (adjustedTravelTime, travelTimeWarnings) = checkAndAdjustTravelTime(travelTime, mmmZone: mmmZone)
        let pricingBreakdown = calculatePricingBreakdown(
            session: session,
            service: service,
            chargeType: chargeType,
            mmmZone: mmmZone,
            travelTime: adjustedTravelTime,
            distance: adjustedDistance,
            parking: parking,
            tolls: tolls,
            participantCount: participantCount,
            splitCosts: splitCosts
        )

        var notes = generateTravelChargeNotes(
            session: session,
            direction: direction,
            distance: adjustedDistance,
            originalDistance: distance,
            distanceWarnings: distanceWarnings,
            travelTime: adjustedTravelTime,
            originalTravelTime: travelTime,
            travelTimeWarnings: travelTimeWarnings,
            mmmZone: mmmZone,
            vehicleType: vehicleType,
            parking: parking,
            tolls: tolls,
            participantCount: participantCount,
            chargeType: chargeType,
            splitCosts: splitCosts,
            pricingBreakdown: pricingBreakdown
        )

        if let notesSuffix, !notesSuffix.isEmpty {
            notes += notesSuffix
        }

        return createTravelSession(
            client: client,
            service: service,
            startTime: startTime,
            endTime: endTime,
            location: location,
            mmmZone: mmmZone,
            distance: adjustedDistance,
            duration: adjustedTravelTime,
            vehicleType: vehicleType,
            parking: parking,
            tolls: tolls,
            participantCount: participantCount,
            notes: notes,
            calculatedAmount: calculatedAmount(for: chargeType, breakdown: pricingBreakdown),
            linkedSession: session,
            chargeType: chargeType,
            splitCosts: splitCosts,
            travelDirection: direction.rawValue
        )
    }

    private func overrideNotesSuffix(overrideType: String?, overrideReason: String?) -> String {
        "\n[Override: \(overrideType ?? "Manual") - \(overrideReason ?? "No reason provided")]"
    }

    private func calculatedAmount(for chargeType: String, breakdown: NDISTravelChargeBreakdown) -> Double {
        switch chargeType.lowercased() {
        case "labour":
            return breakdown.labourPerParticipant
        case "non-labour":
            return breakdown.nonLabourPerParticipant
        case "activity-based":
            return breakdown.totalPerParticipant
        default:
            return breakdown.totalPerParticipant
        }
    }
    
    /// Generates a detailed notes string for the travel charge.
    private func generateTravelChargeNotes(
        session: SessionEntity,
        direction: TravelDirection,
        distance: Double?,
        originalDistance: Double?,
        distanceWarnings: [ComplianceViolation],
        travelTime: Double,
        originalTravelTime: Double?,
        travelTimeWarnings: [ComplianceViolation],
        mmmZone: MMMZone,
        vehicleType: String?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int,
        chargeType: String,
        splitCosts: Bool,
        pricingBreakdown: NDISTravelChargeBreakdown
    ) -> String {
        var notes = "Travel ("
        notes += chargeType
        notes += ") "
        notes += (direction == .before ? "before" : "after")
        notes += " session '"
        notes += session.title
        notes += "':\n"
        
        // Show distance information with adjustment details if applicable
        if let distance = distance {
            notes += "Distance: \(String(format: "%.1f", distance)) km"
            
            // Add distance adjustment information if there were warnings
            if !distanceWarnings.isEmpty {
                notes += " (adjusted from \(String(format: "%.1f", originalDistance ?? 0)) km)"
            }
            
            notes += ", Time: \(String(format: "%.0f", travelTime)) min"
            
            // Add travel time adjustment information if there were warnings
            if !travelTimeWarnings.isEmpty {
                notes += " (adjusted from \(String(format: "%.0f", originalTravelTime ?? 0)) min)"
            }
            
            notes += ", MMM Zone: \(mmmZone.name)\n"
        } else {
            notes += "Distance: Unknown, Time: \(String(format: "%.0f", travelTime)) min"
            
            // Add travel time adjustment information if there were warnings
            if !travelTimeWarnings.isEmpty {
                notes += " (adjusted from \(String(format: "%.0f", originalTravelTime ?? 0)) min)"
            }
            
            notes += ", MMM Zone: \(mmmZone.name)\n"
        }
        
        // Add distance adjustment warning details
        for warning in distanceWarnings {
            if warning.rule == "Distance Adjustment" {
                notes += "⚠️ \(warning.description)\n"
            }
        }
        
        // Add travel time adjustment warning details
        for warning in travelTimeWarnings {
            if warning.rule == "Travel Time Adjustment" {
                notes += "⚠️ \(warning.description)\n"
            }
        }
        
        if let vehicleType = vehicleType {
            notes += "Vehicle: \(vehicleType)\n"
        }
        notes += "Participants: \(participantCount)"
        if splitCosts {
            notes += " (costs split)"
        }
        notes += "\nProvider Type: \(pricingBreakdown.providerType.rawValue)"
        notes += "\nBillable Time: \(String(format: "%.1f", pricingBreakdown.billableMinutes)) min"
        if pricingBreakdown.maxBillableMinutes.isInfinite {
            notes += " (uncapped MMM 6/7)"
        } else {
            notes += " (cap \(String(format: "%.1f", pricingBreakdown.maxBillableMinutes)) min)"
        }

        if chargeType.lowercased() == "labour" || chargeType.lowercased() == "activity-based" {
            notes += "\nLabour per participant: \(pricingBreakdown.labourPerParticipant.formatted(.currency(code: "AUD")))"
        }

        if chargeType.lowercased() == "non-labour" || chargeType.lowercased() == "activity-based" {
            notes += "\nVehicle + ancillary per participant: \(pricingBreakdown.nonLabourPerParticipant.formatted(.currency(code: "AUD")))"
        }

        let chargeAmountPerParticipant = calculatedAmount(for: chargeType, breakdown: pricingBreakdown)
        notes += "\nTotal per participant: \(chargeAmountPerParticipant.formatted(.currency(code: "AUD")))"
        return notes
    }
    
    /// Adds a session to the user review queue for manual intervention.
    private func queueForUserReview(session: SessionEntity, reason: String) {
        queueForUserReview(session: session, reason: reason, violations: [], suggestedActions: [], overrideOptions: [])
    }
    
    /// Adds a session to the user review queue with detailed violation information.
    private func queueForUserReview(session: SessionEntity, reason: String, violations: [Core.ComplianceViolation] = [], suggestedActions: [String] = [], overrideOptions: [String] = []) {
        if testingMode {
            let summary = "Session: \(session.title), Reason: \(reason)"
            testReviewSummaries.append(summary)
            
            // Map SessionEntity to Session (domain model)
            let domainSession = Session(
                id: session.id,
                title: session.title,
                startTime: session.startTime,
                endTime: session.endTime,
                isAllDay: session.isAllDay,
                location: session.location,
                notes: session.notes,
                status: session.status?.rawValue,
                isTravel: session.isTravel,
                clientId: session.client?.id,
                clientServiceId: session.clientService?.id,
                groupID: session.groupID,
                recurrenceRuleData: session.recurrenceRuleData
            )
            
            // Create detailed review item for testing
            let detailedItem = Core.DetailedReviewItem(
                id: UUID(),
                session: domainSession,
                clientName: session.client?.fullName,
                reason: reason,
                violations: violations,
                suggestedActions: suggestedActions,
                overrideOptions: overrideOptions,
                timestamp: Date()
            )
            testDetailedReviewItems.append(detailedItem)
            
            print("[TravelChargeAutomation] Flagged for review: \(session.title) - Reason: \(reason)")
            if !violations.isEmpty {
                print("[TravelChargeAutomation] Violations: \(violations.map { $0.rule }.joined(separator: ", "))")
            }
            return
        }
        
        let reviewItem = TravelChargeReviewItemEntity(id: UUID())
        reviewItem.session = session
        reviewItem.reason = reason
        reviewItem.timestamp = Date()
        
        // Store detailed violation information using the enhanced fields
        if !violations.isEmpty {
            reviewItem.violations = violations.map { $0.rule }
            reviewItem.violationDetails = violations.map { "\($0.rule): \($0.currentValue) (limit: \($0.limit)) - \($0.description)" }
        }
        
        // Store suggested actions and override options
        if !suggestedActions.isEmpty {
            reviewItem.suggestedActions = suggestedActions
        }
        
        if !overrideOptions.isEmpty {
            reviewItem.overrideOptions = overrideOptions
        }
        
        context.insert(reviewItem)
        logReviewItem(reviewItem)
        print("[TravelChargeAutomation] Flagged for review: \(session.title) - Reason: \(reason)")
        if !violations.isEmpty {
            print("[TravelChargeAutomation] Violations: \(violations.map { $0.rule }.joined(separator: ", "))")
        }
    }
    
    /// Fetches all review items for UI/admin display.
    func fetchReviewItems() -> [TravelChargeReviewItemEntity] {
        let resolver = EntityResolutionService(context: context)
        do {
            return try resolver.resolveReviewItems()
        } catch {
            print("[TravelChargeAutomation] Failed to fetch review items: \(error)")
            return []
        }
    }
    
    /// Fetches pending review items that need user attention.
    func fetchPendingReviewItems() -> [TravelChargeReviewItemEntity] {
        let resolver = EntityResolutionService(context: context)
        do {
            return try resolver.resolveReviewItems(pendingOnly: true)
        } catch {
            print("[TravelChargeAutomation] Failed to fetch pending review items: \(error)")
            return []
        }
    }
    
    /// Resolves a review item by creating a travel charge with override (safe for concurrency).
    public func resolveReviewWithOverride(reviewItemId: UUID, overrideType: String, overrideReason: String? = nil) async throws {
        let resolver = EntityResolutionService(context: context)
        guard let reviewItem = try? resolver.resolveReviewItem(id: reviewItemId) else {
            throw TravelChargeError.invalidSession // Using generic error for item not found
        }
        try await resolveReviewWithOverride(reviewItem, overrideType: overrideType, overrideReason: overrideReason)
    }

    /// Resolves a review item by skipping the travel charge (safe for concurrency).
    public func resolveReviewBySkipping(reviewItemId: UUID, reason: String? = nil) async throws {
        let resolver = EntityResolutionService(context: context)
        guard let reviewItem = try? resolver.resolveReviewItem(id: reviewItemId) else {
             throw TravelChargeError.invalidSession
        }
        try await resolveReviewBySkipping(reviewItem, reason: reason)
    }

    /// Resolves a review item by creating a travel charge with override.
    public func resolveReviewWithOverride(_ reviewItem: TravelChargeReviewItemEntity, overrideType: String, overrideReason: String? = nil) async throws {
        guard let session = reviewItem.session else {
            throw TravelChargeError.invalidSession
        }
        
        // Mark the review item as overridden
        reviewItem.applyOverride(type: overrideType, reason: overrideReason)
        
        // Create the travel charge with override information
        try await createTravelChargeForSession(session, overrideType: overrideType, overrideReason: overrideReason)
        
        // Log the override action
        logReviewResolution(reviewItem, action: "overridden", details: "Override type: \(overrideType)")
        
        try context.save()
    }
    
    /// Resolves a review item by skipping the travel charge.
    public func resolveReviewBySkipping(_ reviewItem: TravelChargeReviewItemEntity, reason: String? = nil) async throws {
        // Mark the review item as skipped
        reviewItem.skip(reason: reason)
        
        // Log the skip action
        logReviewResolution(reviewItem, action: "skipped", details: reason ?? "User chose to skip")
        
        try context.save()
    }
    
    /// Creates a travel charge for a session with override information.
    private func createTravelChargeForSession(_ session: SessionEntity, overrideType: String? = nil, overrideReason: String? = nil) async throws {
        print("[TravelChargeAutomation] Creating travel charge for session: \(session.title) with override")
        
        guard let client = session.client, let startTime = session.startTime else {
            throw TravelChargeError.invalidSession
        }
        
        // 1. Re-construct context: Fetch sibling sessions for the same day to determine travel logic
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: startTime)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch sessions for the client on this day
        let resolver = EntityResolutionService(context: context)
        let daySessionsRaw = resolver.resolveSessions(forClient: client.id, onDate: startTime)
            .filter { $0.isTravel == false }
        let daySessionInstances = expandSessionsToInstances(daySessionsRaw)
        let sortedSessions = sortSessionsChronologically(daySessionInstances)
        
        // Find the index of the current session
        guard let index = sortedSessions.firstIndex(where: { $0.session.id == session.id }) else {
            throw TravelChargeError.invalidSession
        }
        
        // 2. Determine necessary travel directions
        let directions = determineTravelDirections(i: index, daySessions: sortedSessions)
        
        for direction in directions {
            // 3. Resolve Locations
            let (fromLocation, toLocation, fromTime, toTime): (String?, String?, Date?, Date?) = {
                switch direction {
                case .before:
                    let prev = previousNonTravelSession(i: index, daySessions: sortedSessions)
                    // If no previous session, use business address
                    let businessAddr = self.getBusinessAddress()
                    return (prev?.session.location ?? businessAddr, session.location, prev?.instanceEnd, session.startTime)
                case .after:
                    let next = nextNonTravelSession(i: index, daySessions: sortedSessions)
                    let businessAddr = self.getBusinessAddress()
                    return (session.location, next?.session.location ?? businessAddr, session.endTime, next?.instanceStart)
                }
            }()
            
            guard let fromLoc = fromLocation, let toLoc = toLocation else {
                print("[TravelChargeAutomation] Missing location data for session \(session.title)")
                continue
            }
            
            // 4. Calculate Metrics (Async)
            guard let fromCoord = await geocodeAddressAsync(fromLoc),
                  let toCoord = await geocodeAddressAsync(toLoc),
                  let distance = await calculateDrivingDistanceAsync(from: fromCoord, to: toCoord) else {
                print("[TravelChargeAutomation] Failed to calculate metrics for session \(session.title)")
                continue
            }
            
            let travelTime = estimateTravelTime(distance: distance) ?? businessRules.defaultTravelTime
            let mmmZone = lookupMMMZone(for: session) ?? businessRules.defaultMMMZone
            
            // 5. Determine Charge Types
            let chargeTypes = determineChargeTypes(session: session)
            
            for chargeType in chargeTypes {
                // Check if already exists (to avoid duplicates, though override might imply forcing)
                if travelChargeExists(client: client, session: session, direction: direction, chargeType: chargeType, daySessions: sortedSessions) {
                    print("[TravelChargeAutomation] Travel charge already exists, skipping duplicate.")
                    continue
                }
                
                // 6. Create Charge with Overrides
                // We bypass isCompliantWithRules because this is an override flows
                
                let service = findTravelService(client: client, session: session, chargeType: chargeType)
                
                // Shared travel logic
                let sharedParticipants = await detectSharedTravelParticipantsAsync(session: session, daySessions: sortedSessions, direction: direction)
                let participantCount = determineParticipantCount(session: session, sharedParticipants: sharedParticipants)
                let splitCosts = participantCount > 1
                let vehicleType = determineVehicleType(session: session, chargeType: chargeType)
                let notesSuffix = overrideNotesSuffix(overrideType: overrideType, overrideReason: overrideReason)
                let travelCharge = buildTravelChargeEntity(
                    client: client,
                    session: session,
                    service: service,
                    direction: direction,
                    startTime: (direction == .before) ? fromTime : session.endTime,
                    endTime: (direction == .before) ? session.startTime : toTime,
                    location: (direction == .before) ? fromLoc : toLoc,
                    mmmZone: mmmZone,
                    distance: distance,
                    travelTime: travelTime,
                    vehicleType: vehicleType,
                    parking: nil,
                    tolls: nil,
                    participantCount: participantCount,
                    chargeType: chargeType,
                    splitCosts: splitCosts,
                    notesSuffix: notesSuffix
                )
                  
                // Store override metadata on the entity if supported (schema dependent). 
                // For now, it's in the notes.
                
                saveTravelCharge(travelCharge)
            }
        }
    }
    
    // MARK: - Async Helper Wrappers
    
    private func getBusinessAddress() -> String? {
         let resolver = EntityResolutionService(context: context)
         let business = try? resolver.resolveBusiness()
         return business?.address?.fullFormattedAddress ?? business?.address?.fullAddressText
    }

    private func geocodeAddressAsync(_ address: String?) async -> CLLocationCoordinate2D? {
        await withCheckedContinuation { continuation in
            geocodeAddress(address) { coord in
                continuation.resume(returning: coord)
            }
        }
    }
    
    private func calculateDrivingDistanceAsync(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> Double? {
        await withCheckedContinuation { continuation in
            calculateDrivingDistance(from: from, to: to) { distance in
                continuation.resume(returning: distance)
            }
        }
    }
    
    private func detectSharedTravelParticipantsAsync(session: SessionEntity, daySessions: [SessionInstance], direction: TravelDirection) async -> [SessionEntity] {
        await withCheckedContinuation { continuation in
            detectSharedTravelParticipants(session: session, daySessions: daySessions, direction: direction) { participants in
                continuation.resume(returning: participants)
            }
        }
    }
    
    /// Logs review resolution for audit purposes.
    private func logReviewResolution(_ reviewItem: TravelChargeReviewItemEntity, action: String, details: String) {
        let auditLog = TravelChargeAuditLog(id: UUID())
        auditLog.charge = nil
        auditLog.timestamp = Date()
        auditLog.summary = "Review Resolution: \(reviewItem.session?.title ?? "Unknown") - \(action)"
        auditLog.action = action
        auditLog.details = details
        context.insert(auditLog)
    }
    
    /// Logs all created travel charges for audit/compliance purposes.
    private func logAllCreatedTravelCharges() {
        guard !createdTravelCharges.isEmpty else { return }
        print("[TravelChargeAutomation] Created \(createdTravelCharges.count) travel charges:")
        for charge in createdTravelCharges {
            let clientName = charge.client?.fullName ?? "Unknown Client"
            let sessionTitle = charge.linkedSession?.title ?? "Unknown Session"
            let type = charge.chargeType?.rawValue ?? "Unknown Type"
            let dist = String(format: "%.1f", charge.travelDistance ?? 0.0)
            let dir = charge.travelDirection?.rawValue ?? "?"
            let amount = charge.calculatedAmount.map { $0.formatted(.currency(code: "AUD")) } ?? "N/A"
            let summary = "Client: \(clientName), Session: \(sessionTitle), Type: \(type), Distance: \(dist) km, Direction: \(dir), Amount/Participant: \(amount)"
            print("- \(summary)")
            // Create and save audit log
            let auditLog = TravelChargeAuditLog(id: UUID())
            auditLog.charge = charge
            auditLog.timestamp = Date()
            auditLog.summary = summary
            auditLog.action = "created"
            auditLog.details = "Automated creation via TravelChargeAutomationService"
            context.insert(auditLog)
        }
        createdTravelCharges.removeAll()
    }
    
    /// Logs review items for audit/compliance purposes
    private func logReviewItem(_ reviewItem: TravelChargeReviewItemEntity, action: String = "flagged") {
        let auditLog = TravelChargeAuditLog(id: UUID())
        auditLog.charge = nil // No charge created
        auditLog.timestamp = Date()
        auditLog.summary = "Review: \(reviewItem.session?.title ?? "Unknown") - \(reviewItem.reason ?? "No reason")"
        auditLog.action = action
        auditLog.details = "Item flagged for manual review"
        context.insert(auditLog)
    }
    
    /// Logs validation events for audit purposes
    private func logValidationEvent(address: AddressEntity, success: Bool, error: String? = nil) {
        let auditLog = TravelChargeAuditLog(id: UUID())
        auditLog.charge = nil
        auditLog.timestamp = Date()
        auditLog.summary = "Address Validation: \(address.fullFormattedAddress)"
        auditLog.action = success ? "validated" : "validation_failed"
        auditLog.details = success ? "Address validated successfully" : "Validation failed: \(error ?? "Unknown error")"
        context.insert(auditLog)
    }
    
    /// Logs distance adjustments for audit purposes
    private func logDistanceAdjustment(originalDistance: Double, adjustedDistance: Double, reason: String) {
        let auditLog = TravelChargeAuditLog(id: UUID())
        auditLog.charge = nil
        auditLog.timestamp = Date()
        auditLog.summary = "Distance adjustment: \(String(format: "%.1f", originalDistance)) km → \(String(format: "%.1f", adjustedDistance)) km"
        auditLog.action = "adjust_distance"
        auditLog.details = "\(reason) - Original: \(String(format: "%.1f", originalDistance)) km, Adjusted: \(String(format: "%.1f", adjustedDistance)) km"
        context.insert(auditLog)
        print("[TravelChargeAutomation] Distance adjusted: \(String(format: "%.1f", originalDistance)) km → \(String(format: "%.1f", adjustedDistance)) km (\(reason))")
    }
    
    /// Logs travel time adjustments for audit purposes
    private func logTravelTimeAdjustment(originalTime: Double, adjustedTime: Double, reason: String) {
        let auditLog = TravelChargeAuditLog(id: UUID())
        auditLog.charge = nil
        auditLog.timestamp = Date()
        auditLog.summary = "Travel time adjustment: \(String(format: "%.1f", originalTime)) min → \(String(format: "%.1f", adjustedTime)) min"
        auditLog.action = "adjust_travel_time"
        auditLog.details = "\(reason) - Original: \(String(format: "%.1f", originalTime)) min, Adjusted: \(String(format: "%.1f", adjustedTime)) min"
        context.insert(auditLog)
        print("[TravelChargeAutomation] Travel time adjusted: \(String(format: "%.1f", originalTime)) min → \(String(format: "%.1f", adjustedTime)) min (\(reason))")
    }
    
    /// Fetches all audit logs for reporting or admin review.
    func fetchAuditLogs() -> [TravelChargeAuditLog] {
        let resolver = EntityResolutionService(context: context)
        do {
            return try resolver.resolveAuditLogs()
        } catch {
            print("[TravelChargeAutomation] Failed to fetch audit logs: \(error)")
            return []
        }
    }
    
    public func getTestResults() -> (charges: [String], reviews: [String], detailedReviews: [Core.DetailedReviewItem]) {
        return (testTravelChargeSummaries, testReviewSummaries, testDetailedReviewItems)
    }
    
    // MARK: - Proactive Validation Service
    
    /// Validates an address entity proactively and updates its validation status
    func validateAddress(_ address: AddressEntity, completion: @escaping @Sendable (Bool) -> Void) {
        guard address.isValidForGeocoding else {
            address.validationStatus = .failed
            address.validationError = "Address is empty or invalid"
            address.lastValidationAttempt = Date()
            completion(false)
            return
        }
        
        address.validationStatus = .pending
        address.lastValidationAttempt = Date()
        
        geocodeAddress(address.fullFormattedAddress) { coordinate in
            DispatchQueue.main.async {
                if let coord = coordinate {
                    address.latitude = coord.latitude
                    address.longitude = coord.longitude
                    address.validationStatus = .valid
                    address.validationError = nil
                    print("[AddressValidation] Address validated successfully: \(address.fullFormattedAddress)")
                    self.logValidationEvent(address: address, success: true)
                } else {
                    address.latitude = 0.0
                    address.longitude = 0.0
                    address.validationStatus = .failed
                    address.validationError = "Failed to geocode address"
                    print("[AddressValidation] Address validation failed: \(address.fullFormattedAddress)")
                    self.logValidationEvent(address: address, success: false, error: "Failed to geocode address")
                }
                completion(address.validationStatus == .valid)
            }
        }
    }
    
    private func validateAddressAsync(_ address: AddressEntity) async -> Bool {
        guard address.isValidForGeocoding else {
            await MainActor.run {
                address.validationStatus = .failed
                address.validationError = "Address is empty or invalid"
                address.lastValidationAttempt = Date()
            }
            return false
        }
        
        await MainActor.run {
            address.validationStatus = .pending
            address.lastValidationAttempt = Date()
        }
        
        let coordinate = await geocodeAddressAsync(address.fullFormattedAddress)
        
        return await MainActor.run {
            if let coord = coordinate {
                address.latitude = coord.latitude
                address.longitude = coord.longitude
                address.validationStatus = .valid
                address.validationError = nil
                self.logValidationEvent(address: address, success: true)
                return true
            } else {
                address.latitude = 0.0
                address.longitude = 0.0
                address.validationStatus = .failed
                address.validationError = "Failed to geocode address"
                self.logValidationEvent(address: address, success: false, error: "Failed to geocode address")
                return false
            }
        }
    }

    /// Validates all addresses in the system that need validation
    func validateAllAddresses(completion: @escaping @Sendable (Int, Int) -> Void) {
        let addressDescriptor = FetchDescriptor<AddressEntity>()
        guard let addresses = try? context.fetch(addressDescriptor) else {
            completion(0, 0)
            return
        }
        
        let addressesToValidate = addresses.filter { $0.validationStatus == .unvalidated }
        let totalCount = addressesToValidate.count
        
        guard !addressesToValidate.isEmpty else {
            completion(0, 0)
            return
        }
        
        Task {

            let results = await withTaskGroup(of: Bool.self) { group in
                for address in addressesToValidate {
                    group.addTask {
                        return await self.validateAddressAsync(address)
                    }
                }
                
                var successCount = 0
                for await result in group {
                    if result {
                        successCount += 1
                    }
                }
                return successCount
            }
            
            await MainActor.run {
                completion(results, totalCount)
            }
        }
    }
    
    /// Validates business address specifically
    func validateBusinessAddress(completion: @escaping @Sendable (Bool) -> Void) {
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        guard let business = try? context.fetch(businessDescriptor).first,
              let address = business.address else {
            completion(false)
            return
        }
        
        validateAddress(address, completion: completion)
    }
    
    /// Validates session addresses that need validation
    /// Validates session addresses that need validation
    func validateSessionAddresses(completion: @escaping @Sendable (Int, Int) -> Void) {
        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        guard let sessions = try? context.fetch(sessionDescriptor) else {
            completion(0, 0)
            return
        }
        
        let sessionsWithAddresses = sessions.compactMap { $0.address }
        let addressesToValidate = sessionsWithAddresses.filter { $0.validationStatus == .unvalidated }
        let totalCount = addressesToValidate.count
        
        guard !addressesToValidate.isEmpty else {
            completion(0, 0)
            return
        }
        
        Task {
            let results = await withTaskGroup(of: Bool.self) { group in
                for address in addressesToValidate {
                    group.addTask {
                        return await self.validateAddressAsync(address)
                    }
                }
                
                var successCount = 0
                for await result in group {
                    if result {
                        successCount += 1
                    }
                }
                return successCount
            }
            
            await MainActor.run {
                completion(results, totalCount)
            }
        }
    }
    
    /// Simulates creating actual travel charges from test summaries (test mode only)
    func simulateChargeCreation(from summaries: [String]) -> [String] {
        var simulationResults: [String] = []
        
        for summary in summaries {
            // Parse the summary to extract session information
            // Format: "Client: [Name], Session: [Title], Type: [Type], Distance: [X] km, Direction: [before/after], Notes: [Notes]"
            if let session = parseSessionFromSummary(summary) {
                // Simulate creating the travel charge (don't actually create it)
                let simulationResult = simulateTravelChargeCreation(summary, session: session)
                simulationResults.append(simulationResult)
            }
        }
        
        return simulationResults
    }
    
    /// Parses session information from a test summary
    private func parseSessionFromSummary(_ summary: String) -> SessionEntity? {
        // Extract session title from summary
        // Look for "Session: [Title]" pattern
        let sessionPattern = "Session: ([^,]+)"
        if let range = summary.range(of: sessionPattern, options: .regularExpression),
           let sessionTitle = summary[range].split(separator: ":").last?.trimmingCharacters(in: .whitespaces) {
            
            // Find the session in the context
            let descriptor = FetchDescriptor<SessionEntity>(
                predicate: #Predicate<SessionEntity> { session in
                    session.title == sessionTitle
                }
            )
            
            return try? context.fetch(descriptor).first
        }
        return nil
    }
    
    /// Simulates creating a travel charge entity from a test summary (test mode only)
    private func simulateTravelChargeCreation(_ summary: String, session: SessionEntity) -> String {
        // Extract information from summary
        let components = summary.components(separatedBy: ", ")
        
        var clientName: String?
        var chargeType: String?
        var distance: Double?
        var direction: String?
        var notes: String?
        
        for component in components {
            if component.hasPrefix("Client: ") {
                clientName = String(component.dropFirst("Client: ".count))
            } else if component.hasPrefix("Type: ") {
                chargeType = String(component.dropFirst("Type: ".count))
            } else if component.hasPrefix("Distance: ") {
                let distanceStr = String(component.dropFirst("Distance: ".count).dropLast(" km".count))
                distance = Double(distanceStr)
            } else if component.hasPrefix("Direction: ") {
                direction = String(component.dropFirst("Direction: ".count))
            } else if component.hasPrefix("Notes: ") {
                notes = String(component.dropFirst("Notes: ".count))
            }
        }
        
        // Simulate travel charge creation (test mode only)
        let simulationResult = """
        SIMULATION: Would create travel charge for:
        - Client: \(clientName ?? "Unknown")
        - Session: \(session.title)
        - Type: \(chargeType ?? "labour")
        - Distance: \(distance ?? 0) km
        - Direction: \(direction ?? "before")
        - Notes: \(notes ?? "Created from automation approval")
        - MMM Zone: MMM Zone 1
        - Vehicle: Standard Car
        - Duration: 30 minutes
        - Participant Count: 1
        - Split Costs: false
        """
        
        return simulationResult
    }
    

    
    /// Maps a session's NDIS Item to the corresponding travel NDIS Item based on NDIS rules.
    ///
    /// NDIS Travel Rules:
    /// - Labour (Travel Time): Use the SAME item number as the primary support
    /// - Non-Labour (Travel Expenses): Use the '799' rule - replace sequence number with '799'
    /// - Activity-Based Transport: Use the '590' rule - replace sequence number with '590'
    private func mapToTravelNDISItem(session: SessionEntity, chargeType: String) -> NDISItemEntity? {
        print("DEBUG: Mapping travel NDIS item for session: '\(session.title)'")
        print("DEBUG: Session has clientService: \(session.clientService != nil)")
        
        guard let mainService = session.clientService else {
            print("DEBUG: Session has no clientService")
            return nil
        }
        
        print("DEBUG: ClientService found: '\(mainService.serviceName)'")
        print("DEBUG: ClientService has ndisItem: \(mainService.ndisItem != nil)")
        
        guard let mainNDISItem = mainService.ndisItem else {
            print("DEBUG: ClientService has no ndisItem")
            print("DEBUG: ClientService details:")
            print("  - serviceName: '\(mainService.serviceName)'")
            print("  - ndisItem: \(mainService.ndisItem?.name ?? "nil")")
            return nil
        }
        
        let mainItemNumber = mainNDISItem.itemNumber
        
        // Parse the main NDIS item number to extract components
        let codeComponents = mainItemNumber.split(separator: "_")
        guard codeComponents.count >= 5 else {
            print("DEBUG: Invalid NDIS item number format: \(mainItemNumber)")
            return nil
        }
        
        // NDIS Item Number Structure: SupportCategory_SequenceNumber_RegistrationGroup_OutcomeDomain_SupportPurpose
        let supportCategory = codeComponents[0]
        let _ = codeComponents[1]
        let registrationGroup = codeComponents[2]
        let outcomeDomain = codeComponents[3]
        let supportPurpose = codeComponents[4]
        
        switch chargeType {
        case "labour":
            // Labour travel: Use the SAME item number as the primary support
            // This follows the 'Same Item' principle for travel time claims
            print("DEBUG: Using same item number for labour travel: \(mainItemNumber)")
            return mainNDISItem
            
        case "non-labour":
            // Non-labour travel: Use the '799' rule
            // Replace the sequence number with '799' while keeping all other components the same
            let travelItemNumber = "\(supportCategory)_799_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)"
            print("DEBUG: Using '799' rule for non-labour travel: \(travelItemNumber)")
            return findNDISItemByItemNumber(travelItemNumber)
            
        case "activity-based":
            // Activity-based transport: Use the '590' rule
            // Replace the sequence number with '590' while keeping all other components the same
            let travelItemNumber = "\(supportCategory)_590_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)"
            print("DEBUG: Using '590' rule for activity-based transport: \(travelItemNumber)")
            return findNDISItemByItemNumber(travelItemNumber)
            
        default:
            print("DEBUG: Unknown charge type: \(chargeType)")
            return nil
        }
    }
    
    private func findNDISItemByItemNumber(_ itemNumber: String) -> NDISItemEntity? {
        let resolver = EntityResolutionService(context: context)
        return try? resolver.resolveNDISItem(byItemNumber: itemNumber)
        

    }
    
    /// Finds an NDIS Item by its name (case-insensitive).
    private func findNDISItemByName(_ name: String) -> NDISItemEntity? {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: #Predicate<NDISItemEntity> { item in
                item.name.localizedStandardContains(name)
            }
        )
        
        do {
            let items = try context.fetch(descriptor)
            if let item = items.first {
                print("DEBUG: Found NDIS item with name containing '\(name)': \(item.name)")
                return item
            } else {
                print("DEBUG: No NDIS item found with name containing '\(name)'")
                return nil
            }
        } catch {
            print("DEBUG: Error finding NDIS item with name '\(name)': \(error)")
            return nil
        }
    }
    
    /// Determines if a provider is a therapist (for rate cap calculations).
    private func isTherapistProvider(_ session: SessionEntity) -> Bool {
        let service = session.clientService
        let providerType = NDISTravelChargeCalculator.inferredProviderType(
            itemName: service?.serviceName,
            itemDescription: service?.ndisItem?.itemDescription,
            ndisCode: service?.ndisCode
        )
        return providerType == .therapist
    }
    
    /// Calculates the travel labour rate after provider-specific caps.
    private func calculateTravelRate(for session: SessionEntity, baseRate: Double, mmmZone: MMMZone?) -> Double {
        _ = mmmZone
        let providerType: TravelChargeProviderType = isTherapistProvider(session) ? .therapist : .dsw
        return max(baseRate, 0) * providerType.travelFactor
    }
    
    /// Determines the maximum claimable travel time based on MMM zone.
    private func getMaxTravelTime(for mmmZone: MMMZone?) -> Double {
        NDISTravelChargeCalculator.maxBillableMinutes(forMMMDescriptor: mmmZone?.name)
    }
    
    /// Finds a travel service for the client based on the session's NDIS Item and charge type.
    ///
    /// For labour charges, this returns the same service as the primary support.
    /// For non-labour and activity-based charges, this finds a service with the derived NDIS item.
    private func findTravelService(client: ClientEntity?, session: SessionEntity, chargeType: String) -> ClientServiceEntity? {
        guard let client = client else { return nil }
        
        // For labour charges, use the same service as the primary support
        if chargeType == "labour" {
            if let primaryService = session.clientService {
                print("DEBUG: Using primary service for labour travel: \(primaryService.serviceName)")
                return primaryService
            } else {
                print("DEBUG: No primary service found for labour travel")
                return nil
            }
        }
        
        // For non-labour and activity-based charges, find a service with the mapped NDIS item
        if let travelNDISItem = mapToTravelNDISItem(session: session, chargeType: chargeType) {
            let services = client.clientServices
            let matchingService = services.first { service in
                service.ndisItem?.id == travelNDISItem.id
            }
            
            if let service = matchingService {
                print("DEBUG: Found travel service with NDIS item: \(travelNDISItem.name)")
                return service
            } else {
                print("DEBUG: No client service found with NDIS item: \(travelNDISItem.name)")
            }
        }
        
        // If no mapped service found, return nil
        print("DEBUG: No travel service found for charge type: \(chargeType)")
        return nil
    }
    
}

#if DEBUG
extension TravelChargeAutomationService {
    func _testCalculatedAmount(for chargeType: String, breakdown: NDISTravelChargeBreakdown) -> Double {
        calculatedAmount(for: chargeType, breakdown: breakdown)
    }

    func _testGenerateTravelChargeNotes(
        session: SessionEntity,
        direction: TravelDirection,
        distance: Double?,
        originalDistance: Double?,
        distanceWarnings: [ComplianceViolation],
        travelTime: Double,
        originalTravelTime: Double?,
        travelTimeWarnings: [ComplianceViolation],
        mmmZone: MMMZone,
        vehicleType: String?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int,
        chargeType: String,
        splitCosts: Bool,
        pricingBreakdown: NDISTravelChargeBreakdown
    ) -> String {
        generateTravelChargeNotes(
            session: session,
            direction: direction,
            distance: distance,
            originalDistance: originalDistance,
            distanceWarnings: distanceWarnings,
            travelTime: travelTime,
            originalTravelTime: originalTravelTime,
            travelTimeWarnings: travelTimeWarnings,
            mmmZone: mmmZone,
            vehicleType: vehicleType,
            parking: parking,
            tolls: tolls,
            participantCount: participantCount,
            chargeType: chargeType,
            splitCosts: splitCosts,
            pricingBreakdown: pricingBreakdown
        )
    }

    func _testOverrideNotesSuffix(overrideType: String?, overrideReason: String?) -> String {
        overrideNotesSuffix(overrideType: overrideType, overrideReason: overrideReason)
    }
}
#endif

// MARK: - Supporting Types (Public)

public enum TravelDirection: String, Sendable { case before, after }

public enum TravelChargeError: Error {
    case invalidSession
    case geocodingFailed
    case distanceCalculationFailed
    case complianceViolation
    case reviewRequired
}

public struct BusinessRules {
    public var nonBillableStatuses: Set<String> = ["cancelled", "non-billable"]
    public var maxTravelDistance: Double? = 200.0
    public var allowedChargeTypes: Set<String>? = nil
    public var defaultTravelTime: Double = 30.0 // minutes
    public var defaultMMMZone: MMMZone = MMMZone(name: "MMM 1", maxTime: 30)
    public var defaultParkingCost: Double? = 3.0 // Default parking cost
    public var defaultTollCost: Double? = nil // Default toll cost

    public init() {}
}

public struct UserPreferences {
    public var averageSpeed: Double? = 50.0 // km/h
    public var preferredVehicleType: String? = nil
    public var preferredParkingCost: Double? = nil // User's preferred parking cost
    public var preferredTollCost: Double? = nil // User's preferred toll cost

    public init() {}
}

public struct MMMZone: Sendable {
    public let name: String
    public let maxTime: Double // in minutes

    public init(name: String, maxTime: Double) {
        self.name = name
        self.maxTime = maxTime
    }
}

public struct MMMZoneTable {
    public init() {}

    /// Coordinate-first MMM lookup using polygon data from `MMMZoneLookup`.
    public func lookup(byCoordinate coordinate: CLLocationCoordinate2D) -> MMMZone? {
        guard let mmmCode = MMMZoneLookup.shared.mmm(for: coordinate) else {
            return nil
        }
        return Self.zone(from: mmmCode)
    }

    /// Synchronous postcode lookup (cache-backed only, no network request).
    /// Use `lookup(byPostcode:countryCode:)` for full postcode resolution.
    public func lookup(byPostcode postcode: String) -> MMMZone? {
        let normalized = Self.normalizePostcode(postcode)
        guard let coordinate = MMMPostcodeLookupCache.coordinate(for: normalized) else {
            return nil
        }
        return lookup(byCoordinate: coordinate)
    }

    /// Full postcode lookup via geocoding + polygon lookup.
    /// This resolves postcode -> coordinate, then delegates to `MMMZoneLookup`.
    @MainActor
    public func lookup(byPostcode postcode: String, countryCode: String = "AU") async -> MMMZone? {
        let normalized = Self.normalizePostcode(postcode)
        guard !normalized.isEmpty else { return nil }

        if let cached = MMMPostcodeLookupCache.coordinate(for: normalized) {
            return lookup(byCoordinate: cached)
        }

        let query = "\(normalized), \(countryCode)"
        guard let request = MKGeocodingRequest(addressString: query) else {
            return nil
        }

        do {
            let mapItems = try await request.mapItems
            guard let coordinate = mapItems.first?.location.coordinate else {
                return nil
            }
            MMMPostcodeLookupCache.store(coordinate: coordinate, for: normalized)
            return lookup(byCoordinate: coordinate)
        } catch {
            return nil
        }
    }

    private static func zone(from mmmCode: Int) -> MMMZone {
        let maxTime: Double
        switch mmmCode {
        case 1...3:
            maxTime = 30.0
        case 4...5:
            maxTime = 60.0
        case 6...7:
            maxTime = .infinity
        default:
            maxTime = 30.0
        }
        return MMMZone(name: "MMM \(mmmCode)", maxTime: maxTime)
    }

    private static func normalizePostcode(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter(\.isNumber)
    }
}

private enum MMMPostcodeLookupCache {
    private nonisolated(unsafe) static var byPostcode: [String: CLLocationCoordinate2D] = [:]
    private static let lock = NSLock()

    static func coordinate(for postcode: String) -> CLLocationCoordinate2D? {
        guard !postcode.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return byPostcode[postcode]
    }

    static func store(coordinate: CLLocationCoordinate2D, for postcode: String) {
        guard !postcode.isEmpty else { return }
        lock.lock()
        byPostcode[postcode] = coordinate
        lock.unlock()
    }
}
