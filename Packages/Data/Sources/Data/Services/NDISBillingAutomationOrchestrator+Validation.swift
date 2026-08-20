import os
import Foundation
import Core
import PersistenceModels

extension NDISBillingAutomationOrchestrator {

    // MARK: - Step 1: Session Data Validation

    func validateSessionData(_ session: Session, result: inout AutomationResult) async -> Bool {
        Logger.automation.info("🔍 [NDIS Automation] Step 1: Validating session data")
        result.updateStatus(.validating)

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
        guard !ndisItem.itemNumber.isEmpty else {
            result.addError("NDIS item has empty item number")
            return false
        }
        if startTime > Date() {
            result.addWarning("Session start time is in the future")
        }
        if let endTime = session.endTime, endTime < startTime {
            result.addError("Session end time is before start time")
            return false
        }
        Logger.automation.info("✅ [NDIS Automation] Session data validation passed")
        return true
    }

    // MARK: - Step 2: Coordinate Availability

    func ensureCoordinatesAvailable(for session: Session, result: inout AutomationResult) async -> Bool {
        Logger.automation.info("🌍 [NDIS Automation] Step 2: Ensuring coordinates are available")
        result.updateStatus(.geocoding)

        if hasValidCoordinates(session) {
            Logger.automation.info("✅ [NDIS Automation] Session already has valid coordinates")
            return true
        }
        guard let location = getSessionLocation(session) else {
            result.addError("Session has no location data to geocode")
            return false
        }
        Logger.automation.info("🌍 [NDIS Automation] Geocoding session location: \(location)")
        let sessionId = session.id
        let geocodingSuccess = await NDISBillingAutomationOrchestrator.performGeocodingForSession(
            sessionId: sessionId,
            geocodingService: self.geocodingService,
            modelContext: self.modelContext
        )
        if geocodingSuccess {
            Logger.automation.info("✅ [NDIS Automation] Session coordinates set successfully")
        } else {
            Logger.automation.error("❌ [NDIS Automation] Failed to geocode session location")
            result.addError("Failed to geocode session location")
        }
        if geocodingSuccess && !hasValidCoordinates(session) {
            result.addError("Geocoding succeeded but coordinates were not set")
            return false
        }
        return geocodingSuccess
    }
}
