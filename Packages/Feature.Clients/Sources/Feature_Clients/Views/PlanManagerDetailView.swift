import SwiftUI
import AppKit // For NSColor, NSPasteboard
import MapKit // For address map view
import SwiftData
import Core
import Data
import SharedUI

// MARK: - Helper Functions

// Import helper function from Data package to avoid Codable conflicts
// Helper functions defined in Packages/Data/Sources/Data/Mapping/Client+Mapping.swift

// MARK: - PlanManagerDetailView

struct PlanManagerDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    // ViewModel manages all state
    @StateObject private var viewModel: PlanManagerDetailViewModel
    
    // UI state only
    @State private var showingMapSheet: Bool = false
    @State private var showingAddressEditingSheet: Bool = false
    
    // Sorting state
    @State private var clientsSortOrder: ClientsSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc
    
    // Computed properties from ViewModel
    private var managedClients: [Client] {
        viewModel.managedClients
    }
    
    private var filteredInvoices: [Invoice] {
        viewModel.relatedInvoices
    }
    
    // MARK: - Computed Properties
    
    private var sortedClients: [Client] {
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
    
    private var sortedInvoices: [Invoice] {
        switch invoicesSortOrder {
        case .dateAsc:
            return filteredInvoices.sorted { $0.issueDate < $1.issueDate }
        case .dateDesc:
            return filteredInvoices.sorted { $0.issueDate > $1.issueDate }
        case .dueDateAsc:
            return filteredInvoices.sorted { ($0.dueDate ?? Date.distantPast) < ($1.dueDate ?? Date.distantPast) }
        case .dueDateDesc:
            return filteredInvoices.sorted { ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast) }
        case .invoiceNumber:
            return filteredInvoices.sorted { $0.invoiceNumber < $1.invoiceNumber }
        case .amountAsc:
            return filteredInvoices.sorted { $0.totalAmount < $1.totalAmount }
        case .amountDesc:
            return filteredInvoices.sorted { $0.totalAmount > $1.totalAmount }
        case .clientName:
            return filteredInvoices.sorted { (invoice1: Invoice, invoice2: Invoice) in
                (invoice1.status ?? "") < (invoice2.status ?? "")
            }
        case .numberAsc:
            return filteredInvoices.sorted { $0.invoiceNumber < $1.invoiceNumber }
        case .numberDesc:
            return filteredInvoices.sorted { $0.invoiceNumber > $1.invoiceNumber }
        case .statusAsc:
            return filteredInvoices.sorted { (invoice1: Invoice, invoice2: Invoice) in
                (invoice1.status ?? "") < (invoice2.status ?? "")
            }
        case .statusDesc:
            return filteredInvoices.sorted { (invoice1: Invoice, invoice2: Invoice) in
                (invoice1.status ?? "") > (invoice2.status ?? "")
            }
        }
    }

    // Initializer for existing plan managers
    // Initializer for existing plan managers
    init(planManager: PlanManager, unitOfWork: UnitOfWorkService, onSave: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: PlanManagerDetailViewModel(
            planManager: planManager,
            unitOfWork: unitOfWork,
            isCreating: false
        ))
        _viewModel.wrappedValue.dismiss = onSave ?? {}
    }

    // Initializer for creating a new plan manager
    init(unitOfWork: UnitOfWorkService, onSave: (() -> Void)? = nil) {
        // Create new plan manager domain model
        let newPlanManager = PlanManager(
            id: UUID(),
            name: "",
            email: nil,
            phone: nil,
            address: nil,
            abn: ""
        )
        
        self._viewModel = StateObject(wrappedValue: PlanManagerDetailViewModel(
            planManager: newPlanManager,
            unitOfWork: unitOfWork,
            isCreating: true
        ))
        _viewModel.wrappedValue.dismiss = onSave ?? {}
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            planManagerHeaderBar
            
            // Main Content
            DetailCardsLayout(minCardWidth: DetailSectionTokens.detailCardMinimumWidth) {
                planManagerInfoCard
                managedClientsSection
                invoicesSection
            }
        }
        .background(.clear)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundColor(Color(NSColor.labelColor))
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {}
            .pointerStyle(.link)
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $showingMapSheet) {
            if let address = viewModel.planManager.address {
                InteractiveMapView(address: viewModel.formattedAddressString(from: address))
            }
        }
        .sheet(isPresented: $showingAddressEditingSheet) {
            PlanManagerAddressEditingSheetView(viewModel: viewModel, isPresented: $showingAddressEditingSheet)
        }
        
    }
    
    // MARK: - Helper Functions
    // Note: Most helper functions moved to ViewModel
    
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
                    .foregroundColor(Color("Text", bundle: .sharedUI).opacity(0.9))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.planManager.name.isEmpty ? "New Plan Manager" : viewModel.planManager.name)
                        .font(.largeTitle.weight(.regular))
                        .kerning(5.0)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .lineLimit(1)
                    
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI).opacity(0.3))
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
        GroupBox {
            VStack(spacing: 16) {
                    // Business Name
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Name:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter business name", text: $viewModel.editableBusinessName)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(viewModel.businessNameError != nil ? Color(NSColor.systemRed) : Color(NSColor.labelColor))
                                    .accentColor(viewModel.businessNameError != nil ? Color(NSColor.systemRed) : Color(NSColor.systemBlue))
                                    .onChange(of: viewModel.editableBusinessName) { _, _ in viewModel.updateAndSavePlanManager() }
                                
                                    Button(action: { viewModel.copyToClipboard(viewModel.editableBusinessName) }) {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(Color(NSColor.secondaryLabelColor))
                                            .contentShape(.rect)
                                    }
                                    .buttonStyle(.plain)
                                    .pointerStyle(.link)
                                }
                                
                                if let error = viewModel.businessNameError {
                                    Text(error)
                                        .foregroundColor(Color(NSColor.systemRed))
                                        .font(.caption)
                                }
                        }
                    }
                    
                    // ABN
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("ABN:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter ABN", text: $viewModel.editableAbn)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(viewModel.abnError != nil ? Color(NSColor.systemRed) : Color(NSColor.labelColor))
                                    .accentColor(viewModel.abnError != nil ? Color(NSColor.systemRed) : Color(NSColor.systemBlue))
                                    .onChange(of: viewModel.editableAbn) { _, _ in viewModel.updateAndSavePlanManager() }
                                
                                Button(action: { viewModel.copyToClipboard(viewModel.editableAbn) }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .pointerStyle(.link)
                            }
                            
                            if let error = viewModel.abnError {
                                Text(error)
                                    .foregroundColor(Color(NSColor.systemRed))
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Email
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Email:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter email address", text: $viewModel.emailValidator.email)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(viewModel.emailValidator.validationMessage != nil ? Color(NSColor.systemRed) : Color(NSColor.labelColor))
                                    .accentColor(viewModel.emailValidator.validationMessage != nil ? Color(NSColor.systemRed) : Color(NSColor.systemBlue))
                                    .onChange(of: viewModel.emailValidator.email) { _, _ in 
                                        if viewModel.emailValidator.isValid { 
                                            viewModel.updateAndSavePlanManager() 
                                        } 
                                    }
                                
                                Button(action: { viewModel.copyToClipboard(viewModel.emailValidator.email) }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .pointerStyle(.link)
                            }
                            
                            if let error = viewModel.emailValidator.validationMessage {
                                Text(error)
                                    .foregroundColor(Color(NSColor.systemRed))
                                    .font(.caption)
                            }
                        }
                    }
                    
                    // Phone
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Phone:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                TextField("Enter phone number", text: $viewModel.phoneFormatter.phoneNumber)
                                    .textFieldStyle(.roundedBorder)
                                    .foregroundColor(viewModel.phoneFormatter.validationMessage != nil ? Color(NSColor.systemRed) : Color(NSColor.labelColor))
                                    .accentColor(viewModel.phoneFormatter.validationMessage != nil ? Color(NSColor.systemRed) : Color(NSColor.systemBlue))
                                    .onChange(of: viewModel.phoneFormatter.phoneNumber) { _, _ in 
                                        if viewModel.phoneFormatter.isValid { 
                                            viewModel.updateAndSavePlanManager() 
                                        }
                                    }
                                
                                Button(action: { viewModel.copyToClipboard(viewModel.phoneFormatter.phoneNumber) }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                                        .padding(4)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .pointerStyle(.link)
                            }
                            
                            if let error = viewModel.phoneFormatter.validationMessage {
                                Text(error)
                                    .foregroundColor(Color(NSColor.systemRed))
                                    .font(.caption)
                            }
                    }
                }
                
                // Address
                compactAddressView
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hasAddressData)
                
                Spacer(minLength: 0)
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "building.2", title: "Plan Manager Information")
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading plan manager information...")
    }

    // MARK: - Address Helper Methods
    
    private var hasAddressData: Bool {
        // Check existing address from domain model
        return viewModel.planManager.address != nil
    }
    
    private var compactAddressView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Address:")
                .frame(width: maxLabelWidth, alignment: .trailing)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if hasAddressData, let address = viewModel.planManager.address {
                    Text(viewModel.formattedAddressString(from: address))
                        .font(.system(size: 14))
                        .foregroundColor(Color(NSColor.labelColor))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                } else {
                    Text("No address added")
                        .font(.system(size: 14))
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                }
                
                if hasAddressData {
                    HStack(spacing: 4) {
                        Button(action: {
                            showingMapSheet = true
                        }) {
                            Image(systemName: "map")
                                .foregroundColor(Color("Primary", bundle: .sharedUI))
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            showingAddressEditingSheet = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(Color("Inactive", bundle: .sharedUI))
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: {
                        showingAddressEditingSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(Color("Active", bundle: .sharedUI))
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var managedClientsSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                DetailListBody(
                    isEmpty: managedClients.isEmpty,
                    emptyMessage: "No clients are using this plan manager"
                ) {
                    ForEach(sortedClients, id: \.id) { client in
                        CompactClientRowView(client: client)
                    }
                }
                
            }
        } label: {
            DetailSectionHeader(icon: "person.3", title: "Managed Clients") {
                DetailSectionSortPicker(selection: $clientsSortOrder)
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading managed clients...")
    }
    
    private var invoicesSection: some View {
        GroupBox {
            VStack(spacing: 12) {
                DetailListBody(
                    isEmpty: filteredInvoices.isEmpty,
                    emptyMessage: "No invoices found"
                ) {
                    ForEach(sortedInvoices, id: \.id) { invoice in
                        CompactInvoiceRowView(invoice: invoice)
                    }
                }
                
            }
        } label: {
            DetailSectionHeader(icon: "doc.text", title: "Invoices") {
                DetailSectionSortPicker(selection: $invoicesSortOrder)
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading invoices...")
    }
}



// MARK: - PlanManagerAddressEditingSheetView

struct PlanManagerAddressEditingSheetView: View {
    @ObservedObject var viewModel: PlanManagerDetailViewModel
    @Binding var isPresented: Bool
    
    @State private var isManualMode = false
    
    // Address search state
    @State private var addressSearchText: String = ""
    @State private var selectedAddress: AddressData?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Text("Search for an address or enter details manually")
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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
                                unitNumber: $viewModel.editableUnitNumber,
                                streetNumber: $viewModel.editableStreetNumber,
                                streetName: $viewModel.editableStreetName,
                                suburb: $viewModel.editableSuburb,
                                postcode: $viewModel.editablePostcode,
                                state: $viewModel.editableState,
                                country: $viewModel.editableCountry,
                                poBox: $viewModel.editablePoBox
                            )
                            .onChange(of: selectedAddress) { _, newValue in
                                if newValue != nil {
                                    // Auto-commit the selected address and close the sheet
                                    viewModel.commitAddressChanges(autosave: true)
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
                                    .font(.title3.weight(.bold)).foregroundColor(Color("Text", bundle: .sharedUI)).padding(.bottom, 4)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                
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
                        viewModel.commitAddressChanges(autosave: true)
                        isPresented = false
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .glassEffect(.regular, in: .rect())
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            // Load existing address data from ViewModel
            viewModel.loadAddressDetails()
            if let address = viewModel.planManager.address {
                addressSearchText = viewModel.formattedAddressString(from: address)
            }
        }
    }
    
    private var hasAddressData: Bool {
        // Check ViewModel's editable address fields
        let hasStateData = !viewModel.editableUnitNumber.isEmpty || !viewModel.editableStreetNumber.isEmpty || 
        !viewModel.editableStreetName.isEmpty || !viewModel.editableSuburb.isEmpty || 
        !viewModel.editableState.isEmpty || !viewModel.editablePostcode.isEmpty || 
        !viewModel.editableCountry.isEmpty || !viewModel.editablePoBox.isEmpty
        
        // Check existing address from domain model
        let hasExistingAddress = viewModel.planManager.address != nil
        
        return hasStateData || hasExistingAddress
    }
    
    private var manualAddressFields: some View {
        VStack(spacing: 8) {
            // Header with clear button
            HStack {
                Text("Address Details")
                    .font(.title3.weight(.bold)).foregroundColor(Color("Text", bundle: .sharedUI)).padding(.bottom, 4)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                Button("Clear") {
                    viewModel.editableUnitNumber = ""
                    viewModel.editableStreetNumber = ""
                    viewModel.editableStreetName = ""
                    viewModel.editableSuburb = ""
                    viewModel.editableState = ""
                    viewModel.editablePostcode = ""
                    viewModel.editableCountry = ""
                    viewModel.editablePoBox = ""
                    addressSearchText = ""
                    selectedAddress = nil
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .foregroundColor(Color(NSColor.systemRed))
            }
            .padding(.bottom, 4)
            
            // Unit Number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Unit:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color(NSColor.labelColor))
                
                TextField("Unit number (optional)", text: $viewModel.editableUnitNumber)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color(NSColor.labelColor))
                    .accentColor(Color(NSColor.systemBlue))
            }
            
            // Street Number and Name
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Street:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color(NSColor.labelColor))
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Number", text: $viewModel.editableStreetNumber)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color(NSColor.labelColor))
                        .accentColor(Color(NSColor.systemBlue))
                        .frame(width: 80)
                    
                    TextField("Street name", text: $viewModel.editableStreetName)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color(NSColor.labelColor))
                        .accentColor(Color(NSColor.systemBlue))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Suburb
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Suburb:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color(NSColor.labelColor))
                
                TextField("Enter suburb", text: $viewModel.editableSuburb)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color(NSColor.labelColor))
                    .accentColor(Color(NSColor.systemBlue))
            }
            
            // State and Postcode
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("State:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color(NSColor.labelColor))
                
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField("State", text: $viewModel.editableState)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color(NSColor.labelColor))
                        .accentColor(Color(NSColor.systemBlue))
                    
                    TextField("Postcode", text: $viewModel.editablePostcode)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color(NSColor.labelColor))
                        .accentColor(Color(NSColor.systemBlue))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Country
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Country:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color(NSColor.labelColor))
                
                TextField("Enter country", text: $viewModel.editableCountry)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color(NSColor.labelColor))
                    .accentColor(Color(NSColor.systemBlue))
            }
            
            // PO Box
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PO Box:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color(NSColor.labelColor))
                
                TextField("PO Box number (optional)", text: $viewModel.editablePoBox)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color(NSColor.labelColor))
                    .accentColor(Color(NSColor.systemBlue))
            }
        }
    }
}
