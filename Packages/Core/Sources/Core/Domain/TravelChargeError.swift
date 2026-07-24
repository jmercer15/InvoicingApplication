import Foundation

public enum TravelChargeError: Error, LocalizedError {
    case travelChargeNotFound
    case invalidAmount
    case invalidSessionId
    case invalidSession
    case cannotApproveTravelCharge
    case cannotDeleteTravelCharge
    case cannotRejectTravelCharge

    public var errorDescription: String? {
        switch self {
        case .travelChargeNotFound:
            return "Travel charge not found"
        case .invalidAmount:
            return "Invalid amount value"
        case .invalidSessionId:
            return "Invalid session ID"
        case .invalidSession:
            return "Invalid or missing session"
        case .cannotApproveTravelCharge:
            return "Only pending travel charges can be approved"
        case .cannotDeleteTravelCharge:
            return "Cannot delete approved or paid travel charges"
        case .cannotRejectTravelCharge:
            return "Only pending travel charges can be rejected"
        }
    }
}
