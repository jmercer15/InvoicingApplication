import SwiftUI
import AppKit
import MapKit
import SwiftData
import Core
import PersistenceModels
import SharedUI
import Observation

@Observable
@MainActor
public class PayeeDetailViewModel {
    
    // MARK: - Core Dependencies
    let modelContext: ModelContext
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    private(set) var payee: Payee
    let isCreatingNew: Bool

    // Editable Payee Properties
    var editableFullName: String = ""
    var editableStatus: String = "Active"
    // colorHex property removed - using deterministic color system instead
    // notes property removed from Payee - no longer supported
    var editableRelationToClient: String = ""

    // Formatters & Validation
    var phoneFormatter: PhoneNumberFormatter
    var emailValidator: EmailValidator
    var fullNameError: String?

    // Address Properties
    var editableUnitNumber: String = ""
    var editableStreetNumber: String = ""
    var editableStreetName: String = ""
    var editableSuburb: String = ""
    var editableCity: String = ""
    var editablePostcode: String = ""
    var editableState: String = ""
    var editableCountry: String = ""
    var editablePoBox: String = ""
    var addressSearchText: String = ""
    var selectedSearchAddress: AddressData?

    var selectedClientIDs: Set<UUID> = []

    // Invoices (Domain Models)
    var relatedInvoices: [Invoice] = []
    var linkedClients: [Client] = []

    private var lastAllInvoices: [Invoice] = []

    // UI State
    var isEditingAddress: Bool = false
    var showAlert: Bool = false
    var alertTitle: String = ""
    var alertMessage: String = ""
    var showingClientSelector = false
    var isLoading: Bool = false

    // MARK: - Initializer
    public init(
        payee: Payee,
        modelContext: ModelContext,
        isCreating: Bool
    ) {
        self.payee = payee
        self.modelContext = modelContext
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: payee.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: payee.email ?? "")
        
        loadAllDetails()
    }
    
    // MARK: - Data Loading
    private func loadAllDetails() {
        self.editableFullName = payee.fullName
        self.editableStatus = payee.status ?? "Active"
        // colorHex property removed - using deterministic color system instead
        // notes property removed from Payee - no longer supported
        self.editableRelationToClient = payee.relationToClient ?? ""
        self.phoneFormatter.phoneNumber = payee.phone ?? ""
        self.emailValidator.email = payee.email ?? ""
        loadAddressFields(from: payee.address)
    }

    func refreshRelatedInvoices() async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        relatedInvoices = []
        linkedClients = []
        lastAllInvoices = []

        let payeeID = payee.id
        let linkedClients = (try? modelContext.fetch(FetchDescriptor<Client>(
            predicate: #Predicate { $0.payee?.id == payeeID }
        ))) ?? []
        let fetchedInvoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.payee?.id == payeeID }
        ))) ?? []
        
        self.lastAllInvoices = fetchedInvoices
        let fetchedIDs = Set(linkedClients.map(\.id))
        if selectedClientIDs.isEmpty {
            selectedClientIDs = fetchedIDs
        }
        self.relatedInvoices = fetchedInvoices
        self.linkedClients = linkedClients
    }

    func loadAddressDetails() {
        loadAddressFields(from: payee.address)
    }

    // MARK: - Save & Update Logic
    
    func updateAndSavePayee() {
        Task {
            await savePayeeUpdates()
        }
    }
    
    private func savePayeeUpdates() async {
        do {
            payee.fullName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
            payee.email = emailValidator.isValid ? emailValidator.email : payee.email
            payee.phone = phoneFormatter.isValid ? phoneFormatter.phoneNumber : payee.phone
            payee.status = editableStatus
            payee.relationToClient = editableRelationToClient.isEmpty ? nil : editableRelationToClient

            if isEditingAddress || !editableStreetName.isEmpty || !editableStreetNumber.isEmpty {
                let address = payee.address ?? Address()
                if payee.address == nil {
                    modelContext.insert(address)
                    payee.address = address
                }
                applyEditableAddressFields(to: address)
            }

            try modelContext.save()
            // Update client associations after saving payee
            await updateClientAssociations()
            
            // Re-fetch using actor
            await refreshRelatedInvoices()
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save changes: \(nsError.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Address Logic

    func updateAddressFromSearchResult(_ address: AddressData) {
        address.copyToStructuredAddressFields(
            unitNumber: &editableUnitNumber,
            streetNumber: &editableStreetNumber,
            streetName: &editableStreetName,
            suburb: &editableSuburb,
            city: &editableCity,
            state: &editableState,
            postcode: &editablePostcode,
            country: &editableCountry,
            poBox: &editablePoBox
        )
    }

    func commitAddressChanges(autosave: Bool = true) {
        let address = payee.address ?? Address()
        if payee.address == nil {
            modelContext.insert(address)
            payee.address = address
        }
        applyEditableAddressFields(to: address)
        address.fullAddressText = address.fullFormattedAddress

        isEditingAddress = false
        
        if autosave && !isCreatingNew {
            Task {
                await savePayeeUpdates()
            }
        }
    }
    
    func formattedAddressString(from address: Address) -> String {
        return address.fullFormattedAddress
    }
    
    // MARK: - Client Association
    func updateClientAssociations() async {
        // Update clients to associate them with this payee
        do {
            let payeeID = payee.id
            
            // 1. Fetch clients currently associated with this payee
            let currentlyAssociatedDescriptor = FetchDescriptor<Client>(
                predicate: #Predicate<Client> { $0.payee?.id == payeeID }
            )
            var allRelevantClients = (try? modelContext.fetch(currentlyAssociatedDescriptor)) ?? []
            
            // 2. Fetch any selected clients not already in the array
            for id in selectedClientIDs {
                if !allRelevantClients.contains(where: { $0.id == id }) {
                    var descriptor = FetchDescriptor<Client>(predicate: #Predicate<Client> { $0.id == id })
                    descriptor.fetchLimit = 1
                    if let client = try? modelContext.fetch(descriptor).first {
                        allRelevantClients.append(client)
                    }
                }
            }

            for client in allRelevantClients {
                let shouldHavePayee = selectedClientIDs.contains(client.id)
                let currentlyHasPayee = client.payee?.id == payeeID
                
                // Only update if the association state has changed
                if shouldHavePayee != currentlyHasPayee {
                    client.payee = shouldHavePayee ? payee : nil
                }
            }
            try modelContext.save()
        } catch {
            print("❌ [PayeeDetailViewModel] Error updating client associations: \(error)")
            alertTitle = "Update Error"
            alertMessage = "Could not update client associations: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // MARK: - Helpers
    func copyToClipboard(_ text: String?) {
        guard let text = text, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

} 
