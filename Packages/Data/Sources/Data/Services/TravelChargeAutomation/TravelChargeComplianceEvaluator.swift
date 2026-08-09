import Core
import Foundation

/// Outcome of pre-persistence business-rule checks for a candidate travel charge.
public struct ComplianceResult: Sendable {
    public let isCompliant: Bool
    public let violations: [ComplianceViolation]
    public let warnings: [ComplianceViolation]

    public init(isCompliant: Bool, violations: [ComplianceViolation], warnings: [ComplianceViolation]) {
        self.isCompliant = isCompliant
        self.violations = violations
        self.warnings = warnings
    }
}

/// Pure evaluation of travel-charge eligibility against configured business rules and same-day sessions.
public enum TravelChargeComplianceEvaluator {
    public static func evaluate(
        travelTime: Double,
        mmmZone: MMMZone,
        businessRules: BusinessRules,
        chargeType: String,
        distance _: Double,
        daySessions: [TravelChargeAutomationService.SessionInstance],
        session: TravelChargeAutomationService.SessionAutomationContext
    ) -> ComplianceResult {
        var violations: [ComplianceViolation] = []
        var warnings: [ComplianceViolation] = []

        if let maxTime = businessRules.maxTravelTime, travelTime > maxTime {
            violations.append(ComplianceViolation(
                rule: "Max Travel Time",
                currentValue: "\(travelTime) min",
                limit: "\(maxTime) min",
                description: "Travel time exceeds business rule",
                severity: .error
            ))
        }

        if let allowed = businessRules.allowedChargeTypes, !allowed.contains(chargeType) {
            violations.append(ComplianceViolation(
                rule: "Allowed Charge Types",
                currentValue: chargeType,
                limit: allowed.joined(separator: ", "),
                description: "Charge type is not in the list of allowed types",
                severity: .error
            ))
        }

        if let startTime = session.startTime, let endTime = session.endTime {
            for otherInstance in daySessions {
                let other = otherInstance.session
                guard other.id != session.id, !other.isTravel, other.client?.id == session.client?.id else { continue }

                let oStart = otherInstance.instanceStart
                let oEnd = otherInstance.instanceEnd
                if startTime < oEnd, endTime > oStart {
                    violations.append(ComplianceViolation(
                        rule: "Time Overlap Prevention",
                        currentValue: "\(startTime) to \(endTime)",
                        limit: "\(oStart) to \(oEnd)",
                        description: "Session times overlap with another session for this client.",
                        severity: .error
                    ))
                }
            }
        }

        if travelTime > mmmZone.maxTime * 0.8 {
            warnings.append(ComplianceViolation(
                rule: "Travel Time Warning",
                currentValue: String(format: "%.1f minutes", travelTime),
                limit: String(format: "%.1f minutes", mmmZone.maxTime * 0.8),
                description: "Travel time is approaching the MMM zone limit",
                severity: .warning
            ))
        }

        return ComplianceResult(
            isCompliant: violations.isEmpty,
            violations: violations,
            warnings: warnings
        )
    }
}
