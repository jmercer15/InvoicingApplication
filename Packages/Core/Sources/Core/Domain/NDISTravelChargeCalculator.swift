import Foundation

public enum TravelChargeProviderType: String, CaseIterable, Codable, Sendable {
    case therapist = "Therapist"
    case dsw = "DSW"

    public var travelFactor: Double {
        switch self {
        case .therapist:
            return 0.5
        case .dsw:
            return 1.0
        }
    }
}

public struct NDISTravelChargeBreakdown: Sendable, Equatable {
    public let providerType: TravelChargeProviderType
    public let requestedMinutes: Double
    public let billableMinutes: Double
    public let maxBillableMinutes: Double
    public let hourlyRate: Double
    public let labourTotal: Double
    public let nonLabourTotal: Double
    public let grossTotal: Double
    public let labourPerParticipant: Double
    public let nonLabourPerParticipant: Double
    public let totalPerParticipant: Double
    public let participantCount: Int

    public init(
        providerType: TravelChargeProviderType,
        requestedMinutes: Double,
        billableMinutes: Double,
        maxBillableMinutes: Double,
        hourlyRate: Double,
        labourTotal: Double,
        nonLabourTotal: Double,
        grossTotal: Double,
        labourPerParticipant: Double,
        nonLabourPerParticipant: Double,
        totalPerParticipant: Double,
        participantCount: Int
    ) {
        self.providerType = providerType
        self.requestedMinutes = requestedMinutes
        self.billableMinutes = billableMinutes
        self.maxBillableMinutes = maxBillableMinutes
        self.hourlyRate = hourlyRate
        self.labourTotal = labourTotal
        self.nonLabourTotal = nonLabourTotal
        self.grossTotal = grossTotal
        self.labourPerParticipant = labourPerParticipant
        self.nonLabourPerParticipant = nonLabourPerParticipant
        self.totalPerParticipant = totalPerParticipant
        self.participantCount = participantCount
    }
}

public enum NDISTravelChargeCalculator {
    public static let vehicleRatePerKilometre: Double = 0.99

    /// MMM 1-3: 30 mins, MMM 4-5: 60 mins, MMM 6-7: uncapped (by agreement).
    public static func maxBillableMinutes(forMMMDescriptor descriptor: String?) -> Double {
        guard let descriptor, !descriptor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return 30.0
        }

        let values = descriptor
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }

        guard let first = values.first else {
            return 30.0
        }

        let lower = min(first, values.dropFirst().first ?? first)
        let upper = max(first, values.dropFirst().first ?? first)

        if upper <= 3 {
            return 30.0
        }
        if lower >= 4 && upper <= 5 {
            return 60.0
        }
        if lower >= 6 {
            return .infinity
        }

        // Mixed/unknown descriptors default to conservative metro cap.
        return 30.0
    }

    public static func inferredProviderType(
        itemName: String?,
        itemDescription: String?,
        ndisCode: String?
    ) -> TravelChargeProviderType {
        let searchable = [
            itemName?.lowercased() ?? "",
            itemDescription?.lowercased() ?? "",
            ndisCode?.lowercased() ?? ""
        ].joined(separator: " ")

        let therapistSignals = [
            "therapy", "therap", "occupational", "physio", "psych",
            "speech", "dietitian", "assessment", "counselling", "counseling"
        ]

        if therapistSignals.contains(where: { searchable.contains($0) }) {
            return .therapist
        }

        return .dsw
    }

    public static func calculate(
        providerType: TravelChargeProviderType,
        hourlyRate: Double,
        mmmZoneDescriptor: String?,
        minutesTravelled: Double,
        kilometresTravelled: Double,
        ancillaryCosts: Double,
        participantCount: Int
    ) -> NDISTravelChargeBreakdown {
        let safeParticipants = max(participantCount, 1)
        let safeMinutes = max(minutesTravelled, 0)
        let safeKilometres = max(kilometresTravelled, 0)
        let safeAncillary = max(ancillaryCosts, 0)
        let safeRate = max(hourlyRate, 0)

        let maxMinutes = maxBillableMinutes(forMMMDescriptor: mmmZoneDescriptor)
        let billableMinutes: Double
        if maxMinutes.isInfinite {
            billableMinutes = safeMinutes
        } else {
            billableMinutes = min(safeMinutes, maxMinutes)
        }

        let labourTotal = (safeRate * providerType.travelFactor) * (billableMinutes / 60.0)
        let nonLabourTotal = (safeKilometres * vehicleRatePerKilometre) + safeAncillary
        let grossTotal = labourTotal + nonLabourTotal

        return NDISTravelChargeBreakdown(
            providerType: providerType,
            requestedMinutes: safeMinutes,
            billableMinutes: billableMinutes,
            maxBillableMinutes: maxMinutes,
            hourlyRate: safeRate,
            labourTotal: labourTotal,
            nonLabourTotal: nonLabourTotal,
            grossTotal: grossTotal,
            labourPerParticipant: labourTotal / Double(safeParticipants),
            nonLabourPerParticipant: nonLabourTotal / Double(safeParticipants),
            totalPerParticipant: grossTotal / Double(safeParticipants),
            participantCount: safeParticipants
        )
    }
}
