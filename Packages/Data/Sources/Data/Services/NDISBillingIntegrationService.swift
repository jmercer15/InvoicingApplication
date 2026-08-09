//
//  NDISBillingIntegrationService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation
import Core
import PersistenceModels
import CoreLocation
import SwiftData

/// Service that integrates existing application data with the NDIS billing algorithm
@MainActor
public class NDISBillingIntegrationService {
    private let modelContainer: ModelContainer
    private let geocodingService: SwiftDataGeocodingService
    private let mmmZoneLookup: Core.MMMZoneLookup

    public init(
        modelContainer: ModelContainer,
        geocodingService: SwiftDataGeocodingService,
        mmmZoneLookup: Core.MMMZoneLookup
    ) {
        self.modelContainer = modelContainer
        self.geocodingService = geocodingService
        self.mmmZoneLookup = mmmZoneLookup
    }

    /// Convenience initializer for callers that only have a `ModelContext`. Internally captures the
    /// container so this service does not share UI save scope.
    public convenience init(
        modelContext: ModelContext,
        geocodingService: SwiftDataGeocodingService,
        mmmZoneLookup: Core.MMMZoneLookup
    ) {
        self.init(
            modelContainer: modelContext.container,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup
        )
    }

    public func generateNDISInvoice(for sessionIds: [UUID], clientId: UUID) async throws -> Core.NDISBillingReport {
        let uniqueSessionIds = Array(Set(sessionIds))
        guard !uniqueSessionIds.isEmpty else {
            return Core.NDISBillingReport(
                invoice: nil,
                processedSessionsCount: 0,
                successfulSessionsCount: 0,
                failedSessions: []
            )
        }

        let modelContext = ModelContainerFactory.makeEphemeralContext(from: modelContainer)
        
        // 1. Fetch Client
        guard let client = try modelContext.fetch(FetchDescriptor<Client>(predicate: #Predicate { $0.id == clientId })).first else {
            return Core.NDISBillingReport(
                invoice: nil,
                processedSessionsCount: uniqueSessionIds.count,
                successfulSessionsCount: 0,
                failedSessions: uniqueSessionIds.map { Core.NDISBillingIssue(sessionId: $0, sessionTitle: "Unknown", reason: "Client not found") }
            )
        }

        // 2. Create Invoice
        let creationDefaults = InvoiceCreationDefaults.load(from: .standard)
        let issueDate = Date()
        let randomSuffix = String(format: "%04d", Int.random(in: 0..<10000))
        let invoiceNumber = "NDIS-\(Int(Date().timeIntervalSince1970))-\(randomSuffix)"
        let invoice = Invoice(id: UUID(), invoiceNumber: invoiceNumber)
        invoice.client = client
        invoice.date = issueDate
        invoice.issueDate = issueDate
        invoice.dueDate = Calendar.current.date(
            byAdding: .day,
            value: creationDefaults.paymentTermsDays,
            to: issueDate
        )
        invoice.paymentTerms = creationDefaults.paymentTermsText.trimmedNil
        invoice.notes = creationDefaults.notes.trimmedNil
        invoice.status = .reviewDraft
        invoice.totalAmount = 0
        invoice.taxRate = Decimal(creationDefaults.taxRate)
        invoice.invoiceEditorStateData = try creationDefaults.editorConfiguration.encoded()

        // Link the seller (Business) before snapshotting so seller/bank details populate for PDF.
        invoice.business = try EntityResolutionService(context: modelContext).resolveBusiness()

        // Link related data snapshots (crucial for PDF rendering)
        invoice.snapshotRelatedData()
        
        modelContext.insert(invoice)

        var successfulSessionsCount = 0
        var failedSessions = [Core.NDISBillingIssue]()
        var reportWarnings = [String]()
        var generatedItems: [InvoiceItem] = []

        // 3. Process Sessions
        for sessionId in uniqueSessionIds {
            var sessionTitleForFailure = "Session"
            do {
                guard let session = try modelContext.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })).first else {
                    failedSessions.append(Core.NDISBillingIssue(sessionId: sessionId, sessionTitle: "Unknown", reason: "Session not found"))
                    continue
                }
                sessionTitleForFailure = session.title

                // Determine claimable lines
                let lineItems: [NDISClaimableLineItem]
                let draftGSTBySupport: [String: String]
                if let draft = session.billableDrafts?.first, let items = draft.items, !items.isEmpty {
                    // Use items from existing draft. Hour-based lines store their quantity as
                    // `hoursHHHMM` (e.g. "002:30") rather than `quantity`; never coerce
                    // those to 0. Invalid/zero quantities fail the session instead of writing $0 lines.
                    var parsed: [NDISClaimableLineItem] = []
                    var gstBySupport: [String: String] = [:]
                    var quantityFailed = false
                    for line in items {
                        guard let quantity = Self.resolvedQuantity(quantity: line.quantity, hoursHHHMM: line.hoursHHHMM),
                              quantity > 0 else {
                            quantityFailed = true
                            break
                        }
                        parsed.append(
                            NDISClaimableLineItem(
                                supportItemNumber: line.supportItemNumber,
                                quantity: quantity,
                                unitPrice: line.unitPrice,
                                totalAmount: quantity * line.unitPrice,
                                claimType: line.claimType
                            )
                        )
                        if !line.gstCode.isEmpty {
                            gstBySupport[line.supportItemNumber] = line.gstCode
                        }
                    }
                    if quantityFailed {
                        failedSessions.append(Core.NDISBillingIssue(
                            sessionId: sessionId,
                            sessionTitle: session.title,
                            reason: "Draft line has zero or invalid quantity"
                        ))
                        continue
                    }

                    // Draft path: always run geo gate; merge live travel when charges exist
                    // but draft omitted travel claim types.
                    let billingContext = await self.resolveBillingContext(forSessionId: sessionId)
                    let geoWarnings = try await self.enforceGeoBillingGate(
                        for: session.snapshot(),
                        client: client.snapshot(),
                        billingContext: billingContext
                    )
                    reportWarnings.append(contentsOf: geoWarnings.map {
                        "\(session.title): \($0)"
                    })

                    // A saved billable draft can outlive a later travel edit. Never let its
                    // manually retained lines bypass the Activity Transport / Provider Travel
                    // choice made by the current travel source of truth.
                    if let conflictReason = Self.draftTravelConflictReason(
                        in: parsed,
                        billingContext: billingContext
                    ) {
                        failedSessions.append(Core.NDISBillingIssue(
                            sessionId: sessionId,
                            sessionTitle: session.title,
                            reason: conflictReason
                        ))
                        continue
                    }

                    let draftHasTravel = parsed.contains(where: Self.isTravelClaimType)
                    let persistedTravel = Self.resolvePersistedTravelTotals(
                        forSessionId: session.id,
                        in: modelContext
                    )
                    if persistedTravel != nil, !draftHasTravel {
                        guard let service = session.clientService else {
                            failedSessions.append(Core.NDISBillingIssue(
                                sessionId: sessionId,
                                sessionTitle: session.title,
                                reason: "No service assigned to session"
                            ))
                            continue
                        }
                        let (liveLines, liveWarnings) = try await self.calculateBillableAmountsWithWarnings(
                            for: session.snapshot(),
                            client: client.snapshot(),
                            service: service.snapshot(),
                            billingContext: billingContext
                        )
                        // Geo already enforced; keep soft-skip / self-managed travel warnings only.
                        let nonGeoWarnings = liveWarnings.filter { $0 != Self.geoFallbackWarning }
                        reportWarnings.append(contentsOf: nonGeoWarnings.map {
                            "\(session.title): \($0)"
                        })

                        let travelLines = liveLines.filter(Self.isTravelClaimType)
                        if travelLines.isEmpty,
                           billingContext.isProviderTravel || billingContext.isActivityTransport
                            || (persistedTravel?.preferredChargeAmount ?? 0) > 0
                            || (persistedTravel?.preferredLabourChargeAmount ?? 0) > 0
                            || (persistedTravel?.preferredNonLabourChargeAmount ?? 0) > 0 {
                            failedSessions.append(Core.NDISBillingIssue(
                                sessionId: sessionId,
                                sessionTitle: session.title,
                                reason: billingContext.isActivityTransport
                                    ? NDISBillingService.activityTravelNotEligibleReason
                                    : NDISBillingService.providerTravelNotEligibleReason
                            ))
                            continue
                        }
                        parsed.append(contentsOf: travelLines)
                    }

                    lineItems = parsed
                    draftGSTBySupport = gstBySupport
                } else {
                    // Calculate live
                    guard let service = session.clientService else {
                        failedSessions.append(Core.NDISBillingIssue(sessionId: sessionId, sessionTitle: session.title, reason: "No service assigned to session"))
                        continue
                    }
                    
                    let billingContext = await self.resolveBillingContext(forSessionId: sessionId)
                    let (calculated, geoWarnings) = try await self.calculateBillableAmountsWithWarnings(
                        for: session.snapshot(),
                        client: client.snapshot(),
                        service: service.snapshot(),
                        billingContext: billingContext
                    )
                    lineItems = calculated
                    draftGSTBySupport = [:]
                    reportWarnings.append(contentsOf: geoWarnings.map {
                        "\(session.title): \($0)"
                    })
                }

                guard !lineItems.isEmpty else {
                    failedSessions.append(Core.NDISBillingIssue(
                        sessionId: sessionId,
                        sessionTitle: session.title,
                        reason: "No claimable line items"
                    ))
                    continue
                }

                let clientService = session.clientService
                let supportName = clientService?.serviceName
                    ?? clientService?.ndisItem?.name
                let supportUnit = Self.resolvedUnit(
                    clientServiceUnit: clientService?.unit,
                    catalogueUnit: clientService?.ndisItem?.unit
                )
                let resolvedGST = Self.resolvedGSTCode(
                    draftCode: nil,
                    clientServiceCode: clientService?.gstCode,
                    fallback: GSTCode.p2
                )

                // Create InvoiceItems
                for item in lineItems {
                    let lineGST = Self.resolvedGSTCode(
                        draftCode: draftGSTBySupport[item.supportItemNumber],
                        clientServiceCode: clientService?.gstCode,
                        fallback: resolvedGST
                    )
                    let invoiceItem = InvoiceItem(
                        id: UUID(),
                        itemDescription: Self.lineDescription(
                            serviceName: supportName,
                            code: item.supportItemNumber
                        )
                    )
                    invoiceItem.position = Int32(generatedItems.count)
                    invoiceItem.ndisItemNumber = item.supportItemNumber
                    invoiceItem.rate = Self.currencyDecimal(item.unitPrice)
                    invoiceItem.quantity = Self.currencyDecimal(item.quantity)
                    invoiceItem.unit = Self.unitForClaimType(item.claimType, supportUnit: supportUnit)
                    invoiceItem.gstCode = lineGST.rawValue
                    invoiceItem.taxRate = lineGST.isGSTFree ? 0 : Decimal(creationDefaults.taxRate)
                    invoiceItem.serviceDate = session.startTime ?? Date()
                    invoiceItem.claimType = NDISClaimType(rawValue: item.claimType) ?? .direct
                    invoiceItem.invoice = invoice
                    invoiceItem.session = session
                    invoiceItem.clientService = clientService
                    modelContext.insert(invoiceItem)
                    generatedItems.append(invoiceItem)
                }

                session.invoice = invoice
                successfulSessionsCount += 1
            } catch let error as NDISBillingIntegrationError {
                failedSessions.append(Core.NDISBillingIssue(
                    sessionId: sessionId,
                    sessionTitle: sessionTitleForFailure,
                    reason: error.failureReason
                ))
            } catch let error as NDISBillingError {
                failedSessions.append(Core.NDISBillingIssue(
                    sessionId: sessionId,
                    sessionTitle: sessionTitleForFailure,
                    reason: error.errorDescription ?? error.localizedDescription
                ))
            } catch {
                failedSessions.append(Core.NDISBillingIssue(
                    sessionId: sessionId,
                    sessionTitle: sessionTitleForFailure,
                    reason: error.localizedDescription
                ))
            }
        }

        guard !generatedItems.isEmpty else {
            modelContext.delete(invoice)
            if modelContext.hasChanges { try modelContext.save() }
            return Core.NDISBillingReport(
                invoice: nil,
                processedSessionsCount: uniqueSessionIds.count,
                successfulSessionsCount: 0,
                failedSessions: failedSessions,
                warnings: reportWarnings
            )
        }

        invoice.items = generatedItems
        invoice.recalculateStoredTotal()
        
        if modelContext.hasChanges {
            try modelContext.save()
        }

        return Core.NDISBillingReport(
            invoice: invoice.snapshot(),
            processedSessionsCount: uniqueSessionIds.count,
            successfulSessionsCount: successfulSessionsCount,
            failedSessions: failedSessions,
            warnings: reportWarnings
        )
    }

    /// Not private so DataTests can exercise the TravelCharge-preference behavior directly
    /// without requiring network-backed MapKit calls.
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

        // Trigger automation flow to properly populate the context (e.g. travel, geographic area, etc.).
        // This ensures the live calculation uses high-fidelity data like real travel distances.
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

        // Persisted TravelCharge rows are the source of truth entered by the provider; MapKit's
        // estimate (populated above) is only a fallback when no TravelCharge has been recorded.
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

        // Activity transport XOR provider travel — never both from the same inputs.
        // When TravelCharge rows exist, chargeType alone decides; orchestrator flag only when none.
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
                // Before/to-client and legacy undirected rows count as travel to the session.
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

    /// Pure gate used after geocode: address + unresolved MMM fails; no address → 1.0× with warning.
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
        if maxMinutes.isInfinite {
            return max(minutes, 0)
        }
        return min(max(minutes, 0), maxMinutes)
    }

    /// Parses `HHH:MM` with minutes restricted to `0...59`. Invalid minutes return `nil`.
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
        if let quantity {
            return quantity
        }
        return hoursHHHMM.flatMap { decimalHours(fromHHHMM: $0).map { Decimal($0) } }
    }

    static func lineDescription(serviceName: String?, code: String) -> String {
        let name = serviceName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return trimmedCode }
        if trimmedCode.isEmpty { return name }
        return "\(name) (\(trimmedCode))"
    }

    static func resolvedUnit(clientServiceUnit: String?, catalogueUnit: String?) -> String {
        let serviceUnit = clientServiceUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !serviceUnit.isEmpty { return serviceUnit }
        let catalogue = catalogueUnit?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !catalogue.isEmpty { return catalogue }
        return "hour"
    }

    static func unitForClaimType(_ claimType: String, supportUnit: String) -> String {
        if claimType.contains("NonLabour") || claimType == NDISClaimType.activityTransport.rawValue {
            return "km"
        }
        if claimType.contains("OtherCosts") {
            return "each"
        }
        if claimType == NDISClaimType.centreCapitalCost.rawValue
            || claimType == NDISClaimType.establishmentFee.rawValue {
            return "unit"
        }
        return supportUnit
    }

    static func resolvedGSTCode(
        draftCode: String?,
        clientServiceCode: String?,
        fallback: GSTCode
    ) -> GSTCode {
        if let draftCode, let code = GSTCode(rawValue: draftCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) {
            return code
        }
        if let clientServiceCode,
           let code = GSTCode(rawValue: clientServiceCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()) {
            return code
        }
        return fallback
    }

    static func currencyDecimal(_ value: Decimal) -> Decimal {
        InvoiceFinancialCalculator.currencyRounded(value)
    }

    /// Geocoding, travel, and billing-context automation for NDIS billing.
    public func executeAutomationFlow(for session: SessionSnapshot, context: inout NDISBillingContext) async -> AutomationResult {
        let modelContext = ModelContainerFactory.makeEphemeralContext(from: modelContainer)
        let orchestrator = NDISBillingAutomationOrchestrator(
            modelContext: modelContext,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup,
            mapKitTravelService: MapKitTravelService()
        )
        let (updatedContext, result) = await orchestrator.executeAutomationFlow(
            sessionId: session.id,
            context: context
        )
        context = updatedContext
        return result
    }
    
    public func calculateBillableAmounts(
        for session: SessionSnapshot,
        client: ClientSnapshot,
        service: ClientServiceSnapshot,
        billingContext: NDISBillingContext
    ) async throws -> [NDISClaimableLineItem] {
        let (lines, _) = try await calculateBillableAmountsWithWarnings(
            for: session,
            client: client,
            service: service,
            billingContext: billingContext
        )
        return lines
    }

    /// Same as `calculateBillableAmounts` but surfaces geo fallback warnings for Hub feedback.
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

    static let selfManagedTravelInvoiceOnlyWarning = "Self-managed: travel included on invoice only"

    static func isTravelClaimType(_ line: NDISClaimableLineItem) -> Bool {
        let type = line.claimType
        return type == "ActivityTransport"
            || type.hasPrefix("ProviderTravel")
    }

    /// Draft line items are editable and can become stale after a TravelCharge changes type.
    /// Reject conflicts rather than silently dropping a line or generating duplicate travel.
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

    /// Geo under-bill gate only (draft path and callers that already have line amounts).
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

    // MARK: - Snapshot input vector construction

    private func createBillingInputVector(
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

        // Geo under-bill guard: address/postcode + unresolved MMM fails the session;
        // no address → allow 1.0× with a Hub warning.
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
        case .proceed:
            break
        case .proceedWithFallbackWarning:
            warnings.append(Self.geoFallbackWarning)
        case .failUnresolvedWithAddress:
            throw NDISBillingIntegrationError.unresolvedGeographicZone
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

        // Enforce ActivityTransport XOR provider travel at the input-vector boundary.
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
        let cappedTimeTo = Self.cappedTravelMinutes(
            rawTimeTo,
            mmmZoneDescriptor: billingContext.travelMMMZoneDescriptor
        )
        let cappedTimeFrom = Self.cappedTravelMinutes(
            billingContext.travelTimeFrom,
            mmmZoneDescriptor: billingContext.travelMMMZoneDescriptor
        )

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

        // Only populate transport when activity-transport context is set, so ActivityTransport
        // lines have the km/tolls/parking they need to emit. Prefer stored chargeAmount.
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

    private func fetchFirstBusinessSnapshot() throws -> BusinessSnapshot? {
        let modelContext = ModelContainerFactory.makeEphemeralContext(from: modelContainer)
        let descriptor = FetchDescriptor<Business>()
        return try modelContext.fetch(descriptor).first?.snapshot()
    }

    /// Resolve lat/lon for MMM: stored coords first, then geocode postcode/address strings.
    /// Returns `(nil, nil)` when nothing resolves — geo loading then uses 1.0x.
    private func resolveCoordinates(
        sessionLatitude: Double,
        sessionLongitude: Double,
        sessionAddress: AddressSnapshot?,
        clientAddress: AddressSnapshot?,
        locationHint: String?
    ) async -> (latitude: Double?, longitude: Double?) {
        if sessionLatitude != 0, sessionLongitude != 0 {
            return (sessionLatitude, sessionLongitude)
        }
        if let address = sessionAddress, address.latitude != 0, address.longitude != 0 {
            return (address.latitude, address.longitude)
        }
        if let address = clientAddress, address.latitude != 0, address.longitude != 0 {
            return (address.latitude, address.longitude)
        }

        var candidates: [String] = []
        if let formatted = sessionAddress?.fullFormattedAddress.trimmedNil {
            candidates.append(formatted)
        }
        if let formatted = clientAddress?.fullFormattedAddress.trimmedNil {
            candidates.append(formatted)
        }
        if let hint = locationHint?.trimmedNil {
            candidates.append(hint)
        }
        if let postcodeOnly = Self.postcodeAddressQuery(from: sessionAddress ?? clientAddress) {
            candidates.append(postcodeOnly)
        }

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

// MARK: - Error Types

// MARK: - Supporting Types

enum NDISBillingIntegrationError: Error {
    case missingSessionTimes
    case unresolvedGeographicZone

    var failureReason: String {
        switch self {
        case .missingSessionTimes:
            return "Session is missing start or end time"
        case .unresolvedGeographicZone:
            return NDISBillingIntegrationService.geoUnresolvedFailureReason
        }
    }
}

extension NDISBillingIntegrationService: Core.NDISBillingIntegrationServiceProtocol {}

private extension String {
    var trimmedNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
