import SwiftUI
import AppKit
import MapKit
import SwiftData
import Data
import SharedUI

class PlanManagerDetailViewModel: ObservableObject {
    
    // MARK: - Core Dependencies
    let modelContext: ModelContext
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    @Published var planManager: PlanManagerEntity
    let isCreatingNew: Bool

    // Editable Plan Manager Properties
    @Published var editableBusinessName: String = ""
    @Published var editableAbn: String = ""

    // Formatters & Validation
    @Published var phoneFormatter: PhoneNumberFormatter
    @Published var emailValidator: EmailValidator
    @Published var businessNameError: String?
    @Published var abnError: String?

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

    // Managed Clients
    @Published var managedClients: [ClientEntity] = []

    // Invoices
    @Published var relatedInvoices: [InvoiceEntity] = []

    // UI State
    @Published var isEditingAddress: Bool = false
    @Published var showDeleteAlert = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    // MARK: - Initializer
    init(planManager: PlanManagerEntity, context: ModelContext, isCreating: Bool) {
        self.planManager = planManager
        self.modelContext = context
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: planManager.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: planManager.email ?? "")
        
        loadAllDetails()
        fetchRelatedInvoices()
    }
    
    // MARK: - Data Loading
    func loadAllDetails() {
        editableBusinessName = planManager.name ?? ""
        editableAbn = planManager.abn
        phoneFormatter.phoneNumber = planManager.phone ?? ""
        emailValidator.email = planManager.email ?? ""
        loadAddressDetails()
        fetchManagedClients()
        fetchRelatedInvoices()
    }

    func loadAddressDetails() {
        if let address = planManager.address {
            editableUnitNumber = address.unitNumber
            editableStreetNumber = address.streetNumber
            editableStreetName = address.streetName
            editableSuburb = address.suburb
            editablePostcode = address.postcode
            editableState = address.state
            editableCountry = address.country
            editablePoBox = address.poBox
        } else {
            editableUnitNumber = ""; editableStreetNumber = ""; editableStreetName = ""
            editableSuburb = ""; editablePostcode = ""; editableState = ""
            editableCountry = "Australia"; editablePoBox = ""
        }
    }
    
    private func fetchManagedClients() {
        let descriptor = FetchDescriptor<ClientEntity>(
            sortBy: [SortDescriptor(\.fullName)]
        )
        do {
            let allClients = try modelContext.fetch(descriptor)
            self.managedClients = allClients.filter { $0.planManager?.id == planManager.id }
        } catch {
            print("Error fetching managed clients for \(planManager.name ?? "Plan Manager"): \(error)")
            self.managedClients = []
        }
    }
    
    private func fetchRelatedInvoices() {
        let allInvoices: [InvoiceEntity] = managedClients
            .flatMap { client in
                client.invoices
            }
            .compactMap { invoice in
                invoice
            }
        
        relatedInvoices = allInvoices.sorted { (invoice1: InvoiceEntity, invoice2: InvoiceEntity) in
            invoice1.issueDate > invoice2.issueDate
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
    
    func updateAndSavePlanManager() {
        guard !isCreatingNew else { return }

        let trimmedBusinessName = editableBusinessName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBusinessName.isEmpty {
            businessNameError = "Business Name cannot be empty."; return
        } else {
            businessNameError = nil; planManager.name = trimmedBusinessName
        }
        
        if isValidABN(editableAbn) {
            abnError = nil; planManager.abn = editableAbn
        } else {
            abnError = "Invalid ABN. Must be 11 digits."; return
        }
        
        if emailValidator.isValid { planManager.email = emailValidator.email }
        if phoneFormatter.isValid { planManager.phone = phoneFormatter.phoneNumber }

        _ = saveContext()
    }
    
    func createPlanManagerAndDismiss() {
        let trimmedBusinessName = editableBusinessName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBusinessName.isEmpty {
            businessNameError = "Business Name cannot be empty."; return
        }
        
        if !isValidABN(editableAbn) {
            abnError = "Invalid ABN. Must be 11 digits."; showAlert = true; alertTitle="Validation Error"; alertMessage=abnError!; return
        }
        
        if !emailValidator.email.isEmpty && !emailValidator.isValid {
            alertTitle = "Validation Error"; alertMessage = "Invalid email address."; showAlert = true; return
        }

            planManager.name = trimmedBusinessName
        planManager.abn = editableAbn
        planManager.email = emailValidator.email.isEmpty ? nil : emailValidator.email
        planManager.phone = phoneFormatter.phoneNumber.isEmpty ? nil : phoneFormatter.phoneNumber
        
        commitAddressChanges(autosave: false)
        
        modelContext.insert(planManager)
        if saveContext() {
            dismiss()
        }
    }
    
    // MARK: - Address Logic
    func commitAddressChanges(autosave: Bool = true) {
        if planManager.address == nil {
             if editableUnitNumber.isEmpty && editableStreetNumber.isEmpty && editableStreetName.isEmpty &&
                editableSuburb.isEmpty && editablePostcode.isEmpty && editableState.isEmpty && editableCountry.isEmpty && editablePoBox.isEmpty {
                 isEditingAddress = false
                 return
             }
             planManager.address = AddressEntity()
         }
        
        planManager.address?.unitNumber = editableUnitNumber
        planManager.address?.streetNumber = editableStreetNumber
        planManager.address?.streetName = editableStreetName
        planManager.address?.suburb = editableSuburb
        planManager.address?.postcode = editablePostcode
        planManager.address?.state = editableState
        planManager.address?.country = editableCountry
        planManager.address?.poBox = editablePoBox
        
        isEditingAddress = false
        
        if let address = planManager.address {
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
        guard let address = planManager.address else { return }
        let query = formattedAddressString(address)
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "maps://?q=\(encodedQuery)") { NSWorkspace.shared.open(url) }
    }

    // MARK: - Plan Manager Actions
    func confirmDeletePlanManager() {
        self.showDeleteAlert = true
    }
    
    func deletePlanManagerAndDismiss() {
        modelContext.delete(planManager)
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

    func isValidABN(_ abn: String) -> Bool {
        let trimmedABN = abn.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedABN.isEmpty { return true }
        let abnRegex = "^\\d{11}$"
        let abnPredicate = NSPredicate(format: "SELF MATCHES %@", abnRegex)
        return abnPredicate.evaluate(with: trimmedABN)
    }
} 