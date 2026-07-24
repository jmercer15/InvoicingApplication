import Foundation
import os

extension TravelChargeAutomationService {
    // MARK: - Pipeline orchestration

    func automateTravelChargesAsync(for sessions: [SessionAutomationContext], dateRange: ClosedRange<Date>? = nil) async {
        Logger.automation.debug("Starting travel charge automation for \(sessions.count) sessions")
        let sessionInstances = expandSessionsToInstances(sessions, dateRange: dateRange)
        Logger.automation.debug("Expanded to \(sessionInstances.count) session instances")

        let business = try? fetchFirstBusinessSnapshot()
        let businessAddress = business?.address?.fullFormattedAddress

        let sessionsByClientDay = groupSessionsByClientAndDay(sessionInstances)

        for (_, daySessions) in sessionsByClientDay {
            let sortedSessions = sortSessionsChronologically(daySessions)

            for (sessionIndex, sessionInstance) in sortedSessions.enumerated() {
                let session = sessionInstance.session
                guard isEligibleForTravelCharge(session) else { continue }

                if sessionIndex == 0 {
                    await processFirstSessionTravelCharge(
                        sessionInstance: sessionInstance,
                        sortedSessions: sortedSessions,
                        businessAddress: businessAddress
                    )
                    continue
                }

                await processSubsequentSessionTravelCharge(
                    sessionIndex: sessionIndex,
                    sessionInstance: sessionInstance,
                    sortedSessions: sortedSessions
                )
            }
        }
    }

    private func processFirstSessionTravelCharge(
        sessionInstance: SessionInstance,
        sortedSessions: [SessionInstance],
        businessAddress: String?
    ) async {
        let session = sessionInstance.session
        let fromLocation = businessAddress
        let toLocation = resolvedLocationText(for: session)
        let missingReason = firstSessionMissingLocationReason(
            session: session,
            sessionLocation: toLocation,
            businessAddress: businessAddress
        )

        await processTravelLeg(
            session: session,
            sortedSessions: sortedSessions,
            fromLocation: fromLocation,
            toLocation: toLocation,
            fromTime: nil,
            toTime: sessionInstance.instanceStart,
            missingLocationReason: missingReason,
            fromGeocodeFailureReason: "Geocoding failed for business address (fromLocation)",
            toGeocodeFailureReason: "Geocoding failed for toLocation"
        )
    }

    private func processSubsequentSessionTravelCharge(
        sessionIndex: Int,
        sessionInstance: SessionInstance,
        sortedSessions: [SessionInstance]
    ) async {
        let session = sessionInstance.session
        let previousSessionInstance = sortedSessions[sessionIndex - 1]
        let previousSession = previousSessionInstance.session
        let fromLocation = resolvedLocationText(for: previousSession)
        let toLocation = resolvedLocationText(for: session)

        await processTravelLeg(
            session: session,
            sortedSessions: sortedSessions,
            fromLocation: fromLocation,
            toLocation: toLocation,
            fromTime: previousSessionInstance.instanceEnd,
            toTime: sessionInstance.instanceStart,
            missingLocationReason: "Missing from/to location. From: '\(fromLocation ?? "nil")', To: '\(toLocation ?? "nil")'",
            fromGeocodeFailureReason: "Geocoding failed for fromLocation",
            toGeocodeFailureReason: "Geocoding failed for toLocation"
        )
    }

    private func processTravelLeg(
        session: SessionAutomationContext,
        sortedSessions: [SessionInstance],
        fromLocation: String?,
        toLocation: String?,
        fromTime: Date?,
        toTime: Date,
        missingLocationReason: String,
        fromGeocodeFailureReason: String,
        toGeocodeFailureReason: String
    ) async {
        guard let fromLoc = nonEmptyLocation(fromLocation),
              let toLoc = nonEmptyLocation(toLocation) else {
            await queueForUserReview(session: session, reason: missingLocationReason)
            return
        }

        guard let fromCoord = await geocodeAddressAsync(fromLoc) else {
            await queueForUserReview(session: session, reason: fromGeocodeFailureReason)
            return
        }

        guard let toCoord = await geocodeAddressAsync(toLoc) else {
            await queueForUserReview(session: session, reason: toGeocodeFailureReason)
            return
        }

        guard let distance = await calculateDrivingDistanceAsync(from: fromCoord, to: toCoord) else {
            await queueForUserReview(session: session, reason: "Distance calculation failed")
            return
        }

        let travelTime = estimateTravelTime(distance: distance) ?? businessRules.defaultTravelTime
        guard let mmmZone = lookupMMMZone(for: session) else {
            await queueForUserReview(
                session: session,
                reason: "MMM zone could not be resolved from available coordinates",
                suggestedActions: ["Review Session Location", "Add Coordinates"],
                overrideOptions: ["MMM Zone Override"]
            )
            return
        }
        let chargeTypes = await determineChargeTypes(session: session)
        for chargeType in chargeTypes {
            await createTravelChargeIfCompliant(
                session: session,
                sortedSessions: sortedSessions,
                toLocation: toLoc,
                fromTime: fromTime,
                toTime: toTime,
                distance: distance,
                travelTime: travelTime,
                mmmZone: mmmZone,
                chargeType: chargeType
            )
        }
    }

    private func createTravelChargeIfCompliant(
        session: SessionAutomationContext,
        sortedSessions: [SessionInstance],
        toLocation: String,
        fromTime: Date?,
        toTime: Date,
        distance: Double,
        travelTime: Double,
        mmmZone: MMMZone,
        chargeType: String
    ) async {
        if TravelChargeDuplicatePolicy.hasExistingCharge(
            sessionId: session.id,
            clientId: session.client?.id,
            chargeType: chargeType,
            direction: .before,
            existing: session.session.travelCharges
        ) {
            return
        }

        let complianceResult = TravelChargeComplianceEvaluator.evaluate(
            travelTime: travelTime,
            mmmZone: mmmZone,
            businessRules: businessRules,
            chargeType: chargeType,
            distance: distance,
            daySessions: sortedSessions,
            session: session
        )
        if !complianceResult.isCompliant {
            await queueForUserReview(
                session: session,
                reason: "Non-compliant travel charge",
                violations: complianceResult.violations,
                suggestedActions: ["Override and Create Charge", "Skip This Charge", "Review Session Location"],
                overrideOptions: ["MMM Zone Override", "Distance Override", "Time Override"]
            )
            return
        }

        let service = await findTravelServiceSnapshotAsync(
            client: session.client,
            session: session,
            chargeType: chargeType
        )
        let sharedParticipants = await detectSharedTravelParticipantsAsync(
            session: session,
            daySessions: sortedSessions,
            direction: .before
        )
        let participantCount = determineParticipantCount(
            session: session,
            sharedParticipants: sharedParticipants
        )
        let vehicleType = determineVehicleType(session: session, chargeType: chargeType)

        let travelCharge = await buildTravelCharge(
            client: session.client!,
            session: session,
            serviceSnapshot: service,
            direction: .before,
            startTime: fromTime,
            endTime: toTime,
            location: toLocation,
            mmmZone: mmmZone,
            distance: distance,
            travelTime: travelTime,
            vehicleType: vehicleType,
            parking: nil,
            tolls: nil,
            participantCount: Int16(participantCount),
            chargeType: chargeType,
            splitCosts: participantCount > 1
        )
        await saveTravelCharge(travelCharge, context: session)
    }
}

