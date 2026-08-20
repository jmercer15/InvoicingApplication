import os
import Foundation
import MapKit
import Core
import PersistenceModels

extension NDISBillingAutomationOrchestrator {

    // MARK: - Step 3: Travel Distance & Time Calculation

    func calculateTravelDetails(for session: Session, result: inout AutomationResult) async -> MapKitTravelService.TravelDetails? {
        Logger.automation.info("🗺️ [NDIS Automation] Step 3: Calculating travel details")
        result.updateStatus(.calculatingTravel)

        guard hasValidCoordinates(session) else {
            Logger.automation.warning("⚠️ [NDIS Automation] Cannot calculate travel details - no valid coordinates")
            result.addWarning("Cannot calculate travel details - no valid coordinates")
            return nil
        }

        guard let businessCoordinate = MapKitTravelService.resolveBusinessCoordinate(
            modelContext: self.modelContext
        ) else {
            Logger.automation.warning("⚠️ [NDIS Automation] Cannot calculate travel details - no business coordinates")
            result.addWarning("Cannot calculate travel details - no business address coordinates")
            return nil
        }

        let travelDetails = await self.mapKitTravelService.calculateTravelDetailsForSession(
            endAddress: session.location,
            businessCoordinate: businessCoordinate
        )

        if let details = travelDetails {
            if details.distance < 0 {
                Logger.automation.warning("⚠️ [NDIS Automation] Invalid travel distance: \(details.distance)")
                result.addWarning("Invalid travel distance: \(details.distance)")
                return nil
            }
            if details.time < 0 {
                Logger.automation.warning("⚠️ [NDIS Automation] Invalid travel time: \(details.time)")
                result.addWarning("Invalid travel time: \(details.time)")
                return nil
            }
            Logger.automation.info("✅ [NDIS Automation] Travel details calculated - Distance: \(details.distance) km, Time: \(details.time) minutes")
            return details
        } else {
            Logger.automation.warning("⚠️ [NDIS Automation] Travel calculation failed")
            result.addWarning("Travel calculation failed")
            return nil
        }
    }
}
