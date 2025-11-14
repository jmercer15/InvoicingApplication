//
//  TemplateDataService.swift
//  Feature_InvoiceTemplateEditor
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftUI
import Core

/// Service for providing real data from persisted entities to the template editor
/// Uses repository pattern for data access
/// Ensures all components always display data from the same invoice
@MainActor
public class TemplateDataService: ObservableObject {
    // MARK: - Dependencies
    private let invoicesRepository: InvoicesRepository
    private let clientsRepository: ClientsRepository
    
    // Selected invoice for template preview (domain model)
    // Marked as private(set) to prevent external modification
    // All components access data through this single source of truth
    @Published private(set) var selectedInvoice: Invoice?
    @Published private(set) var selectedInvoiceItems: [InvoiceItem] = []
    
    // Track invoice ID to ensure consistency
    private(set) var selectedInvoiceId: UUID?
    
    public init(
        invoicesRepository: InvoicesRepository,
        clientsRepository: ClientsRepository
    ) {
        self.invoicesRepository = invoicesRepository
        self.clientsRepository = clientsRepository
        Task {
            await selectRandomInvoice()
        }
    }
    
    /// Sets a specific invoice as the selected invoice for all template components
    /// This ensures all components display data from the same invoice
    public func setSelectedInvoice(_ invoice: Invoice) async {
        print("🔄 [TemplateDataService] Setting selected invoice: \(invoice.invoiceNumber)")
        
        // Store the invoice ID for validation
        selectedInvoiceId = invoice.id
        
        // Update the selected invoice
        selectedInvoice = invoice
        
        // Reload invoice items for this invoice
        await loadInvoiceItems(for: invoice.id)
        
        print("✅ [TemplateDataService] Invoice set: \(invoice.invoiceNumber), ID: \(invoice.id)")
    }
    
    /// Selects a random invoice from the database for template editing, preferring invoices with complete relationship data
    private func selectRandomInvoice() async {
        print("🔍 [TemplateDataService] Selecting random invoice from database")
        
        do {
            let invoices = try await invoicesRepository.fetchAll()
            print("📊 [TemplateDataService] Found \(invoices.count) invoices in database")
            
            // Prefer invoices with complete snapshot data (business, client, payee names)
            let invoicesWithCompleteData = invoices.filter { invoice in
                return invoice.businessName != nil &&
                       invoice.clientName != nil &&
                       (invoice.payeeName != nil || invoice.billToName != nil)
            }
            
            let invoiceToSelect: Invoice?
            if !invoicesWithCompleteData.isEmpty {
                invoiceToSelect = invoicesWithCompleteData.randomElement()!
                print("✅ [TemplateDataService] Selected invoice with complete data: \(invoiceToSelect?.invoiceNumber ?? "unknown")")
            } else if let randomInvoice = invoices.randomElement() {
                invoiceToSelect = randomInvoice
                print("✅ [TemplateDataService] Selected random invoice: \(invoiceToSelect?.invoiceNumber ?? "unknown")")
            } else {
                print("❌ [TemplateDataService] No invoices available for selection")
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
            print("❌ [TemplateDataService] Error fetching invoices: \(error)")
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
            print("⚠️ [TemplateDataService] Invoice ID mismatch - skipping item load")
            return
        }
        
        do {
            let items = try await invoicesRepository.fetchItems(by: invoiceId)
            
            // Double-check the invoice ID still matches before updating
            if invoiceId == selectedInvoiceId {
                selectedInvoiceItems = items
                print("✅ [TemplateDataService] Loaded \(selectedInvoiceItems.count) invoice items for invoice \(invoiceId)")
            } else {
                print("⚠️ [TemplateDataService] Invoice changed during item load - discarding items")
            }
        } catch {
            print("❌ [TemplateDataService] Error loading invoice items: \(error)")
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
        print("🔍 [TemplateDataService] getClientData() called")
        
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            print("❌ [TemplateDataService] No selected invoice found")
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
        
        print("✅ [TemplateDataService] Found selected invoice: \(invoice.invoiceNumber)")
        print("📊 [TemplateDataService] Client data from invoice:")
        print("   - clientName: '\(invoice.clientName ?? "nil")'")
        print("   - clientEmail: '\(invoice.clientEmail ?? "nil")'")
        print("   - clientPhone: '\(invoice.clientPhone ?? "nil")'")
        print("   - clientAddress: '\(invoice.clientAddress ?? "nil")'")
        print("   - clientNDISNumber: '\(invoice.clientNDISNumber ?? "nil")'")
        
        // Use snapshotted data from invoice domain model
        let clientName = invoice.clientName ?? ""
        let clientEmail = invoice.clientEmail ?? ""
        let clientPhone = invoice.clientPhone ?? ""
        let clientAddress = invoice.clientAddress ?? ""
        let clientNDISNumber = invoice.clientNDISNumber ?? ""
        
        if !clientName.isEmpty {
            print("📊 [TemplateDataService] Using client data from invoice snapshot")
            let clientData = ClientTemplateData(
                name: clientName,
                address: clientAddress,
                city: "", // Not in invoice snapshot
                email: clientEmail,
                phone: clientPhone,
                ndisNumber: clientNDISNumber,
                state: "", // Not in invoice snapshot
                postcode: "", // Not in invoice snapshot
                status: "Active", // Default, not in snapshot
                isMinor: false, // Not in snapshot
                hasNdisPlan: !clientNDISNumber.isEmpty
            )
            print("📤 [TemplateDataService] Returning client data: \(clientData.name)")
            return clientData
        } else {
            // Try to fetch from repository using clientId if available
            if let clientId = invoice.clientId ?? clientId {
                Task {
                    if let client = try? await clientsRepository.fetch(by: clientId) {
                        // Update selected invoice with client data if needed
                        // For now, return default
                    }
                }
            }
            
            print("❌ [TemplateDataService] No client data available")
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
    }
    
    // MARK: - Business Data
    
    /// Gets business data from the selected invoice's snapshotted business data
    /// Always returns data from the same invoice as other get* methods
    public func getBusinessData() -> BusinessTemplateData {
        print("🔍 [TemplateDataService] getBusinessData() called")
        
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            print("❌ [TemplateDataService] No selected invoice found")
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
        
        print("✅ [TemplateDataService] Found selected invoice: \(invoice.invoiceNumber)")
        print("📊 [TemplateDataService] Business data from invoice:")
        print("   - businessName: '\(invoice.businessName ?? "nil")'")
        print("   - businessABN: '\(invoice.businessABN ?? "nil")'")
        print("   - businessEmail: '\(invoice.businessEmail ?? "nil")'")
        print("   - businessPhone: '\(invoice.businessPhone ?? "nil")'")
        print("   - businessAddress: '\(invoice.businessAddress ?? "nil")'")
        print("   - bankName: '\(invoice.bankName ?? "nil")'")
        print("   - bankAccountName: '\(invoice.bankAccountName ?? "nil")'")
        
        // Use snapshotted data from invoice domain model
        let businessName = invoice.businessName ?? ""
        let businessABN = invoice.businessABN ?? ""
        let businessEmail = invoice.businessEmail ?? ""
        let businessPhone = invoice.businessPhone ?? ""
        let businessAddress = invoice.businessAddress ?? ""
        let bankName = invoice.bankName ?? ""
        let bankAccountName = invoice.bankAccountName ?? ""
        let bankBSB = invoice.bankBSB ?? ""
        let bankAccountNumber = invoice.bankAccountNumber ?? ""
        
        if !businessName.isEmpty {
            print("📊 [TemplateDataService] Using business data from invoice snapshot")
            let businessData = BusinessTemplateData(
                name: businessName,
                abn: businessABN,
                email: businessEmail,
                phone: businessPhone,
                address: businessAddress,
                city: "", // Not in invoice snapshot
                state: "", // Not in invoice snapshot
                postcode: "", // Not in invoice snapshot
                bankAccountName: bankAccountName,
                bankAccountNumber: bankAccountNumber,
                bankBSB: bankBSB,
                bankName: bankName
            )
            print("📤 [TemplateDataService] Returning business data: \(businessData.name)")
            return businessData
        } else {
            print("❌ [TemplateDataService] No business data available")
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
    }
    
    // MARK: - Payee Data
    
    /// Gets payee data from the selected invoice's snapshotted payee data
    /// Always returns data from the same invoice as other get* methods
    public func getPayeeData(for clientId: UUID? = nil) -> PayeeTemplateData {
        print("🔍 [TemplateDataService] getPayeeData() called")
        
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            print("❌ [TemplateDataService] No selected invoice found")
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
        
        print("✅ [TemplateDataService] Found selected invoice: \(invoice.invoiceNumber)")
        print("📊 [TemplateDataService] Payee data from invoice:")
        print("   - payeeName: '\(invoice.payeeName ?? "nil")'")
        print("   - payeeEmail: '\(invoice.payeeEmail ?? "nil")'")
        print("   - payeePhone: '\(invoice.payeePhone ?? "nil")'")
        print("   - payeeAddress: '\(invoice.payeeAddress ?? "nil")'")
        print("   - billingAuthority: '\(invoice.billingAuthority ?? "nil")'")
        print("   - billToName: '\(invoice.billToName ?? "nil")'")
        print("   - billToEmail: '\(invoice.billToEmail ?? "nil")'")
        print("   - billToAddress: '\(invoice.billToAddress ?? "nil")'")
        
        // Use snapshotted data from invoice domain model
        // Prefer payeeName, fallback to billToName
        let payeeName = invoice.payeeName ?? invoice.billToName ?? ""
        let payeeEmail = invoice.payeeEmail ?? invoice.billToEmail ?? ""
        let payeePhone = invoice.payeePhone ?? ""
        let payeeAddress = invoice.payeeAddress ?? invoice.billToAddress ?? ""
        
        if !payeeName.isEmpty {
            print("📊 [TemplateDataService] Using payee data from invoice snapshot")
            let payeeData = PayeeTemplateData(
                name: payeeName,
                role: "Parent/Guardian", // Default, not in snapshot
                id: invoice.payeeId?.uuidString ?? UUID().uuidString,
                email: payeeEmail,
                phone: payeePhone,
                address: payeeAddress,
                city: "", // Not in invoice snapshot
                state: "", // Not in invoice snapshot
                postcode: "" // Not in invoice snapshot
            )
            print("📤 [TemplateDataService] Returning payee data: \(payeeData.name)")
            return payeeData
        } else {
            print("❌ [TemplateDataService] No payee data available")
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
    }
    
    // MARK: - Service Data
    
    /// Gets service data from the selected invoice's invoice items
    /// Always returns data from the same invoice as other get* methods
    public func getServiceData(for clientId: UUID? = nil) -> [ServiceTemplateData] {
        print("🔍 [TemplateDataService] getServiceData() called")
        
        // Ensure we have a selected invoice - all components use the same one
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            print("❌ [TemplateDataService] No selected invoice found")
            return []
        }
        
        print("✅ [TemplateDataService] Found selected invoice: \(invoice.invoiceNumber)")
        print("📊 [TemplateDataService] Invoice items count: \(selectedInvoiceItems.count)")
        
        // Use InvoiceItem domain models - note: some fields may not be available in domain model
        let serviceData = selectedInvoiceItems.map { item in
            print("   - Item: '\(item.itemDescription)' | Rate: \(item.rate) | Qty: \(item.quantity) | Total: \(item.lineTotal)")
            return ServiceTemplateData(
                name: item.itemDescription,
                unit: "hr", // Default, not in InvoiceItem domain model
                rate: item.rate,
                amount: item.lineTotal, // Use lineTotal from domain model
                quantity: item.quantity,
                description: item.itemDescription,
                serviceDate: Date(), // Default, not in InvoiceItem domain model
                ndisItemNumber: nil, // Not in InvoiceItem domain model
                ndisSupportCategory: nil, // Not in InvoiceItem domain model
                ndisRegistrationGroup: nil, // Not in InvoiceItem domain model
                claimType: nil // Not in InvoiceItem domain model
            )
        }
        
        print("📤 [TemplateDataService] Returning \(serviceData.count) service items")
        return serviceData
    }
    
    // MARK: - Invoice Data
    
    /// Gets invoice data from the selected invoice
    /// Always returns data from the same invoice as other get* methods
    public func getInvoiceData(for invoiceId: UUID? = nil) -> InvoiceTemplateData {
        print("🔍 [TemplateDataService] getInvoiceData() called")
        
        // Ensure we have a selected invoice - all components use the same one
        // Ignore the invoiceId parameter - we always use the selected invoice
        guard let invoice = selectedInvoice, invoice.id == selectedInvoiceId else {
            print("❌ [TemplateDataService] No selected invoice found")
            return InvoiceTemplateData(
                invoiceNumber: "No Invoice Data",
                issueDate: Date(),
                dueDate: Date(),
                totalAmount: 0.0,
                taxRate: 0.0,
                subtotal: 0.0,
                calculatedTotal: 0.0
            )
        }
        
        print("✅ [TemplateDataService] Found selected invoice: \(invoice.invoiceNumber)")
        print("📊 [TemplateDataService] Invoice data:")
        print("   - invoiceNumber: '\(invoice.invoiceNumber)'")
        print("   - issueDate: \(invoice.issueDate)")
        print("   - dueDate: \(invoice.dueDate?.description ?? "nil")")
        print("   - totalAmount: \(invoice.totalAmount)")
        print("   - taxRate: \(invoice.taxRate)")
        
        // Calculate subtotal from items
        let subtotal = selectedInvoiceItems.reduce(0.0) { $0 + $1.lineTotal }
        // Calculate total - using invoice totalAmount if available, otherwise calculate from subtotal
        let calculatedTotal = invoice.totalAmount > 0 ? invoice.totalAmount : (subtotal * (1 + invoice.taxRate / 100.0))
        
        let invoiceData = InvoiceTemplateData(
            invoiceNumber: invoice.invoiceNumber,
            issueDate: invoice.issueDate,
            dueDate: invoice.dueDate ?? Date(),
            totalAmount: invoice.totalAmount,
            taxRate: invoice.taxRate,
            subtotal: subtotal,
            calculatedTotal: calculatedTotal
        )
        
        print("📤 [TemplateDataService] Returning invoice data: \(invoiceData.invoiceNumber)")
        return invoiceData
    }
    
}

// MARK: - Data Models
// Data models have been moved to Services/DataModels/TemplateDataModels.swift
