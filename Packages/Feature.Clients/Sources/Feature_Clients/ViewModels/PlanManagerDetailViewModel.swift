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
public class PlanManagerDetailViewModel {
    
    // MARK: - Core Dependencies
    let modelContext: ModelContext
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    private(set) var planManager: PlanManager
    let isCreatingNew: Bool

    // Editable Plan Manager Properties
    var editableBusinessName: String = ""
    var editableAbn: String = ""

    // Formatters & Validation
    var phoneFormatter: PhoneNumberFormatter
    var emailValidator: EmailValidator
    var businessNameError: String?
    var abnError: String?

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

    // Invoices (Domain Models)
    var relatedInvoices: [Invoice] = []
    var linkedClients: [Client] = []

    private var lastAllInvoices: [Invoice] = []

    // UI State
    var isEditingAddress: Bool = false
    var showAlert: Bool = false
    var alertTitle: String = ""
    var alertMessage: String = ""
    var isLoading: Bool = false

    // MARK: - Initializer
    public init(
        planManager: PlanManager,
        modelContext: ModelContext,
        isCreating: Bool
    ) {
        self.planManager = planManager
        self.modelContext = modelContext
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: planManager.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: planManager.email ?? "")
        
        loadAllDetails()
    }
    
    // MARK: - Data Loading
    func loadAllDetails() {
        editableBusinessName = planManager.name ?? ""
        editableAbn = planManager.abn
        phoneFormatter.phoneNumber = planManager.phone ?? ""
        emailValidator.email = planManager.email ?? ""
        loadAddressFields(from: planManager.address)
    }

    func refreshRelatedInvoices() async {
        await MainActor.run { self.isLoading = true }
        defer { Task { @MainActor in self.isLoading = false } }

        relatedInvoices = []
        linkedClients = []
        lastAllInvoices = []

        let managerID = planManager.id
        let linkedClients = (try? modelContext.fetch(FetchDescriptor<Client>(
            predicate: #Predicate { $0.planManager?.id == managerID }
        ))) ?? []
        let fetchedInvoices = (try? modelContext.fetch(FetchDescriptor<Invoice>(
            predicate: #Predicate { $0.client?.planManager?.id == managerID }
        ))) ?? []
        
        self.lastAllInvoices = fetchedInvoices
        self.relatedInvoices = fetchedInvoices
        self.linkedClients = linkedClients
    }

    func loadAddressDetails() {
        loadAddressFields(from: planManager.address)
    }

    // MARK: - Save & Update Logic
    
    func updateAndSavePlanManager() {
        Task {
            await savePlanManagerUpdates()
        }
    }
    
    private func savePlanManagerUpdates() async {
        let trimmedBusinessName = editableBusinessName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBusinessName.isEmpty else {
            businessNameError = "Business Name cannot be empty."
            return
        }
        
        guard isValidABN(editableAbn) else {
            abnError = "Invalid ABN. Must be 11 digits."
            return
        }
        
        do {
            planManager.name = trimmedBusinessName
            planManager.email = emailValidator.isValid ? emailValidator.email : planManager.email
            planManager.phone = phoneFormatter.isValid ? phoneFormatter.phoneNumber : planManager.phone
            planManager.abn = editableAbn

            if isEditingAddress || !editableStreetName.isEmpty || !editableStreetNumber.isEmpty {
                let address = planManager.address ?? Address()
                if planManager.address == nil {
                    modelContext.insert(address)
                    planManager.address = address
                }
                applyEditableAddressFields(to: address)
            }

            try modelContext.save()
            
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
        let address = planManager.address ?? Address()
        if planManager.address == nil {
            modelContext.insert(address)
            planManager.address = address
        }
        applyEditableAddressFields(to: address)

        isEditingAddress = false
        
        if autosave && !isCreatingNew {
            Task {
                await savePlanManagerUpdates()
            }
        }
    }
    
    func formattedAddressString(from address: Address) -> String {
        return address.fullFormattedAddress
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
