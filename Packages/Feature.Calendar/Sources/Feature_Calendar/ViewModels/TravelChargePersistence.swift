import Foundation
import SwiftData
import Core
import Data

@MainActor
struct TravelChargePersistence {
    let modelContext: ModelContext

    func saveTravelCharges(form: TravelChargeFormState) {
        guard form.canSave else { return }

        if form.chargeType == .standard {
            if form.includeLabour, let service = form.labourService {
                createTimeBasedSessions(form: form, service: service)
            }
            if form.includeNonLabour, let service = form.nonLabourService {
                createEventBasedSessions(form: form, service: service)
            }
        } else if let service = form.labourService {
            createActivityBasedSessions(form: form, service: service)
        }
    }

    private func createTimeBasedSessions(form: TravelChargeFormState, service: ClientService) {
        let currentTravelTime = form.travelDirection == .before ? form.travelTimeBefore : form.travelTimeAfter
        let breakdown = Core.NDISTravelChargeCalculator.calculate(
            providerType: form.providerType,
            hourlyRate: Double(service.rate),
            mmmZoneDescriptor: form.mmmZone.rawValue,
            minutesTravelled: currentTravelTime,
            kilometresTravelled: 0,
            ancillaryCosts: 0,
            participantCount: form.effectiveParticipantCount
        )
        let clampedTime = breakdown.billableMinutes
        let notes = """
        Labour travel charge.
        Provider type: \(form.providerType.rawValue)
        Hourly rate: \(service.rate.formatted(.currency(code: "AUD")))/hr
        Travel factor: \(String(format: "%.2f", form.providerType.travelFactor))
        Billable time: \(String(format: "%.1f", clampedTime)) min
        Amount per participant: \(breakdown.labourPerParticipant.formatted(.currency(code: "AUD")))
        Participants: \(form.effectiveParticipantCount)
        """

        if form.travelDirection == .before && !form.hasExistingTravelBefore {
            createSession(
                form: form,
                startTime: form.effectiveStartTime.addingTimeInterval(-clampedTime * 60),
                endTime: form.effectiveStartTime,
                service: service,
                amount: breakdown.labourPerParticipant,
                distance: 0,
                duration: clampedTime,
                chargeType: "labour",
                travelDirection: "before",
                notes: notes
            )
        }
        if form.travelDirection == .after && !form.hasExistingTravelAfter {
            createSession(
                form: form,
                startTime: form.effectiveEndTime,
                endTime: form.effectiveEndTime.addingTimeInterval(clampedTime * 60),
                service: service,
                amount: breakdown.labourPerParticipant,
                distance: 0,
                duration: clampedTime,
                chargeType: "labour",
                travelDirection: "after",
                notes: notes
            )
        }
    }

    private func createEventBasedSessions(form: TravelChargeFormState, service: ClientService) {
        let breakdown = Core.NDISTravelChargeCalculator.calculate(
            providerType: form.providerType,
            hourlyRate: Double(service.rate),
            mmmZoneDescriptor: form.mmmZone.rawValue,
            minutesTravelled: 0,
            kilometresTravelled: form.distance,
            ancillaryCosts: form.parking + form.tolls,
            participantCount: form.effectiveParticipantCount
        )
        let notes = """
        Non-labour travel charge.
        Kilometres: \(String(format: "%.1f", form.distance)) km @ \(Core.NDISTravelChargeCalculator.vehicleRatePerKilometre.formatted(.currency(code: "AUD")))/km
        Ancillary costs: \((form.parking + form.tolls).formatted(.currency(code: "AUD")))
        Amount per participant: \(breakdown.nonLabourPerParticipant.formatted(.currency(code: "AUD")))
        Participants: \(form.effectiveParticipantCount)
        """

        if form.travelDirection == .before && !form.hasExistingTravelBefore {
            createSession(
                form: form,
                startTime: form.effectiveStartTime,
                endTime: form.effectiveStartTime,
                service: service,
                amount: breakdown.nonLabourPerParticipant,
                distance: form.distance,
                duration: 0,
                chargeType: "non-labour",
                travelDirection: "before",
                notes: notes,
                isAllDay: true
            )
        }
        if form.travelDirection == .after && !form.hasExistingTravelAfter {
            createSession(
                form: form,
                startTime: form.effectiveEndTime,
                endTime: form.effectiveEndTime,
                service: service,
                amount: breakdown.nonLabourPerParticipant,
                distance: form.distance,
                duration: 0,
                chargeType: "non-labour",
                travelDirection: "after",
                notes: notes,
                isAllDay: true
            )
        }
    }

    private func createActivityBasedSessions(form: TravelChargeFormState, service: ClientService) {
        let requestedTime = form.travelDirection == .before ? form.travelTimeBefore : form.travelTimeAfter
        let maxMinutes = Core.NDISTravelChargeCalculator.maxBillableMinutes(forMMMDescriptor: form.mmmZone.rawValue)
        let billableMinutes = maxMinutes.isInfinite ? requestedTime : min(requestedTime, maxMinutes)
        let timeCost = (billableMinutes / 60.0) * service.rate
        let vehicleCost = form.distance * form.vehicleType.rate
        let totalCost = (timeCost + vehicleCost + form.parking + form.tolls) / Double(form.effectiveParticipantCount)

        let notes = """
        Activity-Based Transport Breakdown:
        - Billable time: \(String(format: "%.1f", billableMinutes)) mins
        - Time: \((timeCost / Double(form.effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - Vehicle: \((vehicleCost / Double(form.effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - Parking: \((form.parking / Double(form.effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - Tolls: \((form.tolls / Double(form.effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - TOTAL PER PARTICIPANT: \(totalCost.formatted(.currency(code: "AUD")))
        """

        let startTime = form.travelDirection == .before
            ? form.effectiveStartTime.addingTimeInterval(-Double(billableMinutes) * 60)
            : form.effectiveEndTime
        let endTime = form.travelDirection == .before
            ? form.effectiveStartTime
            : form.effectiveEndTime.addingTimeInterval(Double(billableMinutes) * 60)

        createSession(
            form: form,
            startTime: startTime,
            endTime: endTime,
            service: service,
            amount: totalCost,
            distance: form.distance,
            duration: billableMinutes,
            chargeType: "activity-based",
            travelDirection: form.travelDirection == .before ? "before" : "after",
            notes: notes,
            vehicleType: form.vehicleType.rawValue,
            parkingCost: form.parking,
            tollCost: form.tolls
        )
    }

    private func createSession(
        form: TravelChargeFormState,
        startTime: Date,
        endTime _: Date,
        service: ClientService,
        amount: Double,
        distance: Double,
        duration: Double,
        chargeType: String,
        travelDirection: String,
        notes: String,
        isAllDay _: Bool = false,
        vehicleType: String? = nil,
        parkingCost: Double = 0.0,
        tollCost: Double = 0.0
    ) {
        let travelCharge = TravelCharge(
            id: UUID(),
            chargeAmount: amount,
            distanceKM: distance,
            durationMinutes: duration,
            location: nil,
            status: .pending,
            chargeType: Core.TravelChargeType(rawValue: chargeType),
            travelDirection: Core.TravelChargeDirection(rawValue: travelDirection),
            vehicleType: vehicleType.flatMap { Core.VehicleType(rawValue: $0) },
            participantCount: Int16(form.effectiveParticipantCount),
            splitCosts: form.splitCosts,
            parkingCost: parkingCost,
            tollCost: tollCost,
            notes: notes,
            startTime: startTime,
            endTime: startTime
        )
        travelCharge.client = form.mainSession.client
        travelCharge.linkedSession = form.mainSession
        travelCharge.service = service
        modelContext.insert(travelCharge)
        do {
            try modelContext.save()
        } catch {
            print("TravelChargePersistence: Failed to save travel charge: \(error)")
        }
    }
}
