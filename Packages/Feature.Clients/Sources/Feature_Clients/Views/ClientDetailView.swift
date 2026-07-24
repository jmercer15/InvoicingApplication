import AppKit
import SwiftUI
import SwiftData
import Core
import Data
import SharedUI
import Observation

// MARK: - Helper Functions

// Import helper functions from Data package to avoid Codable conflicts
// Helper functions defined in:
// - Packages/Data/Sources/Data/Mapping/Client+Mapping.swift (clientFromEntity, payeeFromEntity, planManagerFromEntity)
// - Packages/Data/Sources/Data/Mapping/Invoice+Mapping.swift (invoiceFromEntity)

// MARK: - Billing Authority Enum

struct ClientDetailView: View {
    private let injectedModelContext: ModelContext
    let clientId: UUID

    @Environment(\.dismiss) var dismiss

    @State private var viewModel: ClientDetailViewModel

    let isCreatingNew: Bool
    let onSave: (() -> Void)?
    let onOpenInvoice: (UUID) -> Void
    
    // Enhanced state management
    @State private var showingServiceAssignment = false
    @State private var reopenServiceAssignmentAfterBulkEditor = false
    @State private var showingMapSheet = false
    @State private var showingAddressEditingSheet = false
    
    // Note: clientServices and relatedInvoices now come from viewModel (domain models)
    
    // Sorting state
    @State private var servicesSortOrder: ServicesSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc
    
    init(
        client: Client,
        modelContext: ModelContext,
        onSave: (() -> Void)? = nil,
        onOpenInvoice: @escaping (UUID) -> Void = { _ in }
    ) {
        let cid = client.id
        self.clientId = cid
        self.injectedModelContext = modelContext
        self.isCreatingNew = false
        self.onSave = onSave
        self.onOpenInvoice = onOpenInvoice
        self._viewModel = State(initialValue: ClientDetailViewModel(
            client: client,
            modelContext: modelContext,
            isCreating: false
        ))
    }
    
    init(
        modelContext: ModelContext,
        onSave: (() -> Void)? = nil,
        onOpenInvoice: @escaping (UUID) -> Void = { _ in }
    ) {
        let newClient = Client(id: UUID(), ndisNumber: "", fullName: "", status: "Active")
        let cid = newClient.id
        self.clientId = cid
        self.injectedModelContext = modelContext
        self.isCreatingNew = true
        self.onSave = onSave
        self.onOpenInvoice = onOpenInvoice
        self._viewModel = State(initialValue: ClientDetailViewModel(
            client: newClient,
            modelContext: modelContext,
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
        .foregroundColor(StyleGuide.Colors.text)
        .sheet(isPresented: $showingServiceAssignment) {
            ServiceAssignmentSheetContainer(
                client: viewModel.client,
                alreadySelectedItems: viewModel.assignedNDISItems,
                onProceed: { selectedItems in
                    viewModel.prepareForBulkServiceCreation(from: selectedItems)
                }
            )
            .fluidSheetTransition()
            .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: showingServiceAssignment)
        }
        .sheet(isPresented: $viewModel.isPresentingServiceBulkEditor, onDismiss: {
            guard reopenServiceAssignmentAfterBulkEditor else { return }
            reopenServiceAssignmentAfterBulkEditor = false
            showingServiceAssignment = true
        }) {
            ServiceBulkEditorView(
                templates: $viewModel.serviceTemplates,
                onSave: { templates in
                    viewModel.commitServices(fromTemplates: templates)
                },
                onBackToServiceSelection: {
                    reopenServiceAssignmentAfterBulkEditor = true
                }
            )
            .fluidSheetTransition()
            .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: viewModel.isPresentingServiceBulkEditor)
        }
        .sheet(isPresented: $viewModel.isPresentingServiceAgreementSheet) {
            ServiceAgreementEditorSheet(viewModel: viewModel)
                .fluidSheetTransition()
                .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: viewModel.isPresentingServiceAgreementSheet)
        }
        .sheet(isPresented: $showingMapSheet) {
            InteractiveMapView(address: getCurrentAddressString())
            .fluidSheetTransition()
            .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: showingMapSheet)
        }
        .sheet(isPresented: $showingAddressEditingSheet) {
            ClientAddressEditingSheet(
                viewModel: viewModel,
                isPresented: $showingAddressEditingSheet
            )
            .fluidSheetTransition()
            .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: showingAddressEditingSheet)
        }
        .toolbar {
            AppToolbarSheetBar(
                confirmTitle: isCreatingNew ? "Create Client" : "Save Changes",
                showsCancel: isCreatingNew,
                isConfirmDisabled: viewModel.editableFullName.isEmpty,
                onCancel: { dismiss() },
                onConfirm: { viewModel.saveClientDetailsAndDismiss() }
            )
        }
        .onAppear {
            viewModel.dismiss = {
                dismiss()
                onSave?()
            }
        }
        .task(id: viewModel.client.id) {
            let actor = ReferenceDataWorkflowActor(modelContainer: injectedModelContext.container)
            await viewModel.refreshProjectedData(using: actor)
        }
        .task {
            let actor = ReferenceDataWorkflowActor(modelContainer: injectedModelContext.container)
            await viewModel.loadReferencePickers(using: actor)
        }

        
    }
    
    // MARK: - Card Views
    
    private var clientInfoCard: some View {
        ClientDetailClientInformationCard(
            viewModel: viewModel,
            maxLabelWidth: maxLabelWidth,
            planManagers: viewModel.planManagerCatalogue,
            hasAddressData: hasAddressData
        ) {
            compactAddressView
        }
    }
    

    

    
    private var billingInfoCard: some View {
        ClientDetailBillingInfoCard(
            viewModel: viewModel,
            maxLabelWidth: maxLabelWidth,
            payeeEntities: viewModel.payeeCatalogue
        )
    }

    private var serviceAgreementsCard: some View {
        ClientDetailServiceAgreementsCard(viewModel: viewModel)
    }

    private var servicesCard: some View {
        ClientDetailServicesCard(
            viewModel: viewModel,
            sortedServices: sortedServices,
            servicesSortOrder: $servicesSortOrder,
            showingServiceAssignment: $showingServiceAssignment
        )
    }

    private var invoicesCard: some View {
        ClientDetailInvoicesCard(
            viewModel: viewModel,
            sortedInvoices: sortedInvoices,
            invoicesSortOrder: $invoicesSortOrder,
            onOpenInvoice: onOpenInvoice
        )
    }
    
    // MARK: - Header Bar
    
    private var clientHeaderBar: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack(spacing: DetailToolbarTokens.titleBadgeSpacing) {
                Image(systemName: "person.circle.fill")
                    .font(StyleGuide.Typography.detailHeaderIcon)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)

                VStack(alignment: .leading, spacing: DetailToolbarTokens.titleSubtitleSpacing) {
                    Text(viewModel.editableFullName.isEmpty ? "New Client" : viewModel.editableFullName)
                        .font(StyleGuide.Typography.hero)
                        .kerning(5.0)
                        .foregroundStyle(StyleGuide.Colors.text)
                        .lineLimit(1)

                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
                .fixedSize(horizontal: true, vertical: true)

                if !viewModel.editableStatus.isEmpty {
                    StatusBadge(status: viewModel.editableStatus.capitalized)
                }

                Spacer()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
        .padding(.top, StyleGuide.Dimensions.paddingXLarge)
        .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
    }
    
    // MARK: - Computed Properties
    

    
    private var sortedServices: [ClientService] {
        viewModel.clientServices.sorted(using: servicesSortOrder)
    }

    private var sortedInvoices: [Invoice] {
        viewModel.relatedInvoices.sorted(using: invoicesSortOrder)
    }
    
    // MARK: - Label Width Calculation
    
    private var maxLabelWidth: CGFloat {
        RelationshipDetailLabelMetrics.maxWidth(for: [
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
        ])
    }
    
}



// MARK: - Supporting Views





// MARK: - Address Helper Methods

extension ClientDetailView {
    private var hasAddressData: Bool {
        let hasEditableAddress = !viewModel.editableUnitNumber.isEmpty ||
            !viewModel.editableStreetNumber.isEmpty ||
            !viewModel.editableStreetName.isEmpty ||
            !viewModel.editableSuburb.isEmpty ||
            !viewModel.editableState.isEmpty ||
            !viewModel.editablePostcode.isEmpty ||
            !viewModel.editableCountry.isEmpty ||
            !viewModel.editablePoBox.isEmpty

        // Check existing address from domain model
        let hasExistingAddress = viewModel.client.address != nil && !viewModel.client.address!.fullFormattedAddress.isEmpty
        
        return hasEditableAddress || hasExistingAddress
    }
    
    private var compactAddressView: some View {
        RelationshipDetailAddressRow(
            maxLabelWidth: maxLabelWidth,
            hasAddressData: hasAddressData,
            addressText: formatAddressForDisplay(),
            showingMapSheet: $showingMapSheet,
            showingAddressEditingSheet: $showingAddressEditingSheet
        )
    }
    
    private func formatAddressForDisplay() -> String {
        var parts: [String] = []
        
        if !viewModel.editablePoBox.isEmpty {
            parts.append("PO Box \(viewModel.editablePoBox)")
        } else {
            if !viewModel.editableUnitNumber.isEmpty { parts.append("Unit \(viewModel.editableUnitNumber)") }
            if !viewModel.editableStreetNumber.isEmpty { parts.append(viewModel.editableStreetNumber) }
            if !viewModel.editableStreetName.isEmpty { parts.append(viewModel.editableStreetName) }
        }
        
        if !viewModel.editableSuburb.isEmpty { parts.append(viewModel.editableSuburb) }
        if !viewModel.editableState.isEmpty { parts.append(viewModel.editableState) }
        if !viewModel.editablePostcode.isEmpty { parts.append(viewModel.editablePostcode) }
        if !viewModel.editableCountry.isEmpty { parts.append(viewModel.editableCountry) }

        if parts.isEmpty, let address = viewModel.client.address {
            return address.fullFormattedAddress
        }
        
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
