import SwiftUI
import AppKit
import MapKit
import SwiftData
import Core
import Data
import SharedUI

@MainActor
public class PlanManagerDetailViewModel: ObservableObject {
    
    // MARK: - Core Dependencies
    private let unitOfWork: UnitOfWorkService
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    @Published private(set) var planManager: PlanManager
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
    @Published var editableCity: String = ""
    @Published var editablePostcode: String = ""
    @Published var editableState: String = ""
    @Published var editableCountry: String = ""
    @Published var editablePoBox: String = ""
    @Published var addressSearchText: String = ""
    @Published var selectedSearchAddress: AddressData?

    // Managed Clients (Domain Models)
    @Published var managedClients: [Client] = []

    // Invoices (Domain Models)
    @Published var relatedInvoices: [Invoice] = []

    // UI State
    @Published var isEditingAddress: Bool = false
    @Published var showDeleteAlert = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var isLoading: Bool = false

    // MARK: - Initializer
    // MARK: - Initializer
    public init(
        planManager: PlanManager,
        unitOfWork: UnitOfWorkService,
        isCreating: Bool
    ) {
        self.planManager = planManager
        self.unitOfWork = unitOfWork
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: planManager.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: planManager.email ?? "")
        
        Task {
            await Task.yield()
            await loadAllDetails()
        }
    }
    
    // MARK: - Data Loading
    func loadAllDetails() async {
        await MainActor.run { self.isLoading = true }
        await Task.yield()
        defer { Task { @MainActor in self.isLoading = false } }
        
        editableBusinessName = planManager.name
        editableAbn = planManager.abn
        phoneFormatter.phoneNumber = planManager.phone ?? ""
        emailValidator.email = planManager.email ?? ""
        loadAddressDetails()
        let managedClients = await fetchManagedClients()
        await fetchRelatedInvoices(for: managedClients)
    }

    func loadAddressDetails() {
        if let address = planManager.address {
            editableUnitNumber = address.unitNumber
            editableStreetNumber = address.streetNumber
            editableStreetName = address.streetName
            editableSuburb = address.suburb
            editableCity = address.city
            editablePostcode = address.postcode
            editableState = address.state
            editableCountry = address.country.isEmpty ? "Australia" : address.country
            editablePoBox = address.poBox
        } else {
            editableUnitNumber = ""
            editableStreetNumber = ""
            editableStreetName = ""
            editableSuburb = ""
            editableCity = ""
            editablePostcode = ""
            editableState = ""
            editableCountry = "Australia"
            editablePoBox = ""
        }
    }
    
    private func fetchManagedClients() async -> [Client] {
        do {
            let clients = try await unitOfWork.clients.fetch(byPlanManagerId: planManager.id)
            await MainActor.run {
                self.managedClients = clients
            }
            return clients
        } catch {
            print("❌ [PlanManagerDetailViewModel] Error fetching managed clients: \(error)")
            await MainActor.run {
                self.managedClients = []
            }
            return []
        }
    }
    
    private func fetchRelatedInvoices(for clients: [Client]) async {
        do {
            // Fetch invoices from managed clients
            var clientInvoices: [Invoice] = []
            for client in clients {
                let clientInvoiceList = try await unitOfWork.invoices.fetch(byClientId: client.id)
                clientInvoices.append(contentsOf: clientInvoiceList)
                await Task.yield()
            }
            
            let sorted = await Task.detached {
                let uniqueInvoices = Array(Set(clientInvoices))
                return uniqueInvoices.sorted { $0.issueDate > $1.issueDate }
            }.value
            await MainActor.run {
                self.relatedInvoices = sorted
            }
        } catch {
            print("❌ [PlanManagerDetailViewModel] Error fetching related invoices: \(error)")
            await MainActor.run {
                self.relatedInvoices = []
            }
        }
    }
    
    // MARK: - Save & Update Logic
    
    func updateAndSavePlanManager() {
        Task {
            await savePlanManagerUpdates()
        }
    }
    
    func createPlanManagerAndDismiss() {
        let trimmedBusinessName = editableBusinessName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBusinessName.isEmpty {
            businessNameError = "Business Name cannot be empty."
            return
        }
        
        if !isValidABN(editableAbn) {
            abnError = "Invalid ABN. Must be 11 digits."
            showAlert = true
            alertTitle = "Validation Error"
            alertMessage = abnError ?? "Invalid ABN"
            return
        }
        
        if !emailValidator.email.isEmpty && !emailValidator.isValid {
            alertTitle = "Validation Error"
            alertMessage = "Invalid email address."
            showAlert = true
            return
        }
        
        Task {
            await createNewPlanManager()
            dismiss()
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
        
        // Create address from editable fields if address is being edited
        let addressToSave: Address?
        if isEditingAddress || !editableStreetName.isEmpty || !editableStreetNumber.isEmpty {
            let addressId = planManager.address?.id ?? UUID()
            addressToSave = Address(
                id: addressId,
                unitNumber: editableUnitNumber,
                streetNumber: editableStreetNumber,
                streetName: editableStreetName,
                suburb: editableSuburb,
                city: editableCity,
                state: editableState,
                postcode: editablePostcode,
                country: editableCountry.isEmpty ? "Australia" : editableCountry,
                poBox: editablePoBox,
                latitude: planManager.address?.latitude ?? 0.0,
                longitude: planManager.address?.longitude ?? 0.0
            )
        } else {
            addressToSave = planManager.address
        }
        
        // Create updated plan manager domain model
        let updatedPlanManager = PlanManager(
            id: planManager.id,
            name: trimmedBusinessName,
            email: emailValidator.isValid ? emailValidator.email : planManager.email,
            phone: phoneFormatter.isValid ? phoneFormatter.phoneNumber : planManager.phone,
            address: addressToSave,
            abn: editableAbn
        )
        
        do {
            let savedPlanManager = try await unitOfWork.planManagers.update(updatedPlanManager)
            planManager = savedPlanManager
            let managedClients = await fetchManagedClients()
            await fetchRelatedInvoices(for: managedClients)
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save changes: \(nsError.localizedDescription)"
            showAlert = true
        }
    }
    
    private func createNewPlanManager() async {
        // Create address from editable fields if any address data exists
        let address: Address?
        if !editableStreetName.isEmpty || !editableStreetNumber.isEmpty || !editableSuburb.isEmpty || !editableCity.isEmpty {
            address = Address(
                id: UUID(),
                unitNumber: editableUnitNumber,
                streetNumber: editableStreetNumber,
                streetName: editableStreetName,
                suburb: editableSuburb,
                city: editableCity,
                state: editableState,
                postcode: editablePostcode,
                country: editableCountry.isEmpty ? "Australia" : editableCountry,
                poBox: editablePoBox,
                latitude: 0.0,
                longitude: 0.0
            )
        } else {
            address = nil
        }
        
        // Create new plan manager domain model
        let newPlanManager = PlanManager(
            id: UUID(),
            name: editableBusinessName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: emailValidator.email.isEmpty ? nil : emailValidator.email,
            phone: phoneFormatter.phoneNumber.isEmpty ? nil : phoneFormatter.phoneNumber,
            address: address,
            abn: editableAbn
        )
        
        do {
            let savedPlanManager = try await unitOfWork.planManagers.create(newPlanManager)
            planManager = savedPlanManager
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save plan manager: \(nsError.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Address Logic
    func commitAddressChanges(autosave: Bool = true) {
        // Create or update Address domain model from editable fields
        let addressId = planManager.address?.id ?? UUID()
        let updatedAddress = Address(
            id: addressId,
            unitNumber: editableUnitNumber,
            streetNumber: editableStreetNumber,
            streetName: editableStreetName,
            suburb: editableSuburb,
            city: editableCity,
            state: editableState,
            postcode: editablePostcode,
            country: editableCountry.isEmpty ? "Australia" : editableCountry,
            poBox: editablePoBox,
            latitude: planManager.address?.latitude ?? 0.0,
            longitude: planManager.address?.longitude ?? 0.0
        )
        
        // Update plan manager with new address
        let updatedPlanManager = PlanManager(
            id: planManager.id,
            name: planManager.name,
            email: planManager.email,
            phone: planManager.phone,
            address: updatedAddress,
            abn: planManager.abn
        )
        
        planManager = updatedPlanManager
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
    
    func openInMaps() {
        guard let address = planManager.address else { return }
        let query = address.fullFormattedAddress
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "maps://?q=\(encodedQuery)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Plan Manager Actions
    func confirmDeletePlanManager() {
        self.showDeleteAlert = true
    }
    
    func deletePlanManagerAndDismiss() {
        Task {
            do {
                try await unitOfWork.planManagers.delete(id: planManager.id)
                dismiss()
            } catch {
                let nsError = error as NSError
                alertTitle = "Delete Error"
                alertMessage = "Could not delete plan manager: \(nsError.localizedDescription)"
                showAlert = true
            }
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
