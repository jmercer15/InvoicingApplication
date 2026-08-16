import SwiftUI
import AppKit
import MapKit
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

    @State private var activeSheet: RelationshipDetailActiveSheet?
    @State private var clientsSortOrder: ClientsSortOrder = .nameAsc
    @State private var invoicesSortOrder: InvoicesSortOrder = .dateDesc

    private var filteredInvoices: [Invoice] { viewModel.relatedInvoices }

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

    private var mapSheetBinding: Binding<Bool> {
        RelationshipDetailSheetBindings.isPresented($activeSheet, equals: .map)
    }

    private var addressEditingSheetBinding: Binding<Bool> {
        RelationshipDetailSheetBindings.isPresented($activeSheet, equals: .addressEditing)
    }

    var body: some View {
        VStack(spacing: 0) {
            RelationshipDetailHeaderBar(
                systemImage: "building.2.fill",
                title: (viewModel.planManager.name ?? "").isEmpty
                    ? "New Plan Manager"
                    : (viewModel.planManager.name ?? "")
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
                RelationshipDetailClientsCard(
                    title: "Managed Clients",
                    emptyMessage: "No clients are using this plan manager",
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
            "ABN:",
            "Email:",
            "Phone:",
            "Address:"
        ])
    }
}
