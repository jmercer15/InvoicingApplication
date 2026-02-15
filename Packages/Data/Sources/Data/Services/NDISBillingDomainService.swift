//
//  NDISBillingDomainService.swift
//  Data
//
//  Domain service for NDIS billing business operations
//

import Foundation
import SwiftData
import Core

/// Implementation of NDISBillingDomainServiceProtocol.
/// Encapsulates complex NDIS billing operations including pricing and claim validation.
@MainActor
public final class NDISBillingDomainService: NDISBillingDomainServiceProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let unitOfWork: UnitOfWorkService
    
    // MARK: - Initialization
    
    public init(unitOfWork: UnitOfWorkService) {
        self.unitOfWork = unitOfWork
    }
    
    // MARK: - NDISBillingDomainServiceProtocol
    
    public func calculateBillableAmounts(for session: Session) async throws -> [Core.NDISClaimableLineItem] {
        guard let clientId = session.clientId else {
            return []
        }
        
        // Get client's NDIS services
        let clientServices = try await unitOfWork.clientServices.fetch(for: clientId)
        
        var lineItems: [Core.NDISClaimableLineItem] = []
        
        // Calculate for each service that has an NDIS code
        for service in clientServices {
            guard let itemNumber = service.ndisCode else { continue }
            
            // Fetch current NDIS pricing
            guard let ndisItem = try await unitOfWork.ndisItems.fetch(by: itemNumber) else { continue }
            guard let itemPrice = ndisItem.price else { continue }
            
            // Calculate quantity based on session duration
            let hours = session.durationHours
            let totalAmount = hours * itemPrice
            
            let lineItem = Core.NDISClaimableLineItem(
                supportItemNumber: ndisItem.itemNumber,
                quantity: hours,
                unitPrice: itemPrice,
                totalAmount: totalAmount,
                claimType: "Direct"
            )
            
            lineItems.append(lineItem)
        }
        
        return lineItems
    }
    
    public func generateInvoice(for sessions: [Session], client: Client) async throws -> Invoice {
        guard !sessions.isEmpty else {
            throw DomainServiceError.invalidOperation(message: "No sessions provided for invoice generation")
        }
        
        // Create invoice
        let sessionIds = sessions.map { $0.id }
        let invoice = try await unitOfWork.invoices.createFromSessions(sessionIds, clientId: client.id)
        
        // Move sessions to readyToSend in billing workflow
        for session in sessions {
            try await unitOfWork.sessions.updateBillingStatus(id: session.id, status: .readyToSend)
        }
        
        try await unitOfWork.saveChanges()
        return invoice
    }
    
    public func fetchCurrentPricing(for itemNumber: String) async throws -> NDISItem? {
        return try await unitOfWork.ndisItems.fetch(by: itemNumber)
    }
    
    public func validateClaim(_ sessions: [Session]) async throws -> [NDISValidationResult] {
        var results: [NDISValidationResult] = []
        
        for session in sessions {
            var errors: [String] = []
            var warnings: [String] = []
            
            // Validate session has client
            guard let clientId = session.clientId else {
                errors.append("Session has no client assigned")
                results.append(NDISValidationResult(
                    sessionId: session.id,
                    isValid: false,
                    errors: errors,
                    warnings: warnings
                ))
                continue
            }
            
            guard let client = try await unitOfWork.clients.fetch(by: clientId) else {
                errors.append("Client not found")
                results.append(NDISValidationResult(
                    sessionId: session.id,
                    isValid: false,
                    errors: errors,
                    warnings: warnings
                ))
                continue
            }
            
            // Validate client has NDIS number
            if client.ndisNumber.isEmpty {
                errors.append("Client does not have an NDIS number")
            }
            
            // Validate session has services
            let services = try await unitOfWork.clientServices.fetch(for: clientId)
            let ndisServices = services.filter { $0.ndisCode != nil }
            
            if ndisServices.isEmpty {
                errors.append("No NDIS services assigned to client")
            }
            
            // Validate each service has valid pricing
            for service in ndisServices {
                if let itemNumber = service.ndisCode {
                    // Use search as workaround for fetch(by:) overload ambiguity
                    let searchResults = try await unitOfWork.ndisItems.search(query: itemNumber)
                    let item = searchResults.first { $0.itemNumber == itemNumber }
                    if item == nil {
                        warnings.append("NDIS item \(itemNumber) not found in price list")
                    }
                }
            }
            
            results.append(NDISValidationResult(
                sessionId: session.id,
                isValid: errors.isEmpty,
                errors: errors,
                warnings: warnings
            ))
        }
        
        return results
    }
    
    public func fetchApplicablePricing(
        for client: Client,
        supportCategory: String,
        effectiveDate: Date
    ) async throws -> [NDISItem] {
        // Fetch items by search since fetchByCategory doesn't exist
        let items = try await unitOfWork.ndisItems.search(query: supportCategory)
        
        // Filter by effective date and category
        return items.filter { item in
            // Filter by category
            guard item.category == supportCategory else { return false }
            
            // Check effective dates
            if let startDate = item.effectiveStartDate, startDate > effectiveDate {
                return false
            }
            if let endDate = item.effectiveEndDate, endDate < effectiveDate {
                return false
            }
            return true
        }
    }
    
    public func executeAutomationFlow(for session: Session, context: inout NDISBillingContext) async -> AutomationResult {
        let orchestrator = await NDISBillingAutomationOrchestrator(unitOfWork: unitOfWork)
        return await orchestrator.executeAutomationFlow(for: session, context: &context)
    }
}
