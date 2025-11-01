import SwiftUI
import AppKit
import MapKit
import SwiftData
import Data
import SharedUI

class PayeeDetailViewModel: ObservableObject {
    
    // MARK: - Core Dependencies
    let modelContext: ModelContext
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    @Published var payee: PayeeEntity
    let isCreatingNew: Bool

    // Editable Payee Properties
    @Published var editableFullName: String = ""
    @Published var editableStatus: String = "Active"
    // colorHex property removed - using deterministic color system instead
    // notes property removed from Payee - no longer supported
    @Published var editableRelationToClient: String = ""

    // Formatters & Validation
    @Published var phoneFormatter: PhoneNumberFormatter
    @Published var emailValidator: EmailValidator
    @Published var fullNameError: String?

    // Address Properties
    @Published var editableUnitNumber: String = ""
    @Published var editableStreetNumber: String = ""
    @Published var editableStreetName: String = ""
    @Published var editableSuburb: String = ""
    @Published var editablePostcode: String = ""
    @Published var editableState: String = ""
    @Published var editableCountry: String = ""
    @Published var editablePoBox: String = ""
    @Published var addressSearchText: String = ""
    @Published var selectedSearchAddress: AddressData?

    // Associated Clients
    @Published var associatedClients: [ClientEntity] = []
    @Published var selectedClientIDs: Set<UUID> = []
    
    // Data for Pickers
    @Published var allClients: [ClientEntity] = []
    let payeeStatuses = ["Active", "Inactive", "Archived"]

    // Invoices
    @Published var relatedInvoices: [InvoiceEntity] = []

    // UI State
    @Published var isEditingAddress: Bool = false
    @Published var showDeleteAlert = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showingClientSelector = false

    // MARK: - Initializer
    init(payee: PayeeEntity, context: ModelContext, isCreating: Bool) {
        self.payee = payee
        self.modelContext = context
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: payee.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: payee.email ?? "")
        
        loadAllDetails()
        fetchRelatedInvoices()
        fetchPickerData()
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
        loadAddressDetails()
        fetchAssociatedClients()
        fetchAllClients()
    }

    private func fetchRelatedInvoices() {
        let directInvoices = payee.invoices

        let clientInvoices = payee.guardedClients.flatMap { $0.invoices }
        
        let allInvoices = directInvoices + clientInvoices
        
        relatedInvoices = Array(allInvoices).sorted {
            $0.issueDate > $1.issueDate
        }
    }

    func loadAddressDetails() {
        if let address = payee.address {
            self.editableUnitNumber = address.unitNumber
            self.editableStreetNumber = address.streetNumber
            self.editableStreetName = address.streetName
            self.editableSuburb = address.suburb
            self.editablePostcode = address.postcode
            self.editableState = address.state
            self.editableCountry = address.country
            self.editablePoBox = address.poBox
        } else {
            self.editableUnitNumber = ""; self.editableStreetNumber = ""; self.editableStreetName = ""
            self.editableSuburb = ""; self.editablePostcode = ""; self.editableState = ""
            self.editableCountry = "Australia"; self.editablePoBox = ""
        }
    }
    
    private func fetchAssociatedClients() {
        let clientSet = payee.guardedClients
        self.associatedClients = Array(clientSet).sorted(by: { $0.fullName < $1.fullName })
        self.selectedClientIDs = Set(clientSet.map { $0.id })
    }
    
    private func fetchAllClients() {
        let descriptor = FetchDescriptor<ClientEntity>(sortBy: [SortDescriptor(\.fullName)])
        do {
            allClients = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching all clients: \(error)")
            allClients = []
        }
    }
    
    private func fetchPickerData() {
        let descriptor = FetchDescriptor<ClientEntity>(sortBy: [SortDescriptor(\.fullName)])
        do {
            allClients = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to fetch clients: \(error)")
        }
    }
    
    // MARK: - Save & Update Logic
    @discardableResult
    func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save changes: \(nsError.localizedDescription)"
            showAlert = true
            return false
        }
    }
    
    func updateAndSavePayee() {
        payee.fullName = editableFullName
        payee.status = editableStatus
        // colorHex property removed - using deterministic color system instead
        // notes property removed from Payee - no longer supported
        payee.relationToClient = editableRelationToClient.isEmpty ? nil : editableRelationToClient
        payee.email = emailValidator.isValid ? emailValidator.email : payee.email
        payee.phone = phoneFormatter.isValid ? phoneFormatter.phoneNumber : payee.phone
        
        validate()
        _ = saveContext()
    }
    
    func createPayeeAndDismiss() {
        let trimmedFullName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFullName.isEmpty {
            fullNameError = "Full Name cannot be empty."; return
        }
        
        if !emailValidator.email.isEmpty && !emailValidator.isValid {
            alertTitle = "Validation Error"; alertMessage = "Invalid email address."; showAlert = true; return
        }

        payee.fullName = trimmedFullName
        payee.status = editableStatus
        // colorHex property removed - using deterministic color system instead
        // notes property removed from Payee - no longer supported
        payee.relationToClient = editableRelationToClient.isEmpty ? nil : editableRelationToClient
        payee.email = emailValidator.email.isEmpty ? nil : emailValidator.email
        payee.phone = phoneFormatter.phoneNumber.isEmpty ? nil : phoneFormatter.phoneNumber
        
        commitAddressChanges(autosave: false) // Commit without saving, main save will handle it.
        updateClientAssociations() // Also without saving
        
        modelContext.insert(payee)

        if saveContext() {
            dismiss()
        }
    }
    
    // MARK: - Address Logic
    func commitAddressChanges(autosave: Bool = true) {
        if payee.address == nil {
             if editableUnitNumber.isEmpty && editableStreetNumber.isEmpty && editableStreetName.isEmpty &&
                editableSuburb.isEmpty && editablePostcode.isEmpty && editableState.isEmpty && editableCountry.isEmpty && editablePoBox.isEmpty {
                 isEditingAddress = false
                 return
             }
             payee.address = AddressEntity()
         }
        
        payee.address?.unitNumber = editableUnitNumber
        payee.address?.streetNumber = editableStreetNumber
        payee.address?.streetName = editableStreetName
        payee.address?.suburb = editableSuburb
        payee.address?.postcode = editablePostcode
        payee.address?.state = editableState
        payee.address?.country = editableCountry
        payee.address?.poBox = editablePoBox
        
        isEditingAddress = false
        
        if let address = payee.address {
            let container = modelContext.container
            DispatchQueue.main.async {
                Task {
                    // Create a background context to avoid data races
                    let backgroundContext = ModelContext(container)
                    await GeocodingService.shared.geocodeAndSave(addressEntity: address, in: backgroundContext)
                }
            }
        }
        
        if autosave && !isCreatingNew {
            _ = saveContext()
        }
    }
    
    func formattedAddressString(_ address: AddressEntity) -> String {
        var components: [String] = []
        if !address.poBox.isEmpty { components.append("PO Box \(address.poBox)") }
        else {
            if !address.unitNumber.isEmpty { components.append("Unit \(address.unitNumber)") }
            var streetLine = ""
            if !address.streetNumber.isEmpty { streetLine += address.streetNumber }
            if !address.streetName.isEmpty { streetLine += streetLine.isEmpty ? address.streetName : " \(address.streetName)" }
            if !streetLine.isEmpty { components.append(streetLine) }
        }
        if !address.suburb.isEmpty { components.append(address.suburb) }
        var statePostcodeLine = ""
        if !address.state.isEmpty { statePostcodeLine += address.state }
        if !address.postcode.isEmpty { statePostcodeLine += statePostcodeLine.isEmpty ? address.postcode : " \(address.postcode)" }
        if !statePostcodeLine.isEmpty { components.append(statePostcodeLine) }
        if !address.country.isEmpty { components.append(address.country) }
        return components.joined(separator: ", ")
    }
    
    func openInMaps() {
        guard let address = payee.address else { return }
        let query = formattedAddressString(address)
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "maps://?q=\(encodedQuery)") { NSWorkspace.shared.open(url) }
    }

    // MARK: - Client Association
    func updateClientAssociations() {
        // Clear existing associations
        payee.guardedClients = []
        
        // Add new associations
        for clientID in selectedClientIDs {
            let descriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == clientID })
            if let clientObject = try? modelContext.fetch(descriptor).first {
                payee.guardedClients.append(clientObject)
            }
        }
        
        if !isCreatingNew {
            if saveContext() {
                fetchAssociatedClients()
            }
        } else {
            // For new payees, just update the local array. The main save will persist it.
            fetchAssociatedClients()
        }
    }
    
    // MARK: - Payee Actions
    func confirmDeletePayee() {
        self.showDeleteAlert = true
    }
    
    func deletePayeeAndDismiss() {
        modelContext.delete(payee)
        if saveContext() {
            dismiss()
        }
    }
    
    // MARK: - Helpers
    func copyToClipboard(_ text: String?) {
        guard let text = text, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Validation
    private func validate() {
        let trimmedFullName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFullName.isEmpty {
            fullNameError = "Full Name cannot be empty."
        } else {
            fullNameError = nil
            payee.fullName = trimmedFullName
        }
        
        payee.status = editableStatus
        
        if emailValidator.isValid { payee.email = emailValidator.email }
        if phoneFormatter.isValid { payee.phone = phoneFormatter.phoneNumber }
    }
} 