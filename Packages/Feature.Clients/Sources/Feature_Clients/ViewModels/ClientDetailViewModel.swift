import SwiftUI
import AppKit
import MapKit
import SwiftData
import Core
import Data
import SharedUI

class ClientDetailViewModel: ObservableObject {
    
    // MARK: - Core Dependencies
    let modelContext: ModelContext
    var dismiss: () -> Void = {}

    // MARK: - Published Properties
    @Published var client: ClientEntity
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
    @Published var editablePostcode: String = ""
    @Published var editableState: String = ""
    @Published var editableCountry: String = ""
    @Published var editablePoBox: String = ""
    @Published var addressSearchText: String = ""
    @Published var selectedSearchAddress: AddressData?

    // Services Management (Domain Models)
    @Published var clientServices: [ClientServiceEntity] = []
    @Published var serviceToEdit: ClientServiceEntity?
    @Published var ndisItemForNewService: NDISItemEntity?
    @Published var serviceToDelete: ClientServiceEntity?
    @Published var isCreatingCustomService: Bool = false
    @Published var availableNDISItems: [NDISItemEntity] = []

    // UI State
    @Published var isPresentingServiceAssignmentSheet = false
    @Published var isPresentingServiceBulkEditor = false
    @Published var isPresentingServiceEditor = false
    @Published var showDeleteServiceAlert = false
    @Published var showDeleteClientAlert = false
    @Published var isEditingAddress: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""

    // Bulk Editing
    @Published var serviceTemplates: [ClientServiceTemplate] = []
    
    // Data for Pickers (Domain Models)
    @Published var allPayees: [PayeeEntity] = []
    @Published var allPlanManagers: [PlanManagerEntity] = []
    let clientStatuses = ["Active", "Inactive", "Archived"]

    // Invoices (Domain Models)
    @Published var relatedInvoices: [InvoiceEntity] = []

    // MARK: - Initializer
    init(client: ClientEntity, context: ModelContext, isCreating: Bool) {
        self.client = client
        self.modelContext = context
        self.isCreatingNew = isCreating
        self.phoneFormatter = PhoneNumberFormatter(initialPhoneNumber: client.phone ?? "")
        self.emailValidator = EmailValidator(initialEmail: client.email ?? "")
        
        loadAllDetails()
        fetchPickerData()
        fetchRelatedInvoices()
        
        // Set up notification observer for reopening service assignment sheet
        NotificationCenter.default.addObserver(forName: .reopenServiceAssignmentSheet, object: nil, queue: .main) { [weak self] _ in
            self?.isPresentingServiceAssignmentSheet = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Data Loading
    func loadAllDetails() {
        loadClientDetails()
        loadAddressDetails()
        fetchClientServices()
        fetchAvailableNDISItems()
    }

    func loadClientDetails() {
        editableFullName = client.fullName
        editableNdisNumber = client.ndisNumber
        editableStatus = client.status.rawValue
        // Use deterministic color based on client ID instead of stored hex color
        editableColor = NSColor(ColorSystem.Client.color(for: client.id))
        editableIsMinor = client.isMinor
        editableHasNdisPlan = client.hasNdisPlan
        editablePlanManagementType = client.planManagementType
        editableCreditAmountString = String(format: "%.2f", client.creditAmount)
        if let authority = client.billingAuthority {
            editableBillingAuthority = BillingAuthority(rawValue: authority.rawValue) ?? .client
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
    
    private func fetchClientServices() {
        let services = client.clientServices
        clientServices = services.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
    }

    var assignedNDISItems: [NDISItemEntity] {
        clientServices.compactMap { $0.ndisItem }
    }

    private func fetchAvailableNDISItems() {
        let descriptor = FetchDescriptor<NDISItemEntity>(
            sortBy: [
                SortDescriptor(\.itemNumber, order: .forward),
                SortDescriptor(\.effectiveStartDate, order: .reverse)
            ])
        do {
            let fetchedItems = try modelContext.fetch(descriptor)
            let now = Date()

            let effectiveItems = fetchedItems.filter { item in
                if item.isCurrent { return true }
                let start = item.effectiveStartDate ?? .distantPast
                let end = item.effectiveEndDate ?? .distantFuture
                return start <= now && now <= end
            }

            let deduplicated = deduplicateCurrentItems(effectiveItems)
            let sorted = deduplicated.sorted { lhs, rhs in
                let numberComparison = lhs.itemNumber.localizedCaseInsensitiveCompare(rhs.itemNumber)
                if numberComparison == .orderedSame {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return numberComparison == .orderedAscending
            }

            availableNDISItems = sorted
        } catch {
            print("Failed to fetch NDIS items: \(error)")
            availableNDISItems = []
        }
    }
    
    private func fetchPickerData() { // Fetch domain models for pickers
        let payeeDescriptor = FetchDescriptor<PayeeEntity>(sortBy: [SortDescriptor(\.fullName)])
        let managerDescriptor = FetchDescriptor<PlanManagerEntity>(sortBy: [SortDescriptor(\.name)])
        do {
            allPayees = try modelContext.fetch(payeeDescriptor)
            allPlanManagers = try modelContext.fetch(managerDescriptor)
        } catch {
            print("Failed to fetch picker data: \(error)")
        }
    }

    private func deduplicateCurrentItems(_ items: [NDISItemEntity]) -> [NDISItemEntity] {
        var itemsDict: [String: NDISItemEntity] = [:]

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
    
    func fetchRelatedInvoices() {
        let invoices = client.invoices
        relatedInvoices = invoices.sorted {
            $0.issueDate > $1.issueDate
        }
    }
    
    // MARK: - Save & Update Logic
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
    
    func updateAndSaveClient() {
        // This function is for changes that should be saved immediately
        // For example, from an `onChange` modifier.
        // It bypasses the main "Create" button validation logic.
        guard !isCreatingNew else { return }
        
        // Transfer all editable properties to the client entity
        client.fullName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        client.ndisNumber = editableNdisNumber
        client.status = ClientStatus(rawValue: editableStatus) ?? .active
        // colorHex property removed - using deterministic color system instead
        client.isMinor = editableIsMinor
        client.hasNdisPlan = editableHasNdisPlan
        client.planManagementType = editablePlanManagementType
        if let credit = Double(editableCreditAmountString) {
            client.creditAmount = credit
        }
        client.billingAuthority = BillingAuthority(rawValue: editableBillingAuthority.rawValue) ?? .client
        client.notes = editableNotes.isEmpty ? nil : editableNotes
        
        // Email and Phone are handled via their formatters' bindings
        if emailValidator.isValid { client.email = emailValidator.email }
        if phoneFormatter.isValid { client.phone = phoneFormatter.phoneNumber }

        _ = saveContext()
    }

    func saveClientDetailsAndDismiss() {
        // This is for the main "Create" button.
        let trimmedFullName = editableFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedFullName.isEmpty {
            fullNameError = "Full Name cannot be empty."; return
        }
        
        if !emailValidator.email.isEmpty && !emailValidator.isValid {
            alertTitle = "Validation Error"; alertMessage = "Invalid email address."; showAlert = true; return
        }
        
        // All other properties are already up-to-date via their bindings.
        // The address is handled by commitAddressChanges().
        if isCreatingNew {
            modelContext.insert(client)
        }
        if saveContext() {
            if isCreatingNew {
                dismiss()
            }
        }
    }
    
    // MARK: - Address Logic
    func commitAddressChanges() {
        if client.address == nil {
             if editableUnitNumber.isEmpty && editableStreetNumber.isEmpty && editableStreetName.isEmpty &&
                editableSuburb.isEmpty && editablePostcode.isEmpty && editableState.isEmpty && editableCountry.isEmpty && editablePoBox.isEmpty {
                 isEditingAddress = false
                 return
             }
             client.address = AddressEntity()
         }
        
        client.address?.unitNumber = editableUnitNumber
        client.address?.streetNumber = editableStreetNumber
        client.address?.streetName = editableStreetName
        client.address?.suburb = editableSuburb
        client.address?.postcode = editablePostcode
        client.address?.state = editableState
        client.address?.country = editableCountry
        client.address?.poBox = editablePoBox
        
        if let address = client.address {
            let container = modelContext.container
            DispatchQueue.main.async {
                Task {
                    // Create a background context to avoid data races
                    let backgroundContext = ModelContext(container)
                    await GeocodingService.shared.geocodeAndSave(addressEntity: address, in: backgroundContext)
                }
            }
        }
        
        isEditingAddress = false
    }
    
    func formattedAddressString(_ address: AddressEntity) -> String { // Format domain model address
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
        guard let address = client.address else { return }
        let query = formattedAddressString(address)
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed),
           let url = URL(string: "maps://?q=\(encodedQuery)") { NSWorkspace.shared.open(url) }
    }

    // MARK: - Service Actions
    func saveService() {
        // Ensure ndisItem is nil for custom services
        if isCreatingCustomService && serviceToEdit != nil {
            serviceToEdit!.ndisItem = nil
            serviceToEdit!.ndisCode = nil
        }
        
        // Validate NDIS item relationship if this is an NDIS service
        if !isCreatingCustomService && serviceToEdit != nil {
            validateAndFixNDISItemRelationship(serviceToEdit!)
        }
        
        modelContext.insert(serviceToEdit!)
        _ = saveContext()
        fetchClientServices()
        serviceToEdit = nil
        ndisItemForNewService = nil
        isCreatingCustomService = false
        isPresentingServiceEditor = false
    }
    
    // MARK: - Validation Functions
    private func validateAndFixNDISItemRelationship(_ service: ClientServiceEntity) { // Validate domain model service
        // Ensure NDIS code is set from the NDIS item
        if let ndisItem = service.ndisItem {
            if service.ndisCode != ndisItem.itemNumber {
                service.ndisCode = ndisItem.itemNumber
            }
            
            // Ensure service name matches NDIS item name if not customized
            if service.serviceName == "" || service.serviceName == "New Service" {
                service.serviceName = ndisItem.name
            }
            
            // Ensure unit matches NDIS item unit if not customized
            if service.unit == "" || service.unit == "hour" {
                service.unit = ndisItem.unit ?? "hour"
            }
        }
    }

    func prepareToAddNewService(from ndisItem: NDISItemEntity) { // Prepare domain model service
        let newService = ClientServiceEntity(id: UUID(), serviceName: ndisItem.name, unit: ndisItem.unit ?? "", rate: 0.0)
        newService.client = client
        newService.ndisItem = ndisItem
        newService.isActive = true
        
        // Set service details from the NDIS item
        newService.serviceName = ndisItem.name
        newService.unit = ndisItem.unit ?? ""
        newService.ndisCode = ndisItem.itemNumber // Set the NDIS code from item number
        
        // Find a default price. This is a simple approach.
        // A more complex app might use a setting for the user's region.
        let remotePrice = ndisItem.regionalPrices.first
        newService.rate = remotePrice?.amount ?? 0.0
        
        // Set start date
        newService.startDate = Date()
        
        // Validate and fix NDIS item relationship
        validateAndFixNDISItemRelationship(newService)
        
        ndisItemForNewService = ndisItem
        serviceToEdit = newService
        isCreatingCustomService = false
        
        // This will trigger the editor sheet
        isPresentingServiceEditor = true
    }

    func prepareToAddCustomService() {
        let newService = ClientServiceEntity(id: UUID(), serviceName: "", unit: "hour", rate: 0.0)
        newService.client = client
        newService.isActive = true
        newService.startDate = Date()
        
        // Set default values for a custom service
        newService.serviceName = ""
        newService.ndisCode = nil // Explicitly set to nil for custom services
        newService.unit = "hour"
        newService.rate = 0.0
        
        // Important: Don't set ndisItem for custom services
        // newService.ndisItem = nil (this is already nil by default)
        
        serviceToEdit = newService
        ndisItemForNewService = nil
        isCreatingCustomService = true
        
        // This will trigger the editor sheet
        isPresentingServiceEditor = true
    }

    func assignServices(from ndisItems: [NDISItemEntity]) { // Assign domain model services
        for item in ndisItems {
            let newService = ClientServiceEntity(id: UUID(), serviceName: item.name, unit: item.unit ?? "", rate: 0.0)
            newService.client = client
            newService.ndisItem = item
            newService.isActive = true
            
            // Set service details from the NDIS item
            newService.serviceName = item.name
            newService.unit = item.unit ?? ""
            newService.ndisCode = item.itemNumber // Set the NDIS code from item number
            
            // Find a default price, similar to the single-add method.
            let remotePrice = item.regionalPrices.first
            newService.rate = remotePrice?.amount ?? 0.0
            
            // Set start date
            newService.startDate = Date()
            
            // Validate and fix NDIS item relationship
            validateAndFixNDISItemRelationship(newService)
            
            modelContext.insert(newService)

        }
        
        if saveContext() {
            fetchClientServices() // Refresh the list
        }
    }

    func prepareForBulkServiceCreation(from ndisItems: [NDISItemEntity]) {
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
        for template in templates {
            let newService = ClientServiceEntity(id: UUID(), serviceName: template.serviceName, unit: template.unit, rate: template.rate)
            newService.client = client
            newService.ndisItem = template.sourceNdisItem
            
            // Assign values from the user-configured template
            newService.serviceName = template.serviceName
            newService.ndisCode = template.ndisCode
            newService.rate = template.rate
            newService.unit = template.unit
            newService.isActive = true
            newService.startDate = Date()
            newService.endDate = nil
            
            // Validate and fix NDIS item relationship
            validateAndFixNDISItemRelationship(newService)
            
            modelContext.insert(newService)
        }
        
        if saveContext() {
            fetchClientServices() // Refresh the list
        }
    }

    func prepareToEditService(_ service: ClientServiceEntity) { // Prepare domain model service for editing
        serviceToEdit = service
        ndisItemForNewService = service.ndisItem // Ensure source item is available
        isPresentingServiceEditor = true
    }
    
    func cancelServiceEdit() {
        if let service = serviceToEdit {
            modelContext.delete(service)
        }
        serviceToEdit = nil
        ndisItemForNewService = nil
        isPresentingServiceEditor = false
    }

    func confirmDeleteService(_ service: ClientServiceEntity) { // Confirm deletion of domain model service
        self.serviceToDelete = service
        self.showDeleteServiceAlert = true
    }
    
    func deleteService() {
        if let service = serviceToDelete {
            modelContext.delete(service)
            if saveContext() {
                fetchClientServices()
            }
        }
        serviceToDelete = nil
        showDeleteServiceAlert = false
    }
    
    func toggleActiveStatus(for service: ClientServiceEntity) { // Toggle domain model service status
        service.isActive.toggle()
        _ = saveContext()
    }

    // MARK: - Client Actions
    func confirmDeleteClient() {
        showDeleteClientAlert = true
    }
    
    func deleteClientAndDismiss() {
        modelContext.delete(client)
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
} 
