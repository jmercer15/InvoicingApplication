import Foundation
import Core

extension NDISBillingAutomationOrchestrator {

    // MARK: - Coordinate / Location Helpers

    func hasValidCoordinates(_ session: Session) -> Bool {
        let hasSessionCoords = session.sessionLatitude  != 0.0 && session.sessionLongitude != 0.0
            && session.sessionLatitude  >= -90.0  && session.sessionLatitude  <= 90.0
            && session.sessionLongitude >= -180.0 && session.sessionLongitude <= 180.0
        if hasSessionCoords { return true }
        if let address = session.address {
            return address.latitude  != 0.0 && address.longitude != 0.0
                && address.latitude  >= -90.0  && address.latitude  <= 90.0
                && address.longitude >= -180.0 && address.longitude <= 180.0
        }
        return false
    }

    func getSessionLocation(_ session: Session) -> String? {
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

    // MARK: - Travel Eligibility Helpers

    func determineProviderTravelEligibility(for session: Session, context: NDISBillingContext) -> Bool {
        if session.isTravel { return true }
        if context.travelDistance > travelDistanceThreshold { return true }
        if let ndisItem = session.clientService?.ndisItem, ndisItem.providerTravel == true { return true }
        if hasValidCoordinates(session) && hasBusinessCoordinates() { return true }
        return false
    }

    func hasBusinessCoordinates() -> Bool {
        let entityResolver = EntityResolutionService(context: modelContext)
        guard let business = try? entityResolver.resolveBusiness(),
              let businessAddress = business.address else { return false }
        return businessAddress.latitude != 0 && businessAddress.longitude != 0
    }

    func isActivityBasedEligible(session: Session) -> Bool {
        guard let ndisItem = session.clientService?.ndisItem else { return false }
        let itemNumber = ndisItem.itemNumber
        if itemNumber.hasPrefix("02_") { return true }
        if itemNumber.contains("_590_") { return true }
        let name = ndisItem.name.lowercased()
        let transportKeywords = ["transport", "travel", "community access", "participation", "community participation"]
        return transportKeywords.contains(where: { name.contains($0) })
    }

    func determineCancellationStatus(session: Session) -> Bool {
        guard let status = session.status?.rawValue.lowercased() else { return false }
        let cancelledStatuses = [
            "cancelled", "canceled", "cancellation",
            "cancelled by client", "cancelled by provider",
            "no show", "no-show", "no_show",
        ]
        return cancelledStatuses.contains(status)
    }

    // MARK: - UI Support Methods

    /// Determines if complex behaviour support is available for the session's NDIS item.
    public func isComplexBehaviorSupported(for session: Session) -> Bool {
        guard let ndisItem = session.clientService?.ndisItem else { return false }
        let itemName = ndisItem.name.lowercased()
        let keywords = ["complex", "challenging", "behavior", "behaviour", "intensive", "high intensity"]
        return keywords.contains(where: { itemName.contains($0) })
    }

    /// Determines if high-intensity support is available for the session's NDIS item.
    public func isHighIntensitySupported(for session: Session) -> Bool {
        guard let ndisItem = session.clientService?.ndisItem else { return false }
        let itemName = ndisItem.name.lowercased()
        let keywords = ["intensive", "high intensity", "complex", "challenging", "high support"]
        return keywords.contains(where: { itemName.contains($0) })
    }

    /// Returns a tuple indicating which special-circumstance claim types are supported.
    public func areSpecialCircumstancesSupported(for session: Session) -> (shadowShift: Bool, silUnplannedExit: Bool, ndiaReport: Bool) {
        guard let ndisItem = session.clientService?.ndisItem else {
            return (false, false, false)
        }
        let itemName = ndisItem.name.lowercased()
        return (
            shadowShift:      itemName.contains("complex") || itemName.contains("challenging") || itemName.contains("behavior"),
            silUnplannedExit: ndisItem.irregularSILSupports == true,
            ndiaReport:       ndisItem.ndiaRequestedReports == true
        )
    }

    /// Maps a session's NDIS item to the corresponding travel NDIS item.
    public func mapToTravelNDISItem(session: Session, chargeType: String) -> NDISItem? {
        guard let mainService = session.clientService,
              let mainNDISItem = mainService.ndisItem else { return nil }
        let mainItemNumber = mainNDISItem.itemNumber
        let codeComponents = mainItemNumber.split(separator: "_")
        guard codeComponents.count >= 5 else { return nil }
        let supportCategory   = codeComponents[0]
        let registrationGroup = codeComponents[2]
        let outcomeDomain     = codeComponents[3]
        let supportPurpose    = codeComponents[4]
        switch chargeType {
        case "labour":
            return mainNDISItem
        case "non-labour":
            return findNDISItemByItemNumber("\(supportCategory)_799_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)")
        case "activity-based":
            return findNDISItemByItemNumber("\(supportCategory)_590_\(registrationGroup)_\(outcomeDomain)_\(supportPurpose)")
        default:
            return nil
        }
    }

    func findNDISItemByItemNumber(_ itemNumber: String) -> NDISItem? {
        let entityResolver = EntityResolutionService(context: modelContext)
        do {
            return try entityResolver.resolveNDISItem(byItemNumber: itemNumber)
        } catch {
            print("DEBUG: Error finding NDIS item with item number \(itemNumber): \(error)")
            return nil
        }
    }
}
