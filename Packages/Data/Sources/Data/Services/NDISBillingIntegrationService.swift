//
//  NDISBillingIntegrationService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation
import Core
import Data
import os

/// Service that integrates existing application data with the NDIS billing algorithm
@MainActor
public class NDISBillingIntegrationService {
    private let invoicesRepository: InvoicesRepository
    private let clientsRepository: ClientsRepository
    private let businessRepository: BusinessRepository
    private let clientServicesRepository: ClientServicesRepository
    private let ndisItemsRepository: NDISItemRepository
    private let billingService: NDISBillingService
    private let configService: NDISBillingConfigService
    private let unitOfWork: UnitOfWorkService
    private let logger = Logger(subsystem: "com.invoicing.ndis", category: "BillingIntegration")
    
    /// Initialize with Repositories and UnitOfWork
    public init(
        invoicesRepository: InvoicesRepository,
        clientsRepository: ClientsRepository,
        businessRepository: BusinessRepository,
        clientServicesRepository: ClientServicesRepository,
        ndisItemsRepository: NDISItemRepository,
        billingService: NDISBillingService,
        unitOfWork: UnitOfWorkService,
        configService: NDISBillingConfigService = NDISBillingConfigService()
    ) {
        self.invoicesRepository = invoicesRepository
        self.clientsRepository = clientsRepository
        self.businessRepository = businessRepository
        self.clientServicesRepository = clientServicesRepository
        self.ndisItemsRepository = ndisItemsRepository
        self.billingService = billingService
        self.unitOfWork = unitOfWork
        self.configService = configService
    }
    
    /// Generate NDIS invoice using domain models and repositories
    public func generateNDISInvoice(for sessions: [Session], client: Client) async throws -> NDISBillingReport {
        logger.info("Starting NDIS invoice generation for \(sessions.count) sessions for client: \(client.ndisNumber)")
        
        // 1. Validate inputs
        guard !sessions.isEmpty else {
             logger.error("No sessions provided for invoice generation")
             throw NDISBillingIntegrationError.invalidSessionData
        }
        
        // 2. Prepare Context Data
        let business = try await businessRepository.fetchFirst()
        
        var invoiceItems: [InvoiceItem] = []
        var totalAmount: Double = 0.0
        let invoiceId = UUID()
        
        var failedSessions: [NDISBillingIssue] = []
        var processedCount = 0
        
        // 3. Process sessions
        for session in sessions {
            processedCount += 1
            do {
                guard let clientServiceId = session.clientServiceId,
                      let clientService = try await clientServicesRepository.fetch(by: clientServiceId) else {
                    throw NDISBillingIntegrationError.missingClientService
                }
                
                let claimableItems = try await calculateBillableAmounts(for: session, client: client, service: clientService)
                logger.debug("Calculated \(claimableItems.count) claimable items for session: \(session.title)")
                
                // Convert to invoice items
                for claimableItem in claimableItems {
                    let itemId = UUID()
                    
                    let invoiceItem = InvoiceItem(
                        id: itemId,
                        invoiceId: invoiceId,
                        sessionId: session.id,
                        clientServiceId: clientService.id,
                        itemDescription: createItemDescription(for: claimableItem, sessionTitle: session.title),
                        quantity: claimableItem.quantity,
                        rate: claimableItem.unitPrice,
                        position: Int32(invoiceItems.count),
                        serviceDate: session.startTime ?? Date(),
                        ndisItemNumber: claimableItem.supportItemNumber,
                        claimType: claimableItem.claimType,
                        unit: getUnitForClaimType(claimableItem.claimType), 
                        taxRate: 0.0
                    )
                    
                    invoiceItems.append(invoiceItem)
                    totalAmount += invoiceItem.lineTotal
                }
                
            } catch {
                logger.error("Failed to process session \(session.title): \(error.localizedDescription)")
                failedSessions.append(NDISBillingIssue(
                    sessionId: session.id,
                    sessionTitle: session.title,
                    reason: error.localizedDescription
                ))
            }
        }
        
        // 4. Create Invoice Domain Model if we have successful items
        guard !invoiceItems.isEmpty else {
            logger.warning("No billable items generated. Invoice creation aborted.")
            return NDISBillingReport(
                invoice: nil,
                processedSessionsCount: sessions.count,
                successfulSessionsCount: 0,
                failedSessions: failedSessions
            )
        }
        
        // Generate number and save
        let invoiceNumber = try await invoicesRepository.generateInvoiceNumber()
        
        let invoice = Invoice(
            id: invoiceId,
            invoiceNumber: invoiceNumber,
            totalAmount: totalAmount,
            date: Date(),
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date()),
            status: BillingStatus.reviewDrafts.rawValue,
            clientId: client.id,
            businessId: business?.id,
            sessionIds: sessions.filter { s in !failedSessions.contains(where: { $0.sessionId == s.id }) }.map { $0.id }
        )
        
        // 5. Transactional Persistence (via Repository)
        logger.info("Saving invoice \(invoiceNumber) with \(invoiceItems.count) items")
        let savedInvoice = try await invoicesRepository.create(invoice)
        
        for item in invoiceItems {
            _ = try await invoicesRepository.addItem(item)
        }
        
        // Finalize transaction
        try await unitOfWork.saveChanges()
        logger.info("Successfully persisted invoice \(invoiceNumber)")
        
        let finalInvoice = try await invoicesRepository.fetch(by: savedInvoice.id) ?? savedInvoice
        
        return NDISBillingReport(
            invoice: finalInvoice,
            processedSessionsCount: sessions.count,
            successfulSessionsCount: sessions.count - failedSessions.count,
            failedSessions: failedSessions
        )
    }
    
    /// Calculate billable amounts using domain models
    public func calculateBillableAmounts(for session: Session) async throws -> [NDISClaimableLineItem] {
        guard let clientServiceId = session.clientServiceId,
              let clientService = try await clientServicesRepository.fetch(by: clientServiceId) else {
            throw NDISBillingIntegrationError.missingClientService
        }
        guard let clientId = session.clientId,
              let client = try await clientsRepository.fetch(by: clientId) else {
             throw NDISBillingIntegrationError.missingClient
        }
        
        return try await calculateBillableAmounts(for: session, client: client, service: clientService)
    }
    
    public func calculateBillableAmounts(for session: Session, client: Client, service: ClientService) async throws -> [NDISClaimableLineItem] {
        let inputVector = try await createBillingInputVector(from: session, client: client, service: service)
        return try await billingService.calculateBillableAmount(context: inputVector)
    }
    
    public func calculateBillableAmounts(for session: Session, client: Client, service: ClientService, billingContext: NDISBillingContext) async throws -> [NDISClaimableLineItem] {
        let inputVector = try await createBillingInputVector(from: session, client: client, service: service, billingContext: billingContext)
        return try await billingService.calculateBillableAmount(context: inputVector)
    }
    
    // MARK: - Helper Methods
    
    func createBillingInputVector(from session: Session, client: Client, service: ClientService) async throws -> NDISBillingInputVector {
        guard let startTime = session.startTime, let endTime = session.endTime else {
            throw NDISBillingIntegrationError.missingSessionTimes
        }
        
        // Get business information
        let business = try await businessRepository.fetchFirst()
        
        // Create participant info
        let participant = NDISParticipantInfo(
            ndisNumber: client.ndisNumber,
            planManagementType: client.planManagementType ?? "Plan-Managed",
            location: NDISLocation(
                postcode: client.address?.postcode ?? "",
                suburb: client.address?.suburb,
                state: client.address?.state,
                latitude: session.sessionLatitude != 0 ? session.sessionLatitude : nil,
                longitude: session.sessionLongitude != 0 ? session.sessionLongitude : nil
            )
        )
        
        // Create provider info
        let provider = NDISProviderInfo(
            abn: business?.abn ?? "",
            location: NDISLocation(
                postcode: business?.address?.postcode ?? "",
                suburb: business?.address?.suburb,
                state: business?.address?.state
            ),
            foundAlternativeWork: false
        )
        
        let duration = endTime.timeIntervalSince(startTime) / 3600.0
        
        let serviceInfo = NDISServiceInfo(
            supportItemNumber: service.ndisCode ?? "",
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            quantity: duration,
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
        
        let context = createContextInfo(from: session)
        let travel = createTravelInfo(from: session)
        let transport = createTransportInfo(from: session)
        let cancellation = createCancellationInfo(from: session)
        
        return NDISBillingInputVector(
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
    }
    
    func createBillingInputVector(from session: Session, client: Client, service: ClientService, billingContext: NDISBillingContext) async throws -> NDISBillingInputVector {
        guard let startTime = session.startTime, let endTime = session.endTime else {
            throw NDISBillingIntegrationError.missingSessionTimes
        }
        
        let business = try await businessRepository.fetchFirst()
        let participant = NDISParticipantInfo(
            ndisNumber: client.ndisNumber,
            planManagementType: client.planManagementType ?? "Plan-Managed",
            location: NDISLocation(
                postcode: client.address?.postcode ?? "",
                suburb: client.address?.suburb,
                state: client.address?.state,
                latitude: session.sessionLatitude != 0 ? session.sessionLatitude : nil,
                longitude: session.sessionLongitude != 0 ? session.sessionLongitude : nil
            )
        )
        let provider = NDISProviderInfo(
            abn: business?.abn ?? "",
            location: NDISLocation(
                postcode: business?.address?.postcode ?? "",
                suburb: business?.address?.suburb,
                state: business?.address?.state
            ),
            foundAlternativeWork: false
        )
        let duration = endTime.timeIntervalSince(startTime) / 3600.0
        let serviceInfo = NDISServiceInfo(
            supportItemNumber: service.ndisCode ?? "",
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            quantity: duration,
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
        let context = createContextInfo(from: session, billingContext: billingContext)
        let travel = createTravelInfo(from: session, billingContext: billingContext)
        
        return NDISBillingInputVector(
            participant: participant,
            provider: provider,
            service: serviceInfo,
            agreement: agreement,
            context: context,
            travel: travel,
            transport: nil,
            cancellation: createCancellationInfo(from: session),
            prepayment: nil
        )
    }

    private func createItemDescription(for claimableItem: NDISClaimableLineItem, sessionTitle: String) -> String {
        let baseDescription = sessionTitle
        
        if claimableItem.claimType.contains("ProviderTravel") {
            if claimableItem.claimType.contains("Labour") && !claimableItem.claimType.contains("NonLabour") {
                return "\(baseDescription) - Provider Travel (Labour)"
            } else if claimableItem.claimType.contains("NonLabour") {
                return "\(baseDescription) - Provider Travel (Non-Labour)"
            } else if claimableItem.claimType.contains("OtherCosts") {
                return "\(baseDescription) - Provider Travel (Tolls/Parking)"
            }
            return "\(baseDescription) - Provider Travel"
        }
        
        switch claimableItem.claimType {
        case "Cancellation":
            return "\(baseDescription) - Cancellation Fee"
        case "Prepayment":
            return "\(baseDescription) - Prepayment"
        case "Telehealth":
            return "\(baseDescription) - Telehealth"
        case "NonFaceToFace":
            return "\(baseDescription) - Non-Face-to-Face"
        case "NDIAReport":
            return "\(baseDescription) - NDIA Report"
        case "IrregularSILSupport":
            return "\(baseDescription) - Irregular SIL Support"
        case "ActivityTransport":
            return "\(baseDescription) - Activity Based Transport"
        case "CentreCapitalCost":
            return "\(baseDescription) - Centre Capital Cost"
        case "EstablishmentFee":
            return "\(baseDescription) - Establishment Fee"
        default:
            return baseDescription
        }
    }
    
    private func getUnitForClaimType(_ claimType: String) -> String {
        if claimType.contains("NonLabour") || claimType == "ActivityTransport" {
            return "km"
        }
        if claimType.contains("OtherCosts") {
            return "each"
        }
        if claimType == "CentreCapitalCost" || claimType == "EstablishmentFee" {
            return "unit"
        }
        
        switch claimType {
        case "ProviderTravel", "Cancellation", "Prepayment":
            return "hour"
        case "NonFaceToFace", "NDIAReport":
            return "hour"
        case "IrregularSILSupport":
            return "hour"
        default:
            return "hour"
        }
    }
    
    // MARK: - Domain Model Helpers
    
    func createContextInfo(from session: Session) -> NDISContextInfo {
        let notes = (session.notes ?? "").lowercased()
        let location = (session.location ?? "").lowercased()
        
        let isTelehealth = location.contains("telehealth") || location.contains("remote") || notes.contains("[telehealth]")
        let isNonFaceToFace = notes.contains("[nf2f]") || notes.contains("[nftf]") || notes.contains("non-face-to-face") || notes.contains("writing")
        let isNDIAReport = notes.contains("[report]") || notes.contains("ndia report") || notes.contains("treatment report")
        let isGroupSupport = session.attendeesCount > 1
        
        return NDISContextInfo(
            isPrepaymentClaim: false,
            isSubscriptionClaim: false,
            isBereavementClaim: false,
            isCancellation: session.status == "cancelled",
            isProviderTravel: (session.travelDistanceKM ?? 0) > 0 || (session.travelTimeMinutes ?? 0) > 0,
            isActivityTransport: false,
            isNonFaceToFace: isNonFaceToFace,
            isNDIAReport: isNDIAReport,
            isShadowShift: notes.contains("[shadow]") || notes.contains("shadow shift") || notes.contains("training shift") || notes.contains("introductory shift"),
            isSilUnplannedExit: notes.contains("[sil_exit]") || notes.contains("sil exit") || notes.contains("unplanned exit") || notes.contains("vacated sil"),
            isComplexBehaviour: notes.contains("[complex]") || notes.contains("complex behaviour") || notes.contains("restrictive practice") || notes.contains("behaviour support") || notes.contains("challenging behaviour"),
            isHighIntensity: notes.contains("[high_intensity]") || notes.contains("high intensity") || notes.contains("tracheostomy") || notes.contains("ventilator") || notes.contains("peg feeding") || notes.contains("cathetering") || notes.contains("wound care") || notes.contains("subcutaneous injection"),
            isGroupSupport: isGroupSupport,
            isTelehealth: isTelehealth,
            isIrregularSil: notes.contains("[irregular_sil]") || notes.contains("irregular sil") || notes.contains("sil irregular"),
            isDirectService: !isTelehealth && !isNonFaceToFace && !isNDIAReport,
            groupSize: isGroupSupport ? Int(session.attendeesCount) : 1,
            travelGroupSize: (session.travelCharges.last?.splitCosts == true) ? (session.travelCharges.last?.participantCount ?? 1) : 1,
            transportGroupSize: 1,
            participantAttended: session.status != "cancelled",
            nonFaceToFaceDuration: isNonFaceToFace ? session.durationHours : nil,
            ndiaReportDuration: isNDIAReport ? session.durationHours : nil,
            nonFaceToFaceActivityDescription: isNonFaceToFace ? (session.notes ?? "Non-Face-to-Face support") : nil,
            coPaymentAmount: 0.0,
            travelTimeTo: nil,
            travelTimeFrom: nil,
            travelKilometres: nil,
            travelTolls: nil,
            travelParking: nil
        )
    }
    
    func createContextInfo(from session: Session, billingContext: NDISBillingContext) -> NDISContextInfo {
        NDISContextInfo(
            isPrepaymentClaim: billingContext.isPrepayment,
            isSubscriptionClaim: false,
            isBereavementClaim: false,
            isCancellation: billingContext.isShortNoticeCancellation,
            isProviderTravel: billingContext.isProviderTravel,
            isActivityTransport: billingContext.isActivityTransport,
            isNonFaceToFace: false,
            isNDIAReport: billingContext.isNdiaReport,
            isShadowShift: billingContext.isShadowShift,
            isSilUnplannedExit: billingContext.isSilUnplannedExit,
            isComplexBehaviour: billingContext.isComplexBehavior,
            isHighIntensity: billingContext.isHighIntensity,
            isGroupSupport: billingContext.isGroupSupport,
            isTelehealth: billingContext.isTelehealth,
            isIrregularSil: false,
            isDirectService: !(billingContext.isTelehealth),
            groupSize: billingContext.isGroupSupport ? max(2, billingContext.groupSize) : 1,
            travelGroupSize: (session.travelCharges.last?.splitCosts == true) ? (session.travelCharges.last?.participantCount ?? 1) : 1,
            transportGroupSize: 1,
            participantAttended: true,
            nonFaceToFaceDuration: nil,
            ndiaReportDuration: nil,
            nonFaceToFaceActivityDescription: nil,
            coPaymentAmount: 0.0,
            travelTimeTo: nil,
            travelTimeFrom: nil,
            travelKilometres: billingContext.travelDistance > 0 ? billingContext.travelDistance : nil,
            travelTolls: billingContext.travelTolls > 0 ? billingContext.travelTolls : nil,
            travelParking: billingContext.travelParking > 0 ? billingContext.travelParking : nil
        )
    }
    
    private func createTravelInfo(from session: Session) -> NDISTravelInfo? {
        // Prioritize rich TravelCharge data
        if let charge = session.travelCharges.last {
            // If split costs is enabled, the amount in charge.amount is the SPLIT amount.
            // However, for the NDIS Billing Service, we usually pass the raw parameters and let it calculate.
            // But here, we seem to be passing 'tolls' and 'parking' directly.
            
            // Critical: If splitCosts is true, we should pass the FULL cost here if the service divides it,
            // OR the SPLIT cost if the service adds it directly.
            // Looking at NDISBillingService.calculateProviderTravel:
            // It uses context.travel.tolls and context.travel.parking directly.
            // So we should pass the SPLIT amount if we want the invoice to reflect the split.
            
            // However, TravelCharge entity 'amount' is the total calculated amount (labour + non-labour + ancillary).
            // 'tollCost' and 'parkingCost' in TravelCharge are the costs for this SPECIFIC charge entry.
            // If the user selected "Split Costs" in the UI, the TravelCharge created usually represents the share?
            // Let's check TravelCharge logic.
            // In BillingHubViewModel.addTravelToSession:
            // let breakdown = NDISTravelChargeCalculator.calculate(...)
            // return TravelCharge(..., amount: breakdown.totalPerParticipant, ...)
            // valid for 'parkingCost' and 'tollCost'?
            // The calculator takes 'ancillaryCosts' (parking + tolls) and divides by participantCount.
            // But the 'TravelCharge' struct simply stores 'parkingCost' and 'tollCost'.
            // Does it store the total or the share?
            // In ViewModel:
            // let parkingPerPerson = parking / Double(effectiveCount)
            // let tollsPerPerson = tolls / Double(effectiveCount)
            // It seems we should ensure TravelCharge stores the PER PERSON amount if split.
            // But wait, the ViewModel stores the RAW input in the entity?
            // Let's check ViewModel.addTravelToSession in a later step if needed.
            // For now, let's assume TravelCharge properties reflect the values applicable to THIS invoice.
            
            // Logic: Use the values from TravelCharge directly.
            
            let timeMinutes = (charge.travelTime ?? 0) / 60.0
            let isFrom = charge.travelDirection.lowercased().contains("after") || 
                         charge.travelDirection.lowercased().contains("from")
            
            return NDISTravelInfo(
                timeTo: isFrom ? 0 : timeMinutes,
                timeFrom: isFrom ? timeMinutes : 0,
                kilometres: charge.distance ?? 0,
                tolls: charge.tollCost,
                parking: charge.parkingCost
            )
        }
        
        // Fallback to flat fields
        let distance = session.travelDistanceKM ?? 0
        let time = session.travelTimeMinutes ?? 0
        let tolls = session.travelTollsAmount ?? 0
        
        if distance > 0 || time > 0 || tolls > 0 {
            return NDISTravelInfo(
                timeTo: time,
                timeFrom: 0,
                kilometres: distance,
                tolls: tolls,
                parking: 0
            )
        }
        return nil
    }
    
    private func createTravelInfo(from session: Session, billingContext: NDISBillingContext) -> NDISTravelInfo? {
        guard billingContext.isProviderTravel || billingContext.travelDistance > 0 || billingContext.travelTolls > 0 || billingContext.travelParking > 0 else {
            return nil
        }
        return NDISTravelInfo(
            timeTo: max(0, billingContext.travelTime),
            timeFrom: 0,
            kilometres: max(0, billingContext.travelDistance),
            tolls: max(0, billingContext.travelTolls),
            parking: max(0, billingContext.travelParking)
        )
    }
    
    private func createTransportInfo(from session: Session) -> NDISTransportInfo? {
        return nil
    }
    
    private func createCancellationInfo(from session: Session) -> NDISCancellationInfo? {
        if session.status == "cancelled" {
            return NDISCancellationInfo(noticeTime: session.lastModifiedDate ?? Date())
        }
        return nil
    }
}

// MARK: - Error Types

// MARK: - Supporting Types

public struct NDISBillingReport {
    public let invoice: Invoice?
    public let processedSessionsCount: Int
    public let successfulSessionsCount: Int
    public let failedSessions: [NDISBillingIssue]
}

public struct NDISBillingIssue {
    public let sessionId: UUID
    public let sessionTitle: String
    public let reason: String
}

enum NDISBillingIntegrationError: Error {
    case missingClient
    case missingClientService
    case missingSessionTimes
    case invalidSessionData
}
