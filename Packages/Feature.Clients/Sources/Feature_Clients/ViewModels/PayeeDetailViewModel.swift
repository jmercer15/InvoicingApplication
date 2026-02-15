import SwiftUI
import AppKit
import MapKit
import SwiftData
import Core
import Data
import SharedUI

@MainActor
public class PayeeDetailViewModel: ObservableObject {
    
    // MARK: - Core Dependencies
    private let unitOfWork: UnitOfWorkService
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    @Published private(set) var payee: Payee
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
    @Published var editableCity: String = ""
    @Published var editablePostcode: String = ""
    @Published var editableState: String = ""
    @Published var editableCountry: String = ""
    @Published var editablePoBox: String = ""
    @Published var addressSearchText: String = ""
    @Published var selectedSearchAddress: AddressData?

    // Associated Clients (Domain Models)
    @Published var associatedClients: [Client] = []
    @Published var selectedClientIDs: Set<UUID> = []
    
    // Data for Pickers (Domain Models)
    @Published var allClients: [Client] = []
    let payeeStatuses = ["Active", "Inactive", "Archived"]

    // Invoices (Domain Models)
    @Published var relatedInvoices: [Invoice] = []

    // UI State
    @Published var isEditingAddress: Bool = false
    @Published var showDeleteAlert = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    @Published var showingClientSelector = false
    @Published var isLoading: Bool = false

    // MARK: - Initializer
    // MARK: - Initializer
    public init(
        payee: Payee,
        unitOfWork: UnitOfWorkService,
        isCreating: Bool
    ) {
        self.payee = payee
        self.unitOfWork = unitOfWork
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: payee.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: payee.email ?? "")
        
        Task {
            await Task.yield()
            await loadAllDetails()
        }
    }
    
    // MARK: - Data Loading
    private func loadAllDetails() async {
        await MainActor.run { self.isLoading = true }
        await Task.yield()
        defer { Task { @MainActor in self.isLoading = false } }
        
        self.editableFullName = payee.fullName
        self.editableStatus = payee.status ?? "Active"
        // colorHex property removed - using deterministic color system instead
        // notes property removed from Payee - no longer supported
        self.editableRelationToClient = payee.relationToClient ?? ""
        self.phoneFormatter.phoneNumber = payee.phone ?? ""
        self.emailValidator.email = payee.email ?? ""
        loadAddressDetails()
        async let allClientsTask = fetchAllClients()
        let associatedClients = await fetchAssociatedClients()
        _ = await allClientsTask
        await fetchRelatedInvoices(for: associatedClients)
    }

    private func fetchRelatedInvoices(for clients: [Client]) async {
        do {
            // Fetch invoices from associated clients (payee-related invoices are stored as snapshots in invoices)
            var clientInvoices: [Invoice] = []
            for client in clients {
                let clientInvoiceList = try await unitOfWork.invoices.fetch(byClientId: client.id)
                clientInvoices.append(contentsOf: clientInvoiceList)
                await Task.yield()
            }
            
            let payeeId = payee.id
            let payeeName = payee.fullName
            let sorted = await Task.detached {
                let filtered = clientInvoices.filter { invoice in
                    invoice.payeeId == payeeId || invoice.payeeName == payeeName
                }
                let uniqueInvoices = Array(Set(filtered))
                return uniqueInvoices.sorted { $0.issueDate > $1.issueDate }
            }.value
            await MainActor.run {
                self.relatedInvoices = sorted
            }
        } catch {
            print("❌ [PayeeDetailViewModel] Error fetching related invoices: \(error)")
            await MainActor.run {
                self.relatedInvoices = []
            }
        }
    }

    func loadAddressDetails() {
        if let address = payee.address {
            self.editableUnitNumber = address.unitNumber
            self.editableStreetNumber = address.streetNumber
            self.editableStreetName = address.streetName
            self.editableSuburb = address.suburb
            self.editableCity = address.city
            self.editablePostcode = address.postcode
            self.editableState = address.state
            self.editableCountry = address.country.isEmpty ? "Australia" : address.country
            self.editablePoBox = address.poBox
        } else {
            self.editableUnitNumber = ""
            self.editableStreetNumber = ""
            self.editableStreetName = ""
            self.editableSuburb = ""
            self.editableCity = ""
            self.editablePostcode = ""
            self.editableState = ""
            self.editableCountry = "Australia"
            self.editablePoBox = ""
        }
    }
    
    private func fetchAssociatedClients() async -> [Client] {
        do {
            let clients = try await unitOfWork.clients.fetch(byPayeeId: payee.id)
            let sorted = await Task.detached {
                clients.sorted(by: { $0.fullName < $1.fullName })
            }.value
            await MainActor.run {
                self.associatedClients = sorted
                self.selectedClientIDs = Set(sorted.map { $0.id })
            }
            return sorted
        } catch {
            print("❌ [PayeeDetailViewModel] Error fetching associated clients: \(error)")
            await MainActor.run {
                self.associatedClients = []
                self.selectedClientIDs = []
            }
            return []
        }
    }
    
    private func fetchAllClients() async {
        do {
            let clients = try await unitOfWork.clients.fetchAll()
            await MainActor.run {
                self.allClients = clients
            }
        } catch {
            print("❌ [PayeeDetailViewModel] Error fetching all clients: \(error)")
            await MainActor.run {
                self.allClients = []
            }
        }
    }
    
    // MARK: - Save & Update Logic
    
    func updateAndSavePayee() {
        Task {
            await savePayeeUpdates()
        }
    }
    
    func createPayeeAndDismiss() {
        let trimmedFullName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFullName.isEmpty {
            fullNameError = "Full Name cannot be empty."
            return
        }
        
        if !emailValidator.email.isEmpty && !emailValidator.isValid {
            alertTitle = "Validation Error"
            alertMessage = "Invalid email address."
            showAlert = true
            return
        }
        
        Task {
            await createNewPayee()
            dismiss()
        }
    }
    
    private func savePayeeUpdates() async {
        // Create updated payee domain model with address from editable fields if address is being edited
        let addressToSave: Address?
        if isEditingAddress || !editableStreetName.isEmpty || !editableStreetNumber.isEmpty {
            let addressId = payee.address?.id ?? UUID()
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
                latitude: payee.address?.latitude ?? 0.0,
                longitude: payee.address?.longitude ?? 0.0
            )
        } else {
            addressToSave = payee.address
        }
        
        let updatedPayee = Payee(
            id: payee.id,
            fullName: editableFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: emailValidator.isValid ? emailValidator.email : payee.email,
            phone: phoneFormatter.isValid ? phoneFormatter.phoneNumber : payee.phone,
            address: addressToSave,
            status: editableStatus,
            relationToClient: editableRelationToClient.isEmpty ? nil : editableRelationToClient
        )
        
        do {
            let savedPayee = try await unitOfWork.payees.update(updatedPayee)
            payee = savedPayee
            // Update client associations after saving payee
            await updateClientAssociations()
            let associatedClients = await fetchAssociatedClients()
            await fetchRelatedInvoices(for: associatedClients)
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save changes: \(nsError.localizedDescription)"
            showAlert = true
        }
    }
    
    private func createNewPayee() async {
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
        
        // Create new payee domain model
        let newPayee = Payee(
            id: UUID(),
            fullName: editableFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            email: emailValidator.email.isEmpty ? nil : emailValidator.email,
            phone: phoneFormatter.phoneNumber.isEmpty ? nil : phoneFormatter.phoneNumber,
            address: address,
            status: editableStatus,
            relationToClient: editableRelationToClient.isEmpty ? nil : editableRelationToClient
        )
        
        do {
            let savedPayee = try await unitOfWork.payees.create(newPayee)
            payee = savedPayee
            // Update client associations after creating payee
            await updateClientAssociations()
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save payee: \(nsError.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Address Logic
    func commitAddressChanges(autosave: Bool = true) {
        // Create or update Address domain model from editable fields
        let addressId = payee.address?.id ?? UUID()
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
            latitude: payee.address?.latitude ?? 0.0,
            longitude: payee.address?.longitude ?? 0.0
        )
        
        // Update payee with new address
        let updatedPayee = Payee(
            id: payee.id,
            fullName: payee.fullName,
            email: payee.email,
            phone: payee.phone,
            address: updatedAddress,
            status: payee.status,
            relationToClient: payee.relationToClient
        )
        
        payee = updatedPayee
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
    
    func openInMaps() {
        guard let address = payee.address else { return }
        let query = address.fullFormattedAddress
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "maps://?q=\(encodedQuery)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Client Association
    func updateClientAssociations() async {
        // Update clients to associate them with this payee
        // We need to fetch each client and update it with the payee reference
        do {
            // Fetch all clients to update
            let allClientsToUpdate = try await unitOfWork.clients.fetchAll()
            
            for client in allClientsToUpdate {
                let shouldHavePayee = selectedClientIDs.contains(client.id)
                let currentlyHasPayee = client.payee?.id == payee.id
                
                // Only update if the association state has changed
                if shouldHavePayee != currentlyHasPayee {
                    let updatedClient = Client(
                        id: client.id,
                        ndisNumber: client.ndisNumber,
                        fullName: client.fullName,
                        status: client.status,
                        email: client.email,
                        notes: client.notes,
                        phone: client.phone,
                        creditAmount: client.creditAmount,
                        isMinor: client.isMinor,
                        hasNdisPlan: client.hasNdisPlan,
                        planManagementType: client.planManagementType,
                        billingAuthority: client.billingAuthority,
                        address: client.address,
                        planManager: client.planManager,
                        payee: shouldHavePayee ? payee : nil,
                        sendInvoicesToClient: client.sendInvoicesToClient,
                        sendInvoicesToPayee: client.sendInvoicesToPayee,
                        sendInvoicesToPlanManager: client.sendInvoicesToPlanManager
                    )
                    _ = try await unitOfWork.clients.update(updatedClient)
                }
            }
        } catch {
            print("❌ [PayeeDetailViewModel] Error updating client associations: \(error)")
            alertTitle = "Update Error"
            alertMessage = "Could not update client associations: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Payee Actions
    func confirmDeletePayee() {
        self.showDeleteAlert = true
    }
    
    func deletePayeeAndDismiss() {
        Task {
            do {
                try await unitOfWork.payees.delete(id: payee.id)
                dismiss()
            } catch {
                let nsError = error as NSError
                alertTitle = "Delete Error"
                alertMessage = "Could not delete payee: \(nsError.localizedDescription)"
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

    // MARK: - Validation
    private func validate() {
        let trimmedFullName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFullName.isEmpty {
            fullNameError = "Full Name cannot be empty."
        } else {
            fullNameError = nil
        }
    }
} 
