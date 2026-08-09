enum TravelChargeSaveReadiness {
    static func message(
        chargeType: TravelChargeSheetChargeType,
        includeLabour: Bool,
        includeNonLabour: Bool,
        hasLabourService: Bool,
        hasNonLabourService: Bool,
        hasChargeableLabour: Bool,
        hasChargeableNonLabour: Bool,
        hasChargeableActivityTransport: Bool,
        direction: TravelChargeSheetDirection,
        hasExistingTravelBefore: Bool,
        hasExistingTravelAfter: Bool
    ) -> String? {
        let directionAlreadyExists = switch direction {
        case .before:
            hasExistingTravelBefore
        case .after:
            hasExistingTravelAfter
        }

        if directionAlreadyExists {
            return "A \(direction.shortLabel.lowercased()) travel charge already exists. Choose the other direction or remove the existing charge first."
        }

        switch chargeType {
        case .standard:
            guard includeLabour || includeNonLabour else {
                return "Select provider travel time, kilometre allowance, or both."
            }
            if includeLabour && !hasLabourService {
                return "Add a matching provider travel service to this client before saving."
            }
            if includeNonLabour && !hasNonLabourService {
                return "Add a matching non-labour travel service to this client before saving."
            }
            if includeLabour && !hasChargeableLabour {
                return "Enter provider travel time that produces an amount above $0, or turn off provider travel time."
            }
            if includeNonLabour && !hasChargeableNonLabour {
                return "Enter kilometres, parking, or tolls that produce an amount above $0, or turn off kilometre allowance."
            }
        case .activityBased:
            guard hasLabourService else {
                return "Add a matching activity transport service to this client before saving."
            }
            guard hasChargeableActivityTransport else {
                return "Enter travel time, distance, parking, or tolls that produce an amount above $0."
            }
        }

        return nil
    }
}

private extension TravelChargeSheetDirection {
    var shortLabel: String {
        switch self {
        case .before:
            "Before-session"
        case .after:
            "After-session"
        }
    }
}
