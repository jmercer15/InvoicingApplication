import Foundation
import MapKit
import Core

extension NDISBillingAutomationOrchestrator {

    // MARK: - Step 3: Travel Distance & Time Calculation

    func calculateTravelDetails(for session: Session, result: inout AutomationResult) async -> MapKitTravelService.TravelDetails? {
        print("🗺️ [NDIS Automation] Step 3: Calculating travel details")
        result.updateStatus(.calculatingTravel)

        guard hasValidCoordinates(session) else {
            print("⚠️ [NDIS Automation] Cannot calculate travel details - no valid coordinates")
            result.addWarning("Cannot calculate travel details - no valid coordinates")
            return nil
        }

        let travelDetails = await self.mapKitTravelService.calculateTravelDetailsForSession(
            endAddress: session.location,
            modelContext: self.modelContext
        )

        if let details = travelDetails {
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
}
