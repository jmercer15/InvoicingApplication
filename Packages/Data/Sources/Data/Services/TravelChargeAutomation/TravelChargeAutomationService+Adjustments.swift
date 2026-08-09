import Core
import Foundation
import os

extension TravelChargeAutomationService {
    /// Returns the adjusted distance and any warnings about adjustments.
    func checkAndAdjustDistance(
        _ distance: Double?,
        businessRules: BusinessRules
    ) async -> (adjustedDistance: Double?, warnings: [ComplianceViolation]) {
        guard let distance, distance > 0 else {
            return (nil, [])
        }

        var warnings: [ComplianceViolation] = []

        if let maxDistance = businessRules.maxTravelDistance, distance > maxDistance {
            let warning = ComplianceViolation(
                rule: "Distance Adjustment",
                currentValue: String(format: "%.1f km", distance),
                limit: String(format: "%.1f km", maxDistance),
                description: "Travel distance automatically adjusted to comply with maximum billable amount",
                severity: .warning
            )
            warnings.append(warning)

            await logDistanceAdjustment(
                originalDistance: distance,
                adjustedDistance: maxDistance,
                reason: "Exceeded maximum billable amount"
            )

            return (maxDistance, warnings)
        }

        return (distance, warnings)
    }

    /// Returns the adjusted travel time and any warnings about adjustments.
    func checkAndAdjustTravelTime(
        _ travelTime: Double,
        mmmZone: MMMZone
    ) async -> (adjustedTravelTime: Double, warnings: [ComplianceViolation]) {
        var warnings: [ComplianceViolation] = []

        if travelTime > mmmZone.maxTime {
            let warning = ComplianceViolation(
                rule: "Travel Time Adjustment",
                currentValue: String(format: "%.1f minutes", travelTime),
                limit: String(format: "%.1f minutes", mmmZone.maxTime),
                description: "Travel time automatically adjusted to comply with MMM zone maximum",
                severity: .warning
            )
            warnings.append(warning)

            await logTravelTimeAdjustment(
                originalTime: travelTime,
                adjustedTime: mmmZone.maxTime,
                reason: "Exceeded MMM zone maximum"
            )

            return (mmmZone.maxTime, warnings)
        }

        return (travelTime, warnings)
    }

    /// Logs distance adjustments for audit purposes.
    func logDistanceAdjustment(originalDistance: Double, adjustedDistance: Double, reason: String) async {
        let log = TravelChargeAuditLogSnapshot(
            id: UUID(),
            timestamp: Date(),
            summary: "Distance adjusted",
            action: "distance_adjustment",
            details: "Original: \(String(format: "%.1f", originalDistance)) km, Adjusted: \(String(format: "%.1f", adjustedDistance)) km - \(reason). Performed by: System",
            travelChargeId: nil
        )
        try? persistence.persistTravelChargeAuditLog(log)
        Logger.automation.info("Distance adjusted: \(String(format: "%.1f", originalDistance)) km → \(String(format: "%.1f", adjustedDistance)) km (\(reason))")
    }

    /// Logs travel time adjustments for audit purposes.
    func logTravelTimeAdjustment(originalTime: Double, adjustedTime: Double, reason: String) async {
        let log = TravelChargeAuditLogSnapshot(
            id: UUID(),
            timestamp: Date(),
            summary: "Travel time adjusted",
            action: "travel_time_adjustment",
            details: "Original: \(String(format: "%.1f", originalTime)) min, Adjusted: \(String(format: "%.1f", adjustedTime)) min - \(reason). Performed by: System",
            travelChargeId: nil
        )
        try? persistence.persistTravelChargeAuditLog(log)
        Logger.automation.info("Travel time adjusted: \(String(format: "%.1f", originalTime)) min → \(String(format: "%.1f", adjustedTime)) min (\(reason))")
    }
}

