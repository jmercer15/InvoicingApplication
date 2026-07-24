import Foundation
import SwiftData
import Core
import Data
import MapKit
import SharedUI
import Observation

@Observable
@MainActor
final class TravelChargeFormState {
    let mainSession: Session
    let daySessions: [DisplayableCalendarItem]

    private let geocodingService: any Core.GeocodingServiceProtocol

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

    var effectiveStartTime: Date {
        mainSession.startTime ?? Date()
    }

    var effectiveEndTime: Date {
        mainSession.endTime ?? Date()
    }

    var canSave: Bool {
        if chargeType == .standard {
            return includeLabour || includeNonLabour
        }
        return true
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
        Task { await doSetupAndCalculateDistance() }
    }

    private func doSetupAndCalculateDistance() async {
        distanceCalculationError = nil
        isCalculatingDistance = true

        guard let sessionLocation = mainSession.location, !sessionLocation.isEmpty else {
            distanceCalculationError = "The current session address is missing."
            isCalculatingDistance = false
            return
        }

        guard let sessionCoordinates = await getCoordinates(for: sessionLocation) else {
            distanceCalculationError = "Could not geocode the current session address: \(sessionLocation)"
            isCalculatingDistance = false
            return
        }

        let otherLocationData = getOtherLocationData()
        guard let otherAddress = otherLocationData.address, !otherAddress.isEmpty else {
            distanceCalculationError = otherLocationData.address ?? "Other session not found"
            isCalculatingDistance = false
            return
        }

        guard let otherCoordinates = await getCoordinates(for: otherAddress) else {
            distanceCalculationError = "Could not geocode the other location's address: \(otherAddress)"
            isCalculatingDistance = false
            return
        }

        if travelDirection == .before {
            fromAddressString = otherAddress
            toAddressString = sessionLocation
        } else {
            fromAddressString = sessionLocation
            toAddressString = otherAddress
        }

        calculateDrivingDistance(from: sessionCoordinates, to: otherCoordinates)
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

    private func calculateDrivingDistance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: start.latitude, longitude: start.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: end.latitude, longitude: end.longitude), address: nil)
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            var distanceInKm: Double?
            if let dist = response?.routes.first?.distance {
                distanceInKm = dist / 1000.0
            }
            let errorMessage = error?.localizedDescription

            Task { @MainActor [weak self] in
                guard let self else { return }
                isCalculatingDistance = false

                if let errorMsg = errorMessage {
                    distanceCalculationError = errorMsg
                    return
                }

                if let distance = distanceInKm {
                    distanceString = String(format: "%.1f", distance)
                }
            }
        }
    }
}
