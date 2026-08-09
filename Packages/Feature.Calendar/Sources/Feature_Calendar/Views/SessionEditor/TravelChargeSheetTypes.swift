import Core
import Foundation

enum TravelChargeSheetChargeType: String, CaseIterable, Identifiable {
    case standard = "Standard Travel"
    case activityBased = "Activity-Based Transport"
    var id: String { rawValue }
}

enum TravelChargeSheetDirection: String, CaseIterable, Identifiable {
    case before = "Before Session"
    case after = "After Session"
    var id: String { rawValue }
}

enum TravelChargeSheetMMMZone: String, CaseIterable, Identifiable {
    case mmm1_3 = "Zones 1-3 (Metro)"
    case mmm4_5 = "Zones 4-5 (Regional)"
    case mmm6_7 = "Zones 6-7 (Remote/Very Remote)"
    var id: String { rawValue }
}

enum TravelChargeSheetVehicleType: String, CaseIterable, Identifiable {
    case standard = "Standard Car"
    case modified = "Modified/Bus"
    var id: String { rawValue }

    var rate: Double {
        switch self {
        case .standard: return Core.NDISTravelChargeCalculator.vehicleRatePerKilometre
        case .modified: return Core.NDISTravelChargeCalculator.modifiedVehicleRatePerKilometre
        }
    }
}
