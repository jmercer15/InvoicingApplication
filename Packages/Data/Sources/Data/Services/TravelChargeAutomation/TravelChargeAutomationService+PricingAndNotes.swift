import Core
import Foundation

extension TravelChargeAutomationService {
    /// Estimates travel time (in minutes) given a distance (km), using user preferences or business rules for average speed.
    func estimateTravelTime(distance: Double?) -> Double? {
        guard let distance, distance > 0 else { return nil }
        let avgSpeed = userPreferences.averageSpeed ?? businessRules.defaultTravelTime
        guard avgSpeed > 0 else { return nil }
        return (distance / avgSpeed) * 60.0 // minutes
    }

    func calculatePricingBreakdown(
        session: SessionAutomationContext,
        serviceSnapshot: ClientServiceSnapshot?,
        chargeType _: String,
        mmmZone: MMMZone,
        travelTime: Double,
        distance: Double?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int,
        splitCosts: Bool
    ) -> NDISTravelChargeBreakdown {
        let effectiveParticipants = splitCosts ? max(participantCount, 1) : 1
        let primaryService = session.service ?? serviceSnapshot
        let providerType = NDISTravelChargeCalculator.inferredProviderType(
            itemName: primaryService?.serviceName,
            itemDescription: session.ndisItem?.itemDescription,
            ndisCode: primaryService?.ndisCode
        )
        let ancillary = (parking ?? 0) + (tolls ?? 0)
        let hourlyRate = NSDecimalNumber(decimal: max(primaryService?.rate ?? 0, 0)).doubleValue

        return NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: hourlyRate,
            mmmZoneDescriptor: mmmZone.name,
            minutesTravelled: travelTime,
            kilometresTravelled: distance ?? 0,
            ancillaryCosts: ancillary,
            participantCount: effectiveParticipants
        )
    }

    func overrideNotesSuffix(overrideType: String?, overrideReason: String?) -> String {
        "\n[Override: \(overrideType ?? "Manual") - \(overrideReason ?? "No reason provided")]"
    }

    func calculatedAmount(for chargeType: String, breakdown: NDISTravelChargeBreakdown) -> Double {
        TravelChargePricingMath.calculatedAmount(for: chargeType, breakdown: breakdown)
    }

    /// Generates a detailed notes string for the travel charge.
    func generateTravelChargeNotes(
        session: SessionAutomationContext,
        direction: TravelDirection,
        distance: Double?,
        originalDistance: Double?,
        distanceWarnings: [ComplianceViolation],
        travelTime: Double,
        originalTravelTime: Double?,
        travelTimeWarnings: [ComplianceViolation],
        mmmZone: MMMZone,
        vehicleType: String?,
        parking _: Double?,
        tolls _: Double?,
        participantCount: Int,
        chargeType: String,
        splitCosts: Bool,
        pricingBreakdown: NDISTravelChargeBreakdown
    ) -> String {
        var notes = "Travel ("
        notes += chargeType
        notes += ") "
        notes += (direction == .before ? "before" : "after")
        notes += " session '"
        notes += session.title
        notes += "':\n"

        if let distance {
            notes += "Distance: \(String(format: "%.1f", distance)) km"
            if !distanceWarnings.isEmpty {
                notes += " (adjusted from \(String(format: "%.1f", originalDistance ?? 0)) km)"
            }

            notes += ", Time: \(String(format: "%.0f", travelTime)) min"
            if !travelTimeWarnings.isEmpty {
                notes += " (adjusted from \(String(format: "%.0f", originalTravelTime ?? 0)) min)"
            }

            notes += ", MMM Zone: \(mmmZone.name)\n"
        } else {
            notes += "Distance: Unknown, Time: \(String(format: "%.0f", travelTime)) min"
            if !travelTimeWarnings.isEmpty {
                notes += " (adjusted from \(String(format: "%.0f", originalTravelTime ?? 0)) min)"
            }

            notes += ", MMM Zone: \(mmmZone.name)\n"
        }

        for warning in distanceWarnings where warning.rule == "Distance Adjustment" {
            notes += "⚠️ \(warning.description)\n"
        }

        for warning in travelTimeWarnings where warning.rule == "Travel Time Adjustment" {
            notes += "⚠️ \(warning.description)\n"
        }

        if let vehicleType {
            notes += "Vehicle: \(vehicleType)\n"
        }
        notes += "Participants: \(participantCount)"
        if splitCosts {
            notes += " (costs split)"
        }
        notes += "\nProvider Type: \(pricingBreakdown.providerType.rawValue)"
        notes += "\nBillable Time: \(String(format: "%.1f", pricingBreakdown.billableMinutes)) min"
        if pricingBreakdown.maxBillableMinutes.isInfinite {
            notes += " (uncapped MMM 6/7)"
        } else {
            notes += " (cap \(String(format: "%.1f", pricingBreakdown.maxBillableMinutes)) min)"
        }

        if chargeType.lowercased() == "labour" || chargeType.lowercased() == "activity-based" {
            notes += "\nLabour per participant: \(pricingBreakdown.labourPerParticipant.formatted(.currency(code: "AUD")))"
        }

        if chargeType.lowercased() == "non-labour" || chargeType.lowercased() == "activity-based" {
            notes += "\nVehicle + ancillary per participant: \(pricingBreakdown.nonLabourPerParticipant.formatted(.currency(code: "AUD")))"
        }

        let chargeAmountPerParticipant = calculatedAmount(for: chargeType, breakdown: pricingBreakdown)
        notes += "\nTotal per participant: \(chargeAmountPerParticipant.formatted(.currency(code: "AUD")))"
        return notes
    }
}

