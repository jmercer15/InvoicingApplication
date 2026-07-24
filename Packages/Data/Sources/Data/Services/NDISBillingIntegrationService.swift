//
//  NDISBillingIntegrationService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation
import Core
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

        let modelContext = ModelContext(modelContainer)
        
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
        invoice.invoiceEditorStateData = try creationDefaults.editorConfiguration.encoded()
        
        // Link related data snapshots (crucial for PDF rendering)
        invoice.snapshotRelatedData()
        
        modelContext.insert(invoice)

        var successfulSessionsCount = 0
        var failedSessions = [Core.NDISBillingIssue]()
        var generatedItems: [InvoiceItem] = []

        // 3. Process Sessions
        for sessionId in uniqueSessionIds {
            do {
                guard let session = try modelContext.fetch(FetchDescriptor<Session>(predicate: #Predicate { $0.id == sessionId })).first else {
                    failedSessions.append(Core.NDISBillingIssue(sessionId: sessionId, sessionTitle: "Unknown", reason: "Session not found"))
                    continue
                }

                // Determine claimable lines
                let lineItems: [NDISClaimableLineItem]
                if let draft = session.billableDrafts?.first, let items = draft.items, !items.isEmpty {
                    // Use items from existing draft
                    lineItems = items.map { line in
                        NDISClaimableLineItem(
                            supportItemNumber: line.supportItemNumber,
                            quantity: line.quantityDecimal ?? 0,
                            unitPrice: line.unitPrice,
                            totalAmount: (line.quantityDecimal ?? 0) * line.unitPrice,
                            claimType: line.claimType
                        )
                    }
                } else {
                    // Calculate live
                    guard let service = session.clientService else {
                        failedSessions.append(Core.NDISBillingIssue(sessionId: sessionId, sessionTitle: session.title, reason: "No service assigned to session"))
                        continue
                    }
                    
                    let billingContext = await self.resolveBillingContext(for: session)
                    lineItems = try await self.calculateBillableAmounts(
                        for: session.snapshot(),
                        client: client.snapshot(),
                        service: service.snapshot(),
                        billingContext: billingContext
                    )
                }

                guard !lineItems.isEmpty else {
                    failedSessions.append(Core.NDISBillingIssue(
                        sessionId: sessionId,
                        sessionTitle: session.title,
                        reason: "No claimable line items"
                    ))
                    continue
                }

                // Create InvoiceItems
                for item in lineItems {
                    let invoiceItem = InvoiceItem(id: UUID(), itemDescription: item.supportItemNumber)
                    invoiceItem.position = Int32(generatedItems.count)
                    invoiceItem.ndisItemNumber = item.supportItemNumber
                    invoiceItem.rate = item.unitPrice
                    invoiceItem.quantity = item.quantity
                    invoiceItem.serviceDate = session.startTime ?? Date()
                    invoiceItem.claimType = NDISClaimType(rawValue: item.claimType) ?? .direct
                    invoiceItem.invoice = invoice
                    invoiceItem.session = session
                    invoiceItem.clientService = session.clientService
                    modelContext.insert(invoiceItem)
                    generatedItems.append(invoiceItem)
                }

                session.invoice = invoice
                successfulSessionsCount += 1
            } catch {
                failedSessions.append(Core.NDISBillingIssue(sessionId: sessionId, sessionTitle: "Session", reason: error.localizedDescription))
            }
        }

        guard !generatedItems.isEmpty else {
            modelContext.delete(invoice)
            if modelContext.hasChanges { try modelContext.save() }
            return Core.NDISBillingReport(
                invoice: nil,
                processedSessionsCount: uniqueSessionIds.count,
                successfulSessionsCount: 0,
                failedSessions: failedSessions
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
            failedSessions: failedSessions
        )
    }

    private func resolveBillingContext(for session: Session) async -> NDISBillingContext {
        var context = NDISBillingContext()
        context.supportItemNumber = session.clientService?.ndisCode ?? ""
        
        // Trigger automation flow to properly populate the context (e.g. travel, geographic area, etc.)
        // This ensures the live calculation uses high-fidelity data like real travel distances.
        let localContext = ModelContext(modelContainer)
        let orchestrator = NDISBillingAutomationOrchestrator(
            modelContext: localContext,
            geocodingService: geocodingService,
            mmmZoneLookup: mmmZoneLookup,
            mapKitTravelService: MapKitTravelService()
        )
        
        let (updatedContext, _) = await orchestrator.executeAutomationFlow(
            sessionId: session.id,
            context: context
        )
        return updatedContext
    }

    /// Geocoding, travel, and billing-context automation for NDIS billing.
    public func executeAutomationFlow(for session: SessionSnapshot, context: inout NDISBillingContext) async -> AutomationResult {
        let modelContext = ModelContext(modelContainer)
        modelContext.autosaveEnabled = false
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
        let inputVector = try await createBillingInputVector(
            from: session,
            client: client,
            service: service,
            billingContext: billingContext
        )
        let modelContext = ModelContext(modelContainer)
        let configService = NDISBillingConfigService(mmmZoneLookup: mmmZoneLookup)
        let billingService = NDISBillingService(modelContext: modelContext, configService: configService)
        return try await billingService.calculateBillableAmount(context: inputVector)
    }

    // MARK: - Snapshot input vector construction

    private func createBillingInputVector(
        from session: SessionSnapshot,
        client: ClientSnapshot,
        service: ClientServiceSnapshot,
        billingContext: NDISBillingContext
    ) async throws -> NDISBillingInputVector {
        guard let startTime = session.startTime, let endTime = session.endTime else {
            throw NDISBillingIntegrationError.missingSessionTimes
        }

        let business = try fetchFirstBusinessSnapshot()

        let participant = NDISParticipantInfo(
            ndisNumber: client.ndisNumber,
            planManagementType: client.planManagementType ?? "Plan-Managed",
            location: NDISLocation(
                postcode: client.address?.postcode ?? "",
                suburb: client.address?.suburb,
                state: client.address?.state,
                latitude: (session.sessionLatitude != 0) ? session.sessionLatitude : nil,
                longitude: (session.sessionLongitude != 0) ? session.sessionLongitude : nil
            )
        )

        let provider = NDISProviderInfo(
            abn: business?.abn ?? "",
            location: NDISLocation(
                postcode: business?.address?.postcode ?? "",
                suburb: business?.address?.suburb,
                state: business?.address?.state,
                latitude: business?.address?.latitude,
                longitude: business?.address?.longitude
            ),
            foundAlternativeWork: false
        )

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
            consecutiveMonths: nil,
            category: nil,
            silVacancyId: nil
        )

        let agreement = NDISAgreementInfo(
            agreedPrice: service.rate,
            agreedCancellationPolicy: nil,
            agreedTravelRatePerKM: nil
        )

        let context = NDISContextInfo(
            isPrepaymentClaim: billingContext.isPrepayment,
            isSubscriptionClaim: false,
            isBereavementClaim: false,
            isCancellation: billingContext.isShortNoticeCancellation || session.status == .cancelled,
            isProviderTravel: billingContext.isProviderTravel,
            isActivityTransport: billingContext.isActivityTransport,
            isNonFaceToFace: billingContext.isNonFaceToFace,
            isNDIAReport: billingContext.isNdiaReport,
            isShadowShift: billingContext.isShadowShift,
            isSilUnplannedExit: billingContext.isSilUnplannedExit,
            isComplexBehaviour: billingContext.isComplexBehavior,
            isHighIntensity: billingContext.isHighIntensity,
            isGroupSupport: billingContext.isGroupSupport,
            isTelehealth: billingContext.isTelehealth,
            isIrregularSil: billingContext.isSilUnplannedExit,
            isDirectService: !(billingContext.isTelehealth || billingContext.isNonFaceToFace || billingContext.isNdiaReport),
            groupSize: max(billingContext.groupSize, 1),
            travelGroupSize: max(billingContext.groupSize, 1),
            transportGroupSize: max(billingContext.groupSize, 1),
            participantAttended: !billingContext.isShortNoticeCancellation,
            nonFaceToFaceDuration: billingContext.isNonFaceToFace ? durationHours : nil,
            ndiaReportDuration: billingContext.isNdiaReport ? durationHours : nil,
            nonFaceToFaceActivityDescription: nil,
            coPaymentAmount: max(billingContext.coPaymentAmount, 0),
            travelTimeTo: billingContext.travelTime,
            travelTimeFrom: 0,
            travelKilometres: billingContext.travelDistance,
            travelTolls: billingContext.travelTolls,
            travelParking: billingContext.travelParking
        )

        let travel = NDISTravelInfo(
            timeTo: max(0, billingContext.travelTime),
            timeFrom: 0,
            kilometres: max(0, billingContext.travelDistance),
            tolls: max(0, billingContext.travelTolls),
            parking: max(0, billingContext.travelParking)
        )

        let cancellation: NDISCancellationInfo? = {
            guard context.isCancellation else { return nil }
            return NDISCancellationInfo(noticeTime: Date())
        }()

        return NDISBillingInputVector(
            participant: participant,
            provider: provider,
            service: serviceInfo,
            agreement: agreement,
            context: context,
            travel: travel,
            transport: nil,
            cancellation: cancellation,
            prepayment: nil
        )
    }

    private func fetchFirstBusinessSnapshot() throws -> BusinessSnapshot? {
        let modelContext = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Business>()
        return try modelContext.fetch(descriptor).first?.snapshot()
    }
}

// MARK: - Error Types

// MARK: - Supporting Types

enum NDISBillingIntegrationError: Error {
    case missingSessionTimes
}

extension NDISBillingIntegrationService: Core.NDISBillingIntegrationServiceProtocol {}

private extension String {
    var trimmedNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
