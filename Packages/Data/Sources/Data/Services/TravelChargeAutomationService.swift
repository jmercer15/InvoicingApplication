import Foundation
import SwiftData // Use SwiftData
@preconcurrency import MapKit
@preconcurrency import Dispatch

struct ClientDayKey: Hashable {
    let clientId: UUID
    let day: Date
}

// MARK: - Enhanced Error Reporting Structures

/// Detailed violation information for compliance checking
public struct ComplianceViolation: Sendable {
    public let rule: String
    public let currentValue: String
    public let limit: String
    public let description: String
    public let severity: ViolationSeverity
    
    public enum ViolationSeverity: Sendable {
        case warning
        case error
        case critical
    }
}

/// Result of compliance checking with detailed violations
struct ComplianceResult {
    let isCompliant: Bool
    let violations: [ComplianceViolation]
    let warnings: [ComplianceViolation]
    
    var hasErrors: Bool {
        violations.contains { $0.severity == .error || $0.severity == .critical }
    }
    
    var hasWarnings: Bool {
        warnings.contains { $0.severity == .warning }
    }
}

/// Enhanced review item with detailed violation information
public struct DetailedReviewItem: Identifiable {
    public let id = UUID()
    public let session: SessionEntity
    public let reason: String
    public let violations: [ComplianceViolation]
    public let suggestedActions: [String]
    public let overrideOptions: [String]
    public let timestamp: Date
}

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
    
    public init(context: ModelContext, businessRules: BusinessRules, userPreferences: UserPreferences, mmmZoneTable: MMMZoneTable, testingMode: Bool = false) {
        self.context = context
        self.businessRules = businessRules
        self.userPreferences = userPreferences
        self.mmmZoneTable = mmmZoneTable
        self.testingMode = testingMode
    }
    
    /// Main entry point: Automate travel charges for a batch of sessions
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
        let businessDescriptor = FetchDescriptor<BusinessEntity>()
        let business: BusinessEntity? = (try? context.fetch(businessDescriptor))?.first
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
                                            // Check and adjust distance if needed
                                            let (adjustedDistance, distanceWarnings) = self.checkAndAdjustDistance(distance, businessRules: self.businessRules)
                                            
                                            // Check and adjust travel time if needed
                                            let (adjustedTravelTime, travelTimeWarnings) = self.checkAndAdjustTravelTime(travelTime, mmmZone: mmmZone)
                                            
                                            let notes = self.generateTravelChargeNotes(
                                                session: session,
                                                direction: .before,
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
                                                splitCosts: splitCosts
                                            )
                                            let travelCharge = self.createTravelSession(
                                                client: session.client!,
                                                service: service,
                                                startTime: fromTime,
                                                endTime: toTime,
                                                location: toLoc,
                                                mmmZone: mmmZone,
                                                distance: adjustedDistance,
                                                duration: adjustedTravelTime,
                                                vehicleType: vehicleType,
                                                parking: parking,
                                                tolls: tolls,
                                                participantCount: participantCount,
                                                notes: notes,
                                                linkedSession: session,
                                                chargeType: chargeType,
                                                splitCosts: splitCosts,
                                                travelDirection: "before"
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
                                    // Notes
                                    // Check and adjust distance if needed
                                    let (adjustedDistance, distanceWarnings) = self.checkAndAdjustDistance(distance, businessRules: self.businessRules)
                                    
                                    // Check and adjust travel time if needed
                                    let (adjustedTravelTime, travelTimeWarnings) = self.checkAndAdjustTravelTime(travelTime, mmmZone: mmmZone)
                                    
                                    let notes = self.generateTravelChargeNotes(
                                        session: session,
                                        direction: .before,
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
                                        splitCosts: splitCosts
                                    )
                                    // Create and save travel charge entity
                                    let travelCharge = self.createTravelSession(
                                        client: session.client!,
                                        service: service,
                                        startTime: fromTime,
                                        endTime: toTime,
                                        location: toLoc,
                                        mmmZone: mmmZone,
                                        distance: adjustedDistance,
                                        duration: adjustedTravelTime,
                                        vehicleType: vehicleType,
                                        parking: parking,
                                        tolls: tolls,
                                        participantCount: participantCount,
                                        notes: notes,
                                        linkedSession: session,
                                        chargeType: chargeType,
                                        splitCosts: splitCosts,
                                        travelDirection: "before"
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
    
    // MARK: - Main Processing Logic
    
    /// Main logic for processing a single travel direction for a session.
    private func processTravelDirection(session: SessionEntity, direction: TravelDirection, i: Int, daySessions: [SessionInstance]) {
        // 1. Determine from/to locations and times
        let (fromLocation, toLocation, fromTime, toTime): (String?, String?, Date?, Date?) = {
            switch direction {
            case .before:
                let prev = previousNonTravelSession(i: i, daySessions: daySessions)
                return (prev?.session.location ?? session.client?.address?.business?.address?.fullAddressText, session.location, prev?.instanceEnd, session.startTime)
            case .after:
                let next = nextNonTravelSession(i: i, daySessions: daySessions)
                return (session.location, next?.session.location ?? session.client?.address?.business?.address?.fullAddressText, session.endTime, next?.instanceStart)
            }
        }()
        guard let fromLoc = fromLocation, let toLoc = toLocation else {
            self.queueForUserReview(session: session, reason: "Missing from/to location")
            return
        }
        // 2. Geocode both addresses (async)
        geocodeAddress(fromLoc) { fromCoord in
            guard let fromCoord = fromCoord else {
                self.queueForUserReview(session: session, reason: "Geocoding failed for fromLocation")
                return
            }
            self.geocodeAddress(toLoc) { toCoord in
                guard let toCoord = toCoord else {
                    self.queueForUserReview(session: session, reason: "Geocoding failed for toLocation")
                    return
                }
                // 3. Calculate driving distance (async)
                self.calculateDrivingDistance(from: fromCoord, to: toCoord) { distance in
                    guard let distance = distance else {
                        self.queueForUserReview(session: session, reason: "Distance calculation failed")
                        return
                    }
                    // 4. Estimate travel time
                    let travelTime = self.estimateTravelTime(distance: distance) ?? self.businessRules.defaultTravelTime
                    // 5. Lookup MMM zone
                    let mmmZone = self.lookupMMMZone(for: session) ?? self.businessRules.defaultMMMZone
                    // 6. Determine charge types
                    let chargeTypes = self.determineChargeTypes(session: session)
                    for chargeType in chargeTypes {
                        // 7. Check for duplicate
                        if self.travelChargeExists(client: session.client!, session: session, direction: direction, chargeType: chargeType, daySessions: daySessions) {
                            continue
                        }
                        // 8. Check and adjust distance if needed
                        let (adjustedDistance, distanceWarnings) = self.checkAndAdjustDistance(distance, businessRules: self.businessRules)
                        
                        // 8.5. Check and adjust travel time if needed
                        let (adjustedTravelTime, travelTimeWarnings) = self.checkAndAdjustTravelTime(travelTime, mmmZone: mmmZone)
                        
                        // 9. Compliance check (using adjusted distance and travel time)
                        let complianceResult = self.isCompliantWithRules(travelTime: adjustedTravelTime, mmmZone: mmmZone, businessRules: self.businessRules, chargeType: chargeType, distance: adjustedDistance, daySessions: daySessions, session: session)
                        
                        // Only queue for review if there are actual violations (not distance/time adjustments)
                        if !complianceResult.isCompliant {
                            self.queueForUserReview(session: session, reason: "Non-compliant travel charge", violations: complianceResult.violations)
                            continue
                        }
                        
                        // If compliant but has distance/time adjustments, create travel charge with informational notes
                        // Distance and time adjustments are handled automatically and don't require review
                        // 9. Find service using improved NDIS Item mapping
                        let service = self.findTravelService(client: session.client, session: session, chargeType: chargeType)
                        // 10. Shared travel detection and participant count
                        self.detectSharedTravelParticipants(session: session, daySessions: daySessions, direction: direction) { sharedParticipants in
                            let participantCount = self.determineParticipantCount(session: session, sharedParticipants: sharedParticipants)
                            let splitCosts = participantCount > 1
                            // 11. Vehicle, parking, tolls
                            let vehicleType = self.determineVehicleType(session: session, chargeType: chargeType)
                            let parking: Double? = nil // Manual entry only
                            let tolls: Double? = nil // Manual entry only
                            // 12. Notes (including distance adjustment info)
                            let notes = self.generateTravelChargeNotes(
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
                                splitCosts: splitCosts
                            )
                            // 13. Create and save travel charge entity (using adjusted distance)
                            let travelCharge = self.createTravelSession(
                                client: session.client!,
                                service: service,
                                startTime: (direction == .before) ? fromTime : session.endTime,
                                endTime: (direction == .before) ? session.startTime : toTime,
                                location: (direction == .before) ? fromLoc : toLoc,
                                mmmZone: mmmZone,
                                distance: adjustedDistance,
                                duration: adjustedTravelTime,
                                vehicleType: vehicleType,
                                parking: parking,
                                tolls: tolls,
                                participantCount: participantCount,
                                notes: notes,
                                linkedSession: session,
                                chargeType: chargeType,
                                splitCosts: splitCosts,
                                travelDirection: direction == .before ? "before" : "after"
                            )
                            self.saveTravelCharge(travelCharge)
                            self.logAllCreatedTravelCharges()
                        }
                    }
                }
            }
        }
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
        // First check if session has valid coordinates
        if session.sessionLatitude != 0.0 && session.sessionLongitude != 0.0 {
            let coord = CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
            if let mmmCode = MMMZoneLookup.shared.mmm(for: coord) {
                // Map MMM code to appropriate max time based on zone classification
                let maxTime = getMaxTimeForMMMZone(String(mmmCode))
                return MMMZone(name: "MMM Zone \(mmmCode)", maxTime: maxTime)
            }
        }
        
        // If no coordinates available, use default MMM zone
        
        return businessRules.defaultMMMZone
    }
    
    /// Maps MMM zone codes to appropriate max travel times
    private func getMaxTimeForMMMZone(_ mmmCode: String) -> Double {
        // MMM zones are classified as:
        // MM1: Major cities (30 minutes)
        // MM2: Regional cities (45 minutes)
        // MM3: Large rural towns (60 minutes)
        // MM4: Medium rural towns (90 minutes)
        // MM5: Small rural towns (120 minutes)
        // MM6: Remote communities (180 minutes)
        // MM7: Very remote communities (240 minutes)
        
        switch mmmCode {
        case "MM1": return 30.0
        case "MM2": return 45.0
        case "MM3": return 60.0
        case "MM4": return 90.0
        case "MM5": return 120.0
        case "MM6": return 180.0
        case "MM7": return 240.0
        default: return 30.0 // Default to MM1 if unknown
        }
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
        // Add activity-based if eligible (stub: check NDIS code pattern or service property)
        if isActivityBasedEligible(session: session) {
            types.append("activity-based")
        }
        return types
    }
    
    /// Determines if a session/service is eligible for activity-based travel charges.
    private func isActivityBasedEligible(session: SessionEntity) -> Bool {
        // Check if the linked NDISItem's name is 'Activity Based Transport' (case-insensitive)
        if let name = session.clientService?.ndisItem?.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           name == "activity based transport" {
            return true
        }
        return false
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
        var locationCache: [SessionEntity: CLLocationCoordinate2D] = [:]
        let cacheQueue = DispatchQueue(label: "locationCache", attributes: .concurrent)
        let group = DispatchGroup()
        let _ = false
        
        // Helper to geocode and cache
        func geocodeSession(_ s: SessionEntity, completion: @escaping @Sendable (CLLocationCoordinate2D?) -> Void) {
            cacheQueue.sync {
                if let cached = locationCache[s] {
                    completion(cached)
                    return
                }
            }
            geocodeAddress(s.location) { coord in
                if let coord = coord {
                    cacheQueue.async(flags: .barrier) {
                        locationCache[s] = coord
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
                    guard other != session, !other.isTravel else { return false }
                    let otherTime: Date = (direction == .before) ? otherInstance.instanceStart : otherInstance.instanceEnd
                    let timeDiff = abs(otherTime.timeIntervalSince(tTime))
                    guard timeDiff <= timeThreshold else { return false }
                    var oCoord: CLLocationCoordinate2D?
                    cacheQueue.sync {
                        oCoord = locationCache[other]
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
    
    /// Generates a detailed notes string for the travel charge.
    private func generateTravelChargeNotes(session: SessionEntity, direction: TravelDirection, distance: Double?, originalDistance: Double?, distanceWarnings: [ComplianceViolation], travelTime: Double, originalTravelTime: Double?, travelTimeWarnings: [ComplianceViolation], mmmZone: MMMZone, vehicleType: String?, parking: Double?, tolls: Double?, participantCount: Int, chargeType: String, splitCosts: Bool) -> String {
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
        return notes
    }
    
    /// Adds a session to the user review queue for manual intervention.
    private func queueForUserReview(session: SessionEntity, reason: String) {
        queueForUserReview(session: session, reason: reason, violations: [], suggestedActions: [], overrideOptions: [])
    }
    
    /// Adds a session to the user review queue with detailed violation information.
    private func queueForUserReview(session: SessionEntity, reason: String, violations: [ComplianceViolation] = [], suggestedActions: [String] = [], overrideOptions: [String] = []) {
        if testingMode {
            let summary = "Session: \(session.title), Reason: \(reason)"
            testReviewSummaries.append(summary)
            
            // Create detailed review item for testing
            let detailedItem = DetailedReviewItem(
                session: session,
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
        
        let reviewItem = TravelChargeReviewItem(id: UUID())
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
    func fetchReviewItems() -> [TravelChargeReviewItem] {
        let descriptor = FetchDescriptor<TravelChargeReviewItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            print("[TravelChargeAutomation] Failed to fetch review items: \(error)")
            return []
        }
    }
    
    /// Fetches pending review items that need user attention.
    func fetchPendingReviewItems() -> [TravelChargeReviewItem] {
        let descriptor = FetchDescriptor<TravelChargeReviewItem>(
            predicate: #Predicate<TravelChargeReviewItem> { $0.status == "pending" },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        do {
            return try context.fetch(descriptor)
        } catch {
            print("[TravelChargeAutomation] Failed to fetch pending review items: \(error)")
            return []
        }
    }
    
    /// Resolves a review item by creating a travel charge with override.
    public func resolveReviewWithOverride(_ reviewItem: TravelChargeReviewItem, overrideType: String, overrideReason: String? = nil) async throws {
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
    public func resolveReviewBySkipping(_ reviewItem: TravelChargeReviewItem, reason: String? = nil) async throws {
        // Mark the review item as skipped
        reviewItem.skip(reason: reason)
        
        // Log the skip action
        logReviewResolution(reviewItem, action: "skipped", details: reason ?? "User chose to skip")
        
        try context.save()
    }
    
    /// Creates a travel charge for a session with override information.
    private func createTravelChargeForSession(_ session: SessionEntity, overrideType: String? = nil, overrideReason: String? = nil) async throws {
        // This is a simplified version - in a full implementation, you would:
        // 1. Re-run the travel charge calculation logic
        // 2. Apply the override to bypass compliance checks
        // 3. Create the travel charge with override metadata
        
        print("[TravelChargeAutomation] Creating travel charge for session: \(session.title)")
        if let overrideType = overrideType {
            print("[TravelChargeAutomation] Override type: \(overrideType)")
        }
        if let overrideReason = overrideReason {
            print("[TravelChargeAutomation] Override reason: \(overrideReason)")
        }
        
        // For now, we'll just log that this would create a travel charge
        // In a full implementation, you would call the existing travel charge creation logic
        // with override flags set
    }
    
    /// Logs review resolution for audit purposes.
    private func logReviewResolution(_ reviewItem: TravelChargeReviewItem, action: String, details: String) {
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
            let summary = "Client: \(clientName), Session: \(sessionTitle), Type: \(type), Distance: \(dist) km, Direction: \(dir)"
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
    private func logReviewItem(_ reviewItem: TravelChargeReviewItem, action: String = "flagged") {
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
        let descriptor = FetchDescriptor<TravelChargeAuditLog>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        do {
            return try context.fetch(descriptor)
        } catch {
            print("[TravelChargeAutomation] Failed to fetch audit logs: \(error)")
            return []
        }
    }
    
    public func getTestResults() -> (charges: [String], reviews: [String], detailedReviews: [DetailedReviewItem]) {
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
        
        let group = DispatchGroup()
        let resultsQueue = DispatchQueue(label: "validationResults", attributes: .concurrent)
        var results: [Bool] = Array(repeating: false, count: totalCount)
        
        for (index, address) in addressesToValidate.enumerated() {
            group.enter()
            validateAddress(address) { success in
                resultsQueue.async(flags: .barrier) {
                    results[index] = success
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let validatedCount = results.filter { $0 }.count
            completion(validatedCount, totalCount)
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
        
        let group = DispatchGroup()
        let resultsQueue = DispatchQueue(label: "validationResults2", attributes: .concurrent)
        var results: [Bool] = Array(repeating: false, count: totalCount)
        
        for (index, address) in addressesToValidate.enumerated() {
            group.enter()
            validateAddress(address) { success in
                resultsQueue.async(flags: .barrier) {
                    results[index] = success
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            let validatedCount = results.filter { $0 }.count
            completion(validatedCount, totalCount)
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
    
    // Add all other helper stubs as per the pseudocode, e.g.:
    // - getPreviousNonTravelSession
    // - getNextNonTravelSession
    // - geocodeAddress
    // - calculateDrivingDistance
    // - estimateTravelTime
    // - lookupMMMZone
    // - determineChargeTypes
    // - findNonLabourService
    // - detectSharedTravelParticipants
    // - travelChargeExists
    // - generateTravelChargeNotes
    // - isCompliantWithRules
    // - createTravelSession
    // - saveTravelSession
    // - linkTravelSessionToParticipants
    // - getRecurrenceInstances
    // - queueForUserReview
    // - logAllCreatedTravelCharges
    // - offerBulkUpdateOfTravelCharges
    // - businessRulesChanged
    
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
    
    /// Finds an NDIS Item by its item number.
    private func findNDISItemByItemNumber(_ itemNumber: String) -> NDISItemEntity? {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            predicate: #Predicate<NDISItemEntity> { item in
                item.itemNumber == itemNumber
            }
        )
        
        do {
            let items = try context.fetch(descriptor)
            if let item = items.first {
                print("DEBUG: Found NDIS item with item number \(itemNumber): \(item.name)")
                return item
            } else {
                print("DEBUG: No NDIS item found with item number \(itemNumber)")
                return nil
            }
        } catch {
            print("DEBUG: Error finding NDIS item with item number \(itemNumber): \(error)")
            return nil
        }
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
        guard let clientService = session.clientService,
              let ndisItem = clientService.ndisItem else { return false }
        
        // Check if the NDIS item indicates therapy services
        let itemName = ndisItem.name.lowercased()
        let itemDescription = ndisItem.itemDescription?.lowercased() ?? ""
        
        let therapyKeywords = [
            "therapy", "therapist", "physiotherapist", "psychologist", "dietitian",
            "occupational", "speech", "assessment", "training"
        ]
        
        return therapyKeywords.contains { keyword in
            itemName.contains(keyword) || itemDescription.contains(keyword)
        }
    }
    
    /// Calculates the appropriate travel rate based on provider type and MMM zone.
    private func calculateTravelRate(for session: SessionEntity, baseRate: Double, mmmZone: MMMZone?) -> Double {
        var adjustedRate = baseRate
        
        // Apply therapist rate cap (50% for therapy providers)
        if isTherapistProvider(session) {
            adjustedRate = baseRate * 0.5
            print("DEBUG: Applied 50% rate cap for therapist provider")
        }
        
        // Apply MMM zone price loadings
        if let mmmZone = mmmZone {
            switch mmmZone.name {
            case "MMM 6":
                adjustedRate = adjustedRate * 1.4 // 40% loading for remote areas
                print("DEBUG: Applied 40% loading for MMM 6 zone")
            case "MMM 7":
                adjustedRate = adjustedRate * 1.5 // 50% loading for very remote areas
                print("DEBUG: Applied 50% loading for MMM 7 zone")
            default:
                // No loading for MMM 1-5 zones
                break
            }
        }
        
        return adjustedRate
    }
    
    /// Determines the maximum claimable travel time based on MMM zone.
    private func getMaxTravelTime(for mmmZone: MMMZone?) -> Double {
        guard let mmmZone = mmmZone else { return 30.0 } // Default to 30 minutes
        
        switch mmmZone.name {
        case "MMM 1", "MMM 2", "MMM 3":
            return 30.0 // 30 minutes for major cities and regional centres
        case "MMM 4", "MMM 5":
            return 60.0 // 60 minutes for regional areas
        case "MMM 6", "MMM 7":
            return Double.infinity // No time cap for remote areas (by agreement)
        default:
            return 30.0 // Default to 30 minutes
        }
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
    public var defaultMMMZone: MMMZone = MMMZone(name: "Default", maxTime: 30)
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
    
    /// Looks up the MMM zone for a given postcode using the existing MMMZoneLookup tool.
    public func lookup(byPostcode postcode: String) -> MMMZone? {
        // Use the existing MMMZoneLookup tool for coordinate-based lookup
        // For postcode-based lookup, we would need to geocode the postcode first
        // This is a simplified implementation - in production you might want to cache results

        // For now, return a default zone based on postcode patterns
        // In a real implementation, you would:
        // 1. Geocode the postcode to get coordinates
        // 2. Use MMMZoneLookup.shared.mmm(for: coordinates)
        // 3. Map the result to appropriate max time

        let postcodeInt = Int(postcode) ?? 0

        // Simple postcode-based classification (Australian postcodes)
        if postcodeInt >= 2000 && postcodeInt <= 2999 {
            return MMMZone(name: "MM1 - Major Cities", maxTime: 30.0)
        } else if postcodeInt >= 3000 && postcodeInt <= 3999 {
            return MMMZone(name: "MM2 - Regional Cities", maxTime: 45.0)
        } else if postcodeInt >= 4000 && postcodeInt <= 4999 {
            return MMMZone(name: "MM3 - Large Rural Towns", maxTime: 60.0)
        } else if postcodeInt >= 5000 && postcodeInt <= 5999 {
            return MMMZone(name: "MM4 - Medium Rural Towns", maxTime: 90.0)
        } else if postcodeInt >= 6000 && postcodeInt <= 6999 {
            return MMMZone(name: "MM5 - Small Rural Towns", maxTime: 120.0)
        } else if postcodeInt >= 7000 && postcodeInt <= 7999 {
            return MMMZone(name: "MM6 - Remote Communities", maxTime: 180.0)
        } else if postcodeInt >= 8000 && postcodeInt <= 8999 {
            return MMMZone(name: "MM7 - Very Remote Communities", maxTime: 240.0)
        } else {
            return MMMZone(name: "Default", maxTime: 30.0)
        }
    }
}
