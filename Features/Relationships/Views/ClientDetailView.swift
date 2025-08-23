import SwiftUI
import SwiftData

// MARK: - Billing Authority Enum
enum BillingAuthority: String, CaseIterable, Identifiable {
    case client = "Client"
    case guardian = "Parent/Guardian"
    var id: String { self.rawValue }
}

struct ClientDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Use @Bindable for better SwiftData integration
    @Bindable var client: ClientEntity
    let isCreatingNew: Bool
    let onSave: (() -> Void)?
    
    // Add ViewModel for service management
    @StateObject private var viewModel: ClientDetailViewModel
    
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
    
    // Real-time queries for related data
    @Query private var clientServices: [ClientServiceEntity]
    @Query private var relatedInvoices: [InvoiceEntity]
    @Query private var allPayees: [PayeeEntity]
    @Query private var allPlanManagers: [PlanManagerEntity]
    
    // Sorting state
    @State private var servicesSortOrder: ServicesSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc
    
    init(client: ClientEntity, context: ModelContext, onSave: (() -> Void)? = nil) {
        self.client = client
        self.isCreatingNew = false
        self.onSave = onSave
        
        // Initialize ViewModel
        self._viewModel = StateObject(wrappedValue: ClientDetailViewModel(client: client, context: context, isCreating: false))
        
        // Set up queries for this specific client
        let clientID = client.id
        _clientServices = Query(filter: #Predicate { $0.client?.id == clientID }, sort: \ClientServiceEntity.startDate)
        _relatedInvoices = Query(filter: #Predicate { $0.client?.id == clientID }, sort: \InvoiceEntity.issueDate)
        _allPayees = Query(sort: \PayeeEntity.fullName)
        _allPlanManagers = Query(sort: \PlanManagerEntity.businessName)
        
        // Load existing address data
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
    
    init(context: ModelContext, onSave: (() -> Void)? = nil) {
        let newClient = ClientEntity(id: UUID(), ndisNumber: "", fullName: "", status: "Active", colorHex: "#0433FF")
        self.client = newClient
        self.isCreatingNew = true
        self.onSave = onSave
        
        // Initialize ViewModel for new client
        self._viewModel = StateObject(wrappedValue: ClientDetailViewModel(client: newClient, context: context, isCreating: true))
        
        // Set up empty queries for new client
        _clientServices = Query(filter: #Predicate { _ in false })
        _relatedInvoices = Query(filter: #Predicate { _ in false })
        _allPayees = Query(sort: \PayeeEntity.fullName)
        _allPlanManagers = Query(sort: \PlanManagerEntity.businessName)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            clientHeaderBar
            
            // Main Content
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    // Main content with ViewThatFits for adaptive layout
                    ViewThatFits {
                        // Primary layout: 2x2 grid (2 columns, 2 rows)
                        VStack(spacing: 20) {
                            // Row 1: 2 columns
                            HStack(spacing: 20) {
                                clientInfoCard
                                    .frame(maxWidth: .infinity)
                                billingInfoCard
                                    .frame(maxWidth: .infinity)
                            }
                            
                            // Row 2: 2 columns
                            HStack(spacing: 20) {
                                servicesCard
                                    .frame(maxWidth: .infinity)
                                invoicesCard
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        
                        // Fallback layout: 1x4 grid (1 column, 4 rows)
                        VStack(spacing: 20) {
                            clientInfoCard
                            billingInfoCard
                            servicesCard
                            invoicesCard
                        }
                    }
                }
                .padding(24)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundColor(.white)

        .sheet(isPresented: $showingServiceAssignment) {
            ServiceAssignmentSheetView(
                client: client,
                alreadySelectedItems: [],
                onProceed: { selectedItems in
                    viewModel.prepareForBulkServiceCreation(from: selectedItems)
                }
            )
        }
        .sheet(isPresented: $viewModel.isPresentingServiceBulkEditor) {
            ServiceBulkEditorView(
                templates: $viewModel.serviceTemplates,
                onSave: { templates in
                    viewModel.commitServices(fromTemplates: templates)
                }
            )
        }
        .sheet(isPresented: $showingMapSheet) {
            InteractiveMapView(address: getCurrentAddressString())
        }
        .sheet(isPresented: $showingAddressEditingSheet) {
            ClientAddressEditingSheet(
                client: client,
                isPresented: $showingAddressEditingSheet
            )
        }

        
    }
    
    // MARK: - Card Views
    
    private var clientInfoCard: some View {
        GroupBox("Client Information") {
            VStack(spacing: 12) {
                                    // Name
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Name:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                    
                    HStack {
                        TextField("Enter client name", text: $client.fullName)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.white)
                            .accentColor(.blue)
                        
                        Button(action: { copyToClipboard(client.fullName) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                                    // Email
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Email:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                    
                    HStack {
                        TextField("Enter email address", text: Binding(
                            get: { client.email ?? "" },
                            set: { client.email = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                        .accentColor(.blue)
                        
                        Button(action: { copyToClipboard(client.email ?? "") }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                                    // Phone
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Phone:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                    
                    HStack {
                        TextField("Enter phone number", text: Binding(
                            get: { client.phone ?? "" },
                            set: { client.phone = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(.white)
                        .accentColor(.blue)
                        
                        Button(action: { copyToClipboard(client.phone ?? "") }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Address
                compactAddressView
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: hasAddressData)
                
                // Divider before NDIS section
                Divider()
                    .glassEffect(.regular, in: .rect())
                    .padding(.vertical, 8)
                
                // Has NDIS Plan - Top of NDIS section
                HStack(alignment: .center, spacing: 6) {
                    Text("Has NDIS Plan:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(.white)
                    
                    Toggle("", isOn: $client.hasNdisPlan)
                        .toggleStyle(.switch)
                        .foregroundColor(.white)
                        .labelsHidden()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // NDIS Number - Only shown when "Has NDIS Plan" is true
                if client.hasNdisPlan {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("NDIS:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        HStack {
                            TextField("Enter NDIS number", text: $client.ndisNumber)
                                .textFieldStyle(.roundedBorder)
                                .foregroundColor(.white)
                                .accentColor(.blue)
                            
                            Button(action: { copyToClipboard(client.ndisNumber) }) {
                                Image(systemName: "doc.on.doc")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: client.hasNdisPlan)
                }
                
                // Plan Management Type - Only shown when "Has NDIS Plan" is true
                if client.hasNdisPlan {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Type:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        Picker("", selection: Binding(
                            get: { client.planManagementType ?? "Self-Managed" },
                            set: { client.planManagementType = $0 }
                        )) {
                            Text("Self-Managed").tag("Self-Managed")
                            Text("Plan-Managed").tag("Plan-Managed")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: client.hasNdisPlan)
                }
                
                // Plan Manager - Only shown when Type is "Plan-Managed"
                if client.hasNdisPlan && client.planManagementType == "Plan-Managed" {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Plan Manager:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        Picker("", selection: Binding(
                            get: { client.planManager },
                            set: { client.planManager = $0 }
                        )) {
                            Text("Select Plan Manager").tag(nil as PlanManagerEntity?)
                            ForEach(allPlanManagers) { planManager in
                                Text(planManager.businessName ?? "Unnamed Plan Manager").tag(planManager as PlanManagerEntity?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: client.planManagementType)
                }
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: 120)
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .modifier(LiquidGlassGroupBoxModifier())
    }
    

    

    
    private var billingInfoCard: some View {
        GroupBox("Billing Information") {
            VStack(spacing: 8) {
                // Options - Always shown first
                HStack(spacing: 16) {
                    // Is Minor
                    HStack(alignment: .center, spacing: 6) {
                        Text("Is Minor:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        Toggle("", isOn: $client.isMinor)
                            .toggleStyle(.switch)
                            .foregroundColor(.white)
                            .labelsHidden()
                            .onChange(of: client.isMinor) { _, isMinor in
                                if isMinor {
                                    client.billingAuthority = "Parent/Guardian"
                                }
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
                        .foregroundColor(.white)
                    
                    Picker("", selection: Binding(
                        get: { client.billingAuthority ?? "Client" },
                        set: { client.billingAuthority = $0 }
                    )) {
                        if !client.isMinor {
                            Text("Client").tag("Client")
                        }
                        Text("Parent/Guardian").tag("Parent/Guardian")
                    }
                    .disabled(client.isMinor)
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Parent/Guardian - Only shown when Authority is "Parent/Guardian"
                if client.billingAuthority == "Parent/Guardian" {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text("Parent/Guardian:")
                            .frame(width: maxLabelWidth, alignment: .trailing)
                            .foregroundColor(.white)
                        
                        Picker("", selection: Binding(
                            get: { client.payee },
                            set: { client.payee = $0 }
                        )) {
                            Text("Select Parent/Guardian").tag(nil as PayeeEntity?)
                            ForEach(allPayees) { payee in
                                Text(payee.fullName).tag(payee as PayeeEntity?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                    .animation(.easeInOut(duration: 0.3), value: client.billingAuthority)
                }
                
                // Credit Amount - Always shown
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Credit:")
                        .frame(width: maxLabelWidth, alignment: .trailing)
                        .foregroundColor(.white)
                    
                    HStack {
                        TextField("0.00", text: Binding(
                            get: { String(format: "%.2f", client.creditAmount) },
                            set: { client.creditAmount = Double($0) ?? 0.0 }
                        ))
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(.white)
                            .accentColor(.blue)
                        
                        Button(action: { copyToClipboard(String(format: "%.2f", client.creditAmount)) }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Divider before Email Recipients section
                Divider()
                    .glassEffect(.regular, in: .rect())
                    .padding(.vertical, 8)
                
                // Email Recipients Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Invoice Email Recipients")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.bottom, 4)
                    
                    // Client Email Recipient
                    if let clientEmail = client.email, !clientEmail.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.fullName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                Text(clientEmail)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { client.sendInvoicesToClient ?? true },
                                set: { client.sendInvoicesToClient = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    }
                    
                    // Payee Email Recipient
                    if let payee = client.payee, let payeeEmail = payee.email, !payeeEmail.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payee.fullName)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                Text(payeeEmail)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { client.sendInvoicesToPayee ?? true },
                                set: { client.sendInvoicesToPayee = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    }
                    
                    // Plan Manager Email Recipient
                    if client.hasNdisPlan && client.planManagementType == "Plan-Managed", 
                       let planManager = client.planManager, 
                       let planManagerEmail = planManager.email, 
                       !planManagerEmail.isEmpty {
                        HStack(alignment: .center, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(planManager.businessName ?? "Unnamed Plan Manager")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                Text(planManagerEmail)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { client.sendInvoicesToPlanManager ?? true },
                                set: { client.sendInvoicesToPlanManager = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    }
                    
                    // No email recipients message
                    if (client.email?.isEmpty ?? true) && 
                       (client.payee?.email?.isEmpty ?? true) && 
                       (client.planManager?.email?.isEmpty ?? true) {
                        Text("No email addresses available. Add email addresses to the relevant entities to configure invoice recipients.")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassEffect(.regular, in: .rect(cornerRadius: 6))
                    }
                }
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: 120)
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .modifier(LiquidGlassGroupBoxModifier())
    }
    

    
    private var servicesCard: some View {
        GroupBox {
            VStack(spacing: 8) {
                if clientServices.isEmpty {
                    Text("No services assigned")
                        .foregroundColor(.gray)
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(sortedServices) { service in
                                CompactServiceRowView(service: service)
                            }
                        }
                        .padding(.horizontal, 0)
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 200)
                }
                
                HStack {
                    Spacer()
                    Button("Assign Services") {
                        showingServiceAssignment = true
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                }
                
                Spacer(minLength: 0)
            }
            .frame(minHeight: 120)
        } label: {
            HStack {
                Text("Services")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Picker("Sort", selection: $servicesSortOrder) {
                    ForEach(ServicesSortOrder.allCases, id: \.self) { sortOrder in
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
    
    private var invoicesCard: some View {
        GroupBox {
            VStack(spacing: 8) {
                if relatedInvoices.isEmpty {
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
    
    // MARK: - Header Bar
    
    private var clientHeaderBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(client.fullName.isEmpty ? "New Client" : client.fullName)
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
    
    // MARK: - Computed Properties
    
    private var sortedServices: [ClientServiceEntity] {
        switch servicesSortOrder {
        case .nameAsc:
            return clientServices.sorted { $0.serviceName < $1.serviceName }
        case .nameDesc:
            return clientServices.sorted { $0.serviceName > $1.serviceName }
        case .rateAsc:
            return clientServices.sorted { $0.rate < $1.rate }
        case .rateDesc:
            return clientServices.sorted { $0.rate > $1.rate }
        case .dateAddedAsc:
            return clientServices.sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
        case .dateAddedDesc:
            return clientServices.sorted { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) }
        case .dateCreatedAsc:
            return clientServices.sorted(by: { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) })
        case .dateCreatedDesc:
            return clientServices.sorted(by: { ($0.startDate ?? Date.distantPast) > ($1.startDate ?? Date.distantPast) })
        }
    }
    
    private var sortedInvoices: [InvoiceEntity] {
        switch invoicesSortOrder {
        case .dateAsc:
            return relatedInvoices.sorted { $0.issueDate < $1.issueDate }
        case .dateDesc:
            return relatedInvoices.sorted { $0.issueDate > $1.issueDate }
        case .numberAsc:
            return relatedInvoices.sorted { $0.invoiceNumber < $1.invoiceNumber }
        case .numberDesc:
            return relatedInvoices.sorted { $0.invoiceNumber > $1.invoiceNumber }
        case .amountAsc:
            return relatedInvoices.sorted { $0.totalAmount < $1.totalAmount }
        case .amountDesc:
            return relatedInvoices.sorted { $0.totalAmount > $1.totalAmount }
        case .statusAsc:
            return relatedInvoices.sorted { ($0.status ?? "") < ($1.status ?? "") }
        case .statusDesc:
            return relatedInvoices.sorted { ($0.status ?? "") > ($1.status ?? "") }
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
    
    private func saveContext() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            print("Error saving context: \(error)")
            return false
        }
    }
    
    private func createClientAndDismiss() {
        let trimmedName = client.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { return }
        
        client.fullName = trimmedName
        
        if isCreatingNew {
            modelContext.insert(client)
        }
        
        if saveContext() {
            if isCreatingNew && onSave != nil {
                onSave?()
            } else {
                dismiss()
            }
        }
    }
    
    private func deleteClientAndDismiss() {
        modelContext.delete(client)
        if saveContext() {
            dismiss()
        }
    }
    
    private func openInMaps() {
        guard let address = client.address else { return }
        let query = address.formattedAddress
        if let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "maps://?q=\(encodedQuery)") {
            NSWorkspace.shared.open(url)
        }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            FormField(label: "Unit Number", text: $unitNumber)
            FormField(label: "Street Number", text: $streetNumber)
            FormField(label: "Street Name", text: $streetName)
            FormField(label: "Suburb", text: $suburb)
            HStack {
                FormField(label: "State", text: $state)
                FormField(label: "Postcode", text: $postcode)
            }
            FormField(label: "Country", text: $country)
            FormField(label: "PO Box", text: $poBox)
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
        if address == nil {
            address = AddressEntity()
        }
        
        address?.unitNumber = unitNumber
        address?.streetNumber = streetNumber
        address?.streetName = streetName
        address?.suburb = suburb
        address?.postcode = postcode
        address?.state = state
        address?.country = country
        address?.poBox = poBox
    }
}

// MARK: - Address Helper Methods

extension ClientDetailView {
    private var hasAddressData: Bool {
        // Check state variables (for editing)
        let hasStateData = !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty || 
        !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty || 
        !country.isEmpty || !poBox.isEmpty
        
        // Check existing address from entity
        let hasExistingAddress = client.address != nil && !client.address!.fullAddressText.isEmpty
        
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
        if let address = client.address, !address.fullAddressText.isEmpty {
            return address.formattedAddress
        }
        
        // Otherwise use the state variables for compact address
        return formatAddressForDisplay()
    }
    
    private func currentAddressView(_ address: AddressEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Address:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Edit") {
                        // Populate form fields with existing address data
                        unitNumber = address.unitNumber
                        streetNumber = address.streetNumber
                        streetName = address.streetName
                        suburb = address.suburb
                        state = address.state
                        postcode = address.postcode
                        country = address.country
                        poBox = address.poBox
                        addressSearchText = address.fullAddressText
                    }
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    
                    Button("Clear") {
                        // Clear all address fields
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
                    .buttonStyle(.glass)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
            
            Text(address.fullFormattedAddress)
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .rect(cornerRadius: 6))
        }
    }
}

// MARK: - Client Address Editing Sheet

struct ClientAddressEditingSheet: View {
    @Bindable var client: ClientEntity
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
        if let address = client.address {
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
        let hasExistingAddress = client.address != nil && !client.address!.fullAddressText.isEmpty
        
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
        let address = client.address ?? AddressEntity()
        address.unitNumber = unitNumber
        address.streetNumber = streetNumber
        address.streetName = streetName
        address.suburb = suburb
        address.postcode = postcode
        address.state = state
        address.country = country
        address.poBox = poBox
        
        client.address = address
    }
}
