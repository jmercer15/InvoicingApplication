import SwiftUI
import SharedUI

enum BillingHubTravelChargeType: String, CaseIterable, Identifiable {
    /// Persist raw values match `TravelChargeType` so Hub writes resolve non-nil.
    case standard = "Standard"
    case labour = "labour"
    case nonLabour = "non-labour"
    case activityBased = "activity-based"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .labour: return "Labour"
        case .nonLabour: return "Non-Labour"
        case .activityBased: return "Activity-Based"
        }
    }

    /// Km-based types need a vehicle rate picker (standard + activity).
    var showsVehiclePicker: Bool {
        switch self {
        case .standard, .activityBased: return true
        case .labour, .nonLabour: return false
        }
    }
}

enum BillingHubTravelVehicleType: String, CaseIterable, Identifiable {
    case standard = "Standard Car"
    case modified = "Modified/Bus"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .modified: return "Modified"
        }
    }

    var ratePerKilometre: Double {
        BillingHubTravelChargeCalculator.vehicleRatePerKilometre(for: rawValue)
    }
}

enum BillingHubTravelDirection: String, CaseIterable, Identifiable {
    case before
    case after

    var id: String { rawValue }

    var label: String {
        switch self {
        case .before: return "Before Session"
        case .after: return "After Session"
        }
    }

    var icon: String {
        switch self {
        case .before: return "arrow.right.circle"
        case .after: return "arrow.left.circle"
        }
    }
}
