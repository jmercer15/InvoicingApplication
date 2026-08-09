import Foundation
import SwiftData
import Core
import PersistenceModels
import Data
import SharedUI

@MainActor
struct TravelChargePersistence {
    let modelContext: ModelContext

    func saveTravelCharges(form: TravelChargeFormState) throws {
        guard form.canSave else { return }

        if form.chargeType == .standard {
            if form.includeLabour, let service = form.labourService {
                try createTimeBasedSessions(form: form, service: service)
            }
            if form.includeNonLabour, let service = form.nonLabourService {
                try createEventBasedSessions(form: form, service: service)
            }
        } else if let service = form.labourService {
            try createActivityBasedSessions(form: form, service: service)
        }
    }

    private func createTimeBasedSessions(form: TravelChargeFormState, service: ClientService) throws {
        let currentTravelTime = form.travelDirection == .before ? form.travelTimeBefore : form.travelTimeAfter
        let breakdown = Core.NDISTravelChargeCalculator.calculate(
            providerType: form.providerType,
            hourlyRate: NSDecimalNumber(decimal: service.rate).doubleValue,
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
        Travel factor: \(MeasurementFormatting.decimal(form.providerType.travelFactor, fractionDigits: 2))
        Billable time: \(MeasurementFormatting.minutes(clampedTime, fractionDigits: 1))
        Amount per participant: \(breakdown.labourPerParticipant.formatted(.currency(code: "AUD")))
        Participants: \(form.effectiveParticipantCount)
        """

        if form.travelDirection == .before && !form.hasExistingTravelBefore {
            try createSession(
                form: form,
                startTime: form.effectiveStartTime.addingTimeInterval(-clampedTime * 60),
                endTime: form.effectiveStartTime,
                service: service,
                amount: Decimal(breakdown.labourPerParticipant),
                distance: 0,
                duration: clampedTime,
                chargeType: "labour",
                travelDirection: "before",
                notes: notes
            )
        }
        if form.travelDirection == .after && !form.hasExistingTravelAfter {
            try createSession(
                form: form,
                startTime: form.effectiveEndTime,
                endTime: form.effectiveEndTime.addingTimeInterval(clampedTime * 60),
                service: service,
                amount: Decimal(breakdown.labourPerParticipant),
                distance: 0,
                duration: clampedTime,
                chargeType: "labour",
                travelDirection: "after",
                notes: notes
            )
        }
    }

    private func createEventBasedSessions(form: TravelChargeFormState, service: ClientService) throws {
        let breakdown = Core.NDISTravelChargeCalculator.calculate(
            providerType: form.providerType,
            hourlyRate: NSDecimalNumber(decimal: service.rate).doubleValue,
            mmmZoneDescriptor: form.mmmZone.rawValue,
            minutesTravelled: 0,
            kilometresTravelled: form.distance,
            ancillaryCosts: form.parking + form.tolls,
            participantCount: form.effectiveParticipantCount
        )
        let notes = """
        Non-labour travel charge.
        Kilometres: \(MeasurementFormatting.kilometers(form.distance)) @ \(Core.NDISTravelChargeCalculator.vehicleRatePerKilometre.formatted(.currency(code: "AUD")))/km
        Ancillary costs: \((form.parking + form.tolls).formatted(.currency(code: "AUD")))
        Amount per participant: \(breakdown.nonLabourPerParticipant.formatted(.currency(code: "AUD")))
        Participants: \(form.effectiveParticipantCount)
        """

        if form.travelDirection == .before && !form.hasExistingTravelBefore {
            try createSession(
                form: form,
                startTime: form.effectiveStartTime,
                endTime: form.effectiveStartTime,
                service: service,
                amount: Decimal(breakdown.nonLabourPerParticipant),
                distance: form.distance,
                duration: 0,
                chargeType: "non-labour",
                travelDirection: "before",
                notes: notes,
                isAllDay: true
            )
        }
        if form.travelDirection == .after && !form.hasExistingTravelAfter {
            try createSession(
                form: form,
                startTime: form.effectiveEndTime,
                endTime: form.effectiveEndTime,
                service: service,
                amount: Decimal(breakdown.nonLabourPerParticipant),
                distance: form.distance,
                duration: 0,
                chargeType: "non-labour",
                travelDirection: "after",
                notes: notes,
                isAllDay: true
            )
        }
    }

    private func createActivityBasedSessions(form: TravelChargeFormState, service: ClientService) throws {
        let requestedTime = form.travelDirection == .before ? form.travelTimeBefore : form.travelTimeAfter
        let maxMinutes = Core.NDISTravelChargeCalculator.maxBillableMinutes(forMMMDescriptor: form.mmmZone.rawValue)
        let billableMinutes = maxMinutes.isInfinite ? requestedTime : min(requestedTime, maxMinutes)
        let participantCount = Decimal(form.effectiveParticipantCount)
        let timeCost = (Decimal(billableMinutes) / 60) * service.rate
        let vehicleCost = Decimal(form.distance) * Decimal(form.vehicleType.rate)
        let totalCost = (timeCost + vehicleCost + Decimal(form.parking) + Decimal(form.tolls)) / participantCount

        let notes = """
        Activity-Based Transport Breakdown:
        - Billable time: \(MeasurementFormatting.minutes(billableMinutes, fractionDigits: 1))
        - Time: \((timeCost / participantCount).formatted(.currency(code: "AUD")))
        - Vehicle: \((vehicleCost / participantCount).formatted(.currency(code: "AUD")))
        - Parking: \((Decimal(form.parking) / participantCount).formatted(.currency(code: "AUD")))
        - Tolls: \((Decimal(form.tolls) / participantCount).formatted(.currency(code: "AUD")))
        - TOTAL PER PARTICIPANT: \(totalCost.formatted(.currency(code: "AUD")))
        """

        let startTime = form.travelDirection == .before
            ? form.effectiveStartTime.addingTimeInterval(-Double(billableMinutes) * 60)
            : form.effectiveEndTime
        let endTime = form.travelDirection == .before
            ? form.effectiveStartTime
            : form.effectiveEndTime.addingTimeInterval(Double(billableMinutes) * 60)

        try createSession(
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
            parkingCost: Decimal(form.parking),
            tollCost: Decimal(form.tolls)
        )
    }

    private func createSession(
        form: TravelChargeFormState,
        startTime: Date,
        endTime _: Date,
        service: ClientService,
        amount: Decimal,
        distance: Double,
        duration: Double,
        chargeType: String,
        travelDirection: String,
        notes: String,
        isAllDay _: Bool = false,
        vehicleType: String? = nil,
        parkingCost: Decimal = 0,
        tollCost: Decimal = 0
    ) throws {
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
        try modelContext.save()
    }
}
