import SwiftUI
import AppKit
import MapKit
import SwiftData
import Combine
import Core
import Data
import SharedUI

@MainActor
public class ClientDetailViewModel: ObservableObject {
    
    // MARK: - Core Dependencies
    private let unitOfWork: UnitOfWorkService
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    @Published private(set) var client: Client
    let isCreatingNew: Bool

    // Editable Client Properties
    @Published var editableFullName: String = ""
    @Published var editableNdisNumber: String = ""
    @Published var editableStatus: String = "Active"
    @Published var editableColor: NSColor = .systemBlue // Using system color instead of hex
    @Published var editableIsMinor: Bool = false
    @Published var editableHasNdisPlan: Bool = false
    @Published var editablePlanManagementType: String? = nil
    @Published var editableCreditAmountString: String = "0.00"
    @Published var editableBillingAuthority: BillingAuthority = .client
    @Published var editableNotes: String = ""

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

    // Services Management (Domain Models)
    @Published var clientServices: [ClientService] = []
    @Published var serviceToEdit: ClientService?
    @Published var ndisItemForNewService: NDISItem?
    @Published var serviceToDelete: ClientService?
    @Published var isCreatingCustomService: Bool = false
    @Published var availableNDISItems: [NDISItem] = []
    @Published var serviceAgreements: [ServiceAgreement] = []
    @Published var serviceAgreementToEdit: ServiceAgreement?
    @Published var isPresentingServiceAgreementSheet: Bool = false
    @Published var serviceAgreementValidationError: String?

    // UI State
    @Published var isPresentingServiceAssignmentSheet = false
    @Published var isPresentingServiceBulkEditor = false
    @Published var isPresentingServiceEditor = false
    @Published var showDeleteServiceAlert = false
    @Published var showDeleteClientAlert = false
    @Published var isEditingAddress: Bool = false
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    // Bulk Editing
    @Published var serviceTemplates: [ClientServiceTemplate] = []
    
    // Data for Pickers (Domain Models)
    @Published var allPayees: [Payee] = []
    @Published var allPlanManagers: [PlanManager] = []
    let clientStatuses = ["Active", "Inactive", "Archived"]

    // Invoices (Domain Models)
    @Published var relatedInvoices: [Invoice] = []
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer
    public init(
        client: Client,
        unitOfWork: UnitOfWorkService,
        isCreating: Bool
    ) {
        self.client = client
        self.unitOfWork = unitOfWork
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: client.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: client.email ?? "")
        
        // Initialize selected payee and plan manager from client
        selectedPayee = client.payee
        selectedPlanManager = client.planManager
        
        Task {
            await Task.yield()
            await loadAllDetails()
        }
        
        // Set up notification observer for reopening service assignment sheet
        NotificationCenter.default.publisher(for: .reopenServiceAssignmentSheet)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isPresentingServiceAssignmentSheet = true
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadAllDetails() async {
        await MainActor.run { self.isLoading = true }
        await Task.yield()
        defer { Task { @MainActor in self.isLoading = false } }
        
        loadClientDetails()
        loadAddressDetails()
        async let servicesTask = fetchClientServices()
        async let ndisItemsTask = fetchAvailableNDISItems()
        async let pickersTask = fetchPickerData()
        async let invoicesTask = fetchRelatedInvoices()
        async let agreementsTask = fetchServiceAgreements()
        _ = await (servicesTask, ndisItemsTask, pickersTask, invoicesTask, agreementsTask)
    }

    func loadClientDetails() {
        editableFullName = client.fullName
        editableNdisNumber = client.ndisNumber
        editableStatus = client.status
        // Use deterministic color based on client ID instead of stored hex color
        editableColor = NSColor(ColorSystem.Client.color(for: client.id))
        editableIsMinor = client.isMinor
        editableHasNdisPlan = client.hasNdisPlan
        editablePlanManagementType = client.planManagementType
        editableCreditAmountString = String(format: "%.2f", client.creditAmount)
        if let authority = client.billingAuthority {
            editableBillingAuthority = BillingAuthority(rawValue: authority) ?? .client
        }
        editableNotes = client.notes ?? ""
        phoneFormatter.phoneNumber = client.phone ?? ""
        emailValidator.email = client.email ?? ""
    }

    func loadAddressDetails() {
        if let address = client.address {
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
    
    private func fetchClientServices() async {
        do {
            let services = try await unitOfWork.clientServices.fetch(for: client.id)
            let sorted = await Task.detached { services.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) } }.value
            await MainActor.run {
                self.clientServices = sorted
            }
        } catch {
            print("❌ [ClientDetailViewModel] Error fetching client services: \(error)")
            await MainActor.run {
                self.clientServices = []
            }
        }
    }

    var assignedNDISItems: [NDISItem] {
        // Extract unique NDIS item IDs from client services and fetch them
        let ndisItemIds = Set(clientServices.compactMap { $0.ndisItemId })
        // Note: This would ideally be async, but computed properties can't be async
        // The actual fetching would need to happen in a method that updates a @Published property
        // For now, return empty array - call fetchAssignedNDISItems() to populate
        return []
    }
    
    func fetchAssignedNDISItems() async -> [NDISItem] {
        let ndisItemIds = Set(clientServices.compactMap { $0.ndisItemId })
        var items: [NDISItem] = []
        
        for id in ndisItemIds {
            if let item = try? await unitOfWork.ndisItems.fetch(by: id) {
                items.append(item)
            }
        }
        
        return items
    }

    private func fetchAvailableNDISItems() async {
        do {
            // Fetch effective NDIS items using repository
            let fetchedItems = try await unitOfWork.ndisItems.fetchEffective()
            let processed = await Task.detached {
                // Deduplicate items by itemNumber and name, keeping the most recent version
                let deduplicated = await Self.deduplicateCurrentItems(
                    fetchedItems
                )
                
                // Sort by item number, then by name
                return deduplicated.sorted { lhs, rhs in
                    let numberComparison = lhs.itemNumber.localizedCaseInsensitiveCompare(rhs.itemNumber)
                    if numberComparison == .orderedSame {
                        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                    }
                    return numberComparison == .orderedAscending
                }
            }.value
            await MainActor.run {
                self.availableNDISItems = processed
            }
        } catch {
            print("❌ [ClientDetailViewModel] Failed to fetch NDIS items: \(error)")
            await MainActor.run {
                self.availableNDISItems = []
            }
        }
    }
    
    private func fetchPickerData() async {
        do {
            // Fetch all payees and plan managers using repositories
            // Capture on MainActor to avoid isolation issues in child tasks
            let payeesRepo = unitOfWork.payees
            let managersRepo = unitOfWork.planManagers

            async let payeesTask = payeesRepo.fetchAll()
            async let managersTask = managersRepo.fetchAll()
            
            let payees = try await payeesTask
            let managers = try await managersTask
            await MainActor.run {
                self.allPayees = payees
                self.allPlanManagers = managers
            }
        } catch {
            print("❌ [ClientDetailViewModel] Failed to fetch picker data: \(error)")
            await MainActor.run {
                self.allPayees = []
                self.allPlanManagers = []
            }
        }
    }

    private static func deduplicateCurrentItems(_ items: [NDISItem]) -> [NDISItem] {
        var itemsDict: [String: NDISItem] = [:]

        for item in items {
            let key = "\(item.itemNumber)|\(item.name)"

            if let existing = itemsDict[key] {
                let itemStart = item.effectiveStartDate ?? .distantPast
                let existingStart = existing.effectiveStartDate ?? .distantPast
                if itemStart > existingStart {
                    itemsDict[key] = item
                }
            } else {
                itemsDict[key] = item
            }
        }

        return Array(itemsDict.values)
    }
    
    func fetchRelatedInvoices() async {
        do {
            let invoices = try await unitOfWork.invoices.fetch(byClientId: client.id)
            let sorted = await Task.detached {
                invoices.sorted { $0.issueDate > $1.issueDate }
            }.value
            await MainActor.run {
                self.relatedInvoices = sorted
            }
        } catch {
            print("❌ [ClientDetailViewModel] Error fetching related invoices: \(error)")
            await MainActor.run {
                self.relatedInvoices = []
            }
        }
    }

    private func fetchServiceAgreements() async {
        do {
            let agreements = try await unitOfWork.serviceAgreements.fetchByClient(client.id, includeArchived: true)
            await MainActor.run {
                self.serviceAgreements = agreements.sorted { $0.effectiveFrom > $1.effectiveFrom }
            }
        } catch {
            print("❌ [ClientDetailViewModel] Error fetching service agreements: \(error)")
            await MainActor.run {
                self.serviceAgreements = []
            }
        }
    }
    
    // MARK: - Save & Update Logic
    
    func updateAndSaveClient() {
        // This function is for changes that should be saved immediately
        // For example, from an `onChange` modifier.
        // It bypasses the main "Create" button validation logic.
        guard !isCreatingNew else { return }
        
        Task {
            await saveClientUpdates()
        }
    }
    
    private func saveClientUpdates() async {
        // Create updated client domain model from editable properties
        let updatedClient = Client(
            id: client.id,
            ndisNumber: editableNdisNumber,
            fullName: editableFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            status: editableStatus,
            email: emailValidator.isValid ? emailValidator.email : client.email,
            notes: editableNotes.isEmpty ? nil : editableNotes,
            phone: phoneFormatter.isValid ? phoneFormatter.phoneNumber : client.phone,
            creditAmount: Double(editableCreditAmountString) ?? client.creditAmount,
            isMinor: editableIsMinor,
            hasNdisPlan: editableHasNdisPlan,
            planManagementType: editablePlanManagementType,
            billingAuthority: editableBillingAuthority.rawValue,
            address: {
                // Create address from editable fields if address is being edited
                if isEditingAddress || !editableStreetName.isEmpty || !editableStreetNumber.isEmpty {
                    let addressId = client.address?.id ?? UUID()
                    return Address(
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
                        latitude: client.address?.latitude ?? 0.0,
                        longitude: client.address?.longitude ?? 0.0
                    )
                } else {
                    return client.address
                }
            }(),
            planManager: selectedPlanManager,
            payee: selectedPayee,
            sendInvoicesToClient: client.sendInvoicesToClient,
            sendInvoicesToPayee: client.sendInvoicesToPayee,
            sendInvoicesToPlanManager: client.sendInvoicesToPlanManager
        )
        
        do {
            let savedClient = try await unitOfWork.clients.update(updatedClient)
            client = savedClient
            // Update selected references
            selectedPlanManager = savedClient.planManager
            selectedPayee = savedClient.payee
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save changes: \(nsError.localizedDescription)"
            showAlert = true
        }
    }
    
    func updateAndSaveClientToggle(
        sendInvoicesToClient: Bool? = nil,
        sendInvoicesToPayee: Bool? = nil,
        sendInvoicesToPlanManager: Bool? = nil
    ) {
        var updatedClient = client
        if let toClient = sendInvoicesToClient { updatedClient.sendInvoicesToClient = toClient }
        if let toPayee = sendInvoicesToPayee { updatedClient.sendInvoicesToPayee = toPayee }
        if let toPlanManager = sendInvoicesToPlanManager { updatedClient.sendInvoicesToPlanManager = toPlanManager }
        
        Task {
            do {
                let savedClient = try await unitOfWork.clients.update(updatedClient)
                await MainActor.run {
                    self.client = savedClient
                }
            } catch {
                print("❌ [ClientDetailViewModel] Error updating client toggles: \(error)")
            }
        }
    }
    
    // MARK: - Payee and Plan Manager Selection
    
    @Published var selectedPayee: Payee?
    @Published var selectedPlanManager: PlanManager?
    
    func updatePayee(by id: UUID?) {
        Task {
            if let id = id {
                selectedPayee = try? await unitOfWork.payees.fetch(by: id)
            } else {
                selectedPayee = nil
            }
            // Save client update
            await saveClientUpdates()
        }
    }
    
    func updatePlanManager(by id: UUID?) {
        Task {
            if let id = id {
                selectedPlanManager = try? await unitOfWork.planManagers.fetch(by: id)
            } else {
                selectedPlanManager = nil
            }
            // Save client update
            await saveClientUpdates()
        }
    }

    func saveClientDetailsAndDismiss() {
        // This is for the main "Create" button.
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
            if isCreatingNew {
                await createNewClient()
            } else {
                await saveClientUpdates()
            }
            
            if isCreatingNew {
                dismiss()
            }
        }
    }
    
    private func createNewClient() async {
        // Create new client domain model
        let newClient = Client(
            id: UUID(),
            ndisNumber: editableNdisNumber,
            fullName: editableFullName.trimmingCharacters(in: .whitespacesAndNewlines),
            status: editableStatus,
            email: emailValidator.isValid ? emailValidator.email : nil,
            notes: editableNotes.isEmpty ? nil : editableNotes,
            phone: phoneFormatter.isValid ? phoneFormatter.phoneNumber : nil,
            creditAmount: Double(editableCreditAmountString) ?? 0.0,
            isMinor: editableIsMinor,
            hasNdisPlan: editableHasNdisPlan,
            planManagementType: editablePlanManagementType,
            billingAuthority: editableBillingAuthority.rawValue,
            address: {
                // Create address from editable fields if any address data exists
                if !editableStreetName.isEmpty || !editableStreetNumber.isEmpty || !editableSuburb.isEmpty || !editableCity.isEmpty {
                    return Address(
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
                    return nil
                }
            }(),
            planManager: selectedPlanManager,
            payee: selectedPayee,
            sendInvoicesToClient: nil,
            sendInvoicesToPayee: nil,
            sendInvoicesToPlanManager: nil
        )
        
        do {
            let savedClient = try await unitOfWork.clients.create(newClient)
            client = savedClient
            // Update selected references
            selectedPlanManager = savedClient.planManager
            selectedPayee = savedClient.payee
            // Address is now committed through commitAddressChanges() when editing
        } catch {
            let nsError = error as NSError
            alertTitle = "Save Error"
            alertMessage = "Could not save client: \(nsError.localizedDescription)"
            showAlert = true
        }
    }
    
    // MARK: - Address Logic
    func commitAddressChanges() {
        // Create or update Address domain model from editable fields
        let addressId = client.address?.id ?? UUID()
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
            latitude: client.address?.latitude ?? 0.0,
            longitude: client.address?.longitude ?? 0.0
        )
        
        // Update client with new address
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
            address: updatedAddress,
            planManager: client.planManager,
            payee: client.payee,
            sendInvoicesToClient: client.sendInvoicesToClient,
            sendInvoicesToPayee: client.sendInvoicesToPayee,
            sendInvoicesToPlanManager: client.sendInvoicesToPlanManager
        )
        
        client = updatedClient
        
        // Save changes
        Task {
            await saveClientUpdates()
        }
        isEditingAddress = false
        
    }
    
    func formattedAddressString(from address: Address) -> String {
        return address.fullFormattedAddress
    }
    
    func openInMaps() {
        guard let address = client.address else { return }
        let query = formattedAddressString(from: address)
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
           let url = URL(string: "maps://?q=\(encodedQuery)") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Service Agreement Actions
    func prepareToAddServiceAgreement() {
        serviceAgreementValidationError = nil
        serviceAgreementToEdit = ServiceAgreement(
            id: UUID(),
            clientId: client.id,
            effectiveFrom: Date(),
            effectiveTo: nil,
            pricingDisclosureAcceptedAt: nil,
            cancellationPolicyType: CancellationPolicyType.twoClearBusinessDays.rawValue,
            allowsProviderTravel: false,
            allowsTelehealth: false,
            allowsNonFaceToFace: false,
            participantSignatoryName: nil,
            participantSignatoryRole: nil,
            signedAt: nil,
            signatureMethod: SignatureMethod.attestation.rawValue,
            notes: nil,
            isArchived: false
        )
        isPresentingServiceAgreementSheet = true
    }

    func prepareToEditServiceAgreement(_ agreement: ServiceAgreement) {
        serviceAgreementValidationError = nil
        serviceAgreementToEdit = agreement
        isPresentingServiceAgreementSheet = true
    }

    func cancelServiceAgreementEdit() {
        serviceAgreementValidationError = nil
        serviceAgreementToEdit = nil
        isPresentingServiceAgreementSheet = false
    }

    func saveServiceAgreement() {
        guard let agreement = serviceAgreementToEdit else { return }
        serviceAgreementValidationError = nil

        Task {
            do {
                let hasOverlap = try await unitOfWork.serviceAgreements.hasOverlap(
                    clientId: client.id,
                    effectiveFrom: agreement.effectiveFrom,
                    effectiveTo: agreement.effectiveTo,
                    excluding: serviceAgreements.contains(where: { $0.id == agreement.id }) ? agreement.id : nil
                )
                if hasOverlap {
                    await MainActor.run {
                        self.serviceAgreementValidationError = "Agreement dates overlap with an existing active agreement."
                    }
                    return
                }

                if serviceAgreements.contains(where: { $0.id == agreement.id }) {
                    _ = try await unitOfWork.serviceAgreements.update(agreement)
                } else {
                    _ = try await unitOfWork.serviceAgreements.create(agreement)
                }

                await fetchServiceAgreements()
                await MainActor.run {
                    self.serviceAgreementToEdit = nil
                    self.isPresentingServiceAgreementSheet = false
                    self.serviceAgreementValidationError = nil
                }
            } catch {
                await MainActor.run {
                    self.serviceAgreementValidationError = error.localizedDescription
                }
            }
        }
    }

    func archiveServiceAgreement(_ agreement: ServiceAgreement) {
        Task {
            do {
                try await unitOfWork.serviceAgreements.archive(id: agreement.id)
                await fetchServiceAgreements()
            } catch {
                print("❌ [ClientDetailViewModel] Error archiving agreement: \(error)")
            }
        }
    }

    // MARK: - Service Actions
    func saveService() {
        guard let serviceToSave = serviceToEdit else { return }
        
        Task {
            do {
                // Create or update service using repository
                let savedService: ClientService
                if let existingId = clientServices.first(where: { $0.id == serviceToSave.id })?.id {
                    // Update existing service
                    savedService = try await unitOfWork.clientServices.update(serviceToSave)
                } else {
                    // Create new service
                    savedService = try await unitOfWork.clientServices.create(serviceToSave)
                }
                
                // Refresh services list
                await fetchClientServices()
                
                serviceToEdit = nil
                ndisItemForNewService = nil
                isCreatingCustomService = false
                isPresentingServiceEditor = false
            } catch {
                print("❌ [ClientDetailViewModel] Error saving service: \(error)")
                alertTitle = "Save Error"
                alertMessage = "Could not save service: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    // MARK: - Validation Functions
    private func validateAndFixNDISItemRelationship(_ service: inout ClientService, ndisItem: NDISItem) {
        // Ensure NDIS code is set from the NDIS item
        if service.ndisCode != ndisItem.itemNumber {
            service = ClientService(
                id: service.id,
                clientId: service.clientId,
                serviceName: service.serviceName,
                rate: service.rate,
                unit: service.unit,
                status: service.status,
                isActive: service.isActive,
                startDate: service.startDate,
                endDate: service.endDate,
                ndisItemId: ndisItem.id,
                ndisCode: ndisItem.itemNumber
            )
        }
        
        // Ensure service name matches NDIS item name if not customized
        if service.serviceName.isEmpty || service.serviceName == "New Service" {
            service = ClientService(
                id: service.id,
                clientId: service.clientId,
                serviceName: ndisItem.name,
                rate: service.rate,
                unit: service.unit,
                status: service.status,
                isActive: service.isActive,
                startDate: service.startDate,
                endDate: service.endDate,
                ndisItemId: service.ndisItemId,
                ndisCode: service.ndisCode
            )
        }
        
        // Ensure unit matches NDIS item unit if not customized
        if service.unit.isEmpty || service.unit == "hour" {
            service = ClientService(
                id: service.id,
                clientId: service.clientId,
                serviceName: service.serviceName,
                rate: service.rate,
                unit: ndisItem.unit ?? "hour",
                status: service.status,
                isActive: service.isActive,
                startDate: service.startDate,
                endDate: service.endDate,
                ndisItemId: service.ndisItemId,
                ndisCode: service.ndisCode
            )
        }
    }

    func prepareToAddNewService(from ndisItem: NDISItem) {
        // Find a default price. This is a simple approach.
        // A more complex app might use a setting for the user's region.
        let remotePrice = ndisItem.regionalPrices.first
        let defaultRate = remotePrice?.amount ?? (ndisItem.price ?? 0.0)
        
        var newService = ClientService(
            id: UUID(),
            clientId: client.id,
            serviceName: ndisItem.name,
            rate: defaultRate,
            unit: ndisItem.unit ?? "hour",
            status: nil,
            isActive: true,
            startDate: Date(),
            endDate: nil,
            ndisItemId: ndisItem.id,
            ndisCode: ndisItem.itemNumber
        )
        
        // Validate and fix NDIS item relationship
        validateAndFixNDISItemRelationship(&newService, ndisItem: ndisItem)
        
        ndisItemForNewService = ndisItem
        serviceToEdit = newService
        isCreatingCustomService = false
        
        // This will trigger the editor sheet
        isPresentingServiceEditor = true
    }

    func prepareToAddCustomService() {
        let newService = ClientService(
            id: UUID(),
            clientId: client.id,
            serviceName: "",
            rate: 0.0,
            unit: "hour",
            status: nil,
            isActive: true,
            startDate: Date(),
            endDate: nil,
            ndisItemId: nil,
            ndisCode: nil
        )
        
        serviceToEdit = newService
        ndisItemForNewService = nil
        isCreatingCustomService = true
        
        // This will trigger the editor sheet
        isPresentingServiceEditor = true
    }

    func assignServices(from ndisItems: [NDISItem]) {
        Task {
            do {
                for item in ndisItems {
                    // Find a default price
                    let remotePrice = item.regionalPrices.first
                    let defaultRate = remotePrice?.amount ?? (item.price ?? 0.0)
                    
                    var newService = ClientService(
                        id: UUID(),
                        clientId: client.id,
                        serviceName: item.name,
                        rate: defaultRate,
                        unit: item.unit ?? "hour",
                        status: nil,
                        isActive: true,
                        startDate: Date(),
                        endDate: nil,
                        ndisItemId: item.id,
                        ndisCode: item.itemNumber
                    )
                    
                    // Validate and fix NDIS item relationship
                    validateAndFixNDISItemRelationship(&newService, ndisItem: item)
                    
                    // Create service using repository
                    _ = try await unitOfWork.clientServices.create(newService)
                }
                
                // Refresh services list
                await fetchClientServices()
            } catch {
                print("❌ [ClientDetailViewModel] Error assigning services: \(error)")
                alertTitle = "Save Error"
                alertMessage = "Could not assign services: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func prepareForBulkServiceCreation(from ndisItems: [NDISItem]) {
        // Create new templates only for items that don't already exist in serviceTemplates
        let existingSourceItemIDs = Set(serviceTemplates.map { $0.sourceNdisItem.id })
        
        let newTemplates = ndisItems
            .filter { !existingSourceItemIDs.contains($0.id) }
            .map { ClientServiceTemplate(from: $0) }
        
        // Append new templates to existing ones
        serviceTemplates.append(contentsOf: newTemplates)
        
        self.isPresentingServiceBulkEditor = true
    }

    func commitServices(fromTemplates templates: [ClientServiceTemplate]) {
        Task {
            do {
                for template in templates {
                    var newService = ClientService(
                        id: UUID(),
                        clientId: client.id,
                        serviceName: template.serviceName,
                        rate: template.rate,
                        unit: template.unit,
                        status: nil,
                        isActive: true,
                        startDate: Date(),
                        endDate: nil,
                        ndisItemId: template.sourceNdisItem.id,
                        ndisCode: template.ndisCode
                    )
                    
                    // Validate and fix NDIS item relationship
                    validateAndFixNDISItemRelationship(&newService, ndisItem: template.sourceNdisItem)
                    
                    // Create service using repository
                    _ = try await unitOfWork.clientServices.create(newService)
                }
                
                // Refresh services list
                await fetchClientServices()
            } catch {
                print("❌ [ClientDetailViewModel] Error committing services: \(error)")
                alertTitle = "Save Error"
                alertMessage = "Could not save services: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    func prepareToEditService(_ service: ClientService) {
        serviceToEdit = service
        
        // Fetch NDISItem if the service has an NDIS item ID
        if let ndisItemId = service.ndisItemId {
            Task {
                ndisItemForNewService = try? await unitOfWork.ndisItems.fetch(by: ndisItemId)
            }
        } else {
            ndisItemForNewService = nil
        }
        
        isPresentingServiceEditor = true
    }
    
    func cancelServiceEdit() {
        serviceToEdit = nil
        ndisItemForNewService = nil
        isPresentingServiceEditor = false
    }

    func confirmDeleteService(_ service: ClientService) {
        self.serviceToDelete = service
        self.showDeleteServiceAlert = true
    }
    
    func deleteService() {
        guard let service = serviceToDelete else { return }
        
        Task {
            do {
                try await unitOfWork.clientServices.delete(id: service.id)
                await fetchClientServices()
                
                serviceToDelete = nil
                showDeleteServiceAlert = false
            } catch {
                print("❌ [ClientDetailViewModel] Error deleting service: \(error)")
                alertTitle = "Delete Error"
                alertMessage = "Could not delete service: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    func toggleActiveStatus(for service: ClientService) {
        let updatedService = ClientService(
            id: service.id,
            clientId: service.clientId,
            serviceName: service.serviceName,
            rate: service.rate,
            unit: service.unit,
            status: service.status,
            isActive: !service.isActive,
            startDate: service.startDate,
            endDate: service.endDate,
            ndisItemId: service.ndisItemId,
            ndisCode: service.ndisCode
        )
        
        Task {
            do {
                _ = try await unitOfWork.clientServices.update(updatedService)
                await fetchClientServices()
            } catch {
                print("❌ [ClientDetailViewModel] Error toggling service status: \(error)")
                alertTitle = "Update Error"
                alertMessage = "Could not update service: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }

    // MARK: - Client Actions
    func confirmDeleteClient() {
        showDeleteClientAlert = true
    }
    
    func deleteClientAndDismiss() {
        Task {
            do {
                try await unitOfWork.clients.delete(id: client.id)
                dismiss()
            } catch {
                print("❌ [ClientDetailViewModel] Error deleting client: \(error)")
                alertTitle = "Delete Error"
                alertMessage = "Could not delete client: \(error.localizedDescription)"
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
} 
