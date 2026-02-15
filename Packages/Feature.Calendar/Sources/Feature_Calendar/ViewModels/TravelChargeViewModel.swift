import Foundation
import SwiftData
import Core
import Data
import MapKit
import Combine
import SharedUI

@MainActor
class TravelChargeViewModel: ObservableObject {
    // Dependencies
    private let unitOfWork: UnitOfWorkService
    private let addressRepository: AddressRepository // Keep address repo if UoW doesn't expose it easily? No, UoW has it.
    
    // Core Data Context removed - fully migrated to UnitOfWork
    // var modelContext: ModelContext?
    
    // Session Data
    let mainSession: Session
    let daySessions: [DisplayableCalendarItem]
    
    // MARK: - Published State
    
    // Config
    @Published var chargeType: TravelChargeView.TravelChargeType = .standard
    @Published var mmmZone: TravelChargeView.MMMZone = .mmm1_3
    @Published var providerType: TravelChargeProviderType = .dsw
    
    // Standard Travel
    @Published var includeLabour: Bool = true
    @Published var includeNonLabour: Bool = true
    @Published var travelTimeBeforeString: String = "30"
    @Published var travelTimeAfterString: String = "30"
    
    // Activity-Based
    @Published var vehicleType: TravelChargeView.VehicleType = .standard
    @Published var distanceString: String = ""
    @Published var parkingString: String = ""
    @Published var tollsString: String = ""
    
    // Shared
    @Published var participantCountString: String = "1"
    @Published var splitCosts: Bool = false
    @Published var travelDirection: TravelChargeView.TravelDirection = .before
    @Published var isLoading: Bool = false
    
    // Distance Calc
    @Published var fromAddressString: String = ""
    @Published var toAddressString: String = ""
    @Published var isCalculatingDistance: Bool = false
    @Published var distanceCalculationError: String?
    
    @Published var hasExistingTravelBefore: Bool = false
    @Published var hasExistingTravelAfter: Bool = false
    
    // Services
    @Published var labourService: ClientService?
    @Published var nonLabourService: ClientService?
    
    // MARK: - Computed Properties
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
            return (includeLabour || includeNonLabour)
        } else {
            return true
        }
    }
    
    // Callbacks
    var onSave: (() -> Void)?
    
    init(
        unitOfWork: UnitOfWorkService,
        mainSession: Session,
        daySessions: [DisplayableCalendarItem]
    ) {
        self.unitOfWork = unitOfWork
        self.mainSession = mainSession
        self.daySessions = daySessions
        // We can access addressRepository via unitOfWork.addresses
        self.addressRepository = unitOfWork.addresses
    }
    

    
    // MARK: - Loading Logic
    
    func loadServices() {
        isLoading = true
        
        guard let clientId = mainSession.clientId,
              let serviceId = mainSession.clientServiceId else {
            isLoading = false
            return
        }
        
        Task {
            do {
                guard let client = try await unitOfWork.clients.fetch(by: clientId),
                      let allServices = try? await unitOfWork.clientServices.fetch(for: clientId),
                      let mainService = allServices.first(where: { $0.id == serviceId }) else {
                    await MainActor.run { isLoading = false }
                    return
                }
                
                await MainActor.run {
                    self.labourService = mainService
                    self.providerType = NDISTravelChargeCalculator.inferredProviderType(
                        itemName: mainService.serviceName,
                        itemDescription: nil,
                        ndisCode: mainService.ndisCode
                    )
        
                    guard let mainNdisCode = mainService.ndisCode,
                          let splitCode = mainNdisCode.split(separator: "_").dropFirst(2).first else {
                        isLoading = false
                        return
                    }

                    let nonLabourCodeFragment = "_799_\(splitCode)_"
                    
                    // Repository currently exposes exact-ID and fetch-all APIs,
                    // so derive a partial-match result in memory.
                    if let nonLabourService = allServices.first(where: { service in
                        service.ndisCode?.contains(nonLabourCodeFragment) == true
                    }) {
                        self.nonLabourService = nonLabourService
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
    
    func checkForExistingTravel() {
        guard let clientId = mainSession.clientId else { return }
        let sessionStartTime = effectiveStartTime
        let sessionEndTime = effectiveEndTime
        
        Task {
            do {
                let clientSessions = try await unitOfWork.sessions.fetch(byClientId: clientId)
                
                let existingBefore = clientSessions.filter { session in
                    session.isTravel &&
                    session.endTime == sessionStartTime &&
                    session.clientId == clientId
                }
                
                if !existingBefore.isEmpty {
                    await MainActor.run {
                        self.hasExistingTravelBefore = true
                        self.travelDirection = .after
                    }
                }
                
                let existingAfter = clientSessions.filter { session in
                    session.isTravel &&
                    session.startTime == sessionEndTime &&
                    session.clientId == clientId
                }
                
                if !existingAfter.isEmpty {
                    await MainActor.run {
                        self.hasExistingTravelAfter = true
                        if !hasExistingTravelBefore {
                            self.travelDirection = .before
                        }
                    }
                }
            } catch {
                print("Failed to fetch existing travel sessions: \(error)")
            }
        }
    }
    
    // MARK: - Save Logic
    
    // MARK: - Save Logic
    
    func saveTravelCharges() {
        guard canSave else { return }

        // --- Standard Travel ---
        if chargeType == .standard {
            if includeLabour, let service = labourService {
                createTimeBasedSessions(service: service)
            }
            if includeNonLabour, let service = nonLabourService {
                createEventBasedSessions(service: service)
            }
        }
        // --- Activity-Based Transport ---
        else {
            if let service = labourService {
                createActivityBasedSessions(service: service)
            }
        }
        
        onSave?()
    }

    private func createTimeBasedSessions(service: ClientService) {
        let currentTravelTime = travelDirection == .before ? travelTimeBefore : travelTimeAfter
        let breakdown = NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: service.rate,
            mmmZoneDescriptor: mmmZone.rawValue,
            minutesTravelled: currentTravelTime,
            kilometresTravelled: 0,
            ancillaryCosts: 0,
            participantCount: effectiveParticipantCount
        )
        let clampedTime = breakdown.billableMinutes
        let notes = """
        Labour travel charge.
        Provider type: \(providerType.rawValue)
        Hourly rate: \(service.rate.formatted(.currency(code: "AUD")))/hr
        Travel factor: \(String(format: "%.2f", providerType.travelFactor))
        Billable time: \(String(format: "%.1f", clampedTime)) min
        Amount per participant: \(breakdown.labourPerParticipant.formatted(.currency(code: "AUD")))
        Participants: \(effectiveParticipantCount)
        """
        
        if travelDirection == .before && !hasExistingTravelBefore {
            createSession(
                title: "Travel (Time) to \(mainSession.title)",
                startTime: effectiveStartTime.addingTimeInterval(-clampedTime * 60),
                endTime: effectiveStartTime,
                service: service,
                amount: breakdown.labourPerParticipant,
                distance: 0,
                duration: clampedTime,
                chargeType: "labour",
                travelDirection: "before",
                notes: notes,
                participantCount: effectiveParticipantCount,
                splitCosts: splitCosts
            )
        }
        if travelDirection == .after && !hasExistingTravelAfter {
            createSession(
                title: "Travel (Time) from \(mainSession.title)",
                startTime: effectiveEndTime,
                endTime: effectiveEndTime.addingTimeInterval(clampedTime * 60),
                service: service,
                amount: breakdown.labourPerParticipant,
                distance: 0,
                duration: clampedTime,
                chargeType: "labour",
                travelDirection: "after",
                notes: notes,
                participantCount: effectiveParticipantCount,
                splitCosts: splitCosts
            )
        }
    }
    
    private func createEventBasedSessions(service: ClientService) {
        let breakdown = NDISTravelChargeCalculator.calculate(
            providerType: providerType,
            hourlyRate: service.rate,
            mmmZoneDescriptor: mmmZone.rawValue,
            minutesTravelled: 0,
            kilometresTravelled: distance,
            ancillaryCosts: parking + tolls,
            participantCount: effectiveParticipantCount
        )
        let notes = """
        Non-labour travel charge.
        Kilometres: \(String(format: "%.1f", distance)) km @ \(NDISTravelChargeCalculator.vehicleRatePerKilometre.formatted(.currency(code: "AUD")))/km
        Ancillary costs: \((parking + tolls).formatted(.currency(code: "AUD")))
        Amount per participant: \(breakdown.nonLabourPerParticipant.formatted(.currency(code: "AUD")))
        Participants: \(effectiveParticipantCount)
        """
        
        if travelDirection == .before && !hasExistingTravelBefore {
            createSession(
                title: "Travel (Non-Labour) to \(mainSession.title)",
                startTime: effectiveStartTime,
                endTime: effectiveStartTime,
                service: service,
                amount: breakdown.nonLabourPerParticipant,
                distance: distance,
                duration: 0, // Event based (km), effectively 0 time
                chargeType: "non-labour",
                travelDirection: "before",
                notes: notes,
                isAllDay: true,
                participantCount: effectiveParticipantCount,
                splitCosts: splitCosts
            )
        }
        if travelDirection == .after && !hasExistingTravelAfter {
             createSession(
                title: "Travel (Non-Labour) from \(mainSession.title)",
                startTime: effectiveEndTime,
                endTime: effectiveEndTime,
                service: service,
                amount: breakdown.nonLabourPerParticipant,
                distance: distance,
                duration: 0,
                chargeType: "non-labour",
                travelDirection: "after",
                notes: notes,
                isAllDay: true,
                participantCount: effectiveParticipantCount,
                splitCosts: splitCosts
            )
        }
    }

    private func createActivityBasedSessions(service: ClientService) {
        let requestedTime = travelDirection == .before ? travelTimeBefore : travelTimeAfter
        let maxMinutes = NDISTravelChargeCalculator.maxBillableMinutes(forMMMDescriptor: mmmZone.rawValue)
        let billableMinutes = maxMinutes.isInfinite ? requestedTime : min(requestedTime, maxMinutes)
        let timeCost = (billableMinutes / 60.0) * service.rate
        let vehicleCost = distance * vehicleType.rate
        let totalCost = (timeCost + vehicleCost + parking + tolls) / Double(effectiveParticipantCount)
        
        let notes = """
        Activity-Based Transport Breakdown:
        - Billable time: \(String(format: "%.1f", billableMinutes)) mins
        - Time: \((timeCost / Double(effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - Vehicle: \((vehicleCost / Double(effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - Parking: \((parking / Double(effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - Tolls: \((tolls / Double(effectiveParticipantCount)).formatted(.currency(code: "AUD")))
        - TOTAL PER PARTICIPANT: \(totalCost.formatted(.currency(code: "AUD")))
        """
        
        let startTime = travelDirection == .before ? effectiveStartTime.addingTimeInterval(-billableMinutes * 60) : effectiveEndTime
        let endTime = travelDirection == .before ? effectiveStartTime : effectiveEndTime.addingTimeInterval(billableMinutes * 60)

        createSession(
            title: "Activity Transport for \(mainSession.title)",
            startTime: startTime,
            endTime: endTime,
            service: service,
            amount: totalCost,
            distance: distance,
            duration: billableMinutes,
            chargeType: "activity-based",
            travelDirection: travelDirection == .before ? "before" : "after",
            notes: notes,
            vehicleType: vehicleType.rawValue,
            parkingCost: parking,
            tollCost: tolls,
            participantCount: effectiveParticipantCount,
            splitCosts: splitCosts
        )
    }

    private func createSession(
        title: String,
        startTime: Date,
        endTime: Date,
        service: ClientService,
        amount: Double,
        distance: Double,
        duration: Double,
        chargeType: String,
        travelDirection: String,
        notes: String,
        isAllDay: Bool = false,
        vehicleType: String? = nil,
        parkingCost: Double = 0.0,
        tollCost: Double = 0.0,
        participantCount: Int = 1,
        splitCosts: Bool = false
    ) {
        guard let clientId = mainSession.clientId else { return }
        
        Task {
            // Using Standard Repository Pattern via UnitOfWork
            let travelCharge = TravelCharge(
                id: UUID(),
                sessionId: mainSession.id,
                clientId: clientId,
                serviceId: service.id,
                amount: amount,
                distance: distance,
                travelTime: duration,
                fromAddress: travelDirection == "before" ? fromAddressString : toAddressString,
                toAddress: travelDirection == "before" ? toAddressString : fromAddressString,
                status: .pending,
                chargeType: chargeType,
                travelDirection: travelDirection,
                vehicleType: vehicleType,
                participantCount: participantCount,
                splitCosts: splitCosts,
                parkingCost: parkingCost,
                tollCost: tollCost,
                createdDate: startTime,
                lastModifiedDate: Date(),
                notes: notes
            )
            
            do {
                _ = try await unitOfWork.travelCharges.create(travelCharge)
                // Note: The repository handles relationship link to mainSession, client, service
                print("TravelChargeViewModel: Saved travel charge via Repository")
            } catch {
                print("TravelChargeViewModel: Failed to save travel charge: \(error)")
            }
        }
    }
    
    // MARK: - Distance Calc (Ported from View)
    
    func setupAndCalculateDistance() {
        Task { await doSetupAndCalculateDistance() }
    }

    private func doSetupAndCalculateDistance() async {
        await MainActor.run {
            distanceCalculationError = nil
            isCalculatingDistance = true
        }

        guard let sessionLocation = mainSession.location, !sessionLocation.isEmpty else {
            await MainActor.run {
                distanceCalculationError = "The current session address is missing."
                isCalculatingDistance = false
            }
            return
        }
        
        guard let sessionCoordinates = await getCoordinates(for: sessionLocation) else {
             await MainActor.run {
                distanceCalculationError = "Could not geocode the current session address: \(sessionLocation)"
                isCalculatingDistance = false
            }
            return
        }
        
        let otherLocationData = getOtherLocationData()
        guard let otherAddress = otherLocationData.address, !otherAddress.isEmpty else {
             await MainActor.run {
                distanceCalculationError = otherLocationData.address ?? "Other session not found"
                isCalculatingDistance = false
            }
            return
        }
        
         guard let otherCoordinates = await getCoordinates(for: otherAddress) else {
            await MainActor.run {
                distanceCalculationError = "Could not geocode the other location's address: \(otherAddress)"
                isCalculatingDistance = false
            }
            return
        }
        
        await MainActor.run {
            if travelDirection == .before {
                fromAddressString = otherAddress
                toAddressString = sessionLocation
            } else {
                fromAddressString = sessionLocation
                toAddressString = otherAddress
            }
        }

        calculateDrivingDistance(from: sessionCoordinates, to: otherCoordinates)
    }
    
    private func getOtherLocationData() -> (address: String?, session: Session?) {
        // Logic to find adjacent session in daySessions
        let sortedSessions = daySessions.sorted { (item1, item2) -> Bool in
             guard let date1 = item1.startDate, let date2 = item2.startDate else { return false }
             return date1 < date2
        }

        guard let currentIndex = sortedSessions.firstIndex(where: { item in
             // Identify main session in list
             if case .session(let s) = item { return s.id == mainSession.id }
             if case .recurringSessionInstance(let t, let d, _, _) = item { 
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
        case .recurringSessionInstance(let s, _, _, _): return (s.location, s) // Simplified
        default: return (nil, nil)
        }
    }
    
    // Helper to replace getOrFetchCoordinates
    private func getCoordinates(for address: String) async -> CLLocationCoordinate2D? {
        guard let coordinate = await GeocodingService.shared.geocodeAddressString(address) else {
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
                guard let self = self else { return }
                self.isCalculatingDistance = false
                
                if let errorMsg = errorMessage {
                    self.distanceCalculationError = errorMsg
                    return
                }
                
                if let distance = distanceInKm {
                    self.distanceString = String(format: "%.1f", distance)
                    // Optionally set travel time estimate
                }
            }
        }
    }
}
