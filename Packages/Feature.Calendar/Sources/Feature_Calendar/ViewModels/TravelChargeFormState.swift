import Foundation
import SwiftData
import Core
import PersistenceModels
import Data
import MapKit
import SharedUI
import Observation

@Observable
@MainActor
final class TravelChargeFormState {
    struct ChargeEstimate {
        let labourAmount: Double?
        let nonLabourAmount: Double?
        let activityTransportAmount: Double?
        let billableMinutes: Double?

        var total: Double {
            (labourAmount ?? 0) + (nonLabourAmount ?? 0) + (activityTransportAmount ?? 0)
        }
    }

    let mainSession: Session
    let daySessions: [DisplayableCalendarItem]

    private let geocodingService: any Core.GeocodingServiceProtocol
    private let travelService = MapKitTravelService()
    @ObservationIgnored
    private var distanceTask: Task<Void, Never>?

    // MARK: - Form Fields

    var chargeType: TravelChargeSheetChargeType = .standard
    var mmmZone: TravelChargeSheetMMMZone = .mmm1_3
    var providerType: Core.TravelChargeProviderType = .dsw

    var includeLabour: Bool = true
    var includeNonLabour: Bool = true
    var travelTimeBeforeString: String = "30"
    var travelTimeAfterString: String = "30"

    var vehicleType: TravelChargeSheetVehicleType = .standard
    var distanceString: String = ""
    var parkingString: String = ""
    var tollsString: String = ""

    var participantCountString: String = "1"
    var splitCosts: Bool = false
    var travelDirection: TravelChargeSheetDirection = .before
    var isLoading: Bool = false

    var fromAddressString: String = ""
    var toAddressString: String = ""
    var isCalculatingDistance: Bool = false
    var distanceCalculationError: String?

    var hasExistingTravelBefore: Bool = false
    var hasExistingTravelAfter: Bool = false

    var labourService: ClientService?
    var nonLabourService: ClientService?

    // MARK: - Computed

    var travelTimeBefore: Double { Double(travelTimeBeforeString) ?? 0 }
    var travelTimeAfter: Double { Double(travelTimeAfterString) ?? 0 }
    var participantCount: Int { Int(participantCountString) ?? 1 }
    var effectiveParticipantCount: Int { splitCosts ? max(participantCount, 1) : 1 }
    var distance: Double { Double(distanceString) ?? 0 }
    var parking: Double { Double(parkingString) ?? 0 }
    var tolls: Double { Double(tollsString) ?? 0 }

    var saveReadinessMessage: String? {
        let estimate = chargeEstimate
        return TravelChargeSaveReadiness.message(
            chargeType: chargeType,
            includeLabour: includeLabour,
            includeNonLabour: includeNonLabour,
            hasLabourService: labourService != nil,
            hasNonLabourService: nonLabourService != nil,
            hasChargeableLabour: (estimate?.labourAmount ?? 0) > 0,
            hasChargeableNonLabour: (estimate?.nonLabourAmount ?? 0) > 0,
            hasChargeableActivityTransport: (estimate?.activityTransportAmount ?? 0) > 0,
            direction: travelDirection,
            hasExistingTravelBefore: hasExistingTravelBefore,
            hasExistingTravelAfter: hasExistingTravelAfter
        )
    }

    var effectiveStartTime: Date {
        mainSession.startTime ?? Date()
    }

    var effectiveEndTime: Date {
        mainSession.endTime ?? Date()
    }

    var canSave: Bool {
        saveReadinessMessage == nil
    }

    /// Mirrors `TravelChargePersistence` so users can review the amount that will be saved,
    /// including MMM caps and participant splitting, before committing a travel row.
    var chargeEstimate: ChargeEstimate? {
        switch chargeType {
        case .standard:
            let minutes = travelDirection == .before ? travelTimeBefore : travelTimeAfter
            let labour: (Double, Double?)? = {
                guard includeLabour, let labourService else { return nil }
                let breakdown = Core.NDISTravelChargeCalculator.calculate(
                    providerType: providerType,
                    hourlyRate: NSDecimalNumber(decimal: labourService.rate).doubleValue,
                    mmmZoneDescriptor: mmmZone.rawValue,
                    minutesTravelled: minutes,
                    kilometresTravelled: 0,
                    ancillaryCosts: 0,
                    participantCount: effectiveParticipantCount
                )
                return (breakdown.labourPerParticipant, breakdown.billableMinutes)
            }()
            let nonLabour: Double? = {
                guard includeNonLabour, let nonLabourService else { return nil }
                return Core.NDISTravelChargeCalculator.calculate(
                    providerType: providerType,
                    hourlyRate: NSDecimalNumber(decimal: nonLabourService.rate).doubleValue,
                    mmmZoneDescriptor: mmmZone.rawValue,
                    minutesTravelled: 0,
                    kilometresTravelled: distance,
                    ancillaryCosts: parking + tolls,
                    participantCount: effectiveParticipantCount
                ).nonLabourPerParticipant
            }()
            guard labour != nil || nonLabour != nil else { return nil }
            return ChargeEstimate(
                labourAmount: labour?.0,
                nonLabourAmount: nonLabour,
                activityTransportAmount: nil,
                billableMinutes: labour?.1
            )
        case .activityBased:
            guard let labourService else { return nil }
            let requestedMinutes = travelDirection == .before ? travelTimeBefore : travelTimeAfter
            let maximum = Core.NDISTravelChargeCalculator.maxBillableMinutes(forMMMDescriptor: mmmZone.rawValue)
            let billableMinutes = maximum.isInfinite ? requestedMinutes : min(requestedMinutes, maximum)
            let labourRate = NSDecimalNumber(decimal: labourService.rate).doubleValue
            let total = (
                (billableMinutes / 60.0) * labourRate
                    + distance * vehicleType.rate
                    + parking
                    + tolls
            ) / Double(effectiveParticipantCount)
            return ChargeEstimate(
                labourAmount: nil,
                nonLabourAmount: nil,
                activityTransportAmount: total,
                billableMinutes: billableMinutes
            )
        }
    }

    init(
        geocodingService: any Core.GeocodingServiceProtocol,
        mainSession: Session,
        daySessions: [DisplayableCalendarItem]
    ) {
        self.geocodingService = geocodingService
        self.mainSession = mainSession
        self.daySessions = daySessions
    }

    // MARK: - Query Snapshot

    func applyTravelChargeQuerySnapshot(
        clientServices: [ClientService],
        travelCharges: [TravelCharge]
    ) {
        isLoading = true
        defer { isLoading = false }

        let mergedServices = mergedKnownServices(fromQuerySnapshot: clientServices)
        guard let mainService = resolveMainService(mergedServices: mergedServices) else {
            labourService = nil
            nonLabourService = nil
            applyExistingTravelState(linkedCharges: mergedLinkedTravelCharges(fromQuerySnapshot: travelCharges))
            return
        }

        labourService = mainService
        providerType = Core.NDISTravelChargeCalculator.inferredProviderType(
            itemName: mainService.serviceName,
            itemDescription: nil,
            ndisCode: mainService.ndisCode
        )

        if let nonLabourCodeFragment = mainService.ndisCode
            .flatMap({ code in code.split(separator: "_").dropFirst(2).first.map { "_799_\($0)_" } }) {
            nonLabourService = mergedServices.first { service in
                service.id != mainService.id &&
                (service.ndisCode?.contains(nonLabourCodeFragment) ?? false)
            }
        } else {
            nonLabourService = nil
        }

        applyExistingTravelState(linkedCharges: mergedLinkedTravelCharges(fromQuerySnapshot: travelCharges))
    }

    // MARK: - Distance Calculation

    func setupAndCalculateDistance() {
        distanceTask?.cancel()
        distanceTask = Task { [weak self] in
            await self?.doSetupAndCalculateDistance()
        }
    }

    private func doSetupAndCalculateDistance() async {
        distanceCalculationError = nil
        isCalculatingDistance = true
        defer {
            if !Task.isCancelled {
                isCalculatingDistance = false
            }
        }

        guard let sessionLocation = mainSession.location, !sessionLocation.isEmpty else {
            distanceCalculationError = "The current session address is missing."
            return
        }

        guard let sessionCoordinates = await getCoordinates(for: sessionLocation) else {
            distanceCalculationError = "Could not geocode the current session address: \(sessionLocation)"
            return
        }
        guard !Task.isCancelled else { return }

        let otherLocationData = getOtherLocationData()
        guard let otherAddress = otherLocationData.address, !otherAddress.isEmpty else {
            distanceCalculationError = otherLocationData.address ?? "Other session not found"
            return
        }

        guard let otherCoordinates = await getCoordinates(for: otherAddress) else {
            distanceCalculationError = "Could not geocode the other location's address: \(otherAddress)"
            return
        }
        guard !Task.isCancelled else { return }

        if travelDirection == .before {
            fromAddressString = otherAddress
            toAddressString = sessionLocation
        } else {
            fromAddressString = sessionLocation
            toAddressString = otherAddress
        }

        await calculateDrivingDistance(from: sessionCoordinates, to: otherCoordinates)
    }

    // MARK: - Private Helpers

    private func mergedKnownServices(fromQuerySnapshot snapshot: [ClientService]) -> [ClientService] {
        var merged: [ClientService] = []
        merged.append(contentsOf: mainSession.client?.clientServices ?? [])
        merged.append(contentsOf: snapshot)
        var seen = Set<UUID>()
        return merged
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                lhs.serviceName.localizedCaseInsensitiveCompare(rhs.serviceName) == .orderedAscending
            }
    }

    private func mergedLinkedTravelCharges(fromQuerySnapshot snapshot: [TravelCharge]) -> [TravelCharge] {
        let sessionID = mainSession.id
        let fromRelationship = mainSession.travelCharges ?? []
        let fromSnapshot = snapshot.filter { $0.linkedSession?.id == sessionID }
        var merged: [TravelCharge] = []
        merged.append(contentsOf: fromRelationship)
        merged.append(contentsOf: fromSnapshot)
        var seen = Set<UUID>()
        return merged.filter { seen.insert($0.id).inserted }
    }

    private func resolveMainService(mergedServices: [ClientService]) -> ClientService? {
        if let directService = mainSession.clientService {
            return directService
        }
        guard let serviceID = mainSession.clientServiceId else {
            return nil
        }
        return mergedServices.first { $0.id == serviceID }
    }

    private func applyExistingTravelState(linkedCharges: [TravelCharge]) {
        let sessionStartTime = effectiveStartTime
        let sessionEndTime = effectiveEndTime

        let hasBeforeCharge = linkedCharges.contains { $0.travelDirection == .before }
        let hasAfterCharge = linkedCharges.contains { $0.travelDirection == .after }

        let legacyTravelSessions = mainSession.client?.sessions ?? []
        let hasBeforeLegacy = legacyTravelSessions.contains {
            $0.id != mainSession.id &&
            $0.isTravel &&
            $0.endTime == sessionStartTime
        }
        let hasAfterLegacy = legacyTravelSessions.contains {
            $0.id != mainSession.id &&
            $0.isTravel &&
            $0.startTime == sessionEndTime
        }

        hasExistingTravelBefore = hasBeforeCharge || hasBeforeLegacy
        hasExistingTravelAfter = hasAfterCharge || hasAfterLegacy

        if hasExistingTravelBefore {
            travelDirection = .after
        } else if hasExistingTravelAfter {
            travelDirection = .before
        }
    }

    private func getOtherLocationData() -> (address: String?, session: Session?) {
        let sortedSessions = daySessions.sorted { (item1, item2) -> Bool in
            guard let date1 = item1.startDate, let date2 = item2.startDate else { return false }
            return date1 < date2
        }

        guard let currentIndex = sortedSessions.firstIndex(where: { item in
            if case .session(let s) = item { return s.id == mainSession.id }
            if case .recurringSessionInstance(let t, let d, _, _, _, _) = item {
                return t.id == mainSession.id && Calendar.current.isDate(d, inSameDayAs: effectiveStartTime)
            }
            return false
        }) else {
            return ("Could not find current session in daily list.", nil)
        }

        let targetIndex = travelDirection == .before ? currentIndex - 1 : currentIndex + 1
        guard targetIndex >= 0 && targetIndex < sortedSessions.count else {
            return ("No \(travelDirection == .before ? "previous" : "following") session found today.", nil)
        }

        let targetItem = sortedSessions[targetIndex]
        switch targetItem {
        case .session(let s): return (s.location, s)
        case .recurringSessionInstance(let s, _, _, _, _, _): return (s.location, s)
        default: return (nil, nil)
        }
    }

    private func getCoordinates(for address: String) async -> CLLocationCoordinate2D? {
        guard let coordinate = await geocodingService.geocodeAddressString(address) else {
            return nil
        }
        return CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private func calculateDrivingDistance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) async {
        guard let details = await travelService.calculateTravelDetails(from: start, to: end) else {
            if !Task.isCancelled {
                distanceCalculationError = "Unable to calculate driving distance."
            }
            return
        }
        guard !Task.isCancelled else { return }
        distanceString = String(format: "%.1f", details.distance)
    }
}
