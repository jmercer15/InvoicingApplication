import SwiftUI
import SwiftData
import Core
import Data
import SharedUI

// MARK: - Helper Functions

// Import helper functions from Data package to avoid Codable conflicts
// Helper functions defined in:
// - Packages/Data/Sources/Data/Mapping/Client+Mapping.swift (clientFromEntity, payeeFromEntity, planManagerFromEntity)
// - Packages/Data/Sources/Data/Mapping/Invoice+Mapping.swift (invoiceFromEntity)

// MARK: - Billing Authority Enum

struct ClientDetailView: View {

    @Environment(\.dismiss) private var dismiss
    
    // ViewModel manages all state
    @StateObject private var viewModel: ClientDetailViewModel
    
    let isCreatingNew: Bool
    let onSave: (() -> Void)?
    
    // Enhanced state management
    @State private var showingServiceAssignment = false
    @State private var isEditingAddress = false
    @State private var showingMapSheet = false
    @State private var showingAddressEditingSheet = false
    
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
    
    // Note: clientServices and relatedInvoices now come from viewModel (domain models)
    
    // Sorting state
    @State private var servicesSortOrder: ServicesSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc
    
    init(client: Client, unitOfWork: UnitOfWorkService, onSave: (() -> Void)? = nil) {
        self.isCreatingNew = false
        self.onSave = onSave
        
        // Initialize ViewModel with domain model and UnitOfWork
        self._viewModel = StateObject(wrappedValue: ClientDetailViewModel(
            client: client,
            unitOfWork: unitOfWork,
            isCreating: false
        ))
        
        // Load existing address data from domain model
        if let address = client.address {
            _unitNumber = State(initialValue: address.unitNumber)
            _streetNumber = State(initialValue: address.streetNumber)
            _streetName = State(initialValue: address.streetName)
            _suburb = State(initialValue: address.suburb)
            _postcode = State(initialValue: address.postcode)
            _state = State(initialValue: address.state)
            _country = State(initialValue: address.country)
            _poBox = State(initialValue: address.poBox)
            _addressSearchText = State(initialValue: address.fullFormattedAddress)
        }
    }
    
    init(unitOfWork: UnitOfWorkService, onSave: (() -> Void)? = nil) {
        let newClient = Client(id: UUID(), ndisNumber: "", fullName: "", status: "Active")
        self.isCreatingNew = true
        self.onSave = onSave
        
        // Initialize ViewModel for new client
        self._viewModel = StateObject(wrappedValue: ClientDetailViewModel(
            client: newClient,
            unitOfWork: unitOfWork,
            isCreating: true
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            clientHeaderBar
            
            // Main Content
            DetailCardsLayout(minCardWidth: DetailSectionTokens.detailCardMinimumWidth) {
                clientInfoCard
                billingInfoCard
                serviceAgreementsCard
                servicesCard
                invoicesCard
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .foregroundColor(Color("Text", bundle: .sharedUI))

        .sheet(isPresented: $showingServiceAssignment) {
            ServiceAssignmentSheetView(
                client: viewModel.client,
                alreadySelectedItems: viewModel.assignedNDISItems,
                availableNDISItems: viewModel.availableNDISItems,
                onProceed: { selectedItems in
                    viewModel.prepareForBulkServiceCreation(from: selectedItems)
                }
            )
            .fluidSheetTransition()
            .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: showingServiceAssignment)
        }
        .sheet(isPresented: $viewModel.isPresentingServiceBulkEditor) {
            ServiceBulkEditorView(
                templates: $viewModel.serviceTemplates,
                onSave: { templates in
                    viewModel.commitServices(fromTemplates: templates)
                }
            )
            .fluidSheetTransition()
            .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.isPresentingServiceBulkEditor)
        }
        .sheet(isPresented: $viewModel.isPresentingServiceAgreementSheet) {
            ServiceAgreementEditorSheet(viewModel: viewModel)
                .fluidSheetTransition()
                .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.isPresentingServiceAgreementSheet)
        }
        .sheet(isPresented: $showingMapSheet) {
            InteractiveMapView(address: getCurrentAddressString())
            .fluidSheetTransition()
            .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: showingMapSheet)
        }
        .sheet(isPresented: $showingAddressEditingSheet) {
            ClientAddressEditingSheet(
                viewModel: viewModel,
                isPresented: $showingAddressEditingSheet
            )
            .fluidSheetTransition()
            .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: showingAddressEditingSheet)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if isCreatingNew {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(isCreatingNew ? "Create Client" : "Save Changes") {
                    viewModel.saveClientDetailsAndDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.editableFullName.isEmpty)
            }
        }
        .onAppear {
            viewModel.dismiss = {
                dismiss()
                onSave?()
            }
        }

        
    }
    
    // MARK: - Card Views
    
    private var clientInfoCard: some View {
        GroupBox {
            VStack(spacing: 16) {
                // Name
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Name:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    HStack {
                        TextField("Enter client name", text: $viewModel.editableFullName)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .onChange(of: viewModel.editableFullName) { viewModel.updateAndSaveClient() }
                        
                        Button(action: { copyToClipboard(viewModel.editableFullName) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                    }
                }
                
                // Email
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Email:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    HStack {
                        TextField("Enter email address", text: $viewModel.emailValidator.email)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .onChange(of: viewModel.emailValidator.email) { viewModel.updateAndSaveClient() }
                        
                        Button(action: { copyToClipboard(viewModel.emailValidator.email) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                    }
                }
                
                // Phone
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Phone:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    HStack {
                        TextField("Enter phone number", text: $viewModel.phoneFormatter.phoneNumber)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .onChange(of: viewModel.phoneFormatter.phoneNumber) { viewModel.updateAndSaveClient() }
                        
                        Button(action: { copyToClipboard(viewModel.phoneFormatter.phoneNumber) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                    }
                }
                
                // Address
                compactAddressView
                    .fluidListTransition()
                    .animation(.easeInOut(duration: 0.3), value: hasAddressData)
                
                // Divider before NDIS section
                Divider()
                    .padding(.vertical, 8)
                
                // Has NDIS Plan - Top of NDIS section
                HStack(alignment: .center, spacing: 6) {
                    Text("Has NDIS Plan:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Toggle("", isOn: $viewModel.editableHasNdisPlan)
                        .toggleStyle(.switch)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .labelsHidden()
                        .onChange(of: viewModel.editableHasNdisPlan) { viewModel.updateAndSaveClient() }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // NDIS Number - Only shown when "Has NDIS Plan" is true
                if viewModel.editableHasNdisPlan {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("NDIS:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        HStack {
                            TextField("Enter NDIS number", text: $viewModel.editableNdisNumber)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                                .accentColor(.blue)
                                .onChange(of: viewModel.editableNdisNumber) { viewModel.updateAndSaveClient() }
                            
                            Button(action: { copyToClipboard(viewModel.editableNdisNumber) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.gray)
                                    .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .fluidListTransition()
                    .animation(.easeInOut(duration: 0.3), value: viewModel.editableHasNdisPlan)
                }
                
                // Plan Management Type - Only shown when "Has NDIS Plan" is true
                if viewModel.editableHasNdisPlan {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Type:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        Picker("", selection: Binding(
                            get: { viewModel.editablePlanManagementType ?? "Self-Managed" },
                            set: { viewModel.editablePlanManagementType = $0; viewModel.updateAndSaveClient() }
                        )) {
                            Text("Self-Managed").tag("Self-Managed")
                            Text("Plan-Managed").tag("Plan-Managed")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.editableHasNdisPlan)
                }
                
                // Plan Manager - Only shown when Type is "Plan-Managed"
                if viewModel.editableHasNdisPlan && viewModel.editablePlanManagementType == "Plan-Managed" {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Plan Manager:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        Picker("", selection: Binding(
                            get: { viewModel.selectedPlanManager?.id },
                            set: { newPlanManagerId in
                                viewModel.updatePlanManager(by: newPlanManagerId)
                            }
                        )) {
                            Text("Select Plan Manager").tag(nil as UUID?)
                            ForEach(viewModel.allPlanManagers) { planManager in
                                Text(planManager.name).tag(planManager.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.editablePlanManagementType)
                }
                
                Spacer(minLength: 0)
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "person.circle", title: "Client Information")
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading client information...")
    }
    

    

    
    private var billingInfoCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                // Options - Always shown first
                HStack(spacing: 16) {
                    // Is Minor
                    HStack(alignment: .center, spacing: 6) {
                        Text("Is Minor:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        Toggle("", isOn: $viewModel.editableIsMinor)
                            .toggleStyle(.switch)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .labelsHidden()
                            .onChange(of: viewModel.editableIsMinor) { _, isMinor in
                                if isMinor {
                                    viewModel.editableBillingAuthority = .parentGuardian
                                }
                                viewModel.updateAndSaveClient()
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Spacer()
                        .frame(maxWidth: .infinity)
                }
                
                // Billing Authority - Always shown
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("Authority:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Picker("", selection: Binding(
                        get: { viewModel.editableBillingAuthority },
                        set: { viewModel.editableBillingAuthority = $0; viewModel.updateAndSaveClient() }
                    )) {
                        if !viewModel.editableIsMinor {
                            Text("Client").tag(BillingAuthority.client)
                        }
                        Text("Parent/Guardian").tag(BillingAuthority.parentGuardian)
                    }
                    .disabled(viewModel.editableIsMinor)
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Parent/Guardian - Only shown when Authority is "Parent/Guardian"
                if viewModel.editableBillingAuthority == .parentGuardian {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Parent/Guardian:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        Picker("", selection: Binding(
                            get: { viewModel.selectedPayee?.id },
                            set: { newPayeeId in
                                viewModel.updatePayee(by: newPayeeId)
                            }
                        )) {
                            Text("Select Parent/Guardian").tag(nil as UUID?)
                            ForEach(viewModel.allPayees) { payee in
                                Text(payee.fullName).tag(payee.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(Animation.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.editableBillingAuthority)
                }
                
                // Credit Amount - Always shown
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Credit:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    HStack {
                        TextField("0.00", text: $viewModel.editableCreditAmountString)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .onChange(of: viewModel.editableCreditAmountString) { viewModel.updateAndSaveClient() }
                        
                        Button(action: { copyToClipboard(viewModel.editableCreditAmountString) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Divider before Email Recipients section
                Divider()
                    .padding(.vertical, 8)
                
                // Email Recipients Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invoice Email Recipients")
                        .font(.title3.weight(.bold))
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .padding(.bottom, 4)
                    
                    // Client Email Recipient
                    if let clientEmail = viewModel.client.email, !clientEmail.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.client.fullName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                Text(clientEmail)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { viewModel.client.sendInvoicesToClient ?? true },
                                set: { viewModel.updateAndSaveClientToggle(sendInvoicesToClient: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    }
                    
                    // Payee Email Recipient
                    if let payee = viewModel.client.payee, let payeeEmail = payee.email, !payeeEmail.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payee.fullName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                Text(payeeEmail)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { viewModel.client.sendInvoicesToPayee ?? true },
                                set: { viewModel.updateAndSaveClientToggle(sendInvoicesToPayee: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    }
                    
                    // Plan Manager Email Recipient
                    if viewModel.client.hasNdisPlan && viewModel.client.planManagementType == "Plan-Managed", 
                       let planManager = viewModel.client.planManager, 
                       let planManagerEmail = planManager.email, 
                       !planManagerEmail.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(planManager.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                Text(planManagerEmail)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { viewModel.client.sendInvoicesToPlanManager ?? true },
                                set: { viewModel.updateAndSaveClientToggle(sendInvoicesToPlanManager: $0) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    }
                    
                    // No email recipients message
                    if (viewModel.client.email?.isEmpty ?? true) && 
                       (viewModel.client.payee?.email?.isEmpty ?? true) && 
                       (viewModel.client.planManager?.email?.isEmpty ?? true) {
                        Text("No email addresses available. Add email addresses to the relevant entities to configure invoice recipients.")
                            .font(.system(size: 11))
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)

                    }
                }
                
                Spacer(minLength: 0)
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "creditcard", title: "Billing Information")
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading billing information...")
    }

    private var serviceAgreementsCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                DetailListBody(
                    isEmpty: viewModel.serviceAgreements.isEmpty,
                    emptyMessage: "No service agreements"
                ) {
                    ForEach(viewModel.serviceAgreements) { agreement in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(serviceAgreementDateRange(agreement))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Cancellation: \(agreement.cancellationPolicyType)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    if agreement.allowsProviderTravel {
                                        Label("Travel", systemImage: "car.fill")
                                            .font(.caption2)
                                    }
                                    if agreement.allowsTelehealth {
                                        Label("Telehealth", systemImage: "video.fill")
                                            .font(.caption2)
                                    }
                                    if agreement.allowsNonFaceToFace {
                                        Label("NF2F", systemImage: "person.2.fill")
                                            .font(.caption2)
                                    }
                                }
                                .foregroundStyle(.secondary)
                                if agreement.isArchived {
                                    Text("Archived")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }

                            Spacer(minLength: 8)

                            Menu {
                                Button("Edit") {
                                    viewModel.prepareToEditServiceAgreement(agreement)
                                }
                                if !agreement.isArchived {
                                    Button("Archive", role: .destructive) {
                                        viewModel.archiveServiceAgreement(agreement)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .menuStyle(.borderlessButton)
                        }
                        .padding(.vertical, 4)
                    }
                }

                HStack {
                    Spacer()
                    Button("Add Agreement") {
                        viewModel.prepareToAddServiceAgreement()
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
                .padding(DetailSectionTokens.listRowInsets)
            }
        } label: {
            DetailSectionHeader(icon: "doc.text", title: "Service Agreements")
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading service agreements...")
    }

    
    private var servicesCard: some View {
        GroupBox {
            VStack {
                DetailListBody(
                    isEmpty: viewModel.clientServices.isEmpty,
                    emptyMessage: "No services assigned",
                    maxHeight: DetailSectionTokens.listMinHeight
                ) {
                    ForEach(sortedServices) { service in
                        CompactServiceRowView(service: service)
                    }
                }
                
                HStack {
                    Spacer()
                    Button("Assign Services") {
                        showingServiceAssignment = true
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
                .padding(DetailSectionTokens.listRowInsets)
                
            }
        } label: {
            DetailSectionHeader(icon: "list.bullet", title: "Services") {
                DetailSectionSortPicker(selection: $servicesSortOrder)
            }
        }
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading services...")
    }
    
    private var invoicesCard: some View {
        GroupBox {
            VStack(spacing: 12) {
                DetailListBody(
                    isEmpty: viewModel.relatedInvoices.isEmpty,
                    emptyMessage: "No invoices found"
                ) {
                    ForEach(sortedInvoices) { invoice in
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
    
    // MARK: - Header Bar
    
    private var clientHeaderBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.editableFullName.isEmpty ? "New Client" : viewModel.editableFullName)
                        .font(.largeTitle.weight(.regular))
                        .kerning(5.0)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .lineLimit(1)
                    
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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
    
    // MARK: - Computed Properties
    

    
    /// Convert domain address to AddressData for UI components
    private var addressData: AddressData {
        get {
            if let address = viewModel.client.address {
                return AddressData(
                    unitNumber: address.unitNumber,
                    streetNumber: address.streetNumber,
                    streetName: address.streetName,
                    suburb: address.suburb,
                    state: address.state,
                    postcode: address.postcode,
                    country: address.country,
                    poBox: address.poBox
                )
            }
            return AddressData()
        }
        set {
            // Address data is updated via ViewModel commitAddressChanges
        }
    }
    
    private var sortedServices: [ClientService] {
        switch servicesSortOrder {
        case .nameAsc:
            return viewModel.clientServices.sorted { $0.serviceName < $1.serviceName }
        case .nameDesc:
            return viewModel.clientServices.sorted { $0.serviceName > $1.serviceName }
        case .rateAsc:
            return viewModel.clientServices.sorted { $0.rate < $1.rate }
        case .rateDesc:
            return viewModel.clientServices.sorted { $0.rate > $1.rate }
        case .dateAddedAsc:
            return viewModel.clientServices.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
        case .dateAddedDesc:
            return viewModel.clientServices.sorted { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) }
        case .dateCreatedAsc:
            return viewModel.clientServices.sorted(by: { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) })
        case .dateCreatedDesc:
            return viewModel.clientServices.sorted(by: { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) })
        }
    }
    
    private var sortedInvoices: [Invoice] {
        switch invoicesSortOrder {
        case .dateAsc:
            return viewModel.relatedInvoices.sorted { $0.issueDate < $1.issueDate }
        case .dateDesc:
            return viewModel.relatedInvoices.sorted { $0.issueDate > $1.issueDate }
        case .dueDateAsc:
            return viewModel.relatedInvoices.sorted { ($0.dueDate ?? Date.distantPast) < ($1.dueDate ?? Date.distantPast) }
        case .dueDateDesc:
            return viewModel.relatedInvoices.sorted { ($0.dueDate ?? Date.distantPast) > ($1.dueDate ?? Date.distantPast) }
        case .invoiceNumber:
            return viewModel.relatedInvoices.sorted { $0.invoiceNumber < $1.invoiceNumber }
        case .amountAsc:
            return viewModel.relatedInvoices.sorted { $0.totalAmount < $1.totalAmount }
        case .amountDesc:
            return viewModel.relatedInvoices.sorted { $0.totalAmount > $1.totalAmount }
        case .clientName:
            return viewModel.relatedInvoices.sorted { $0.status < $1.status }
        case .numberAsc:
            return viewModel.relatedInvoices.sorted { $0.invoiceNumber < $1.invoiceNumber }
        case .numberDesc:
            return viewModel.relatedInvoices.sorted { $0.invoiceNumber > $1.invoiceNumber }
        case .statusAsc:
            return viewModel.relatedInvoices.sorted { $0.status < $1.status }
        case .statusDesc:
            return viewModel.relatedInvoices.sorted { $0.status > $1.status }
        }
    }
    
    // MARK: - Label Width Calculation
    
    private var maxLabelWidth: CGFloat {
        let labels = [
            "Name:",
            "Email:",
            "Phone:",
            "Address:",
            "NDIS:",
            "Type:",
            "Plan Manager:",
            "Authority:",
            "Parent/Guardian:",
            "Credit:",
            "Options:"
        ]
        
        let font = NSFont.systemFont(ofSize: 14)
        let maxWidth = labels.map { label in
            let size = (label as NSString).size(withAttributes: [.font: font])
            return size.width
        }.max() ?? 80
        
        return maxWidth + 20 // Add some padding
    }
    
    // MARK: - Helper Methods
    

    
    private func openInMaps() {
        viewModel.openInMaps()
    }

    private func serviceAgreementDateRange(_ agreement: ServiceAgreement) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let from = formatter.string(from: agreement.effectiveFrom)
        if let to = agreement.effectiveTo {
            return "\(from) - \(formatter.string(from: to))"
        }
        return "\(from) onwards"
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}



// MARK: - Supporting Views





struct AddressEditorView: View {
    @Binding var address: AddressEntity?
    
    @State private var unitNumber = ""
    @State private var streetNumber = ""
    @State private var streetName = ""
    @State private var suburb = ""
    @State private var postcode = ""
    @State private var state = ""
    @State private var country = "Australia"
    @State private var poBox = ""
    
    /// Convert AddressEntity to AddressData for UI components
    private var addressData: AddressData {
        get {
            return address != nil ? AddressData(from: address!) : AddressData()
        }
        set {
            if address == nil {
                address = newValue.toAddressEntity()
            } else {
                // Update existing address
                address?.unitNumber = newValue.unitNumber
                address?.streetNumber = newValue.streetNumber
                address?.streetName = newValue.streetName
                address?.suburb = newValue.suburb
                address?.state = newValue.state
                address?.postcode = newValue.postcode
                address?.country = newValue.country
                address?.poBox = newValue.poBox
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormField("Unit Number") {
                TextField("Unit Number", text: $unitNumber)
            }
            FormField("Street Number") {
                TextField("Street Number", text: $streetNumber)
            }
            FormField("Street Name") {
                TextField("Street Name", text: $streetName)
            }
            FormField("Suburb") {
                TextField("Suburb", text: $suburb)
            }
            HStack {
                FormField("State") {
                    TextField("State", text: $state)
                }
                FormField("Postcode") {
                    TextField("Postcode", text: $postcode)
                }
            }
            FormField("Country") {
                TextField("Country", text: $country)
            }
            FormField("PO Box") {
                TextField("PO Box", text: $poBox)
            }
        }
        .onAppear {
            if let addr = address {
                unitNumber = addr.unitNumber
                streetNumber = addr.streetNumber
                streetName = addr.streetName
                suburb = addr.suburb
                postcode = addr.postcode
                state = addr.state
                country = addr.country
                poBox = addr.poBox
            }
        }
        .onChange(of: unitNumber) { updateAddress() }
        .onChange(of: streetNumber) { updateAddress() }
        .onChange(of: streetName) { updateAddress() }
        .onChange(of: suburb) { updateAddress() }
        .onChange(of: postcode) { updateAddress() }
        .onChange(of: state) { updateAddress() }
        .onChange(of: country) { updateAddress() }
        .onChange(of: poBox) { updateAddress() }
    }
    
    private func updateAddress() {
        // Create AddressData from current form values
        var addressData = AddressData()
        addressData.unitNumber = unitNumber
        addressData.streetNumber = streetNumber
        addressData.streetName = streetName
        addressData.suburb = suburb
        addressData.postcode = postcode
        addressData.state = state
        addressData.country = country
        addressData.poBox = poBox
        
        // Update the address directly
        if address == nil {
            address = addressData.toAddressEntity()
        } else {
            // Update existing address
            address?.unitNumber = addressData.unitNumber
            address?.streetNumber = addressData.streetNumber
            address?.streetName = addressData.streetName
            address?.suburb = addressData.suburb
            address?.state = addressData.state
            address?.postcode = addressData.postcode
            address?.country = addressData.country
            address?.poBox = addressData.poBox
        }
    }
}

// MARK: - Address Helper Methods

extension ClientDetailView {
    private var hasAddressData: Bool {
        // Check state variables (for editing)
        let hasStateData = !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty || 
        !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty || 
        !country.isEmpty || !poBox.isEmpty
        
        // Check existing address from domain model
        let hasExistingAddress = viewModel.client.address != nil && !viewModel.client.address!.fullFormattedAddress.isEmpty
        
        return hasStateData || hasExistingAddress
    }
    
    private var compactAddressView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("Address:")
                .frame(width: maxLabelWidth, alignment: .trailing)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if hasAddressData {
                    Text(formatAddressForDisplay())
                        .font(.system(size: 14))
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                } else {
                    Text("No address added")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
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
                                .foregroundColor(.blue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        
                        Button(action: {
                            showingAddressEditingSheet = true
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.orange)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                    }
                } else {
                    Button(action: {
                        showingAddressEditingSheet = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.green)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func formatAddressForDisplay() -> String {
        var parts: [String] = []
        
        if !poBox.isEmpty {
            parts.append("PO Box \(poBox)")
        } else {
            if !unitNumber.isEmpty { parts.append("Unit \(unitNumber)") }
            if !streetNumber.isEmpty { parts.append(streetNumber) }
            if !streetName.isEmpty { parts.append(streetName) }
        }
        
        if !suburb.isEmpty { parts.append(suburb) }
        if !state.isEmpty { parts.append(state) }
        if !postcode.isEmpty { parts.append(postcode) }
        if !country.isEmpty { parts.append(country) }
        
        return parts.joined(separator: ", ")
    }
    
    private func getCurrentAddressString() -> String {
        // If we have existing address data, use that
        if let address = viewModel.client.address, !address.fullFormattedAddress.isEmpty {
            return address.fullFormattedAddress
        }
        
        // Otherwise use the state variables for compact address
        return formatAddressForDisplay()
    }
}

// MARK: - Client Address Editing Sheet

struct ClientAddressEditingSheet: View {
    @ObservedObject var viewModel: ClientDetailViewModel
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
    
    /// Convert AddressEntity to AddressData for UI components
    private var addressData: AddressData {
        get {
            return AddressData()
        }
        set {
            // Unused
        }
    }
    
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
                        commitAddressChanges()
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
            loadExistingAddressData()
        }
    }
    
    private func loadExistingAddressData() {
        // Load from ViewModel (already loaded from entity)
        unitNumber = viewModel.editableUnitNumber
        streetNumber = viewModel.editableStreetNumber
        streetName = viewModel.editableStreetName
        suburb = viewModel.editableSuburb
        postcode = viewModel.editablePostcode
        state = viewModel.editableState
        country = viewModel.editableCountry
        poBox = viewModel.editablePoBox
        
        // Construct display string from VM properties for search text if needed
        let address = Address(
            id: UUID(),
            unitNumber: unitNumber,
            streetNumber: streetNumber,
            streetName: streetName,
            suburb: suburb,
            city: viewModel.editableCity,
            state: state,
            postcode: postcode,
            country: country,
            poBox: poBox,
            latitude: 0,
            longitude: 0
        )
        addressSearchText = address.fullFormattedAddress
    }
    
    private var hasAddressData: Bool {
        // Check state variables (for editing)
        return !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty || 
               !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty || 
               !country.isEmpty || !poBox.isEmpty
    }
    
    private func commitAddressChanges() {
        // Update ViewModel properties with form data
        viewModel.editableUnitNumber = unitNumber
        viewModel.editableStreetNumber = streetNumber
        viewModel.editableStreetName = streetName
        viewModel.editableSuburb = suburb
        viewModel.editablePostcode = postcode
        viewModel.editableState = state
        viewModel.editableCountry = country
        viewModel.editablePoBox = poBox
        
        // Trigger VM to commit changes to client
        viewModel.commitAddressChanges()
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
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("Unit number (optional)", text: $unitNumber)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // Street Number and Name
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Street:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TextField("Number", text: $streetNumber)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                        .frame(width: 80)
                    
                    TextField("Street name", text: $streetName)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Suburb
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Suburb:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("Enter suburb", text: $suburb)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // State and Postcode
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("State:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    TextField("State", text: $state)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                    
                    TextField("Postcode", text: $postcode)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Country
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Country:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("Enter country", text: $country)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // PO Box
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PO Box:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("PO Box number (optional)", text: $poBox)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
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
}

private struct ServiceAgreementEditorSheet: View {
    @ObservedObject var viewModel: ClientDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Effective From", selection: binding(\.effectiveFrom, default: Date()), displayedComponents: .date)

                Toggle(
                    "Open-ended",
                    isOn: Binding(
                        get: { viewModel.serviceAgreementToEdit?.effectiveTo == nil },
                        set: { isOpenEnded in
                            guard var agreement = viewModel.serviceAgreementToEdit else { return }
                            if isOpenEnded {
                                agreement.effectiveTo = nil
                            } else if agreement.effectiveTo == nil {
                                agreement.effectiveTo = Calendar.current.date(byAdding: .year, value: 1, to: agreement.effectiveFrom)
                            }
                            viewModel.serviceAgreementToEdit = agreement
                        }
                    )
                )

                if viewModel.serviceAgreementToEdit?.effectiveTo != nil {
                    DatePicker(
                        "Effective To",
                        selection: Binding(
                            get: {
                                viewModel.serviceAgreementToEdit?.effectiveTo
                                    ?? Calendar.current.date(byAdding: .year, value: 1, to: Date())
                                    ?? Date()
                            },
                            set: { newDate in
                                guard var agreement = viewModel.serviceAgreementToEdit else { return }
                                agreement.effectiveTo = newDate
                                viewModel.serviceAgreementToEdit = agreement
                            }
                        ),
                        displayedComponents: .date
                    )
                }

                Picker("Cancellation Policy", selection: binding(\.cancellationPolicyType, default: CancellationPolicyType.twoClearBusinessDays.rawValue)) {
                    ForEach(CancellationPolicyType.allCases, id: \.rawValue) { policy in
                        Text(policy.rawValue).tag(policy.rawValue)
                    }
                }

                Toggle("Allows Provider Travel", isOn: binding(\.allowsProviderTravel, default: false))
                Toggle("Allows Telehealth", isOn: binding(\.allowsTelehealth, default: false))
                Toggle("Allows Non Face-to-Face", isOn: binding(\.allowsNonFaceToFace, default: false))

                TextField(
                    "Signatory Name (optional)",
                    text: Binding(
                        get: { viewModel.serviceAgreementToEdit?.participantSignatoryName ?? "" },
                        set: { updateOptionalString(\.participantSignatoryName, to: $0) }
                    )
                )

                TextField(
                    "Signatory Role (optional)",
                    text: Binding(
                        get: { viewModel.serviceAgreementToEdit?.participantSignatoryRole ?? "" },
                        set: { updateOptionalString(\.participantSignatoryRole, to: $0) }
                    )
                )

                Picker(
                    "Signature Method",
                    selection: Binding(
                        get: { viewModel.serviceAgreementToEdit?.signatureMethod ?? SignatureMethod.attestation.rawValue },
                        set: { updateOptionalString(\.signatureMethod, to: $0) }
                    )
                ) {
                    ForEach(SignatureMethod.allCases, id: \.rawValue) { method in
                        Text(method.rawValue.capitalized).tag(method.rawValue)
                    }
                }

                DatePicker(
                    "Signed At",
                    selection: Binding(
                        get: { viewModel.serviceAgreementToEdit?.signedAt ?? Date() },
                        set: { updateOptionalDate(\.signedAt, to: $0) }
                    ),
                    displayedComponents: .date
                )

                TextField(
                    "Notes (optional)",
                    text: Binding(
                        get: { viewModel.serviceAgreementToEdit?.notes ?? "" },
                        set: { updateOptionalString(\.notes, to: $0) }
                    )
                )

                if let error = viewModel.serviceAgreementValidationError,
                   !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Service Agreement")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelServiceAgreementEdit()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveServiceAgreement()
                    }
                }
            }
        }
    }

    private func binding<T>(_ keyPath: WritableKeyPath<ServiceAgreement, T>, default defaultValue: T) -> Binding<T> {
        Binding(
            get: { viewModel.serviceAgreementToEdit?[keyPath: keyPath] ?? defaultValue },
            set: { newValue in
                guard var agreement = viewModel.serviceAgreementToEdit else { return }
                agreement[keyPath: keyPath] = newValue
                viewModel.serviceAgreementToEdit = agreement
            }
        )
    }

    private func updateOptionalString(_ keyPath: WritableKeyPath<ServiceAgreement, String?>, to value: String) {
        guard var agreement = viewModel.serviceAgreementToEdit else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        agreement[keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
        viewModel.serviceAgreementToEdit = agreement
    }

    private func updateOptionalDate(_ keyPath: WritableKeyPath<ServiceAgreement, Date?>, to value: Date) {
        guard var agreement = viewModel.serviceAgreementToEdit else { return }
        agreement[keyPath: keyPath] = value
        viewModel.serviceAgreementToEdit = agreement
    }
}
