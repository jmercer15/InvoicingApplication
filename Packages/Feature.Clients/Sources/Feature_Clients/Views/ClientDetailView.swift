import SwiftUI
import SwiftData
import PersistenceModels
import SharedUI
import Observation

struct ClientDetailView: View {
    let injectedModelContext: ModelContext
    let clientId: UUID

    @Environment(\.dismiss) var dismiss

    @State var viewModel: ClientDetailViewModel

    let isCreatingNew: Bool
    let onSave: (() -> Void)?
    let onOpenInvoice: (UUID) -> Void

    @State var showingServiceAssignment = false
    @State var reopenServiceAssignmentAfterBulkEditor = false
    @State var showingMapSheet = false
    @State var showingAddressEditingSheet = false

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            clientHeaderBar

            DetailCardsLayout(minCardWidth: DetailSectionTokens.detailCardMinimumWidth) {
                clientInfoCard
                billingInfoCard
                serviceAgreementsCard
                servicesCard
                invoicesCard
            }
        }
        .foregroundColor(StyleGuide.Colors.text)
        .sheet(item: activeSheetBinding) { sheet in
            switch sheet {
            case .serviceAssignment:
                ServiceAssignmentSheetContainer(
                    client: viewModel.client,
                    alreadySelectedItems: viewModel.assignedNDISItems,
                    onProceed: { selectedItems in
                        viewModel.prepareForBulkServiceCreation(from: selectedItems)
                    }
                )
                .fluidSheetTransition()
            case .serviceBulkEditor:
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
            case .serviceAgreement:
                ServiceAgreementEditorSheet(viewModel: viewModel)
                    .fluidSheetTransition()
            case .clientService:
                ClientServiceEditorSheet(viewModel: viewModel)
                    .fluidSheetTransition()
            case .map:
                InteractiveMapView(address: getCurrentAddressString())
                    .fluidSheetTransition()
            case .addressEditing:
                ClientAddressEditingSheet(
                    viewModel: viewModel,
                    isPresented: $showingAddressEditingSheet
                )
                .fluidSheetTransition()
            }
        }
        .animation(
            reduceMotion ? nil : .spring(
                response: StyleGuide.Animations.springResponse,
                dampingFraction: StyleGuide.Animations.springDamping
            ),
            value: activeSheet
        )
        .onChange(of: viewModel.isPresentingServiceBulkEditor) { wasPresented, isPresented in
            if wasPresented && !isPresented {
                handleServiceBulkEditorDismiss()
            }
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
            await viewModel.refreshProjectedData()
        }
        .task {
            await viewModel.loadReferencePickers()
        }
    }

    var maxLabelWidth: CGFloat {
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
