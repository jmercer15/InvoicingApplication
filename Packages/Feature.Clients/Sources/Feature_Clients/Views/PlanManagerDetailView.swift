import SwiftUI
import AppKit // For NSColor, NSPasteboard
import MapKit // For address map view
import SwiftData
import Core
import PersistenceModels
import SharedUI
import WorkspaceUI
import Observation

// MARK: - PlanManagerDetailView

struct PlanManagerDetailView: View {
    let planManagerId: UUID
    let onOpenInvoice: (UUID) -> Void
    let onOpenClient: (UUID) -> Void
    @State private var viewModel: PlanManagerDetailViewModel

    // UI state only
    @State private var activeSheet: PlanManagerDetailSheet?

    private enum PlanManagerDetailSheet: Identifiable {
        case map
        case addressEditing

        var id: Self { self }
    }
    
    // Sorting state
    @State private var clientsSortOrder: ClientsSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc
    
    private var filteredInvoices: [Invoice] {
        viewModel.relatedInvoices
    }
    
    // MARK: - Computed Properties
    
    private var sortedClients: [Client] {
        viewModel.linkedClients.sorted(using: clientsSortOrder)
    }

    private var sortedInvoices: [Invoice] {
        filteredInvoices.sorted(using: invoicesSortOrder)
    }

    init(
        planManager: PlanManager,
        modelContext: ModelContext,
        onSave: (() -> Void)? = nil,
        onOpenInvoice: @escaping (UUID) -> Void = { _ in },
        onOpenClient: @escaping (UUID) -> Void = { _ in }
    ) {
        self.planManagerId = planManager.id
        self.onOpenInvoice = onOpenInvoice
        self.onOpenClient = onOpenClient
        self._viewModel = State(initialValue: PlanManagerDetailViewModel(
            planManager: planManager,
            modelContext: modelContext,
            isCreating: false
        ))
        _viewModel.wrappedValue.dismiss = onSave ?? {}
    }

    init(
        modelContext: ModelContext,
        onSave: (() -> Void)? = nil,
        onOpenInvoice: @escaping (UUID) -> Void = { _ in },
        onOpenClient: @escaping (UUID) -> Void = { _ in }
    ) {
        let newPlanManager = PlanManager(id: UUID(), abn: "")
        newPlanManager.name = ""
        newPlanManager.email = nil
        newPlanManager.phone = nil
        newPlanManager.address = nil
        newPlanManager.abn = ""
        self.planManagerId = newPlanManager.id
        self.onOpenInvoice = onOpenInvoice
        self.onOpenClient = onOpenClient
        self._viewModel = State(initialValue: PlanManagerDetailViewModel(
            planManager: newPlanManager,
            modelContext: modelContext,
            isCreating: true
        ))
        _viewModel.wrappedValue.dismiss = onSave ?? {}
    }

    private var planManagerAddressText: String {
        guard let address = viewModel.planManager.address else { return "" }
        return viewModel.formattedAddressString(from: address)
    }

    var body: some View {
        VStack(spacing: 0) {
            RelationshipDetailHeaderBar(
                systemImage: "building.2.fill",
                title: (viewModel.planManager.name ?? "").isEmpty ? "New Plan Manager" : (viewModel.planManager.name ?? "")
            )

            DetailCardsLayout(minCardWidth: DetailSectionTokens.detailCardMinimumWidth) {
                PlanManagerDetailInformationCard(
                    viewModel: viewModel,
                    maxLabelWidth: maxLabelWidth,
                    hasAddressData: viewModel.planManager.address != nil,
                    addressText: planManagerAddressText,
                    showingMapSheet: mapSheetBinding,
                    showingAddressEditingSheet: addressEditingSheetBinding
                )
                PlanManagerDetailManagedClientsCard(
                    clients: sortedClients,
                    clientsSortOrder: $clientsSortOrder,
                    onOpenClient: onOpenClient
                )
                RelationshipDetailInvoicesCard(
                    invoices: sortedInvoices,
                    isEmpty: filteredInvoices.isEmpty,
                    invoicesSortOrder: $invoicesSortOrder,
                    onOpenInvoice: onOpenInvoice
                )
            }
        }
        .foregroundColor(StyleGuide.Colors.text)
        .task(id: viewModel.planManager.id) {
            await viewModel.refreshRelatedInvoices()
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {}
            .pointerStyle(.link)
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .map:
                if let address = viewModel.planManager.address {
                    InteractiveMapView(address: viewModel.formattedAddressString(from: address))
                }
            case .addressEditing:
                PlanManagerAddressEditingSheetView(viewModel: viewModel, isPresented: addressEditingSheetBinding)
            }
        }
        
    }

    private var mapSheetBinding: Binding<Bool> {
        Binding(
            get: { activeSheet == .map },
            set: { activeSheet = $0 ? .map : nil }
        )
    }

    private var addressEditingSheetBinding: Binding<Bool> {
        Binding(
            get: { activeSheet == .addressEditing },
            set: { activeSheet = $0 ? .addressEditing : nil }
        )
    }
    
    // MARK: - Helper Functions
    // Note: Most helper functions moved to ViewModel
    
    // MARK: - Label Width Calculation
    
    private var maxLabelWidth: CGFloat {
        RelationshipDetailLabelMetrics.maxWidth(for: [
            "Name:",
            "ABN:",
            "Email:",
            "Phone:",
            "Address:"
        ])
    }

}



// MARK: - PlanManagerAddressEditingSheetView

struct PlanManagerAddressEditingSheetView: View {
    @Bindable var viewModel: PlanManagerDetailViewModel
    @Binding var isPresented: Bool

    @State private var form = AddressFormState()

    var body: some View {
        AddressFormSheet(
            state: form,
            isPresented: $isPresented,
            hasAddressDataOverride: form.hasAddressData || viewModel.planManager.address != nil,
            onSearchAddressSelected: { viewModel.updateAddressFromSearchResult($0) },
            onCommit: {
                syncFormToViewModel()
                viewModel.commitAddressChanges(autosave: true)
            }
        )
        .onAppear {
            viewModel.loadAddressDetails()
            syncViewModelToForm()
            if let address = viewModel.planManager.address {
                form.addressSearchText = viewModel.formattedAddressString(from: address)
            }
        }
    }

    private func syncViewModelToForm() {
        form.unitNumber = viewModel.editableUnitNumber
        form.streetNumber = viewModel.editableStreetNumber
        form.streetName = viewModel.editableStreetName
        form.suburb = viewModel.editableSuburb
        form.postcode = viewModel.editablePostcode
        form.state = viewModel.editableState
        form.country = viewModel.editableCountry
        form.poBox = viewModel.editablePoBox
    }

    private func syncFormToViewModel() {
        viewModel.editableUnitNumber = form.unitNumber
        viewModel.editableStreetNumber = form.streetNumber
        viewModel.editableStreetName = form.streetName
        viewModel.editableSuburb = form.suburb
        viewModel.editableCity = form.suburb
        viewModel.editablePostcode = form.postcode
        viewModel.editableState = form.state
        viewModel.editableCountry = form.country
        viewModel.editablePoBox = form.poBox
    }
}
