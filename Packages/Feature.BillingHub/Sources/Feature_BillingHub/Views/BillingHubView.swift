import SwiftUI
import SwiftData
import Core
import Data
import SharedUI
import Observation

public struct BillingHubView: View {
    @Bindable private var viewModel: BillingHubViewModel


    @State private var selectedCardID: UUID?
    @State private var presentedCardID: UUID?
    
    let openInvoice: (UUID) -> Void
    let openSession: (UUID) -> Void

    private var projectionTaskID: BillingHubProjectionTaskID {
        BillingHubProjectionTaskID(
            revision: viewModel.dataRevision,
            searchText: viewModel.searchText,
            selectedClientID: viewModel.selectedClientID,
            sortOptions: viewModel.columnSortOptions
        )
    }

    private var readyToSendCount: Int {
        viewModel.boardProjection.invoicesByStatus[.readyToSend]?.count ?? 0
    }

    private var pendingPaymentCount: Int {
        viewModel.boardProjection.invoicesByStatus[.pending]?.count ?? 0
    }

    private var groupedDraftBatchCount: Int {
        viewModel.boardProjection.groupedSessions.count
    }

    public init(
        viewModel: BillingHubViewModel,
        openInvoice: @escaping (UUID) -> Void = { _ in },
        openSession: @escaping (UUID) -> Void = { _ in }
    ) {
        self._viewModel = Bindable(viewModel)
        self.openInvoice = openInvoice
        self.openSession = openSession
    }

    public var body: some View {
        ZStack {
            boardContent(projection: viewModel.boardProjection)
                .opacity(viewModel.isLoading ? 0.6 : 1.0)
            
            if viewModel.isLoading {
                ProgressView("Refreshing Board...")
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            } else if viewModel.boardProjection.isEmpty {
                ContentUnavailableView(
                    "No Billing Data Available",
                    systemImage: "tray.fill",
                    description: Text("Try adjusting client filters or check your date ranges.")
                )
            }
        }
        .task(id: projectionTaskID) {
            try? await Task.sleep(for: .milliseconds(150))
            await viewModel.refreshProjection()
        }
        .toolbar {
            toolbarContent
        }
        .navigationTitle("Billing Hub")
        .sheet(item: presentedCardBinding) { card in
            EditingPanel(
                card: card,
                viewModel: viewModel,
                openInvoice: openInvoice,
                openSession: openSession
            )
        }
    }
}

private extension BillingHubView {
    func boardContent(projection: BillingHubBoardProjection) -> some View {
        KanbanBoardView(
            viewModel: viewModel,
            projection: projection,
            selectedCardID: $selectedCardID,
            onOpenCard: { presentedCardID = $0 }
        )
    }

    var presentedCardBinding: Binding<KanbanCardData?> {
        Binding(
            get: { viewModel.boardProjection.card(for: presentedCardID) },
            set: { presentedCardID = $0?.id }
        )
    }
}

/// Lightweight identity for board projection rebuilds — avoids recomputing the Kanban graph on every layout pass.
private struct BillingHubProjectionTaskID: Equatable {
    let revision: Int
    let searchText: String
    let selectedClientID: UUID?
    let sortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption]
}

private extension BillingHubView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        AppToolbarUtilityGroup {
            clientFilter

            if viewModel.hasActiveFilters {
                clearFiltersButton
            }
        }

        AppToolbarStatusGroup {
            if let feedback = viewModel.bulkActionFeedback {
                bulkFeedbackPill(text: feedback)
            }

            if viewModel.canUndoLastBulkAction {
                undoBulkButton
            }
        }

        if groupedDraftBatchCount > 0 || readyToSendCount > 0 || pendingPaymentCount > 0 {
            ToolbarItem(placement: .primaryAction) {
                bulkActionsMenu
            }
        }
    }

    @ViewBuilder
    var bulkActionsMenu: some View {
        if groupedDraftBatchCount > 0 || readyToSendCount > 0 || pendingPaymentCount > 0 {
            AppToolbarActionsMenu(
                title: "Bulk Actions",
                systemImage: "tray.2.fill",
                help: "Batch invoice workflow actions"
            ) {
                if groupedDraftBatchCount > 0 {
                    Button {
                        Task {
                            await viewModel.createDraftInvoicesForGroupedSessions(from: viewModel.boardProjection)
                        }
                    } label: {
                        Label("Create Drafts (\(groupedDraftBatchCount))", systemImage: "doc.badge.plus")
                    }
                }

                if readyToSendCount > 0 {
                    Button {
                        Task {
                            await viewModel.sendAllReadyToSendInvoices(from: viewModel.boardProjection)
                        }
                    } label: {
                        Label("Send Ready (\(readyToSendCount))", systemImage: "paperplane")
                    }
                }

                if pendingPaymentCount > 0 {
                    Button {
                        Task {
                            await viewModel.completeAllPendingInvoices(from: viewModel.boardProjection)
                        }
                    } label: {
                        Label("Complete Pending (\(pendingPaymentCount))", systemImage: "checkmark.seal")
                    }
                }
            }
        }
    }

    var clientFilter: some View {
        let summaries = viewModel.boardProjection.clientSummaries
        return Menu {
            Button {
                viewModel.selectClient(withID: nil)
            } label: {
                if viewModel.selectedClientID == nil {
                    Label("All Clients", systemImage: "checkmark")
                } else {
                    Text("All Clients")
                }
            }

            if !summaries.isEmpty {
                Divider()
            }

            ForEach(summaries) { summary in
                Button {
                    viewModel.selectClient(withID: summary.id)
                } label: {
                    HStack {
                        clientBadge(clientId: summary.id)
                        Text(summary.name)
                        if viewModel.selectedClientID == summary.id {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(StyleGuide.Colors.primary)
                        }
                    }
                }
            }
        } label: {
            Label {
                Text(
                    summaries.first(where: { $0.id == viewModel.selectedClientID })?.name
                    ?? "Client"
                )
            } icon: {
                Image(systemName: viewModel.selectedClientID == nil ? "person.2" : "person.2.fill")
            }
        }
        .appToolbarLinkStyle(help: "Filter by client")
    }

    func clientBadge(clientId: UUID) -> some View {
        Circle()
            .fill(ColorSystem.Client.color(for: clientId).opacity(0.85))
            .frame(width: BillingHubTheme.Dimensions.clientBadgeSize, height: BillingHubTheme.Dimensions.clientBadgeSize)
    }

    var clearFiltersButton: some View {
        Button {
            withAnimation(BillingHubTheme.Animations.hover) {
                viewModel.clearFilters()
            }
        } label: {
            Label("Clear", systemImage: "line.3.horizontal.decrease.circle")
        }
        .appToolbarLinkStyle(help: "Clear all filters")
    }

    var undoBulkButton: some View {
        Button {
            Task {
                await viewModel.undoLastBulkAction()
            }
        } label: {
            Label("Undo Bulk", systemImage: "arrow.uturn.backward.circle")
        }
        .appToolbarLinkStyle(help: "Undo last bulk action")
    }

    func bulkFeedbackPill(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(BillingHubTheme.Typography.bulkFeedbackIcon)
                .foregroundColor(BillingHubTheme.Columns.payment)
            Text(text)
                .font(BillingHubTheme.Typography.bulkFeedbackText)
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
            Button {
                viewModel.clearBulkActionFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(BillingHubTheme.Typography.bulkFeedbackDismiss)
                    .foregroundColor(BillingHubTheme.Palette.textMuted)
            }
            .buttonStyle(.plain)
            .billingHubPointerStyle(.link)
        }
    }
}

extension BillingHubBoardProjection {
    public var isEmpty: Bool {
        sessionsByStatus.values.allSatisfy(\.isEmpty) &&
        invoicesByStatus.values.allSatisfy(\.isEmpty) &&
        groupedSessions.isEmpty
    }
}
