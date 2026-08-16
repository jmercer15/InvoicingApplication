//
//  NDISSessionClaimProcessor.swift
//  InvoicingApplication
//
//  Extension on NDISBillingIntegrationService containing session claim line calculation,
//  travel distance/charge computation, and billing context resolution.
//

import Foundation
import Core
import PersistenceModels
import CoreLocation
import SwiftData

// MARK: - Session Claim Processing & Travel Context Resolution

extension NDISBillingIntegrationService {

    /// Resolves the full `NDISBillingContext` for a session, merging live geocoding,
    /// automation flow results, and persisted `TravelCharge` rows.
    func resolveBillingContext(forSessionId sessionId: UUID) async -> NDISBillingContext {
        let localContext = ModelContainerFactory.makeEphemeralContext(from: modelContainer)
        let persistenceActor = NDISBillingPersistenceActor(modelContainer: modelContainer)

        guard let session = try? localContext.fetch(
            FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })
        ).first else {
            return NDISBillingContext()
        }

        var context = NDISBillingContext()
        context.supportItemNumber = session.clientService?.ndisCode ?? ""

        let orchestrator = NDISBillingAutomationOrchestrator(
            modelContext: localContext,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup,
            mapKitTravelService: MapKitTravelService()
        )

        let (updatedContext, _) = await orchestrator.executeAutomationFlow(
            sessionId: sessionId,
            context: context
        )
        var finalContext = updatedContext

        let persistedTravel = try? await persistenceActor.resolvePersistedTravelTotals(forSessionId: sessionId)
        if let persistedTravel {
            finalContext.travelDistance = persistedTravel.distanceKM
            finalContext.travelTime = persistedTravel.timeToMinutes + persistedTravel.timeFromMinutes
            finalContext.travelTimeTo = persistedTravel.timeToMinutes
            finalContext.travelTimeFrom = persistedTravel.timeFromMinutes
            finalContext.travelTolls = NSDecimalNumber(decimal: persistedTravel.tolls).doubleValue
            finalContext.travelParking = NSDecimalNumber(decimal: persistedTravel.parking).doubleValue
            finalContext.travelMMMZoneDescriptor = persistedTravel.mmmZoneDescriptor
            finalContext.activityTransportChargeAmount = persistedTravel.preferredChargeAmount.map { NSDecimalNumber(decimal: $0).doubleValue }
            finalContext.providerTravelLabourChargeAmount = persistedTravel.preferredLabourChargeAmount.map { NSDecimalNumber(decimal: $0).doubleValue }
            finalContext.providerTravelNonLabourChargeAmount = persistedTravel.preferredNonLabourChargeAmount.map { NSDecimalNumber(decimal: $0).doubleValue }
            finalContext.isModifiedVehicle = persistedTravel.isModifiedVehicle
        }

        let preferActivity: Bool
        if let persistedTravel {
            preferActivity = persistedTravel.isActivityBased
        } else {
            preferActivity = finalContext.isActivityTransport
        }
        let hasTravelInputs = (persistedTravel != nil)
            || finalContext.travelDistance > 0
            || finalContext.travelTime > 0
            || finalContext.travelTolls > 0
            || finalContext.travelParking > 0
            || finalContext.isProviderTravel
            || finalContext.isActivityTransport

        if preferActivity && hasTravelInputs {
            finalContext.isActivityTransport = true
            finalContext.isProviderTravel = false
        } else if hasTravelInputs {
            finalContext.isProviderTravel = true
            finalContext.isActivityTransport = false
        } else {
            finalContext.isProviderTravel = false
            finalContext.isActivityTransport = false
        }

        return finalContext
    }

    /// Resolves persisted travel charge totals for a session from the main model context.
    nonisolated static func resolvePersistedTravelTotals(forSessionId sessionId: UUID, in modelContext: ModelContext) -> PersistedTravelTotals? {
        let descriptor = FetchDescriptor<TravelCharge>(
            predicate: #Predicate { $0.linkedSession?.id == sessionId }
        )
        guard let charges = try? modelContext.fetch(descriptor), !charges.isEmpty else { return nil }

        let distance = charges.compactMap(\.distanceKM).reduce(0, +)
        let tolls: Decimal = charges.compactMap(\.tollCost).reduce(0, +)
        let parking: Decimal = charges.compactMap(\.parkingCost).reduce(0, +)
        let mmmDescriptor = charges.compactMap(\.mmmZoneName).first { !$0.isEmpty }
        let isActivityBased = charges.contains { $0.chargeType == .activityBased }
        let activityAmounts = charges
            .filter { $0.chargeType == .activityBased }
            .compactMap(\.chargeAmount)
            .filter { $0 > 0 }
        let labourAmounts = charges
            .filter { $0.chargeType == .labour }
            .compactMap(\.chargeAmount)
            .filter { $0 > 0 }
        let nonLabourAmounts = charges
            .filter { $0.chargeType == .nonLabour || $0.chargeType == .standard }
            .compactMap(\.chargeAmount)
            .filter { $0 > 0 }
        let preferredChargeAmount: Decimal? = activityAmounts.isEmpty ? nil : activityAmounts.reduce(0, +)
        let preferredLabourChargeAmount: Decimal? = labourAmounts.isEmpty ? nil : labourAmounts.reduce(0, +)
        let preferredNonLabourChargeAmount: Decimal? = nonLabourAmounts.isEmpty ? nil : nonLabourAmounts.reduce(0, +)
        let isModifiedVehicle = charges.contains { Self.isModifiedVehicle($0.vehicleType) }

        var timeTo: Double = 0
        var timeFrom: Double = 0
        for charge in charges {
            let rawMinutes = max(charge.durationMinutes ?? 0, 0)
            let capped = Self.cappedTravelMinutes(rawMinutes, mmmZoneDescriptor: charge.mmmZoneName ?? mmmDescriptor)
            switch charge.travelDirection {
            case .after, .fromClient:
                timeFrom += capped
            case .before, .toClient, .roundTrip, .betweenClients, .none:
                timeTo += capped
            }
        }

        guard distance > 0 || timeTo > 0 || timeFrom > 0 || tolls > 0 || parking > 0
            || preferredChargeAmount != nil
            || preferredLabourChargeAmount != nil
            || preferredNonLabourChargeAmount != nil else { return nil }
        return PersistedTravelTotals(
            distanceKM: distance,
            timeToMinutes: timeTo,
            timeFromMinutes: timeFrom,
            tolls: tolls,
            parking: parking,
            mmmZoneDescriptor: mmmDescriptor,
            isActivityBased: isActivityBased,
            preferredChargeAmount: preferredChargeAmount,
            preferredLabourChargeAmount: preferredLabourChargeAmount,
            preferredNonLabourChargeAmount: preferredNonLabourChargeAmount,
            isModifiedVehicle: isModifiedVehicle
        )
    }

    /// Calculates billable line items with geo-warning propagation for a session.
    func calculateBillableAmountsWithWarnings(
        for session: SessionSnapshot,
        client: ClientSnapshot,
        service: ClientServiceSnapshot,
        billingContext: NDISBillingContext
    ) async throws -> (lines: [NDISClaimableLineItem], warnings: [String]) {
        let (inputVector, warnings) = try await createBillingInputVector(
            from: session,
            client: client,
            service: service,
            billingContext: billingContext
        )
        let modelContext = ModelContainerFactory.makeEphemeralContext(from: modelContainer)
        let configService = NDISBillingConfigService(mmmZoneLookup: mmmZoneLookup)
        let billingService = NDISBillingService(modelContext: modelContext, configService: configService)
        let linesResult = try await billingService.calculateBillableAmountWithWarnings(context: inputVector)
        var combinedWarnings = warnings
        combinedWarnings.append(contentsOf: linesResult.warnings)
        if inputVector.participant.planManagementType == "Self-Managed",
           linesResult.lines.contains(where: Self.isTravelClaimType) {
            combinedWarnings.append(Self.selfManagedTravelInvoiceOnlyWarning)
        }
        return (linesResult.lines, combinedWarnings)
    }

    /// Geo gate enforcement for the draft billing path.
    func enforceGeoBillingGate(
        for session: SessionSnapshot,
        client: ClientSnapshot,
        billingContext: NDISBillingContext
    ) async throws -> [String] {
        let business = try fetchFirstBusinessSnapshot()

        let participantCoords = await resolveCoordinates(
            sessionLatitude: session.sessionLatitude,
            sessionLongitude: session.sessionLongitude,
            sessionAddress: session.address,
            clientAddress: client.address,
            locationHint: session.location
        )
        let providerCoords = await resolveCoordinates(
            sessionLatitude: business?.address?.latitude ?? 0,
            sessionLongitude: business?.address?.longitude ?? 0,
            sessionAddress: business?.address,
            clientAddress: nil,
            locationHint: nil
        )

        let participantLocation = NDISLocation(
            postcode: client.address?.postcode ?? session.address?.postcode ?? "",
            suburb: client.address?.suburb ?? session.address?.suburb,
            state: client.address?.state ?? session.address?.state,
            latitude: participantCoords.latitude,
            longitude: participantCoords.longitude
        )
        let providerLocation = NDISLocation(
            postcode: business?.address?.postcode ?? "",
            suburb: business?.address?.suburb,
            state: business?.address?.state,
            latitude: providerCoords.latitude,
            longitude: providerCoords.longitude
        )

        let isDirect = !(billingContext.isTelehealth || billingContext.isNonFaceToFace || billingContext.isNdiaReport)
        let geoLocation = isDirect ? participantLocation : providerLocation
        let mmmRating: Int? = {
            guard let lat = geoLocation.latitude, let lon = geoLocation.longitude else { return nil }
            return mmmZoneLookup.mmm(for: .init(latitude: lat, longitude: lon))
        }()
        var warnings: [String] = []
        switch Self.geoBillingGate(
            hasAddressOrPostcode: geoLocation.hasAddressOrPostcode,
            mmmRating: mmmRating
        ) {
        case .proceed:
            break
        case .proceedWithFallbackWarning:
            warnings.append(Self.geoFallbackWarning)
        case .failUnresolvedWithAddress:
            throw NDISBillingIntegrationError.unresolvedGeographicZone
        }
        return warnings
    }
}

// MARK: - Billing Vector and Geo Helpers

extension NDISBillingIntegrationService {
    // MARK: - Shared Static Helpers

    struct PersistedTravelTotals {
        let distanceKM: Double
        let timeToMinutes: Double
        let timeFromMinutes: Double
        let tolls: Decimal
        let parking: Decimal
        let mmmZoneDescriptor: String?
        let isActivityBased: Bool
        let preferredChargeAmount: Decimal?
        let preferredLabourChargeAmount: Decimal?
        let preferredNonLabourChargeAmount: Decimal?
        let isModifiedVehicle: Bool
    }

    enum GeoBillingGate: Equatable, Sendable {
        case proceed
        case proceedWithFallbackWarning
        case failUnresolvedWithAddress
    }

    nonisolated static func geoBillingGate(hasAddressOrPostcode: Bool, mmmRating: Int?) -> GeoBillingGate {
        if mmmRating != nil { return .proceed }
        if hasAddressOrPostcode { return .failUnresolvedWithAddress }
        return .proceedWithFallbackWarning
    }

    nonisolated static func isModifiedVehicle(_ vehicleType: VehicleType?) -> Bool {
        vehicleType == .modifiedBus
    }

    nonisolated static let geoFallbackWarning =
        "Billed at 1.0× geographic loading — no address/postcode to resolve MMM zone"

    nonisolated static let geoUnresolvedFailureReason =
        "Geographic zone unresolved (address/postcode present but MMM could not be determined)"

    nonisolated static func cappedTravelMinutes(_ minutes: Double, mmmZoneDescriptor: String?) -> Double {
        let maxMinutes = NDISTravelChargeCalculator.maxBillableMinutes(forMMMDescriptor: mmmZoneDescriptor)
        if maxMinutes.isInfinite { return max(minutes, 0) }
        return min(max(minutes, 0), maxMinutes)
    }

    static func decimalHours(fromHHHMM value: String) -> Double? {
        let parts = value.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              hours >= 0,
              (0...59).contains(minutes) else { return nil }
        return Double(hours) + Double(minutes) / 60.0
    }

    static func resolvedQuantity(quantity: Decimal?, hoursHHHMM: String?) -> Decimal? {
        if let quantity { return quantity }
        return hoursHHHMM.flatMap { decimalHours(fromHHHMM: $0).map { Decimal($0) } }
    }

    static let selfManagedTravelInvoiceOnlyWarning = "Self-managed: travel included on invoice only"

    static func isTravelClaimType(_ line: NDISClaimableLineItem) -> Bool {
        let type = line.claimType
        return type == "ActivityTransport" || type.hasPrefix("ProviderTravel")
    }

    static func draftTravelConflictReason(
        in lines: [NDISClaimableLineItem],
        billingContext: NDISBillingContext
    ) -> String? {
        let hasActivityTransport = lines.contains { $0.claimType == NDISClaimType.activityTransport.rawValue }
        let hasProviderTravel = lines.contains { $0.claimType.hasPrefix(NDISClaimType.providerTravel.rawValue) }

        if hasActivityTransport && hasProviderTravel {
            return "Draft includes both Activity Transport and Provider Travel. Keep only one travel method."
        }
        if hasActivityTransport && billingContext.isProviderTravel {
            return "Saved travel selects Provider Travel, but draft includes Activity Transport. Update the draft travel line."
        }
        if hasProviderTravel && billingContext.isActivityTransport {
            return "Saved travel selects Activity Transport, but draft includes Provider Travel. Update the draft travel line."
        }
        return nil
    }

    // MARK: - Private Billing Input Vector Construction

    func createBillingInputVector(
        from session: SessionSnapshot,
        client: ClientSnapshot,
        service: ClientServiceSnapshot,
        billingContext: NDISBillingContext
    ) async throws -> (NDISBillingInputVector, [String]) {
        guard let startTime = session.startTime, let endTime = session.endTime else {
            throw NDISBillingIntegrationError.missingSessionTimes
        }

        let business = try fetchFirstBusinessSnapshot()

        let participantCoords = await resolveCoordinates(
            sessionLatitude: session.sessionLatitude,
            sessionLongitude: session.sessionLongitude,
            sessionAddress: session.address,
            clientAddress: client.address,
            locationHint: session.location
        )
        let providerCoords = await resolveCoordinates(
            sessionLatitude: business?.address?.latitude ?? 0,
            sessionLongitude: business?.address?.longitude ?? 0,
            sessionAddress: business?.address,
            clientAddress: nil,
            locationHint: nil
        )

        let participant = NDISParticipantInfo(
            ndisNumber: client.ndisNumber,
            planManagementType: client.planManagementType ?? "Plan-Managed",
            location: NDISLocation(
                postcode: client.address?.postcode ?? session.address?.postcode ?? "",
                suburb: client.address?.suburb ?? session.address?.suburb,
                state: client.address?.state ?? session.address?.state,
                latitude: participantCoords.latitude,
                longitude: participantCoords.longitude
            )
        )

        let provider = NDISProviderInfo(
            abn: business?.abn ?? "",
            location: NDISLocation(
                postcode: business?.address?.postcode ?? "",
                suburb: business?.address?.suburb,
                state: business?.address?.state,
                latitude: providerCoords.latitude,
                longitude: providerCoords.longitude
            ),
            foundAlternativeWork: false
        )

        let isDirect = !(billingContext.isTelehealth || billingContext.isNonFaceToFace || billingContext.isNdiaReport)
        let geoLocation = isDirect ? participant.location : provider.location
        let mmmRating: Int? = {
            guard let lat = geoLocation.latitude, let lon = geoLocation.longitude else { return nil }
            return mmmZoneLookup.mmm(for: .init(latitude: lat, longitude: lon))
        }()
        var warnings: [String] = []
        switch Self.geoBillingGate(
            hasAddressOrPostcode: geoLocation.hasAddressOrPostcode,
            mmmRating: mmmRating
        ) {
        case .proceed: break
        case .proceedWithFallbackWarning: warnings.append(Self.geoFallbackWarning)
        case .failUnresolvedWithAddress: throw NDISBillingIntegrationError.unresolvedGeographicZone
        }

        let durationHours = endTime.timeIntervalSince(startTime) / 3600.0
        let supportItemNumber = !billingContext.supportItemNumber.isEmpty
            ? billingContext.supportItemNumber
            : (service.ndisCode ?? "")

        let serviceInfo = NDISServiceInfo(
            supportItemNumber: supportItemNumber,
            startTime: startTime,
            endTime: endTime,
            duration: durationHours,
            quantity: max(durationHours, 0),
            date: startTime,
            hoursPerMonth: nil,
            consecutiveMonths: service.consecutiveMonths,
            category: nil,
            silVacancyId: nil
        )

        let agreement = NDISAgreementInfo(
            agreedPrice: NSDecimalNumber(decimal: service.rate).doubleValue,
            agreedCancellationPolicy: nil,
            agreedTravelRatePerKM: nil
        )

        let providerType = NDISTravelChargeCalculator.inferredProviderType(
            itemName: service.serviceName,
            itemDescription: nil,
            ndisCode: service.ndisCode ?? service.ndisItemNumber ?? supportItemNumber
        ).rawValue

        let useActivityTransport = billingContext.isActivityTransport
        let useProviderTravel = billingContext.isProviderTravel && !useActivityTransport

        let context = NDISContextInfo(
            isPrepaymentClaim: billingContext.isPrepayment,
            isSubscriptionClaim: false,
            isBereavementClaim: false,
            isCancellation: billingContext.isShortNoticeCancellation || session.status == .cancelled,
            isProviderTravel: useProviderTravel,
            isActivityTransport: useActivityTransport,
            isNonFaceToFace: billingContext.isNonFaceToFace,
            isNDIAReport: billingContext.isNdiaReport,
            isShadowShift: billingContext.isShadowShift,
            isSilUnplannedExit: billingContext.isSilUnplannedExit,
            isComplexBehaviour: billingContext.isComplexBehavior,
            isHighIntensity: billingContext.isHighIntensity,
            isGroupSupport: billingContext.isGroupSupport,
            isTelehealth: billingContext.isTelehealth,
            isIrregularSil: billingContext.isSilUnplannedExit,
            isDirectService: isDirect,
            groupSize: max(billingContext.groupSize, 1),
            travelGroupSize: max(billingContext.groupSize, 1),
            transportGroupSize: max(billingContext.groupSize, 1),
            participantAttended: !billingContext.isShortNoticeCancellation,
            nonFaceToFaceDuration: billingContext.isNonFaceToFace ? durationHours : nil,
            ndiaReportDuration: billingContext.isNdiaReport ? durationHours : nil,
            nonFaceToFaceActivityDescription: nil,
            coPaymentAmount: max(billingContext.coPaymentAmount, 0),
            travelTimeTo: billingContext.travelTimeTo > 0 ? billingContext.travelTimeTo : billingContext.travelTime,
            travelTimeFrom: billingContext.travelTimeFrom,
            travelKilometres: billingContext.travelDistance,
            travelTolls: billingContext.travelTolls,
            travelParking: billingContext.travelParking,
            providerType: providerType
        )

        let rawTimeTo = billingContext.travelTimeTo > 0 ? billingContext.travelTimeTo : billingContext.travelTime
        let cappedTimeTo = Self.cappedTravelMinutes(rawTimeTo, mmmZoneDescriptor: billingContext.travelMMMZoneDescriptor)
        let cappedTimeFrom = Self.cappedTravelMinutes(billingContext.travelTimeFrom, mmmZoneDescriptor: billingContext.travelMMMZoneDescriptor)

        let travel: NDISTravelInfo? = useProviderTravel
            ? NDISTravelInfo(
                timeTo: cappedTimeTo,
                timeFrom: cappedTimeFrom,
                kilometres: max(0, billingContext.travelDistance),
                tolls: max(0, billingContext.travelTolls),
                parking: max(0, billingContext.travelParking),
                preferredLabourChargeAmount: billingContext.providerTravelLabourChargeAmount,
                preferredNonLabourChargeAmount: billingContext.providerTravelNonLabourChargeAmount
            )
            : nil

        let cancellation: NDISCancellationInfo? = {
            guard context.isCancellation else { return nil }
            return NDISCancellationInfo(noticeTime: Date())
        }()

        let transport: NDISTransportInfo? = useActivityTransport
            ? NDISTransportInfo(
                kilometres: max(0, billingContext.travelDistance),
                tolls: max(0, billingContext.travelTolls),
                parking: max(0, billingContext.travelParking),
                isModifiedVehicle: billingContext.isModifiedVehicle,
                preferredChargeAmount: billingContext.activityTransportChargeAmount
            )
            : nil

        let vector = NDISBillingInputVector(
            participant: participant,
            provider: provider,
            service: serviceInfo,
            agreement: agreement,
            context: context,
            travel: travel,
            transport: transport,
            cancellation: cancellation,
            prepayment: nil
        )
        return (vector, warnings)
    }

    func fetchFirstBusinessSnapshot() throws -> BusinessSnapshot? {
        let modelContext = ModelContainerFactory.makeEphemeralContext(from: modelContainer)
        let descriptor = FetchDescriptor<Business>()
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    func resolveCoordinates(
        sessionLatitude: Double,
        sessionLongitude: Double,
        sessionAddress: AddressSnapshot?,
        clientAddress: AddressSnapshot?,
        locationHint: String?
    ) async -> (latitude: Double?, longitude: Double?) {
        if sessionLatitude != 0, sessionLongitude != 0 { return (sessionLatitude, sessionLongitude) }
        if let address = sessionAddress, address.latitude != 0, address.longitude != 0 { return (address.latitude, address.longitude) }
        if let address = clientAddress, address.latitude != 0, address.longitude != 0 { return (address.latitude, address.longitude) }

        var candidates: [String] = []
        if let formatted = sessionAddress?.fullFormattedAddress.trimmedNil { candidates.append(formatted) }
        if let formatted = clientAddress?.fullFormattedAddress.trimmedNil { candidates.append(formatted) }
        if let hint = locationHint?.trimmedNil { candidates.append(hint) }
        if let postcodeOnly = Self.postcodeAddressQuery(from: sessionAddress ?? clientAddress) { candidates.append(postcodeOnly) }

        var seen = Set<String>()
        for candidate in candidates where seen.insert(candidate).inserted {
            if let coords = await geocodingService.geocodeAddressString(candidate) {
                return (coords.latitude, coords.longitude)
            }
        }
        return (nil, nil)
    }

    private static func postcodeAddressQuery(from address: AddressSnapshot?) -> String? {
        guard let address else { return nil }
        var parts: [String] = []
        let suburb = address.suburb.trimmingCharacters(in: .whitespacesAndNewlines)
        let city = address.city.trimmingCharacters(in: .whitespacesAndNewlines)
        let state = address.state.trimmingCharacters(in: .whitespacesAndNewlines)
        let postcode = address.postcode.trimmingCharacters(in: .whitespacesAndNewlines)
        if !suburb.isEmpty { parts.append(suburb) }
        else if !city.isEmpty { parts.append(city) }
        if !state.isEmpty { parts.append(state) }
        if !postcode.isEmpty { parts.append(postcode) }
        guard !parts.isEmpty else { return nil }
        if parts.last != "Australia" { parts.append("Australia") }
        return parts.joined(separator: " ")
    }
}
