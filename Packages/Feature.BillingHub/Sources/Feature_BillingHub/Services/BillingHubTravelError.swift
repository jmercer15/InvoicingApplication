import Foundation

public enum BillingHubTravelError: LocalizedError, Sendable, Equatable {
    case sessionNotFound

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound:
            return "Session could not be found."
        }
    }
}
