//
//  DomainServiceProtocols.swift
//  Core
//
//  Domain Service Protocols for DAL Standardization
//

import Foundation

// MARK: - Client Domain Service

/// Encapsulates complex business operations for Client entities.
/// Use for operations that span multiple repositories or require
/// coordination (e.g., client + address + services).
public protocol ClientDomainServiceProtocol: Sendable {
    
    /// Create a new client with optional associated services.
    @discardableResult
    func createClient(_ client: Client, withServices services: [ClientService]?) async throws -> Client
    
    /// Update an existing client.
    @discardableResult
    func updateClient(_ client: Client) async throws -> Client
    
    /// Update a client's address, including geocoding.
    @discardableResult
    func updateClientAddress(_ clientId: UUID, address: Address) async throws -> Client
    
    /// Archive a client (soft delete).
    func archiveClient(_ clientId: UUID) async throws
    
    /// Permanently delete a client and related data.
    func deleteClient(_ clientId: UUID) async throws
    
    /// Geocode the client's address and update coordinates.
    func geocodeClientAddress(_ clientId: UUID) async throws
}

// MARK: - Session Domain Service

/// Encapsulates complex business operations for Session entities.
/// Handles EventKit synchronization and recurrence management.
public protocol SessionDomainServiceProtocol: Sendable {
    
    /// Create a new session with optional calendar sync.
    @discardableResult
    func createSession(_ session: Session, syncToCalendar: Bool) async throws -> Session
    
    /// Update an existing session with optional calendar sync.
    @discardableResult
    func updateSession(_ session: Session, syncToCalendar: Bool) async throws -> Session
    
    /// Delete a session with optional calendar sync.
    func deleteSession(_ sessionId: UUID, syncToCalendar: Bool) async throws
    
    /// Handle changes detected from external calendar sources.
    func handleExternalCalendarChanges() async
    
    /// Expand a recurring session into individual instances.
    func expandRecurrence(for session: Session, until date: Date) async throws -> [Session]
    
    /// Sync all sessions with external calendar.
    func syncAllWithCalendar() async throws
}

// MARK: - Invoice Domain Service

/// Encapsulates complex business operations for Invoice entities.
/// Handles invoice creation from sessions and status workflow.
public protocol InvoiceDomainServiceProtocol: Sendable {
    
    /// Create an invoice from selected sessions.
    @discardableResult
    func createInvoiceFromSessions(_ sessionIds: [UUID], clientId: UUID) async throws -> Invoice
    
    /// Update invoice status following business rules.
    @discardableResult
    func updateInvoiceStatus(_ invoiceId: UUID, status: String) async throws -> Invoice
    
    /// Generate a PDF for the invoice.
    func generatePDF(for invoiceId: UUID) async throws -> URL
    
    /// Mark sessions as billed when invoice is finalized.
    func markSessionsAsBilled(for invoiceId: UUID) async throws
    
    /// Generate the next invoice number for a client.
    func generateNextInvoiceNumber(for client: Client?) async throws -> String
}

// MARK: - Travel Charge Domain Service

/// Encapsulates complex business operations for TravelCharge entities.
/// Handles distance calculations and approval workflow.
public protocol TravelChargeDomainServiceProtocol: Sendable {
    
    /// Create a travel charge for a session.
    @discardableResult
    func createTravelCharge(for session: Session) async throws -> TravelCharge
    
    /// Approve multiple travel charges at once.
    @discardableResult
    func approveCharges(_ chargeIds: [UUID]) async throws -> [TravelCharge]
    
    /// Reject multiple travel charges with optional reason.
    @discardableResult
    func rejectCharges(_ chargeIds: [UUID], reason: String?) async throws -> [TravelCharge]
    
    /// Calculate distance between two addresses.
    func calculateDistance(from: Address, to: Address) async throws -> Double
    
    /// Automatically create travel charge for session if applicable.
    @discardableResult
    func autoCreateChargeForSession(_ sessionId: UUID) async throws -> TravelCharge?
    
    /// Recalculate distance for an existing charge.
    @discardableResult
    func recalculateDistance(for chargeId: UUID) async throws -> TravelCharge
}

// MARK: - NDIS Billing Domain Service

/// Encapsulates complex business operations for NDIS billing.
/// Handles pricing lookups, claim calculations, and invoice generation.
public protocol NDISBillingDomainServiceProtocol: Sendable {
    
    /// Calculate billable amounts for a session based on NDIS pricing.
    func calculateBillableAmounts(for session: Session) async throws -> [NDISClaimableLineItem]
    
    /// Generate an NDIS invoice for sessions.
    @discardableResult
    func generateInvoice(for sessions: [Session], client: Client) async throws -> Invoice
    
    /// Fetch current pricing for an NDIS item number.
    func fetchCurrentPricing(for itemNumber: String) async throws -> NDISItem?
    
    /// Validate NDIS claims before submission.
    func validateClaim(_ sessions: [Session]) async throws -> [NDISValidationResult]
    
    /// Fetch applicable pricing for a client's location and support type.
    func fetchApplicablePricing(
        for client: Client,
        supportCategory: String,
        effectiveDate: Date
    ) async throws -> [NDISItem]
    
    /// Execute NDIS billing automation flow for a session (Billing context determination).
    @discardableResult
    func executeAutomationFlow(for session: Session, context: inout NDISBillingContext) async -> AutomationResult
}

// MARK: - Supporting Types

/// Result of NDIS claim validation.
public struct NDISValidationResult: Sendable {
    public let sessionId: UUID
    public let isValid: Bool
    public let errors: [String]
    public let warnings: [String]
    
    public init(sessionId: UUID, isValid: Bool, errors: [String], warnings: [String]) {
        self.sessionId = sessionId
        self.isValid = isValid
        self.errors = errors
        self.warnings = warnings
    }
}

/// A single claimable line item for NDIS billing.
/// Matches existing NDISBillingService.swift structure in Data package.
public struct NDISClaimableLineItem: Sendable {
    public let supportItemNumber: String
    public let quantity: Double
    public let unitPrice: Double
    public let totalAmount: Double
    public let claimType: String
    
    public init(
        supportItemNumber: String,
        quantity: Double,
        unitPrice: Double,
        totalAmount: Double,
        claimType: String
    ) {
        self.supportItemNumber = supportItemNumber
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalAmount = totalAmount
        self.claimType = claimType
    }
    
    /// Computed convenience property
    public var lineTotal: Double {
        quantity * unitPrice
    }
}
