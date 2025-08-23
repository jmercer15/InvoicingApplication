import SwiftUI
import AppKit // For NSColor, NSPasteboard
import MapKit // For address map view
import SwiftData

// MARK: - PlanManagerDetailView

struct PlanManagerDetailView: View {
    @Bindable var planManager: PlanManagerEntity
    let isCreatingNew: Bool
    let onSave: (() -> Void)?
    
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    // For real-time data fetching
    @Query private var allClients: [ClientEntity]
    @Query private var relatedInvoices: [InvoiceEntity]
    
    // State variables
    @State private var editableBusinessName: String = ""
    @State private var editableAbn: String = ""
    @State private var editableEmail: String = ""
    @State private var editablePhone: String = ""
    
    // Address editing state
    @State private var isEditingAddress: Bool = false
    @State private var addressSearchText: String = ""
    @State private var selectedSearchAddress: AddressData?
    @State private var editableUnitNumber: String = ""
    @State private var editableStreetNumber: String = ""
    @State private var editableStreetName: String = ""
    @State private var editableSuburb: String = ""
    @State private var editablePostcode: String = ""
    @State private var editableState: String = ""
    @State private var editableCountry: String = ""
    @State private var editablePoBox: String = ""
    
    // Alert state
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var showingMapSheet: Bool = false
    @State private var showingAddressEditingSheet: Bool = false
    
    // Formatters and validators
    @StateObject private var emailValidator = EmailValidator()
    @StateObject private var phoneFormatter = PhoneNumberFormatter()
    
    // Sorting state
    @State private var clientsSortOrder: ClientsSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc
    
    // Computed properties
    private var managedClients: [ClientEntity] {
        allClients.filter { $0.planManager?.id == planManager.id }
    }
    
    private var filteredInvoices: [InvoiceEntity] {
        let managedClientIDs = Set(managedClients.map { $0.id })
        return relatedInvoices.filter { invoice in
            guard let clientID = invoice.client?.id else { return false }
            return managedClientIDs.contains(clientID)
        }
    }
    
    private var businessNameError: String? {
        if editableBusinessName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Business name is required"
        }
        return nil
    }
    
    private var abnError: String? {
        if !isValidABN(editableAbn) {
            return "Please enter a valid ABN"
        }
        return nil
    }
    
    // MARK: - Computed Properties
    
    private var sortedClients: [ClientEntity] {
        switch clientsSortOrder {
        case .nameAsc:
            return managedClients.sorted { $0.fullName < $1.fullName }
        case .nameDesc:
            return managedClients.sorted { $0.fullName > $1.fullName }
        case .ndisAsc:
            return managedClients.sorted { $0.ndisNumber < $1.ndisNumber }
        case .ndisDesc:
            return managedClients.sorted { $0.ndisNumber > $1.ndisNumber }
        case .statusAsc:
            return managedClients.sorted { $0.status < $1.status }
        case .statusDesc:
            return managedClients.sorted { $0.status > $1.status }

        }
    }
    
    private var sortedInvoices: [InvoiceEntity] {
        switch invoicesSortOrder {
        case .dateAsc:
            return filteredInvoices.sorted { $0.issueDate < $1.issueDate }
        case .dateDesc:
            return filteredInvoices.sorted { $0.issueDate > $1.issueDate }
        case .numberAsc:
            return filteredInvoices.sorted { $0.invoiceNumber < $1.invoiceNumber }
        case .numberDesc:
            return filteredInvoices.sorted { $0.invoiceNumber > $1.invoiceNumber }
        case .amountAsc:
            return filteredInvoices.sorted { $0.totalAmount < $1.totalAmount }
        case .amountDesc:
            return filteredInvoices.sorted { $0.totalAmount > $1.totalAmount }
        case .statusAsc:
            return filteredInvoices.sorted { ($0.status ?? "") < ($1.status ?? "") }
        case .statusDesc:
            return filteredInvoices.sorted { ($0.status ?? "") > ($1.status ?? "") }
        }
    }

    // Initializer for existing plan managers
    init(planManager: PlanManagerEntity, context: ModelContext, onSave: (() -> Void)? = nil) {
        self.planManager = planManager
        self.isCreatingNew = false
        self.onSave = onSave
        self._allClients = Query()
        self._relatedInvoices = Query()
    }

    // Initializer for creating a new plan manager
    init(context: ModelContext, onSave: (() -> Void)? = nil) {
        let newPlanManager = PlanManagerEntity(id: UUID(), abn: "")
        self.planManager = newPlanManager
        self.isCreatingNew = true
        self.onSave = onSave
        self._allClients = Query()
        self._relatedInvoices = Query()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            planManagerHeaderBar
            
            // Main Content
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                // Main content with ViewThatFits for adaptive layout
                ViewThatFits {
                    // Primary layout: 2x2 grid (2 columns, 2 rows)
                    VStack(spacing: 20) {
                        // Row 1: 2 columns
                        HStack(spacing: 20) {
                            planManagerInfoCard
                                .frame(maxWidth: .infinity)
                            managedClientsSection
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Row 2: 2 columns
                        HStack(spacing: 20) {
                            invoicesSection
                                .frame(maxWidth: .infinity)
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Fallback layout: 1x3 grid (1 column, 3 rows)
                    VStack(spacing: 20) {
                        planManagerInfoCard
                        managedClientsSection
                        invoicesSection
                    }
                }
            }
            .padding(24)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundColor(.white)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {}
            .appInteractiveCursor()
        } message: {
            Text(alertMessage)
        }

        .onAppear {
            loadPlanManagerDetails()
        }
        .sheet(isPresented: $showingMapSheet) {
            InteractiveMapView(address: getCurrentAddressString())
        }
        .sheet(isPresented: $showingAddressEditingSheet) {
            PlanManagerAddressEditingSheet(
                planManager: planManager,
                isPresented: $showingAddressEditingSheet
            )
        }
        
    }
    
    // MARK: - Helper Functions
    
    private func loadPlanManagerDetails() {
        editableBusinessName = planManager.businessName ?? ""
        editableAbn = planManager.abn
        editableEmail = planManager.email ?? ""
        editablePhone = planManager.phone ?? ""
        
        // Initialize formatters
        emailValidator.email = editableEmail
        phoneFormatter.phoneNumber = editablePhone
        
        // Load address details if editing
        if isEditingAddress {
            loadAddressDetails()
        }
        
        // Load existing address data into state variables
        if let address = planManager.address {
            editableUnitNumber = address.unitNumber
            editableStreetNumber = address.streetNumber
            editableStreetName = address.streetName
            editableSuburb = address.suburb
            editablePostcode = address.postcode
            editableState = address.state
            editableCountry = address.country
            editablePoBox = address.poBox
            addressSearchText = formattedAddressString(address)
        }
    }
    
    private func updateAndSavePlanManager() {
        planManager.businessName = editableBusinessName
        planManager.abn = editableAbn
        planManager.email = editableEmail.isEmpty ? nil : editableEmail
        planManager.phone = editablePhone.isEmpty ? nil : editablePhone
        
        _ = saveContext()
    }
    
    private func createPlanManagerAndDismiss() {
        updateAndSavePlanManager()
        if isCreatingNew && onSave != nil {
            onSave?()
        } else {
            dismiss()
        }
    }
    
    private func deletePlanManagerAndDismiss() {
        context.delete(planManager)
        _ = saveContext()
        dismiss()
    }
    

    
    private func saveContext() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            alertTitle = "Save Error"
            alertMessage = "Failed to save changes: \(error.localizedDescription)"
            showAlert = true
            return false
        }
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    private func loadAddressDetails() {
        guard let address = planManager.address else { return }
        editableUnitNumber = address.unitNumber
        editableStreetNumber = address.streetNumber
        editableStreetName = address.streetName
        editableSuburb = address.suburb
        editablePostcode = address.postcode
        editableState = address.state
        editableCountry = address.country
        editablePoBox = address.poBox
    }
    
    private func commitAddressChanges() {
        let address = planManager.address ?? AddressEntity()
        address.unitNumber = editableUnitNumber
        address.streetNumber = editableStreetNumber
        address.streetName = editableStreetName
        address.suburb = editableSuburb
        address.postcode = editablePostcode
        address.state = editableState
        address.country = editableCountry
        address.poBox = editablePoBox
        
        planManager.address = address
        _ = saveContext()
        isEditingAddress = false
    }
    
    private func openInMaps() {
        guard let address = planManager.address else { return }
        let addressString = formattedAddressString(address)
        let encodedAddress = addressString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "http://maps.apple.com/?address=\(encodedAddress)"
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func formattedAddressString(_ address: AddressEntity) -> String {
        var components: [String] = []
        
        if !address.unitNumber.isEmpty {
            components.append("Unit \(address.unitNumber)")
        }
        if !address.streetNumber.isEmpty {
            components.append(address.streetNumber)
        }
        if !address.streetName.isEmpty {
            components.append(address.streetName)
        }
        if !address.suburb.isEmpty {
            components.append(address.suburb)
        }
        if !address.state.isEmpty {
            components.append(address.state)
        }
        if !address.postcode.isEmpty {
            components.append(address.postcode)
        }
        if !address.country.isEmpty {
            components.append(address.country)
        }
        
        return components.joined(separator: " ")
    }
    
    private func getCurrentAddressString() -> String {
        // If we have existing address data, use that
        if let address = planManager.address, !address.fullAddressText.isEmpty {
            return address.formattedAddress
        }
        
        // Otherwise use the state variables for compact address
        return formatAddressForDisplay()
    }
    
    private func formatAddressForDisplay() -> String {
        var parts: [String] = []
        
        if !editablePoBox.isEmpty {
            parts.append("PO Box \(editablePoBox)")
        } else {
            if !editableUnitNumber.isEmpty { parts.append("Unit \(editableUnitNumber)") }
            if !editableStreetNumber.isEmpty { parts.append(editableStreetNumber) }
            if !editableStreetName.isEmpty { parts.append(editableStreetName) }
        }
        
        if !editableSuburb.isEmpty { parts.append(editableSuburb) }
        if !editableState.isEmpty { parts.append(editableState) }
        if !editablePostcode.isEmpty { parts.append(editablePostcode) }
        if !editableCountry.isEmpty { parts.append(editableCountry) }
        
        return parts.joined(separator: ", ")
    }
    
    private func isValidABN(_ abn: String) -> Bool {
        let cleaned = abn.replacingOccurrences(of: " ", with: "")
        return cleaned.count == 11 && cleaned.allSatisfy { $0.isNumber }
    }
    
    // MARK: - Label Width Calculation
    
    private var maxLabelWidth: CGFloat {
        let labels = [
            "Name:",
            "ABN:",
            "Email:",
            "Phone:",
            "Address:"
        ]
        
        let font = NSFont.systemFont(ofSize: 14)
        let maxWidth = labels.map { label in
            let size = (label as NSString).size(withAttributes: [.font: font])
            return size.width
        }.max() ?? 80
        
        return maxWidth + 20 // Add some padding
    }

    // MARK: - Header Bar
    
    private var planManagerHeaderBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(planManager.businessName?.isEmpty == false ? planManager.businessName! : "New Plan Manager")
                        .font(.largeTitle.weight(.regular))
                        .kerning(5.0)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(.white.opacity(0.3))
                }
                .fixedSize(horizontal: true, vertical: true)
                Spacer()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Subviews

    private var planManagerInfoCard: some View {
        GroupBox("Plan Manager Information") {
            VStack(spacing: 12) {
                    // Business Name
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Name:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter business name", text: $editableBusinessName)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(businessNameError != nil ? .red : .white)
                                    .accentColor(businessNameError != nil ? .red : .blue)
                                    .onChange(of: editableBusinessName) { updateAndSavePlanManager() }
                                
                                    Button(action: { copyToClipboard(editableBusinessName) }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.gray)
                                    }
                                    .buttonStyle(.plain)
                            }
                            
                            if let error = businessNameError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // ABN
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("ABN:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter ABN", text: $editableAbn)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(abnError != nil ? .red : .white)
                                    .accentColor(abnError != nil ? .red : .blue)
                                    .onChange(of: editableAbn) { updateAndSavePlanManager() }
                                
                                Button(action: { copyToClipboard(editableAbn) }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if let error = abnError {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Email
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Email:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter email address", text: $emailValidator.email)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(emailValidator.validationMessage != nil ? .red : .white)
                                    .accentColor(emailValidator.validationMessage != nil ? .red : .blue)
                                    .onChange(of: emailValidator.email) { 
                                        editableEmail = emailValidator.email
                                        if emailValidator.isValid { updateAndSavePlanManager() } 
                                    }
                                
                                Button(action: { copyToClipboard(emailValidator.email) }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if let error = emailValidator.validationMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Phone
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Phone:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter phone number", text: $phoneFormatter.phoneNumber)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(phoneFormatter.validationMessage != nil ? .red : .white)
                                    .accentColor(phoneFormatter.validationMessage != nil ? .red : .blue)
                                    .onChange(of: phoneFormatter.phoneNumber) { 
                                        editablePhone = phoneFormatter.phoneNumber
                                        if phoneFormatter.isValid { updateAndSavePlanManager() } 
                                    }
                                
                                Button(action: { copyToClipboard(phoneFormatter.phoneNumber) }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.gray)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if let error = phoneFormatter.validationMessage {
                                Text(error)
                                    .foregroundColor(.red)
                                    .font(.caption)
                        }
                    }
                }
                
                // Address
                compactAddressView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: hasAddressData)
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: 120)
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .modifier(LiquidGlassGroupBoxModifier())
    }

    // MARK: - Address Helper Methods
    
    private var hasAddressData: Bool {
        // Check state variables (for editing)
        let hasStateData = !editableUnitNumber.isEmpty || !editableStreetNumber.isEmpty || !editableStreetName.isEmpty || 
        !editableSuburb.isEmpty || !editableState.isEmpty || !editablePostcode.isEmpty || 
        !editableCountry.isEmpty || !editablePoBox.isEmpty
        
        // Check existing address from entity
        let hasExistingAddress = planManager.address != nil && !planManager.address!.fullAddressText.isEmpty
        
        return hasStateData || hasExistingAddress
    }
    
    private var compactAddressView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Address:")
                .frame(width: maxLabelWidth, alignment: .trailing)
                .foregroundColor(.white)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if hasAddressData {
                    Text(formatAddressForDisplay())
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .glassEffect(.regular, in: .rect(cornerRadius: 6))
                } else {
                    Text("No address added")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .glassEffect(.regular, in: .rect(cornerRadius: 6))
                }
                
                if hasAddressData {
                    HStack(spacing: 4) {
                        Button(action: {
                            showingMapSheet = true
                        }) {
                            Image(systemName: "map")
                                .foregroundColor(.blue)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .rect(cornerRadius: 4))
                        
                        Button(action: {
                            showingAddressEditingSheet = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .rect(cornerRadius: 4))
                    }
                } else {
                    Button(action: {
                        showingAddressEditingSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .rect(cornerRadius: 4))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var managedClientsSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                if !managedClients.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(sortedClients) { client in
                                CompactClientRowView(client: client)
                            }
                        }
                        .padding(.horizontal, 0)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 200)
                } else {
                    Text("No clients are using this plan manager")
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                }
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: 120)
        } label: {
            HStack {
                Text("Managed Clients")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("Sort", selection: $clientsSortOrder) {
                    ForEach(ClientsSortOrder.allCases, id: \.self) { sortOrder in
                        Text(sortOrder.displayName).tag(sortOrder)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .modifier(LiquidGlassGroupBoxModifier())
    }
    
    private var invoicesSection: some View {
        GroupBox {
            VStack(spacing: 8) {
                if filteredInvoices.isEmpty {
                    Text("No invoices found")
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(sortedInvoices) { invoice in
                                CompactInvoiceRowView(invoice: invoice)
                            }
                        }
                        .padding(.horizontal, 0)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 200)
                }
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: 120)
        } label: {
            HStack {
                Text("Invoices")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("Sort", selection: $invoicesSortOrder) {
                    ForEach(InvoicesSortOrder.allCases, id: \.self) { sortOrder in
                        Text(sortOrder.displayName).tag(sortOrder)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .frame(width: 120)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .modifier(LiquidGlassGroupBoxModifier())
    }
}



// MARK: - Plan Manager Address Editing Sheet

struct PlanManagerAddressEditingSheet: View {
    @Bindable var planManager: PlanManagerEntity
    @Binding var isPresented: Bool
    
    @State private var isManualMode = false
    
    // Address editing state (matching NativeSessionFormView)
    @State private var addressSearchText: String = ""
    @State private var selectedAddress: AddressData?
    @State private var unitNumber: String = ""
    @State private var streetNumber: String = ""
    @State private var streetName: String = ""
    @State private var suburb: String = ""
    @State private var postcode: String = ""
    @State private var state: String = ""
    @State private var country: String = ""
    @State private var poBox: String = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Search for an address or enter details manually")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Address Search (only shown when not in manual mode)
                    if !isManualMode {
                        VStack(spacing: 12) {
                            NativeAddressSearchField(
                                searchText: $addressSearchText,
                                selectedAddress: $selectedAddress,
                                unitNumber: $unitNumber,
                                streetNumber: $streetNumber,
                                streetName: $streetName,
                                suburb: $suburb,
                                postcode: $postcode,
                                state: $state,
                                country: $country,
                                poBox: $poBox
                            )
                            .onChange(of: selectedAddress) { _, newValue in
                                if newValue != nil {
                                    // Auto-commit the selected address and close the sheet
                                    commitAddressChanges()
                                    isPresented = false
                                }
                            }
                            
                            // Toggle to manual mode
                            HStack {
                                Spacer()
                                Button("Enter Manually") {
                                    isManualMode = true
                                }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    // Manual Entry Fields (only shown in manual mode)
                    if isManualMode {
                        VStack(spacing: 12) {
                            // Header with mode toggle
                            HStack {
                                Text("Manual Address Entry")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                Button("Search Instead") {
                                    isManualMode = false
                                }
                                .buttonStyle(.glass)
                                .controlSize(.small)
                            }
                            .padding(.bottom, 4)
                            
                            manualAddressFields
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Footer
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.glass)
                
                Spacer()
                
                if hasAddressData {
                    Button("Done") {
                        commitAddressChanges()
                        isPresented = false
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.95),
                    Color.black.opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            loadExistingAddressData()
        }
    }
    
    private func loadExistingAddressData() {
        if let address = planManager.address {
            unitNumber = address.unitNumber
            streetNumber = address.streetNumber
            streetName = address.streetName
            suburb = address.suburb
            postcode = address.postcode
            state = address.state
            country = address.country
            poBox = address.poBox
            addressSearchText = address.fullFormattedAddress
        }
    }
    
    private var hasAddressData: Bool {
        // Check state variables (for editing)
        let hasStateData = !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty || 
        !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty || 
        !country.isEmpty || !poBox.isEmpty
        
        // Check existing address from entity
        let hasExistingAddress = planManager.address != nil && !planManager.address!.fullAddressText.isEmpty
        
        return hasStateData || hasExistingAddress
    }
    
    private var manualAddressFields: some View {
        VStack(spacing: 8) {
            // Header with clear button
            HStack {
                Text("Address Details")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Clear") {
                    clearAddressData()
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .foregroundColor(.red)
            }
            .padding(.bottom, 4)
            
            // Unit Number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Unit:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.white)
                
                TextField("Unit number (optional)", text: $unitNumber)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)
                    .accentColor(.blue)
            }
            
            // Street Number and Name
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Street:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.white)
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Number", text: $streetNumber)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                        .accentColor(.blue)
                        .frame(width: 80)
                    
                    TextField("Street name", text: $streetName)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                        .accentColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Suburb
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Suburb:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.white)
                
                TextField("Enter suburb", text: $suburb)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)
                    .accentColor(.blue)
            }
            
            // State and Postcode
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("State:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.white)
                
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField("State", text: $state)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                        .accentColor(.blue)
                    
                    TextField("Postcode", text: $postcode)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                        .accentColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Country
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Country:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.white)
                
                TextField("Enter country", text: $country)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)
                    .accentColor(.blue)
            }
            
            // PO Box
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PO Box:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(.white)
                
                TextField("PO Box number (optional)", text: $poBox)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(.white)
                    .accentColor(.blue)
            }
        }
    }
    
    private func clearAddressData() {
        unitNumber = ""
        streetNumber = ""
        streetName = ""
        suburb = ""
        state = ""
        postcode = ""
        country = ""
        poBox = ""
        addressSearchText = ""
        selectedAddress = nil
    }
    
    private func commitAddressChanges() {
        let address = planManager.address ?? AddressEntity()
        address.unitNumber = unitNumber
        address.streetNumber = streetNumber
        address.streetName = streetName
        address.suburb = suburb
        address.postcode = postcode
        address.state = state
        address.country = country
        address.poBox = poBox
        
        planManager.address = address
    }
}




 
