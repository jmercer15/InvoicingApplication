//
//  TemplateDataService.swift
//  Feature_InvoiceTemplateEditor
//
//  Created by AI Assistant on 21/7/2025.
//

import Foundation
import SwiftData
import SwiftUI
import Data
import Core

/// Service for providing real data from persisted entities to the template editor
@MainActor
public class TemplateDataService: ObservableObject {
    private let modelContext: ModelContext
    private let selectedInvoice: InvoiceEntity?
    
    public init(modelContext: ModelContext) {
        print("🚀 [TemplateDataService] Initializing with modelContext")
        self.modelContext = modelContext
        self.selectedInvoice = Self.selectRandomInvoice(from: modelContext)
        
        if let invoice = selectedInvoice {
            print("✅ [TemplateDataService] Selected invoice: \(invoice.invoiceNumber)")
        } else {
            print("❌ [TemplateDataService] No invoices found in database")
        }
    }
    
    /// Shared instance for consistent data across all components
    public static var shared: TemplateDataService?
    
    /// Initialize the shared instance with a model context
    /// Call this once when the template editor starts to ensure all components use the same invoice
    public static func initializeShared(with modelContext: ModelContext) {
        print("🔧 [TemplateDataService] Initializing shared instance")
        shared = TemplateDataService(modelContext: modelContext)
        print("✅ [TemplateDataService] Shared instance created")
    }
    
    /// Get the shared instance
    /// Note: Components should call initializeShared(with:) before using getShared()
    public static func getShared() -> TemplateDataService {
        print("🔍 [TemplateDataService] getShared() called")
        guard let shared = shared else {
            print("❌ [TemplateDataService] Shared instance not initialized!")
            fatalError("TemplateDataService.shared must be initialized before use. Call TemplateDataService.initializeShared(with: modelContext) first.")
        }
        print("✅ [TemplateDataService] Returning shared instance")
        return shared
    }
    
    /// Selects a random invoice from the database for template editing, preferring invoices with complete relationship data
    private static func selectRandomInvoice(from modelContext: ModelContext) -> InvoiceEntity? {
        print("🔍 [TemplateDataService] Selecting random invoice from database")
        let descriptor = FetchDescriptor<InvoiceEntity>()
        
        do {
            let invoices = try modelContext.fetch(descriptor)
            print("📊 [TemplateDataService] Found \(invoices.count) invoices in database")
            
            // First, try to find an invoice with complete relationship data
            let invoicesWithCompleteData = invoices.filter { invoice in
                return invoice.business != nil && 
                       invoice.client != nil && 
                       invoice.payee != nil
            }
            
            if !invoicesWithCompleteData.isEmpty {
                let selectedInvoice = invoicesWithCompleteData.randomElement()!
                print("✅ [TemplateDataService] Selected invoice with complete relationships: \(selectedInvoice.invoiceNumber)")
                return selectedInvoice
            }
            
            // Fallback to any random invoice
            if let selectedInvoice = invoices.randomElement() {
                print("✅ [TemplateDataService] Selected random invoice: \(selectedInvoice.invoiceNumber)")
                return selectedInvoice
            } else {
                print("❌ [TemplateDataService] No invoices available for selection")
                return nil
            }
        } catch {
            print("❌ [TemplateDataService] Error fetching invoices: \(error)")
            return nil
        }
    }
    
    // MARK: - Client Data
    
    /// Gets client data from the selected invoice's snapshotted client data
    public func getClientData(for clientId: UUID? = nil) -> ClientTemplateData {
        print("🔍 [TemplateDataService] getClientData() called")
        
        guard let invoice = selectedInvoice else {
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
        
        // Use snapshotted data if available, otherwise fall back to relationship data (following Invoices feature pattern)
        let clientData: ClientTemplateData
        
        // Priority 1: Use snapshotted data if available
        let clientName = invoice.clientName ?? invoice.client?.fullName ?? ""
        let clientEmail = invoice.clientEmail ?? invoice.client?.email ?? ""
        let clientPhone = invoice.clientPhone ?? invoice.client?.phone ?? ""
        let clientAddress = invoice.clientAddress ?? invoice.client?.address?.fullFormattedAddress ?? ""
        let clientNDISNumber = invoice.clientNDISNumber ?? invoice.client?.ndisNumber ?? ""
        
        if !clientName.isEmpty {
            print("📊 [TemplateDataService] Using client data (snapshotted + relationship fallback)")
            clientData = ClientTemplateData(
                name: clientName,
                address: clientAddress,
                city: invoice.client?.address?.suburb ?? "",
                email: clientEmail,
                phone: clientPhone,
                ndisNumber: clientNDISNumber,
                state: invoice.client?.address?.state ?? "",
                postcode: invoice.client?.address?.postcode ?? "",
                status: invoice.client?.status.rawValue ?? "Active",
                isMinor: invoice.client?.isMinor ?? false,
                hasNdisPlan: invoice.client?.hasNdisPlan ?? true
            )
        } else {
            // No client data available
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
        
        print("📤 [TemplateDataService] Returning client data: \(clientData.name)")
        return clientData
    }
    
    // MARK: - Business Data
    
    /// Gets business data from the selected invoice's snapshotted business data
    public func getBusinessData() -> BusinessTemplateData {
        print("🔍 [TemplateDataService] getBusinessData() called")
        
        guard let invoice = selectedInvoice else {
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
        
        // Follow Invoices feature pattern: invoice.business ?? fetch first business from database
        var business: BusinessEntity? = invoice.business
        if business == nil {
            print("📊 [TemplateDataService] No business relationship, fetching first business from database")
            let descriptor = FetchDescriptor<BusinessEntity>()
            business = (try? modelContext.fetch(descriptor))?.first
        }
        
        // Use snapshotted data if available, otherwise fall back to business entity data
        let businessName = invoice.businessName ?? business?.name ?? ""
        let businessABN = invoice.businessABN ?? business?.abn ?? ""
        let businessEmail = invoice.businessEmail ?? business?.email ?? ""
        let businessPhone = invoice.businessPhone ?? business?.phone ?? ""
        let businessAddress = invoice.businessAddress ?? business?.address?.fullFormattedAddress ?? ""
        let bankName = invoice.bankName ?? business?.bankName ?? ""
        let bankAccountName = invoice.bankAccountName ?? business?.bankAccountName ?? ""
        let bankBSB = invoice.bankBSB ?? business?.bankBSB ?? ""
        let bankAccountNumber = invoice.bankAccountNumber ?? business?.bankAccountNumber ?? ""
        
        if !businessName.isEmpty {
            print("📊 [TemplateDataService] Using business data (snapshotted + business entity fallback)")
            let businessData = BusinessTemplateData(
                name: businessName,
                abn: businessABN,
                email: businessEmail,
                phone: businessPhone,
                address: businessAddress,
                city: business?.address?.city ?? "",
                state: business?.address?.state ?? "",
                postcode: business?.address?.postcode ?? "",
                bankAccountName: bankAccountName,
                bankAccountNumber: bankAccountNumber,
                bankBSB: bankBSB,
                bankName: bankName
            )
            print("📤 [TemplateDataService] Returning business data: \(businessData.name)")
            return businessData
        } else {
            // No business data available
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
    public func getPayeeData(for clientId: UUID? = nil) -> PayeeTemplateData {
        print("🔍 [TemplateDataService] getPayeeData() called")
        
        guard let invoice = selectedInvoice else {
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
        print("   - billingAuthority: '\(invoice.billingAuthority?.rawValue ?? "nil")'")
        print("   - billToName: '\(invoice.billToName ?? "nil")'")
        print("   - billToEmail: '\(invoice.billToEmail ?? "nil")'")
        print("   - billToAddress: '\(invoice.billToAddress ?? "nil")'")
        
        // Use snapshotted data if available, otherwise fall back to relationship data (following Invoices feature pattern)
        let payeeData: PayeeTemplateData
        
        // Priority 1: Use snapshotted data if available
        let payeeName = invoice.payeeName ?? invoice.client?.payee?.fullName ?? ""
        let payeeEmail = invoice.payeeEmail ?? invoice.client?.payee?.email ?? ""
        let payeePhone = invoice.payeePhone ?? invoice.client?.payee?.phone ?? ""
        let payeeAddress = invoice.payeeAddress ?? invoice.client?.payee?.address?.fullFormattedAddress ?? ""
        
        if !payeeName.isEmpty {
            print("📊 [TemplateDataService] Using payee data (snapshotted + relationship fallback)")
            payeeData = PayeeTemplateData(
                name: payeeName,
                role: invoice.client?.payee?.relationToClient ?? "Parent/Guardian",
                id: invoice.client?.payee?.id.uuidString ?? UUID().uuidString,
                email: payeeEmail,
                phone: payeePhone,
                address: payeeAddress,
                city: invoice.client?.payee?.address?.city ?? "",
                state: invoice.client?.payee?.address?.state ?? "",
                postcode: invoice.client?.payee?.address?.postcode ?? ""
            )
        } else {
            // No payee data available
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
        
        print("📤 [TemplateDataService] Returning payee data: \(payeeData.name)")
        return payeeData
    }
    
    // MARK: - Service Data
    
    /// Gets service data from the selected invoice's invoice items relationship
    public func getServiceData(for clientId: UUID? = nil) -> [ServiceTemplateData] {
        print("🔍 [TemplateDataService] getServiceData() called")
        
        guard let invoice = selectedInvoice else {
            print("❌ [TemplateDataService] No selected invoice found")
            return []
        }
        
        print("✅ [TemplateDataService] Found selected invoice: \(invoice.invoiceNumber)")
        print("📊 [TemplateDataService] Invoice items count: \(invoice.items.count)")
        
        let serviceData = invoice.items.map { item in
            print("   - Item: '\(item.itemDescription)' | Rate: \(item.rate) | Qty: \(item.quantity) | Amount: \(item.amount)")
            return ServiceTemplateData(
                name: item.itemDescription,
                unit: item.unit ?? "hr",
                rate: item.rate,
                amount: item.amount,
                quantity: item.quantity,
                description: item.itemDescription,
                serviceDate: item.serviceDate,
                ndisItemNumber: item.ndisItemNumber,
                ndisSupportCategory: item.ndisSupportCategory,
                ndisRegistrationGroup: item.ndisRegistrationGroup,
                claimType: getClaimTypeDisplayName(for: item.claimType)
            )
        }
        
        print("📤 [TemplateDataService] Returning \(serviceData.count) service items")
        return serviceData
    }
    
    // MARK: - Invoice Data
    
    /// Gets invoice data from the selected invoice
    public func getInvoiceData(for invoiceId: UUID? = nil) -> InvoiceTemplateData {
        print("🔍 [TemplateDataService] getInvoiceData() called")
        
        guard let invoice = selectedInvoice else {
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
        print("   - subtotal: \(invoice.subtotal)")
        print("   - calculatedTotal: \(invoice.calculatedTotal)")
        
        let invoiceData = InvoiceTemplateData(
                    invoiceNumber: invoice.invoiceNumber,
                    issueDate: invoice.issueDate,
            dueDate: invoice.dueDate ?? Date(),
            totalAmount: invoice.totalAmount,
                    taxRate: invoice.taxRate,
            subtotal: invoice.subtotal,
            calculatedTotal: invoice.calculatedTotal
        )
        
        print("📤 [TemplateDataService] Returning invoice data: \(invoiceData.invoiceNumber)")
        return invoiceData
    }
    
    
    // MARK: - Helper Methods
    
    /// Gets the display name for NDIS claim type
    private func getClaimTypeDisplayName(for claimType: NDISClaimType?) -> String {
        guard let claimType = claimType else { return "Standard" }
        
        switch claimType {
        case .direct:
            return "Direct Support"
        case .providerTravel:
            return "Provider Travel"
        case .cancellation:
            return "Cancellation Fee"
        case .prepayment:
            return "Prepayment"
        case .telehealth:
            return "Telehealth"
        case .nonFaceToFace:
            return "Non-Face-to-Face"
        case .ndiaReport:
            return "NDIA Report"
        case .irregularSILSupport:
            return "Irregular SIL Support"
        case .bereavement:
            return "Bereavement Support"
        @unknown default:
            return claimType.rawValue
        }
    }
    
}

// MARK: - Data Models

public struct ClientTemplateData {
    public let name: String
    public let address: String
    public let city: String
    public let email: String
    public let phone: String
    public let ndisNumber: String
    public let state: String
    public let postcode: String
    public let status: String
    public let isMinor: Bool
    public let hasNdisPlan: Bool
}

public struct BusinessTemplateData {
    public let name: String
    public let abn: String
    public let email: String
    public let phone: String
    public let address: String
    public let city: String
    public let state: String
    public let postcode: String
    public let bankAccountName: String
    public let bankAccountNumber: String
    public let bankBSB: String
    public let bankName: String
}

public struct PayeeTemplateData {
    public let name: String
    public let role: String
    public let id: String
    public let email: String
    public let phone: String
    public let address: String
    public let city: String
    public let state: String
    public let postcode: String
}

public struct ServiceTemplateData {
    public let name: String
    public let unit: String
    public let rate: Double
    public let amount: Double
    public let quantity: Double
    public let description: String
    public let serviceDate: Date
    public let ndisItemNumber: String?
    public let ndisSupportCategory: String?
    public let ndisRegistrationGroup: String?
    public let claimType: String?
}

public struct InvoiceTemplateData {
    public let invoiceNumber: String
    public let issueDate: Date
    public let dueDate: Date
    public let totalAmount: Double
    public let taxRate: Double
    public let subtotal: Double
    public let calculatedTotal: Double
}
