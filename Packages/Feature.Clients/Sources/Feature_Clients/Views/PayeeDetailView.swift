import SwiftUI
import AppKit // For NSColor, NSPasteboard
import MapKit // For address map view
import SwiftData
import Core
import Data
import SharedUI
import WorkspaceUI
import Observation

// MARK: - PayeeDetailView

struct PayeeDetailView: View {
    let payeeId: UUID
    let onOpenInvoice: (UUID) -> Void
    let onOpenClient: (UUID) -> Void
    @State private var viewModel: PayeeDetailViewModel

    // UI state only
    @State private var showingMapSheet: Bool = false
    @State private var showingAddressEditingSheet: Bool = false
    
    // Sorting state
    @State private var clientsSortOrder: ClientsSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc
    
    // Computed properties from ViewModel
    private var linkedClients: [Client] {
        viewModel.linkedClients
    }
    
    private var filteredInvoices: [Invoice] {
        viewModel.relatedInvoices
    }
    
    // MARK: - Computed Properties
    
    private var sortedClients: [Client] {
        linkedClients.sorted(using: clientsSortOrder)
    }

    private var sortedInvoices: [Invoice] {
        filteredInvoices.sorted(using: invoicesSortOrder)
    }

    init(
        payee: Payee,
        modelContext: ModelContext,
        onSave: (() -> Void)? = nil,
        onOpenInvoice: @escaping (UUID) -> Void = { _ in },
        onOpenClient: @escaping (UUID) -> Void = { _ in }
    ) {
        self.payeeId = payee.id
        self.onOpenInvoice = onOpenInvoice
        self.onOpenClient = onOpenClient
        self._viewModel = State(initialValue: PayeeDetailViewModel(
            payee: payee,
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
        let newPayee = Payee(id: UUID(), fullName: "")
        newPayee.status = "Active"
        self.payeeId = newPayee.id
        self.onOpenInvoice = onOpenInvoice
        self.onOpenClient = onOpenClient
        self._viewModel = State(initialValue: PayeeDetailViewModel(
            payee: newPayee,
            modelContext: modelContext,
            isCreating: true
        ))
        _viewModel.wrappedValue.dismiss = onSave ?? {}
    }

    private var payeeAddressText: String {
        guard let address = viewModel.payee.address else { return "" }
        return viewModel.formattedAddressString(from: address)
    }

    var body: some View {
        VStack(spacing: 0) {
            RelationshipDetailHeaderBar(
                systemImage: "person.text.rectangle.fill",
                title: viewModel.payee.fullName.isEmpty ? "New Payee" : viewModel.payee.fullName
            )

            DetailCardsLayout(minCardWidth: DetailSectionTokens.detailCardMinimumWidth) {
                PayeeDetailInformationCard(
                    viewModel: viewModel,
                    maxLabelWidth: maxLabelWidth,
                    hasAddressData: viewModel.payee.address != nil,
                    addressText: payeeAddressText,
                    showingMapSheet: $showingMapSheet,
                    showingAddressEditingSheet: $showingAddressEditingSheet
                )
                PayeeDetailLinkedClientsCard(
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
        .task(id: viewModel.payee.id) {
            let actor = ReferenceDataWorkflowActor(modelContainer: viewModel.modelContext.container)
            await viewModel.refreshRelatedInvoices(using: actor)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showAlert) {
            Button("OK") {}
            .pointerStyle(.link)
        } message: {
            Text(viewModel.alertMessage)
        }
        .sheet(isPresented: $showingMapSheet) {
            if let address = viewModel.payee.address {
                InteractiveMapView(address: viewModel.formattedAddressString(from: address))
            }
        }
        .sheet(isPresented: $showingAddressEditingSheet) {
            PayeeAddressEditingSheetView(viewModel: viewModel, isPresented: $showingAddressEditingSheet)
        }
    }
    
    // MARK: - Helper Functions
    
    private var maxLabelWidth: CGFloat {
        RelationshipDetailLabelMetrics.maxWidth(for: [
            "Name:",
            "Email:",
            "Phone:",
            "Address:"
        ])
    }

}

// MARK: - PayeeAddressEditingSheetView

struct PayeeAddressEditingSheetView: View {
    @Bindable var viewModel: PayeeDetailViewModel
    @Binding var isPresented: Bool

    @State private var form = AddressFormState()

    var body: some View {
        AddressFormSheet(
            state: form,
            isPresented: $isPresented,
            hasAddressDataOverride: form.hasAddressData || viewModel.payee.address != nil,
            onSearchAddressSelected: { viewModel.updateAddressFromSearchResult($0) },
            onCommit: {
                syncFormToViewModel()
                viewModel.commitAddressChanges(autosave: true)
            }
        )
        .onAppear {
            viewModel.loadAddressDetails()
            syncViewModelToForm()
            if let address = viewModel.payee.address {
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
