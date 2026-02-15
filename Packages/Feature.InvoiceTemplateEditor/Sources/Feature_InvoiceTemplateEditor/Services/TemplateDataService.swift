//
//  TemplateDataService.swift
//  Feature_InvoiceTemplateEditor
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftUI
import Core
import os

/// Service for providing real data from persisted entities to the template editor
/// Uses repository pattern for data access
/// Ensures all components always display data from the same invoice
@MainActor
public class TemplateDataService: ObservableObject {
    // MARK: - Dependencies
    private let invoicesRepository: InvoicesRepository
    private let clientsRepository: ClientsRepository
    private let businessRepository: BusinessRepository
    private let payeeRepository: PayeeRepository
    
    // Selected invoice for template preview (domain model)
    // Marked as private(set) to prevent external modification
    // All components access data through this single source of truth
    @Published private(set) var selectedInvoice: Invoice?
    @Published private(set) var selectedInvoiceItems: [InvoiceItem] = []
    
    // Related entities for fallback when snapshot data is missing
    @Published private(set) var selectedClient: Client?
    @Published private(set) var selectedBusiness: Business?
    @Published private(set) var selectedPayee: Payee?
    
    // Track invoice ID to ensure consistency
    private(set) var selectedInvoiceId: UUID?
    private let logger = Logger(subsystem: "Feature.InvoiceTemplateEditor", category: "TemplateDataService")
    
    public init(
        invoicesRepository: InvoicesRepository,
        clientsRepository: ClientsRepository,
        businessRepository: BusinessRepository,
        payeeRepository: PayeeRepository
    ) {
        self.invoicesRepository = invoicesRepository
        self.clientsRepository = clientsRepository
        self.businessRepository = businessRepository
        self.payeeRepository = payeeRepository
        Task {
            await loadRandomInvoice()
        }
    }
    
    /// Sets a specific invoice as the selected invoice for all template components
    /// This ensures all components display data from the same invoice
    /// - Parameters:
    ///   - invoice: The invoice to select
    ///   - items: Optional list of invoice items to override repository data (e.g. for live preview of unsaved items)
    public func setSelectedInvoice(_ invoice: Invoice, items: [InvoiceItem]? = nil) async {
        // Store the invoice ID for validation
        selectedInvoiceId = invoice.id
        
        // Update the selected invoice
        selectedInvoice = invoice
        
        // Load invoice items: use override if provided, otherwise load from repository
        if let overriddenItems = items {
            selectedInvoiceItems = overriddenItems
        } else {
            await loadInvoiceItems(for: invoice.id)
        }
        
        // Fetch related entities
        await loadRelatedEntities(for: invoice)
    }
    
    private func loadRelatedEntities(for invoice: Invoice) async {
        // Reset previous data
        selectedClient = nil
        selectedBusiness = nil
        selectedPayee = nil
        
        // Load Client
        if let clientId = invoice.clientId {
            do {
                selectedClient = try await clientsRepository.fetch(by: clientId)
            } catch {
                logger.error("Failed to load client: \(String(describing: error))")
            }
        }
        
        // Load Business
        if let businessId = invoice.businessId {
            do {
                selectedBusiness = try await businessRepository.fetch(by: businessId)
            } catch {
                logger.error("Failed to load business: \(String(describing: error))")
            }
        } else {
            // Fallback to default business (first found)
            do {
                selectedBusiness = try await businessRepository.fetchFirst()
                logger.notice("Loaded default business fallback: \(self.selectedBusiness?.name ?? "unknown")")
            } catch {
                logger.error("Failed to load default business: \(String(describing: error))")
            }
        }
        
        // Load Payee
        if let payeeId = invoice.payeeId {
            do {
                selectedPayee = try await payeeRepository.fetch(by: payeeId)
            } catch {
                logger.error("Failed to load payee: \(String(describing: error))")
            }
        }
    }


    
    /// Selects a random invoice from the database for template editing, preferring invoices with complete relationship data
    public func loadRandomInvoice() async {
        do {
            let invoices = try await invoicesRepository.fetchAll()
            
            // Prefer invoices with complete snapshot data (business, client, payee names)
            let invoicesWithCompleteData = invoices.filter { invoice in
                return invoice.businessName != nil &&
                       invoice.clientName != nil &&
                       (invoice.payeeName != nil || invoice.billToName != nil)
            }
            
            let invoiceToSelect: Invoice?
            if !invoicesWithCompleteData.isEmpty {
                invoiceToSelect = invoicesWithCompleteData.randomElement()
            } else if let randomInvoice = invoices.randomElement() {
                invoiceToSelect = randomInvoice
            } else {
                logger.warning("No invoices available for selection")
                invoiceToSelect = nil
            }
            
            // Set the selected invoice using the public method to ensure consistency
            if let invoice = invoiceToSelect {
                await setSelectedInvoice(invoice)
            } else {
                selectedInvoiceId = nil
                selectedInvoice = nil
                selectedInvoiceItems = []
            }
        } catch {
            logger.error("Error fetching invoices: \(String(describing: error))")
            selectedInvoiceId = nil
            selectedInvoice = nil
            selectedInvoiceItems = []
        }
    }
    
    /// Loads invoice items for the selected invoice using repository
    /// Only loads items if the invoiceId matches the currently selected invoice
    private func loadInvoiceItems(for invoiceId: UUID) async {
        // Verify this is still the selected invoice
        guard invoiceId == selectedInvoiceId else {
            logger.notice("Invoice ID mismatch - skipping item load")
            return
        }
        
        do {
            let items = try await invoicesRepository.fetchItems(by: invoiceId)
            
            // Double-check the invoice ID still matches before updating
            if invoiceId == selectedInvoiceId {
                selectedInvoiceItems = items
            } else {
                logger.notice("Invoice changed during item load - discarding items")
            }
        } catch {
            logger.error("Error loading invoice items: \(String(describing: error))")
            // Only clear items if this is still the selected invoice
            if invoiceId == selectedInvoiceId {
                selectedInvoiceItems = []
            }
        }
    }
    
    // MARK: - Client Data
    
    /// Gets client data from the selected invoice's snapshotted client data
    /// Always returns data from the same invoice as other get* methods
    public func getClientData(for clientId: UUID? = nil) -> ClientTemplateData {
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            return ClientTemplateData(
                name: "No Client Data",
                address: "",
                city: "",
                email: "",
                phone: "",
                ndisNumber: "",
                state: "",
                postcode: "",
                status: "Unknown",
                isMinor: false,
                hasNdisPlan: false
            )
        }
        
        return ClientTemplateData(from: invoice, fallbackClient: selectedClient)
    }
    
    // MARK: - Business Data
    
    /// Gets business data from the selected invoice's snapshotted business data
    /// Always returns data from the same invoice as other get* methods
    public func getBusinessData() -> BusinessTemplateData {
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            return BusinessTemplateData(
                name: "No Business Data",
                abn: "",
                email: "",
                phone: "",
                address: "",
                city: "",
                state: "",
                postcode: "",
                bankAccountName: "",
                bankAccountNumber: "",
                bankBSB: "",
                bankName: ""
            )
        }
        
        return BusinessTemplateData(from: invoice, fallbackBusiness: selectedBusiness)
    }
    
    // MARK: - Payee Data
    
    /// Gets payee data from the selected invoice's snapshotted payee data
    /// Always returns data from the same invoice as other get* methods
    public func getPayeeData(for clientId: UUID? = nil) -> PayeeTemplateData {
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            return PayeeTemplateData(
                name: "No Payee Data",
                role: "",
                id: UUID().uuidString,
                email: "",
                phone: "",
                address: "",
                city: "",
                state: "",
                postcode: ""
            )
        }
        
        return PayeeTemplateData(from: invoice, fallbackPayee: selectedPayee)
    }
    
    // MARK: - Service Data
    
    /// Gets service data from the selected invoice's invoice items
    /// Always returns data from the same invoice as other get* methods
    public func getServiceData(for clientId: UUID? = nil) -> [ServiceTemplateData] {
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            return []
        }

        // Use InvoiceItem domain models - note: some fields may not be available in domain model
        return selectedInvoiceItems.map { ServiceTemplateData(from: $0) }
    }
    
    // MARK: - Invoice Data
    
    /// Gets invoice data from the selected invoice
    /// Always returns data from the same invoice as other get* methods
    public func getInvoiceData(for invoiceId: UUID? = nil) -> InvoiceTemplateData {
        // Ensure we have a selected invoice - all components use the same one
        // Ignore the invoiceId parameter - we always use the selected invoice
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            return InvoiceTemplateData(
                invoiceNumber: "No Invoice Data",
                issueDate: Date(),
                dueDate: Date(),
                totalAmount: 0.0,
                taxRate: 0.0,
                subtotal: 0.0,
                calculatedTotal: 0.0,
                notes: "",
                paymentTerms: "",
                creditApplied: 0.0,
                discount: 0.0
            )
        }
        
        return InvoiceTemplateData(from: invoice, items: selectedInvoiceItems)
    }
    

}

// MARK: - Data Models
// Data models have been moved to Services/DataModels/TemplateDataModels.swift
