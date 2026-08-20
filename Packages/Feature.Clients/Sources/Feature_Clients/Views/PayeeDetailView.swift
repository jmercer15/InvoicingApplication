import SwiftUI
import AppKit
import MapKit
import SwiftData
import Core
import PersistenceModels
import SharedUI
import WorkspaceUI
import Observation

// MARK: - PayeeDetailView

struct PayeeDetailView: View {
    let payeeId: UUID
    let onOpenInvoice: (UUID) -> Void
    let onOpenClient: (UUID) -> Void
    @State private var viewModel: PayeeDetailViewModel

    @State private var activeSheet: RelationshipDetailActiveSheet?
    @State private var clientsSortOrder: ClientsSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc

    private var linkedClients: [Client] { viewModel.linkedClients }
    private var filteredInvoices: [Invoice] { viewModel.relatedInvoices }

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

    private var mapSheetBinding: Binding<Bool> {
        RelationshipDetailSheetBindings.isPresented($activeSheet, equals: .map)
    }

    private var addressEditingSheetBinding: Binding<Bool> {
        RelationshipDetailSheetBindings.isPresented($activeSheet, equals: .addressEditing)
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
                    showingMapSheet: mapSheetBinding,
                    showingAddressEditingSheet: addressEditingSheetBinding
                )
                RelationshipDetailClientsCard(
                    title: "Linked Clients",
                    emptyMessage: "No clients are linked to this payee",
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
        .foregroundStyle(StyleGuide.Colors.text)
        .task(id: viewModel.payee.id) {
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
                if let address = viewModel.payee.address {
                    InteractiveMapView(address: viewModel.formattedAddressString(from: address))
                }
            case .addressEditing:
                RelationshipAddressEditingSheetView(
                    viewModel: viewModel,
                    isPresented: addressEditingSheetBinding
                )
            }
        }
    }

    private var maxLabelWidth: CGFloat {
        RelationshipDetailLabelMetrics.maxWidth(for: [
            "Name:",
            "Email:",
            "Phone:",
            "Address:"
        ])
    }
}
