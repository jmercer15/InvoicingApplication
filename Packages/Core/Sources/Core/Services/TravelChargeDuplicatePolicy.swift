import Foundation

/// Pure duplicate detection for travel charges (same client, session, charge type, and direction).
public enum TravelChargeDuplicatePolicy {
    public static func hasExistingCharge(
        sessionId: UUID,
        clientId: UUID?,
        chargeType: String,
        direction: TravelChargeDirection,
        existing: [TravelChargeSnapshot]
    ) -> Bool {
        let normalizedType = TravelChargeType(rawValue: chargeType.lowercased())
        for travelCharge in existing {
            if travelCharge.clientId == clientId,
               travelCharge.sessionId == sessionId,
               travelCharge.travelType == normalizedType,
               travelCharge.travelDirection == direction {
                return true
            }
        }
        return false
    }
}
