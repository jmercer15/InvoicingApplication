//
//  NDISBillingIntegrationService.swift
//  InvoicingApplication
//
//  Lightweight facade coordinating high-level NDIS billing workflows.
//  Implementation details live in:
//    - NDISInvoiceBuilder.swift   (invoice & line item creation)
//    - NDISSessionClaimProcessor.swift  (session claim calc & travel context)
//

import Foundation
import Core
import PersistenceModels
import CoreLocation
import SwiftData

/// Service that integrates existing application data with the NDIS billing algorithm.
@MainActor
public class NDISBillingIntegrationService {
    let modelContainer: ModelContainer
    let geocodingService: SwiftDataGeocodingService
    let mmmZoneLookup: Core.MMMZoneLookup

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

    // MARK: - Main Entry Point

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

        // 2. Create Invoice (NDISInvoiceBuilder)
        let invoice = try makeInvoice(for: client, in: modelContext)

        var successfulSessionsCount = 0
        var failedSessions = [Core.NDISBillingIssue]()
        var reportWarnings = [String]()
        var generatedItems: [InvoiceItem] = []

        // 3. Process Sessions (NDISSessionClaimProcessor)
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

                    let billingContext = await self.resolveBillingContext(forSessionId: sessionId)
                    let geoWarnings = try await self.enforceGeoBillingGate(
                        for: session.snapshot(),
                        client: client.snapshot(),
                        billingContext: billingContext
                    )
                    reportWarnings.append(contentsOf: geoWarnings.map { "\(session.title): \($0)" })

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
                    let persistedTravel = Self.resolvePersistedTravelTotals(forSessionId: session.id, in: modelContext)
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
                        let nonGeoWarnings = liveWarnings.filter { $0 != Self.geoFallbackWarning }
                        reportWarnings.append(contentsOf: nonGeoWarnings.map { "\(session.title): \($0)" })

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
                    reportWarnings.append(contentsOf: geoWarnings.map { "\(session.title): \($0)" })
                }

                guard !lineItems.isEmpty else {
                    failedSessions.append(Core.NDISBillingIssue(
                        sessionId: sessionId,
                        sessionTitle: session.title,
                        reason: "No claimable line items"
                    ))
                    continue
                }

                // 4. Insert items (NDISInvoiceBuilder)
                let newItems = insertInvoiceItems(
                    for: lineItems,
                    session: session,
                    invoice: invoice,
                    clientService: session.clientService,
                    draftGSTBySupport: draftGSTBySupport,
                    existingCount: generatedItems.count,
                    modelContext: modelContext
                )
                generatedItems.append(contentsOf: newItems)
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
        if modelContext.hasChanges { try modelContext.save() }

        return Core.NDISBillingReport(
            invoice: invoice.snapshot(),
            processedSessionsCount: uniqueSessionIds.count,
            successfulSessionsCount: successfulSessionsCount,
            failedSessions: failedSessions,
            warnings: reportWarnings
        )
    }

    // MARK: - Automation Flow (public API surface)

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
}

// MARK: - Error Types

enum NDISBillingIntegrationError: Error {
    case missingSessionTimes
    case unresolvedGeographicZone

    var failureReason: String {
        switch self {
        case .missingSessionTimes: return "Session is missing start or end time"
        case .unresolvedGeographicZone: return NDISBillingIntegrationService.geoUnresolvedFailureReason
        }
    }
}

extension NDISBillingIntegrationService: Core.NDISBillingIntegrationServiceProtocol {}

extension String {
    var trimmedNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
