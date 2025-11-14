//
//  NDISBillingIntegrationService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for NDIS Billing Integration
//

import Foundation
import SwiftData
import Core

/// Service that integrates existing application data with the NDIS billing algorithm
public class NDISBillingIntegrationService {
    private let modelContext: ModelContext
    private let billingService: NDISBillingService
    private let configService: NDISBillingConfigService
    
    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.billingService = NDISBillingService(modelContext: modelContext)
        self.configService = NDISBillingConfigService()
    }
    
    // MARK: - Domain Model Methods (Preferred)
    
    /// Generate NDIS invoice using domain models (preferred over entity-based methods)
    /// This method accepts domain models and handles entity fetching internally
    public func generateNDISInvoice(for sessions: [Session], client: Client) throws -> Invoice {
        // Fetch entities internally for billing service compatibility
        let sessionEntities = try fetchSessionEntities(for: sessions.map { $0.id })
        guard let clientEntity = fetchClientEntity(by: client.id) else {
            throw NDISBillingIntegrationError.missingClient
        }
        
        let invoiceEntity = try generateNDISInvoice(for: sessionEntities, client: clientEntity)
        return invoiceFromEntity(invoiceEntity)
    }
    
    /// Calculate billable amounts using domain models (preferred over entity-based methods)
    public func calculateBillableAmounts(for session: Session) throws -> [NDISClaimableLineItem] {
        guard let sessionEntity = fetchSessionEntity(by: session.id) else {
            throw NDISBillingIntegrationError.invalidSessionData
        }
        return try calculateBillableAmounts(for: sessionEntity)
    }
    
    /// Calculate billable amounts with billing context using domain models
    public func calculateBillableAmounts(for session: Session, billingContext: NDISBillingContext) throws -> [NDISClaimableLineItem] {
        guard let sessionEntity = fetchSessionEntity(by: session.id) else {
            throw NDISBillingIntegrationError.invalidSessionData
        }
        return try calculateBillableAmounts(for: sessionEntity, billingContext: billingContext)
    }
    
    // MARK: - Entity Fetching Helpers
    
    /// Fetch SessionEntity by ID (internal helper)
    private func fetchSessionEntity(by id: UUID) -> SessionEntity? {
        let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Fetch SessionEntity instances by IDs (internal helper)
    private func fetchSessionEntities(for sessionIds: [UUID]) throws -> [SessionEntity] {
        var entities: [SessionEntity] = []
        for sessionId in sessionIds {
            let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id == sessionId })
            if let entity = try? modelContext.fetch(descriptor).first {
                entities.append(entity)
            }
        }
        return entities
    }
    
    /// Fetch ClientEntity by ID (internal helper)
    private func fetchClientEntity(by id: UUID) -> ClientEntity? {
        let descriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }
    
    /// Converts a session to NDIS billing input vector (legacy, without billingContext)
    func createBillingInputVector(from session: SessionEntity) throws -> NDISBillingInputVector {
        guard let client = session.client else {
            throw NDISBillingIntegrationError.missingClient
        }
        
        guard let clientService = session.clientService else {
            throw NDISBillingIntegrationError.missingClientService
        }
        
        guard let startTime = session.startTime, let endTime = session.endTime else {
            throw NDISBillingIntegrationError.missingSessionTimes
        }
        
        // Get business information for provider details
        let business = getBusiness()
        
        // Create participant info
        let participant = NDISParticipantInfo(
            ndisNumber: client.ndisNumber,
            planManagementType: client.planManagementType ?? "Plan-Managed",
            location: NDISLocation(
                postcode: client.address?.postcode ?? "",
                suburb: client.address?.suburb,
                state: client.address?.state
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
            foundAlternativeWork: false // This would need to be tracked separately
        )
        
        // Create service info
        let duration = endTime.timeIntervalSince(startTime) / 3600.0 // Convert to hours
        let service = NDISServiceInfo(
            supportItemNumber: clientService.ndisCode ?? "",
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            quantity: duration, // For hourly services, quantity = duration
            date: startTime,
            hoursPerMonth: nil, // Would need to be calculated from monthly totals
            consecutiveMonths: nil, // Would need to be tracked
            category: clientService.ndisItem?.category,
            silVacancyId: nil // Would need to be tracked for SIL services
        )
        
        // Create agreement info
        let agreement = NDISAgreementInfo(
            agreedPrice: clientService.rate,
            agreedCancellationPolicy: nil, // Would need to be stored in service agreement
            agreedTravelRatePerKM: nil // Would need to be stored in service agreement
        )
        
        // Create context info
        let context = createContextInfo(from: session, clientService: clientService)
        
        // Create travel info if applicable
        let travel = createTravelInfo(from: session)
        
        // Create transport info if applicable
        let transport = createTransportInfo(from: session)
        
        // Create cancellation info if applicable
        let cancellation = createCancellationInfo(from: session)
        
        // Create prepayment info if applicable
        let prepayment = createPrepaymentInfo(from: session)
        
        return NDISBillingInputVector(
            participant: participant,
            provider: provider,
            service: service,
            agreement: agreement,
            context: context,
            travel: travel,
            transport: transport,
            cancellation: cancellation,
            prepayment: prepayment
        )
    }
    
    /// Converts a session to NDIS billing input vector using an explicit billingContext
    func createBillingInputVector(from session: SessionEntity, billingContext: NDISBillingContext) throws -> NDISBillingInputVector {
        guard let client = session.client else {
            throw NDISBillingIntegrationError.missingClient
        }
        guard let clientService = session.clientService else {
            throw NDISBillingIntegrationError.missingClientService
        }
        guard let startTime = session.startTime, let endTime = session.endTime else {
            throw NDISBillingIntegrationError.missingSessionTimes
        }
        let business = getBusiness()
        let participant = NDISParticipantInfo(
            ndisNumber: client.ndisNumber,
            planManagementType: client.planManagementType ?? "Plan-Managed",
            location: NDISLocation(
                postcode: client.address?.postcode ?? "",
                suburb: client.address?.suburb,
                state: client.address?.state
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
        let service = NDISServiceInfo(
            supportItemNumber: clientService.ndisCode ?? "",
            startTime: startTime,
            endTime: endTime,
            duration: duration,
            quantity: duration,
            date: startTime,
            hoursPerMonth: nil,
            consecutiveMonths: nil,
            category: clientService.ndisItem?.category,
            silVacancyId: nil
        )
        let agreement = NDISAgreementInfo(
            agreedPrice: clientService.rate,
            agreedCancellationPolicy: nil,
            agreedTravelRatePerKM: nil
        )
        let context = createContextInfo(from: session, clientService: clientService, billingContext: billingContext)
        let travel = createTravelInfo(from: session, billingContext: billingContext)
        let transport = createTransportInfo(from: session)
        let cancellation = createCancellationInfo(from: session)
        let prepayment = createPrepaymentInfo(from: session)
        return NDISBillingInputVector(
            participant: participant,
            provider: provider,
            service: service,
            agreement: agreement,
            context: context,
            travel: travel,
            transport: transport,
            cancellation: cancellation,
            prepayment: prepayment
        )
    }
    
    /// Calculates billable amounts for a session using the NDIS billing algorithm
    public func calculateBillableAmounts(for session: SessionEntity) throws -> [NDISClaimableLineItem] {
        let inputVector = try createBillingInputVector(from: session)
        return try billingService.calculateBillableAmount(for: session, context: inputVector)
    }
    
    /// Calculates billable amounts using explicit billingContext (preferred for live preview)
    public func calculateBillableAmounts(for session: SessionEntity, billingContext: NDISBillingContext) throws -> [NDISClaimableLineItem] {
        let inputVector = try createBillingInputVector(from: session, billingContext: billingContext)
        return try billingService.calculateBillableAmount(for: session, context: inputVector)
    }
    
    /// Converts NDIS claimable line items to invoice items
    public func convertToInvoiceItems(_ claimableItems: [NDISClaimableLineItem], for session: SessionEntity) -> [InvoiceItemEntity] {
        return claimableItems.enumerated().map { index, claimableItem in
            let invoiceItem = InvoiceItemEntity(
                id: UUID(),
                itemDescription: createItemDescription(for: claimableItem, session: session)
            )
            
            invoiceItem.quantity = claimableItem.quantity
            invoiceItem.rate = claimableItem.unitPrice
            invoiceItem.unit = getUnitForClaimType(claimableItem.claimType)
            invoiceItem.position = Int32(index)
            invoiceItem.serviceDate = session.startTime ?? Date()
            invoiceItem.session = session
            invoiceItem.date = session.startTime ?? Date()
            invoiceItem.amount = claimableItem.totalAmount
            
            // Add NDIS-specific metadata
            invoiceItem.ndisItemNumber = claimableItem.supportItemNumber
            invoiceItem.claimType = NDISClaimType(rawValue: claimableItem.claimType) ?? .direct
            
            return invoiceItem
        }
    }
    
    // MARK: - Entity-Based Methods (Legacy - Use Domain Model Methods Instead)
    
    /// Enhanced invoice generation using NDIS billing algorithm (legacy - use domain model version)
    /// This method is kept for backward compatibility but prefer `generateNDISInvoice(for:client:)` with domain models
    public func generateNDISInvoice(for sessions: [SessionEntity], client: ClientEntity) throws -> InvoiceEntity {
        let invoice = InvoiceEntity(id: UUID(), invoiceNumber: generateInvoiceNumber())
        invoice.client = client
        invoice.issueDate = Date()
        invoice.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: Date())
        invoice.status = .draft
        invoice.business = getBusiness()
        
        var allInvoiceItems: [InvoiceItemEntity] = []
        var totalAmount: Double = 0.0
        
        for session in sessions {
            do {
                let claimableItems = try calculateBillableAmounts(for: session)
                let invoiceItems = convertToInvoiceItems(claimableItems, for: session)
                
                for item in invoiceItems {
                    item.invoice = invoice
                    modelContext.insert(item)
                    allInvoiceItems.append(item)
                    totalAmount += item.amount
                }
            } catch {
                print("Warning: Could not calculate billing for session \(session.title): \(error)")
                // Fall back to simple billing for this session
                if let clientService = session.clientService,
                   let startTime = session.startTime,
                   let endTime = session.endTime {
                    let duration = endTime.timeIntervalSince(startTime) / 3600.0
                    let invoiceItem = InvoiceItemEntity(
                        id: UUID(),
                        itemDescription: clientService.serviceName
                    )
                    invoiceItem.quantity = duration
                    invoiceItem.rate = clientService.rate
                    invoiceItem.unit = clientService.unit
                    invoiceItem.position = Int32(allInvoiceItems.count)
                    invoiceItem.serviceDate = startTime
                    invoiceItem.session = session
                    invoiceItem.invoice = invoice
                    invoiceItem.date = startTime
                    invoiceItem.amount = duration * clientService.rate
                    
                    modelContext.insert(invoiceItem)
                    allInvoiceItems.append(invoiceItem)
                    totalAmount += invoiceItem.amount
                }
            }
        }
        
        invoice.totalAmount = totalAmount
        invoice.snapshotRelatedData()
        
        return invoice
    }
    
    // MARK: - Helper Methods
    
    private func createContextInfo(from session: SessionEntity, clientService: ClientServiceEntity) -> NDISContextInfo {
        // Legacy defaults
        return NDISContextInfo(
            isPrepaymentClaim: false,
            isSubscriptionClaim: false,
            isBereavementClaim: false,
            isCancellation: false,
            isProviderTravel: !session.travelCharges.isEmpty,
            isActivityTransport: false,
            isNonFaceToFace: false,
            isNDIAReport: false,
            isShadowShift: false,
            isSilUnplannedExit: false,
            isComplexBehaviour: false,
            isHighIntensity: false,
            isGroupSupport: false,
            isTelehealth: false,
            isIrregularSil: false,
            isDirectService: true,
            groupSize: 1,
            travelGroupSize: 1,
            transportGroupSize: 1,
            participantAttended: true,
            nonFaceToFaceDuration: nil,
            ndiaReportDuration: nil,
            nonFaceToFaceActivityDescription: nil,
            coPaymentAmount: 0.0,
            travelTimeTo: nil,
            travelTimeFrom: nil,
            travelKilometres: nil,
            travelTolls: nil,
            travelParking: nil
        )
    }
    
    private func createContextInfo(from session: SessionEntity, clientService: ClientServiceEntity, billingContext: NDISBillingContext) -> NDISContextInfo {
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
            travelGroupSize: 1,
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
    
    private func createTravelInfo(from session: SessionEntity) -> NDISTravelInfo? {
        // Legacy placeholder
        return nil
    }
    
    private func createTravelInfo(from session: SessionEntity, billingContext: NDISBillingContext) -> NDISTravelInfo? {
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
    
    private func createTransportInfo(from session: SessionEntity) -> NDISTransportInfo? {
        // This would extract transport information from session
        return nil
    }
    
    private func createCancellationInfo(from session: SessionEntity) -> NDISCancellationInfo? {
        // This would extract cancellation information from session
        return nil
    }
    
    private func createPrepaymentInfo(from session: SessionEntity) -> NDISPrepaymentInfo? {
        // This would extract prepayment information from session
        return nil
    }
    
    private func getBusiness() -> BusinessEntity? {
        let descriptor = FetchDescriptor<BusinessEntity>()
        return try? modelContext.fetch(descriptor).first
    }
    
    private func generateInvoiceNumber() -> String {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 4
        formatter.maximumIntegerDigits = 4
        
        let invoiceDescriptor = FetchDescriptor<InvoiceEntity>()
        let allInvoices = (try? modelContext.fetch(invoiceDescriptor)) ?? []
        let highestExistingNumber = allInvoices.compactMap { Int(String($0.invoiceNumber.suffix(4))) }.max() ?? 0
        
        return "INV-\(formatter.string(from: NSNumber(value: highestExistingNumber + 1)) ?? "0001")"
    }
    
    private func createItemDescription(for claimableItem: NDISClaimableLineItem, session: SessionEntity) -> String {
        let baseDescription = session.title
        
        switch claimableItem.claimType {
        case "ProviderTravel":
            return "\(baseDescription) - Provider Travel"
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
        default:
            return baseDescription
        }
    }
    
    private func getUnitForClaimType(_ claimType: String) -> String {
        switch claimType {
        case "ProviderTravel", "Cancellation", "Prepayment":
            return "hour"
        case "NonFaceToFace", "NDIAReport":
            return "hour"
        default:
            return "hour"
        }
    }
}

// MARK: - Error Types

enum NDISBillingIntegrationError: Error {
    case missingClient
    case missingClientService
    case missingSessionTimes
    case invalidSessionData
} 
