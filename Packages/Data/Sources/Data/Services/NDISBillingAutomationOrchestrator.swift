import Foundation
import SwiftData
import MapKit
import CoreLocation
import Core

/// Orchestrates the NDIS billing automation flow with proper async execution
/// Provides comprehensive error handling, validation, and status tracking
@MainActor
public class NDISBillingAutomationOrchestrator {
    let modelContext: ModelContext
    let geocodingService: SwiftDataGeocodingService
    let mapKitTravelService: MapKitTravelService
    let mmmZoneLookup: Core.MMMZoneLookup

    // Configuration constants
    let travelDistanceThreshold: Double = 0.5 // km
    let eveningStartHour = 18 // 6 PM
    let eveningEndHour = 22 // 10 PM
    let nightStartHour = 22 // 10 PM
    let nightEndHour = 6 // 6 AM

    init(
        modelContext: ModelContext,
        geocodingService: SwiftDataGeocodingService,
        mmmZoneLookup: Core.MMMZoneLookup,
        mapKitTravelService: MapKitTravelService
    ) {
        self.modelContext = modelContext
        self.geocodingService = geocodingService
        self.mapKitTravelService = mapKitTravelService
        self.mmmZoneLookup = mmmZoneLookup
    }

    static func performGeocodingForSession(
        sessionId: UUID,
        geocodingService: SwiftDataGeocodingService,
        modelContext: ModelContext
    ) async -> Bool {
        // Use GeocodingService to geocode the session if coordinates are missing
        let modelResolver = EntityResolutionService(context: modelContext)
        guard let sessionModel = try? modelResolver.resolveSession(id: sessionId) else {
            return false
        }
        
        // Call the async geocoding service method
        return await geocodingService.ensureCoordinatesForSession(sessionModel, modelContext: modelContext)
    }
    
    /// Executes the complete automation flow for a session (Domain Model)
    /// This is the preferred entry point for Feature layers.
    /// - Parameters:
    ///   - session: The session (Domain Model) to automate billing context for
    ///   - context: The billing context to populate
    ///   - progressHandler: Optional progress handler for UI updates
    /// - Returns: Automation result with status and any errors
    public func executeAutomationFlow(
        sessionId: UUID,
        context: NDISBillingContext,
        progressHandler: ((AutomationProgress) -> Void)? = nil
    ) async -> (NDISBillingContext, AutomationResult) {
        let modelResolver = EntityResolutionService(context: modelContext)
        guard let sessionModel = try? modelResolver.resolveSession(id: sessionId) else {
            var result = AutomationResult()
            result.markFailed()
            result.addError("Could not resolve Session for session ID: \(sessionId)")
            return (context, result)
        }

        var workingContext = context
        var result = AutomationResult()
        let steps: [AutomationStep] = [
            .validateSessionData,
            .ensureCoordinatesAvailable,
            .calculateTravelDetails,
            .determineGeographicContext,
            .determineTimeContext,
            .determineTravelContext,
            .determineServiceTypeContext,
        ]

        for (index, step) in steps.enumerated() {
            let stepProgress = Double(index) / Double(steps.count)
            progressHandler?(
                AutomationProgress(step: step.progressStep, message: step.progressMessage, progress: stepProgress)
            )

            let shouldContinue = await executeStep(step, for: sessionModel, context: &workingContext, result: &result)
            if !shouldContinue {
                result.markFailed()
                return (workingContext, result)
            }
        }

        result.markCompleted()
        progressHandler?(AutomationProgress(step: .completed, message: "Automation completed", progress: 1.0))
        return (workingContext, result)
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
    
    private func executeStep(_ step: AutomationStep, for session: Session, context: inout NDISBillingContext, result: inout AutomationResult) async -> Bool {
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
            await determineTravelContext(for: session, context: &context, result: &result)
            return true
        case .determineServiceTypeContext:
            await determineServiceTypeContext(for: session, context: &context, result: &result)
            return true
        }
    }
}

// MARK: - Progress Tracking

public struct AutomationProgress {
    let step: ProgressStep
    let message: String
    let progress: Double // 0.0 to 1.0

    init(step: ProgressStep, message: String, progress: Double = 0.0) {
        self.step     = step
        self.message  = message
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
