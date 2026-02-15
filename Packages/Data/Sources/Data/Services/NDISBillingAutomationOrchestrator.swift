import Foundation
import SwiftData
import MapKit
import CoreLocation
import Core

// swiftlint:disable concurrency

/// Orchestrates the NDIS billing automation flow with proper async execution
/// Provides comprehensive error handling, validation, and status tracking
public class NDISBillingAutomationOrchestrator: @unchecked Sendable {
    private let modelContext: ModelContext
    private let geocodingService: GeocodingService
    private let mapKitTravelService: MapKitTravelService
    private let mmmZoneLookup: MMMZoneLookup
    private var unitOfWork: UnitOfWorkService?
    
    // Configuration constants
    private let geocodingTimeout: TimeInterval = 30.0
    private let travelDistanceThreshold: Double = 0.5 // km
    private let eveningStartHour = 18 // 6 PM
    private let eveningEndHour = 22 // 10 PM
    private let nightStartHour = 22 // 10 PM
    private let nightEndHour = 6 // 6 AM
    
    /// Initialize with ModelContext (legacy pattern)
    @MainActor
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.geocodingService = GeocodingService.shared
        self.mapKitTravelService = MapKitTravelService.shared
        self.mmmZoneLookup = MMMZoneLookup.shared
        self.unitOfWork = nil
    }
    
    /// Initialize with UnitOfWorkService (preferred pattern)
    @MainActor
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
        
        // Extract ModelContext from UnitOfWork (Legacy support)
        if let swiftData = unitOfWork as? SwiftDataUnitOfWork {
            self.modelContext = swiftData.legacyModelContext
        } else {
            // This is a critical failure because the orchestrator relies on ModelContext.
            fatalError("NDISBillingAutomationOrchestrator requires SwiftDataUnitOfWork")
        }
        
        self.geocodingService = GeocodingService.shared
        self.mapKitTravelService = MapKitTravelService.shared
        self.mmmZoneLookup = MMMZoneLookup.shared
    }
    
    /// Initialize with UnitOfWorkService and explicit ModelContext
    @MainActor
    public init(unitOfWork: UnitOfWorkService, modelContext: ModelContext) {
        self.unitOfWork = unitOfWork
        self.modelContext = modelContext
        self.geocodingService = GeocodingService.shared
        self.mapKitTravelService = MapKitTravelService.shared
        self.mmmZoneLookup = MMMZoneLookup.shared
    }

    @MainActor
    private static func performGeocoding(session: SessionEntity, geocodingService: GeocodingService, modelContext: ModelContext) async -> Bool {
        // Extract only the necessary data to avoid concurrency issues
        let sessionId = session.id
        let address = session.address
        let clientId = session.client?.id
        
        // Call a method that doesn't require the full entity
        return await performGeocodingForSession(
            sessionId: sessionId,
            address: address,
            clientId: clientId,
            geocodingService: geocodingService,
            modelContext: modelContext
        )
    }
    
    @MainActor
    private static func performGeocodingForSession(
        sessionId: UUID,
        address: AddressEntity?,
        clientId: UUID?,
        geocodingService: GeocodingService,
        modelContext: ModelContext
    ) async -> Bool {
        // Use GeocodingService to geocode the session if coordinates are missing
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let sessionEntity = try? entityResolver.resolveSession(id: sessionId) else {
            return false
        }
        
        // Call the async geocoding service method
        return await geocodingService.ensureCoordinatesForSession(sessionEntity, modelContext: modelContext)
    }
    
    @MainActor
    static func create(modelContext: ModelContext) -> NDISBillingAutomationOrchestrator {
        return NDISBillingAutomationOrchestrator(modelContext: modelContext)
    }
    
    /// Executes the complete automation flow for a session (Domain Model)
    /// This is the preferred entry point for Feature layers.
    /// - Parameters:
    ///   - session: The session (Domain Model) to automate billing context for
    ///   - context: The billing context to populate
    ///   - progressHandler: Optional progress handler for UI updates
    /// - Returns: Automation result with status and any errors
    @MainActor
    public func executeAutomationFlow(
        for session: Session,
        context: inout NDISBillingContext,
        progressHandler: ((AutomationProgress) -> Void)? = nil
    ) async -> AutomationResult {
        // Resolve entity internally
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let sessionEntity = try? entityResolver.resolveSession(id: session.id) else {
            var result = AutomationResult()
            result.markFailed()
            result.addError("Could not resolve SessionEntity for session ID: \(session.id)")
            return result
        }
        
        // Delegate to entity-based method
        return await executeAutomationFlow(for: sessionEntity, context: &context, progressHandler: progressHandler)
    }
    
    /// Executes the complete automation flow for a session asynchronously
    /// - Parameters:
    ///   - session: The session to automate billing context for
    ///   - context: The billing context to populate
    ///   - progressHandler: Optional progress handler for UI updates
    /// - Returns: Automation result with status and any errors
    @MainActor
    public func executeAutomationFlow(
        for session: SessionEntity, 
        context: inout NDISBillingContext,
        progressHandler: ((AutomationProgress) -> Void)? = nil
    ) async -> AutomationResult {
        print("🚀 [NDIS Automation] Starting async automation flow for session: \(session.id.uuidString)")
        
        var result = AutomationResult()
        
        // Pre-flight validation
        progressHandler?(AutomationProgress(step: .validating, message: "Validating session data..."))
        guard await performPreFlightValidation(session: session, result: &result) else {
            return result
        }
        
        // Execute automation steps
        let steps: [AutomationStep] = [
            .validateSessionData,
            .ensureCoordinatesAvailable,
            .calculateTravelDetails,
            .determineGeographicContext,
            .determineTimeContext,
            .determineTravelContext,
            .determineServiceTypeContext
        ]
        
        for (index, step) in steps.enumerated() {
            let progress = Double(index) / Double(steps.count)
            progressHandler?(AutomationProgress(step: step.progressStep, message: step.progressMessage, progress: progress))
            
            guard await executeStep(step, for: session, context: &context, result: &result) else {
                result.markFailed()
                return result
            }
        }
        
        progressHandler?(AutomationProgress(step: .completed, message: "Automation completed", progress: 1.0))
        result.markCompleted()
        print("✅ [NDIS Automation] Async automation flow completed successfully")
        return result
    }
    
    // MARK: - Pre-flight Validation
    
    private func performPreFlightValidation(session: SessionEntity, result: inout AutomationResult) async -> Bool {
        print("🔍 [NDIS Automation] Performing pre-flight validation")
        
        // Check for nil session
        guard session.id != UUID() else {
            result.addError("Invalid session: session ID is nil")
            return false
        }
        
        // Check for required session properties
        let requiredProperties: [(String, Any?)] = [
            ("startTime", session.startTime),
            ("clientService", session.clientService),
            ("client", session.client)
        ]
        
        for (propertyName, value) in requiredProperties {
            if value == nil {
                result.addError("Session missing required property: \(propertyName)")
                return false
            }
        }
        
        // Check for NDIS item
        guard let ndisItem = session.clientService?.ndisItem else {
            result.addError("Session has no associated NDIS item")
            return false
        }
        
        // Validate NDIS item
        guard !ndisItem.itemNumber.isEmpty else {
            result.addError("NDIS item has empty item number")
            return false
        }
        
        print("✅ [NDIS Automation] Pre-flight validation passed")
        return true
    }
    
    // MARK: - Step Execution
    
    private enum AutomationStep {
        case validateSessionData
        case ensureCoordinatesAvailable
        case calculateTravelDetails
        case determineGeographicContext
        case determineTimeContext
        case determineTravelContext
        case determineServiceTypeContext
        
        var progressStep: ProgressStep {
            switch self {
            case .validateSessionData: return .validating
            case .ensureCoordinatesAvailable: return .geocoding
            case .calculateTravelDetails: return .calculatingTravel
            case .determineGeographicContext: return .determiningGeographic
            case .determineTimeContext: return .determiningTime
            case .determineTravelContext: return .determiningTravel
            case .determineServiceTypeContext: return .determiningServiceType
            }
        }
        
        var progressMessage: String {
            switch self {
            case .validateSessionData: return "Validating session data..."
            case .ensureCoordinatesAvailable: return "Ensuring coordinates are available..."
            case .calculateTravelDetails: return "Calculating travel details..."
            case .determineGeographicContext: return "Determining geographic context..."
            case .determineTimeContext: return "Determining time context..."
            case .determineTravelContext: return "Determining travel context..."
            case .determineServiceTypeContext: return "Determining service type context..."
            }
        }
    }
    
    @MainActor
    private func executeStep(_ step: AutomationStep, for session: SessionEntity, context: inout NDISBillingContext, result: inout AutomationResult) async -> Bool {
        switch step {
        case .validateSessionData:
            return await validateSessionData(session, result: &result)
        case .ensureCoordinatesAvailable:
            return await ensureCoordinatesAvailable(for: session, result: &result)
        case .calculateTravelDetails:
            let travelDetails = await calculateTravelDetails(for: session, result: &result)
            // Store travel details for later use
            if let details = travelDetails {
                context.travelDistance = details.distance
                context.travelTime = details.time
                context.autoDeterminedValues.insert(.travelDetails)
            }
            return true // This step can succeed even without travel details
        case .determineGeographicContext:
            await determineGeographicContext(for: session, context: &context, result: &result)
            return true
        case .determineTimeContext:
            await determineTimeContext(for: session, context: &context, result: &result)
            return true
        case .determineTravelContext:
            let travelDetails = context.travelDistance > 0 ? MapKitTravelService.TravelDetails(distance: context.travelDistance, time: context.travelTime) : nil
            await determineTravelContext(for: session, context: &context, travelDetails: travelDetails, result: &result)
            return true
        case .determineServiceTypeContext:
            await determineServiceTypeContext(for: session, context: &context, result: &result)
            return true
        }
    }
    
    // MARK: - Step 1: Validation
    
    private func validateSessionData(_ session: SessionEntity, result: inout AutomationResult) async -> Bool {
        print("🔍 [NDIS Automation] Step 1: Validating session data")
        result.updateStatus(.validating)
        
        // Validate session has required data
        guard let startTime = session.startTime else {
            result.addError("Session has no start time")
            return false
        }
        
        guard let clientService = session.clientService else {
            result.addError("Session has no client service")
            return false
        }
        
        guard let ndisItem = clientService.ndisItem else {
            result.addError("Session has no NDIS item")
            return false
        }
        
        // Validate NDIS item properties
        guard !ndisItem.itemNumber.isEmpty else {
            result.addError("NDIS item has empty item number")
            return false
        }
        
        // Validate session dates
        let now = Date()
        if startTime > now {
            result.addWarning("Session start time is in the future")
        }
        
        if let endTime = session.endTime, endTime < startTime {
            result.addError("Session end time is before start time")
            return false
        }
        
        print("✅ [NDIS Automation] Session data validation passed")
        return true
    }
    
    // MARK: - Step 2: Coordinate Availability
    
    private nonisolated func ensureCoordinatesAvailable(for session: SessionEntity, result: inout AutomationResult) async -> Bool {
        print("🌍 [NDIS Automation] Step 2: Ensuring coordinates are available")
        result.updateStatus(.geocoding)
        
        // Check if session already has valid coordinates
        if hasValidCoordinates(session) {
            print("✅ [NDIS Automation] Session already has valid coordinates")
            return true
        }
        
        // Check if session has location data to geocode
        guard let location = getSessionLocation(session) else {
            result.addError("Session has no location data to geocode")
            return false
        }
        
        print("🌍 [NDIS Automation] Geocoding session location: \(location)")
        
        // Simplified approach: perform geocoding sequentially to avoid concurrency issues
        let sessionId = session.id
        let address = session.address
        let clientId = session.client?.id
        
        let geocodingSuccess = await NDISBillingAutomationOrchestrator.performGeocodingForSession(
            sessionId: sessionId,
            address: address,
            clientId: clientId,
            geocodingService: self.geocodingService,
            modelContext: self.modelContext
        )
        
        if geocodingSuccess {
            print("✅ [NDIS Automation] Session coordinates set successfully")
        } else {
            print("❌ [NDIS Automation] Failed to geocode session location")
            result.addError("Failed to geocode session location")
        }
        
        // Verify coordinates were actually set
        if geocodingSuccess && !hasValidCoordinates(session) {
            result.addError("Geocoding succeeded but coordinates were not set")
            return false
        }
        
        return geocodingSuccess
    }
    
    // MARK: - Step 3: Travel Calculation
    
    private func calculateTravelDetails(for session: SessionEntity, result: inout AutomationResult) async -> MapKitTravelService.TravelDetails? {
        print("🗺️ [NDIS Automation] Step 3: Calculating travel details")
        result.updateStatus(.calculatingTravel)
        
        // Check if we have valid coordinates for travel calculation
        guard hasValidCoordinates(session) else {
            print("⚠️ [NDIS Automation] Cannot calculate travel details - no valid coordinates")
            result.addWarning("Cannot calculate travel details - no valid coordinates")
            return nil
        }
        
        // Extract all data outside the TaskGroup to avoid concurrency issues
        let sessionId = session.id
        let clientId = session.client?.id
        let location = session.location
        
        // Simplified approach: perform travel calculation sequentially to avoid concurrency issues
        let travelDetails = await self.mapKitTravelService.calculateTravelDetailsForSession(
            sessionId: sessionId,
            clientId: clientId,
            startAddress: location,
            endAddress: location, // Use same location as a conservative fallback when only one location is provided.
            modelContext: self.modelContext
        )
        
        if let details = travelDetails {
            // Validate travel details
            if details.distance < 0 {
                print("⚠️ [NDIS Automation] Invalid travel distance: \(details.distance)")
                result.addWarning("Invalid travel distance: \(details.distance)")
                return nil
            }
            
            if details.time < 0 {
                print("⚠️ [NDIS Automation] Invalid travel time: \(details.time)")
                result.addWarning("Invalid travel time: \(details.time)")
                return nil
            }
            
            print("✅ [NDIS Automation] Travel details calculated - Distance: \(details.distance) km, Time: \(details.time) minutes")
            return details
        } else {
            print("⚠️ [NDIS Automation] Travel calculation failed")
            result.addWarning("Travel calculation failed")
            return nil
        }
    }
    
    // MARK: - Step 4: Geographic Context
    
    private func determineGeographicContext(for session: SessionEntity, context: inout NDISBillingContext, result: inout AutomationResult) async {
        print("🌍 [NDIS Automation] Step 4: Determining geographic context")
        result.updateStatus(.determiningGeographic)
        
        guard hasValidCoordinates(session) else {
            print("⚠️ [NDIS Automation] Cannot determine geographic context - no valid coordinates")
            result.addWarning("Cannot determine geographic context - no valid coordinates")
            return
        }
        
        // Get coordinates (prefer session coordinates, fall back to address coordinates)
        let coordinate: CLLocationCoordinate2D
        if session.sessionLatitude != 0.0 && session.sessionLongitude != 0.0 {
            coordinate = CLLocationCoordinate2D(
                latitude: session.sessionLatitude,
                longitude: session.sessionLongitude
            )
        } else if let address = session.address, address.latitude != 0.0 && address.longitude != 0.0 {
            coordinate = CLLocationCoordinate2D(
                latitude: address.latitude,
                longitude: address.longitude
            )
            print("🌍 [NDIS Automation] Using session address coordinates for geographic context")
        } else {
            print("⚠️ [NDIS Automation] No coordinates available for geographic context")
            result.addWarning("No coordinates available for geographic context")
            return
        }
        
        if let mmmCode = mmmZoneLookup.mmm(for: coordinate) {
            print("🌍 [NDIS Automation] MMM zone found: \(mmmCode)")
            
            switch mmmCode {
            case 4:
                context.isRemoteArea = true
                context.isVeryRemoteArea = false
                context.autoDeterminedValues.insert(.remoteArea)
                context.autoDeterminedValues.insert(.veryRemoteArea)
                print("✅ [NDIS Automation] Set Remote Area (MMM Zone 4)")
            case 5:
                context.isRemoteArea = false
                context.isVeryRemoteArea = true
                context.autoDeterminedValues.insert(.remoteArea)
                context.autoDeterminedValues.insert(.veryRemoteArea)
                print("✅ [NDIS Automation] Set Very Remote Area (MMM Zone 5)")
            default:
                context.isRemoteArea = false
                context.isVeryRemoteArea = false
                context.autoDeterminedValues.insert(.remoteArea)
                context.autoDeterminedValues.insert(.veryRemoteArea)
                print("✅ [NDIS Automation] No geographic modifier applied (MMM Zone \(mmmCode))")
            }
        } else {
            print("⚠️ [NDIS Automation] No MMM zone found for coordinates")
            result.addWarning("No MMM zone found for session coordinates")
            // Set defaults
            context.isRemoteArea = false
            context.isVeryRemoteArea = false
            context.autoDeterminedValues.insert(.remoteArea)
            context.autoDeterminedValues.insert(.veryRemoteArea)
        }
    }
    
    // MARK: - Step 5: Time Context
    
    private func determineTimeContext(for session: SessionEntity, context: inout NDISBillingContext, result: inout AutomationResult) async {
        print("⏰ [NDIS Automation] Step 5: Determining time context")
        result.updateStatus(.determiningTime)
        
        guard let startTime = session.startTime else {
            result.addError("Session has no start time")
            return
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekday, .hour], from: startTime)
        
        // Weekend check
        if let weekday = components.weekday {
            let isWeekend = weekday == 1 || weekday == 7 // Sunday or Saturday
            context.isWeekend = isWeekend
            context.autoDeterminedValues.insert(.weekend)
            if isWeekend {
                print("✅ [NDIS Automation] Set Weekend (Day \(weekday))")
            }
        }
        
        // Evening/Night check
        if let hour = components.hour {
            let isEvening = hour >= eveningStartHour && hour < eveningEndHour
            let isNight = hour >= nightStartHour || hour < nightEndHour
            
            context.isEvening = isEvening
            context.isNight = isNight
            context.autoDeterminedValues.insert(.evening)
            context.autoDeterminedValues.insert(.night)
            
            if isEvening {
                print("✅ [NDIS Automation] Set Evening (Hour \(hour))")
            } else if isNight {
                print("✅ [NDIS Automation] Set Night (Hour \(hour))")
            }
        }
        
        // Public holiday check (simplified - would need holiday calendar integration)
        let isPublicHoliday = false
        context.isPublicHoliday = isPublicHoliday
        context.autoDeterminedValues.insert(.publicHoliday)
        
        print("✅ [NDIS Automation] Time context determined")
    }
    
    // MARK: - Step 6: Travel Context
    
    private func determineTravelContext(for session: SessionEntity, context: inout NDISBillingContext, travelDetails: MapKitTravelService.TravelDetails?, result: inout AutomationResult) async {
        print("🚗 [NDIS Automation] Step 6: Determining travel context")
        result.updateStatus(.determiningTravel)
        
        // Determine provider travel eligibility
        let shouldSetProviderTravel = determineProviderTravelEligibility(for: session, context: context)
        
        context.isProviderTravel = shouldSetProviderTravel
        context.autoDeterminedValues.insert(.providerTravel)
        
        if shouldSetProviderTravel {
            print("✅ [NDIS Automation] Set Provider Travel")
        }
        
        // Determine activity transport eligibility
        let isActivityTransport = isActivityBasedEligible(session: session)
        context.isActivityTransport = isActivityTransport
        context.autoDeterminedValues.insert(.activityTransport)
        
        if isActivityTransport {
            print("✅ [NDIS Automation] Set Activity Transport")
        }
        
        print("✅ [NDIS Automation] Travel context determined")
    }
    
    // MARK: - Step 7: Service Type Context
    
    private func determineServiceTypeContext(for session: SessionEntity, context: inout NDISBillingContext, result: inout AutomationResult) async {
        print("🏥 [NDIS Automation] Step 7: Determining service type context")
        result.updateStatus(.determiningServiceType)
        
        // Check group support
        let attendeesCount = session.attendeesCount
        let isGroupSupport = attendeesCount > 1
        
        context.isGroupSupport = isGroupSupport
        context.groupSize = Int(attendeesCount)
        context.autoDeterminedValues.insert(.groupSupport)
        
        if isGroupSupport {
            print("✅ [NDIS Automation] Set Group Support (size: \(attendeesCount))")
        }
        
        // Check short notice cancellation
        let isCancelled = determineCancellationStatus(session: session)
        context.isShortNoticeCancellation = isCancelled
        context.autoDeterminedValues.insert(.shortNoticeCancellation)
        
        if isCancelled {
            print("✅ [NDIS Automation] Set Short Notice Cancellation")
        }
        
        print("✅ [NDIS Automation] Service type context determined")
    }
    
    // MARK: - Helper Methods
    
    private func hasValidCoordinates(_ session: SessionEntity) -> Bool {
        // Check session coordinates first
        let hasSessionCoords = session.sessionLatitude != 0.0 && 
                              session.sessionLongitude != 0.0 &&
                              session.sessionLatitude >= -90.0 && session.sessionLatitude <= 90.0 &&
                              session.sessionLongitude >= -180.0 && session.sessionLongitude <= 180.0
        
        if hasSessionCoords {
            return true
        }
        
        // Fall back to session address coordinates if available
        if let address = session.address {
            let hasAddressCoords = address.latitude != 0.0 && 
                                  address.longitude != 0.0 &&
                                  address.latitude >= -90.0 && address.latitude <= 90.0 &&
                                  address.longitude >= -180.0 && address.longitude <= 180.0
            return hasAddressCoords
        }
        
        return false
    }
    
    private func getSessionLocation(_ session: SessionEntity) -> String? {
        if let location = session.location, !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return location
        }
        if let address = session.address {
            let fullAddress = address.fullFormattedAddress
            if !fullAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return fullAddress
            }
        }
        return nil
    }
    
    private func determineProviderTravelEligibility(for session: SessionEntity, context: NDISBillingContext) -> Bool {
        // Check if session is explicitly marked as travel
        if session.isTravel {
            return true
        }
        
        // Check if calculated distance exceeds threshold
        if context.travelDistance > travelDistanceThreshold {
            return true
        }
        
        // Check if NDIS item supports provider travel
        if let ndisItem = session.clientService?.ndisItem,
           ndisItem.providerTravel == true {
            return true
        }
        
        // Check if session has valid coordinates and business has coordinates
        if hasValidCoordinates(session) && hasBusinessCoordinates() {
            return true
        }
        
        return false
    }
    
    private func hasBusinessCoordinates() -> Bool {
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let business = try? entityResolver.resolveBusiness(),
              let businessAddress = business.address else {
            return false
        }
        
        return businessAddress.latitude != 0 && businessAddress.longitude != 0
    }
    
    private func isActivityBasedEligible(session: SessionEntity) -> Bool {
        guard let ndisItem = session.clientService?.ndisItem else { return false }
        
        let itemNumber = ndisItem.itemNumber
        
        // Check for transport-related support categories (02 = Transport)
        if itemNumber.hasPrefix("02_") {
            return true
        }
        
        // Check for specific activity transport item numbers (590 series)
        if itemNumber.contains("_590_") {
            return true
        }
        
        // Check item name for transport-related keywords
        let name = ndisItem.name.lowercased()
        let transportKeywords = ["transport", "travel", "community access", "participation", "community participation"]
        if transportKeywords.contains(where: { name.contains($0) }) {
            return true
        }
        
        return false
    }
    
    private func determineCancellationStatus(session: SessionEntity) -> Bool {
        guard let status = session.status?.rawValue.lowercased() else { return false }
        
        let cancelledStatuses = [
            "cancelled", "canceled", "cancellation", 
            "cancelled by client", "cancelled by provider",
            "no show", "no-show", "no_show"
        ]
        
        return cancelledStatuses.contains(status)
    }
    
    // MARK: - Async Utilities
    
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            // swiftlint:disable:next closure_captures
            group.addTask {
                try await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Support Methods for UI Components
    
    /// Determines if complex behavior support is available based on NDIS item capabilities
    public func isComplexBehaviorSupported(for session: Session) -> Bool {
        // Use domain model properties if available, or fetch
        guard session.clientServiceId != nil else { return false }
        
        // Resolve via entity context so UI toggles can evaluate synchronously.
        
        // Actually, let's just resolve it internally using the context we have.
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let sessionEntity = try? entityResolver.resolveSession(id: session.id) else { return false }
        return isComplexBehaviorSupported(for: sessionEntity)
    }

    /// Determines if complex behavior support is available based on NDIS item capabilities
    public func isComplexBehaviorSupported(for session: SessionEntity) -> Bool {
        guard let ndisItem = session.clientService?.ndisItem else { return false }
        
        let itemName = ndisItem.name.lowercased()
        let complexBehaviorKeywords = ["complex", "challenging", "behavior", "behaviour", "intensive", "high intensity"]
        return complexBehaviorKeywords.contains(where: { itemName.contains($0) })
    }
    
    /// Determines if high intensity support is available based on NDIS item capabilities
    public func isHighIntensitySupported(for session: Session) -> Bool {
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let sessionEntity = try? entityResolver.resolveSession(id: session.id) else { return false }
        return isHighIntensitySupported(for: sessionEntity)
    }

    /// Determines if high intensity support is available based on NDIS item capabilities
    public func isHighIntensitySupported(for session: SessionEntity) -> Bool {
        guard let ndisItem = session.clientService?.ndisItem else { return false }
        
        let itemName = ndisItem.name.lowercased()
        let intensityKeywords = ["intensive", "high intensity", "complex", "challenging", "high support"]
        return intensityKeywords.contains(where: { itemName.contains($0) })
    }
    
    /// Determines if special circumstances are available based on NDIS item capabilities
    public func areSpecialCircumstancesSupported(for session: Session) -> (shadowShift: Bool, silUnplannedExit: Bool, ndiaReport: Bool) {
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let sessionEntity = try? entityResolver.resolveSession(id: session.id) else {
            return (shadowShift: false, silUnplannedExit: false, ndiaReport: false)
        }
        return areSpecialCircumstancesSupported(for: sessionEntity)
    }

    /// Determines if special circumstances are available based on NDIS item capabilities
    public func areSpecialCircumstancesSupported(for session: SessionEntity) -> (shadowShift: Bool, silUnplannedExit: Bool, ndiaReport: Bool) {
        guard let ndisItem = session.clientService?.ndisItem else {
            return (shadowShift: false, silUnplannedExit: false, ndiaReport: false)
        }
        
        let itemName = ndisItem.name.lowercased()
        let shadowShiftSupported = itemName.contains("complex") || itemName.contains("challenging") || itemName.contains("behavior")
        let silUnplannedExitSupported = ndisItem.irregularSILSupports == true
        let ndiaReportSupported = ndisItem.ndiaRequestedReports == true
        
        return (shadowShift: shadowShiftSupported, silUnplannedExit: silUnplannedExitSupported, ndiaReport: ndiaReportSupported)
    }
    
    /// Maps a session's NDIS Item to the corresponding travel NDIS Item based on NDIS rules
    public func mapToTravelNDISItem(session: Session, chargeType: String) -> NDISItem? {
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let sessionEntity = try? entityResolver.resolveSession(id: session.id) else { return nil }
        
        let entity = mapToTravelNDISItem(session: sessionEntity, chargeType: chargeType)
        guard let entity = entity else { return nil }
        
        // Map back to domain model
        return NDISItemMapper().mapToDomain(entity)
    }

    /// Maps a session's NDIS Item to the corresponding travel NDIS Item based on NDIS rules
    public func mapToTravelNDISItem(session: SessionEntity, chargeType: String) -> NDISItemEntity? {
        guard let mainService = session.clientService,
              let mainNDISItem = mainService.ndisItem else { return nil }
        
        let mainItemNumber = mainNDISItem.itemNumber
        
        // Parse the main NDIS item number to extract components
        let codeComponents = mainItemNumber.split(separator: "_")
        guard codeComponents.count >= 5 else { return nil }
        
        // NDIS Item Number Structure: SupportCategory_SequenceNumber_RegistrationGroup_OutcomeDomain_SupportPurpose
        let supportCategory = codeComponents[0]
        let registrationGroup = codeComponents[2]
        let outcomeDomain = codeComponents[3]
        let supportPurpose = codeComponents[4]
        
        switch chargeType {
        case "labour":
            // Labour travel: Use the SAME item number as the primary support
            return mainNDISItem
            
        case "non-labour":
            // Non-labour travel: Use the '799' rule
            let travelItemNumber = "\(supportCategory)_799_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)"
            return findNDISItemByItemNumber(travelItemNumber)
            
        case "activity-based":
            // Activity-based transport: Use the '590' rule
            let travelItemNumber = "\(supportCategory)_590_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)"
            return findNDISItemByItemNumber(travelItemNumber)
            
        default:
            return nil
        }
    }
    
    /// Finds an NDIS Item by its item number
    private func findNDISItemByItemNumber(_ itemNumber: String) -> NDISItemEntity? {
        let entityResolver = EntityResolutionService(context: modelContext)
        do {
            return try entityResolver.resolveNDISItem(byItemNumber: itemNumber)
        } catch {
            print("DEBUG: Error finding NDIS item with item number \(itemNumber): \(error)")
            return nil
        }
    }
}

// MARK: - Progress Tracking

public struct AutomationProgress {
    let step: ProgressStep
    let message: String
    let progress: Double // 0.0 to 1.0
    
    init(step: ProgressStep, message: String, progress: Double = 0.0) {
        self.step = step
        self.message = message
        self.progress = progress
    }
}

public enum ProgressStep {
    case validating
    case geocoding
    case calculatingTravel
    case determiningGeographic
    case determiningTime
    case determiningTravel
    case determiningServiceType
    case completed
    case failed
}

// MARK: - Automation Result
// Note: AutomationResult has been moved to Core package.
// The type is now imported via `import Core`.


    // TimeoutError for orchestrator timeouts
    struct TimeoutError: Error {
        let message = "Operation timed out"
    } 
