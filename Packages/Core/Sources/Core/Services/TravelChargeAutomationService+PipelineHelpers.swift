import Foundation

extension TravelChargeAutomationService {
    func firstSessionMissingLocationReason(
        session: SessionAutomationContext,
        sessionLocation: String?,
        businessAddress: String?
    ) -> String {
        if sessionLocation == nil {
            return "Session has no location set. Session: '\(session.title)', Business address: '\(businessAddress ?? "nil")'. Please set a location for this session."
        }
        if businessAddress == nil {
            return "Business address is not set. Please configure the business address in Settings → Company Details."
        }
        return "Missing business address for first session of the day."
    }
}

