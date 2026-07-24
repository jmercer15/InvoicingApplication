import SwiftUI
import SwiftData
import Core
import SharedUI
import Observation

public struct RelationshipsDetailColumn: View {
    @Environment(\.modelContext) private var swiftDataContext
    @Bindable private var viewModel: RelationshipsContainerViewModel
    private let onOpenInvoice: (UUID) -> Void
    private let onOpenClient: (UUID) -> Void
    @Query(sort: \Client.fullName) private var clients: [Client]
    @Query(sort: \Payee.fullName) private var payees: [Payee]
    @Query(sort: \PlanManager.name) private var planManagers: [PlanManager]

    @State private var showingDeleteAlert: Bool = false
    @State private var deleteAlertTitle: String = ""
    @State private var deleteAlertMessage: String = ""
    @State private var deleteAction: (() -> Void)?
    @State private var resolvedClient: Client?
    @State private var resolvedPayee: Payee?
    @State private var resolvedPlanManager: PlanManager?

    public init(
        viewModel: RelationshipsContainerViewModel,
        onOpenInvoice: @escaping (UUID) -> Void = { _ in },
        onOpenClient: @escaping (UUID) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onOpenInvoice = onOpenInvoice
        self.onOpenClient = onOpenClient
    }

    public var body: some View {
        detailContent
            .toolbar(content: deletionToolbar)
            .alert(deleteAlertTitle, isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) { deleteAction?() }
            } message: {
                Text(deleteAlertMessage)
            }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch viewModel.detailState {
        case .client(let objectID):
            RelationshipResolvedDetailView(
                objectID: objectID,
                entities: clients,
                resolved: $resolvedClient,
                revision: viewModel.dataRevision,
                emptyState: LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            ) { client in
                ClientDetailView(
                    client: client,
                    modelContext: swiftDataContext,
                    onOpenInvoice: onOpenInvoice
                )
                    .id("client_\(objectID)")
            }
        case .payee(let objectID):
            RelationshipResolvedDetailView(
                objectID: objectID,
                entities: payees,
                resolved: $resolvedPayee,
                revision: viewModel.dataRevision,
                emptyState: LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            ) { payee in
                PayeeDetailView(
                    payee: payee,
                    modelContext: swiftDataContext,
                    onOpenInvoice: onOpenInvoice,
                    onOpenClient: onOpenClient
                )
                    .id("payee_\(objectID)")
            }
        case .planManager(let objectID):
            RelationshipResolvedDetailView(
                objectID: objectID,
                entities: planManagers,
                resolved: $resolvedPlanManager,
                revision: viewModel.dataRevision,
                emptyState: LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            ) { manager in
                PlanManagerDetailView(
                    planManager: manager,
                    modelContext: swiftDataContext,
                    onOpenInvoice: onOpenInvoice,
                    onOpenClient: onOpenClient
                )
                    .id("planManager_\(objectID)")
            }
        case .newClient:
            ClientDetailView(modelContext: swiftDataContext) { viewModel.detailState = .none }
                .id("new_client")
        case .newPayee:
            PayeeDetailView(modelContext: swiftDataContext) { viewModel.detailState = .none }
                .id("new_payee")
        case .newPlanManager:
            PlanManagerDetailView(modelContext: swiftDataContext) { viewModel.detailState = .none }
                .id("new_plan_manager")
        case .none:
            emptyState
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "person.2.fill",
            title: "No Relationship Selected",
            message: "Select a client, payee, or plan manager from the list."
        )
        .padding(StyleGuide.Dimensions.paddingMedium)
    }

    @ToolbarContentBuilder
    private func deletionToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .destructiveAction) {
            deletionButton
        }
    }

    @ViewBuilder
    private var deletionButton: some View {
        if !viewModel.isCreatingNewEntity {
            switch viewModel.detailState {
            case .client(let objectID) where resolvedClient?.id == objectID:
                Button("Delete Client", systemImage: "trash", role: .destructive) {
                    confirmDeleteClient(with: objectID)
                }
                .appToolbarLinkStyle(help: "Delete this client")

            case .payee(let objectID) where resolvedPayee?.id == objectID:
                Button("Delete Payee", systemImage: "trash", role: .destructive) {
                    confirmDeletePayee(with: objectID)
                }
                .appToolbarLinkStyle(help: "Delete this payee")

            case .planManager(let objectID) where resolvedPlanManager?.id == objectID:
                Button("Delete Plan Manager", systemImage: "trash", role: .destructive) {
                    confirmDeletePlanManager(with: objectID)
                }
                .appToolbarLinkStyle(help: "Delete this plan manager")

            default:
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }

    private func confirmDeleteClient(with id: UUID) {
        deleteAlertTitle = "Delete Client"
        deleteAlertMessage = "Are you sure you want to delete this client? This action cannot be undone."
        deleteAction = {
            Task {
                do {
                    guard let entity = resolvedClient, entity.id == id else {
                        print("❌ Error deleting client: resolved model missing")
                        return
                    }
                    try await viewModel.deleteClient(entity)
                    await MainActor.run {
                        viewModel.detailState = .none
                    }
                } catch {
                    print("❌ Error deleting client: \(error)")
                }
            }
        }
        showingDeleteAlert = true
    }

    private func confirmDeletePayee(with id: UUID) {
        deleteAlertTitle = "Delete Payee"
        deleteAlertMessage = "Are you sure you want to delete this payee? This action cannot be undone."
        deleteAction = {
            Task {
                do {
                    guard let entity = resolvedPayee, entity.id == id else {
                        print("❌ Error deleting payee: resolved model missing")
                        return
                    }
                    try await viewModel.deletePayee(entity)
                    await MainActor.run {
                        viewModel.detailState = .none
                    }
                } catch {
                    print("❌ Error deleting payee: \(error)")
                }
            }
        }
        showingDeleteAlert = true
    }

    private func confirmDeletePlanManager(with id: UUID) {
        deleteAlertTitle = "Delete Plan Manager"
        deleteAlertMessage = "Are you sure you want to delete this plan manager? This action cannot be undone."
        deleteAction = {
            Task {
                do {
                    guard let entity = resolvedPlanManager, entity.id == id else {
                        print("❌ Error deleting plan manager: resolved model missing")
                        return
                    }
                    try await viewModel.deletePlanManager(entity)
                    await MainActor.run {
                        viewModel.detailState = .none
                    }
                } catch {
                    print("❌ Error deleting plan manager: \(error)")
                }
            }
        }
        showingDeleteAlert = true
    }
}
