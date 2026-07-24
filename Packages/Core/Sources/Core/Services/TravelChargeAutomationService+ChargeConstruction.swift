import Foundation

extension TravelChargeAutomationService {
    /// Determines the vehicle type for the travel charge, including business-specific logic.
    func determineVehicleType(session _: SessionAutomationContext, chargeType _: String) -> String? {
        if let preferred = userPreferences.preferredVehicleType {
            return preferred
        }
        return "Standard Car"
    }

    /// Determines the participant count for cost splitting, including business-specific logic.
    func determineParticipantCount(session _: SessionAutomationContext, sharedParticipants: [SessionAutomationContext]) -> Int {
        max(sharedParticipants.count, 1)
    }

    func buildTravelCharge(
        client: ClientSnapshot,
        session: SessionAutomationContext,
        serviceSnapshot: ClientServiceSnapshot?,
        direction: TravelChargeDirection,
        startTime: Date?,
        endTime: Date?,
        location: String?,
        mmmZone: MMMZone,
        distance: Double?,
        travelTime: Double?,
        vehicleType: String?,
        parking: Double?,
        tolls: Double?,
        participantCount: Int16?,
        chargeType: String,
        splitCosts: Bool,
        status: TravelChargeStatus = .pending
    ) async -> TravelChargeSnapshot {
        let (adjustedDistance, distanceWarnings) = await checkAndAdjustDistance(distance, businessRules: businessRules)
        let (adjustedTravelTime, travelTimeWarnings) = await checkAndAdjustTravelTime(travelTime ?? 0.0, mmmZone: mmmZone)

        let pricingBreakdown = calculatePricingBreakdown(
            session: session,
            serviceSnapshot: serviceSnapshot,
            chargeType: chargeType,
            mmmZone: mmmZone,
            travelTime: adjustedTravelTime,
            distance: adjustedDistance,
            parking: parking,
            tolls: tolls,
            participantCount: Int(participantCount ?? 1),
            splitCosts: splitCosts
        )

        let notes = generateTravelChargeNotes(
            session: session,
            direction: (direction == .before) ? .before : .after,
            distance: adjustedDistance,
            originalDistance: distance,
            distanceWarnings: distanceWarnings,
            travelTime: adjustedTravelTime,
            originalTravelTime: travelTime ?? 0.0,
            travelTimeWarnings: travelTimeWarnings,
            mmmZone: mmmZone,
            vehicleType: vehicleType,
            parking: parking,
            tolls: tolls,
            participantCount: Int(participantCount ?? 1),
            chargeType: chargeType,
            splitCosts: splitCosts,
            pricingBreakdown: pricingBreakdown
        )

        let notesSuffix = overrideNotesSuffix(overrideType: "Manual", overrideReason: "Automated")

        return TravelChargeSnapshot(
            id: UUID(),
            chargeAmount: pricingBreakdown.totalPerParticipant,
            distanceKM: adjustedDistance,
            durationMinutes: adjustedTravelTime,
            location: location,
            effectiveStatus: status,
            travelType: TravelChargeType(rawValue: chargeType.lowercased()) ?? .labour,
            travelDirection: direction,
            vehicleType: vehicleType != nil ? VehicleType(rawValue: vehicleType!) : nil,
            participantCount: participantCount ?? 1,
            splitCosts: splitCosts,
            parkingCost: parking ?? 0.0,
            tollCost: tolls ?? 0.0,
            notes: notes + notesSuffix,
            startTime: startTime,
            endTime: endTime,
            sessionId: session.id,
            clientId: client.id,
            serviceId: serviceSnapshot?.id
        )
    }
}

