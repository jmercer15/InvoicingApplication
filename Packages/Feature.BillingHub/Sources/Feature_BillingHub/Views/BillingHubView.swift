import SwiftUI
import SharedUI
import Core

public struct BillingHubView: View {
    @ObservedObject private var viewModel: BillingHubViewModel
    
    @State private var isEditingPanelVisible = false
    @State private var selectedCard: KanbanCardData?

    public init(viewModel: BillingHubViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        KanbanBoardView(
            viewModel: viewModel,
            selectedCard: $selectedCard,
            isEditingPanelVisible: $isEditingPanelVisible
        )
        .environmentObject(viewModel)
        .loadingOverlay(isLoading: viewModel.isLoading, message: "Loading billing data...")
        .searchable(text: $viewModel.searchText, prompt: "Search sessions or invoices")
        .toolbar {
            toolbarContent
        }
        .navigationTitle("Billing Hub")
        .sheet(item: $selectedCard) { card in
             EditingPanel(
                 card: card
             )
             .environmentObject(viewModel)
        }
        .onAppear {
            viewModel.refreshIfNeeded()
        }
    }
}

private extension BillingHubView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            refreshButton
        }

        ToolbarItemGroup(placement: .automatic) {
            clientFilter

            if viewModel.hasActiveFilters {
                clearFiltersButton
            }
        }
        
        ToolbarItemGroup(placement: .automatic) {
            if viewModel.canBulkCreateDrafts {
                createDraftsButton
            }

            if viewModel.canBulkSendReadyInvoices {
                sendReadyButton
            }

            if viewModel.canBulkCompletePendingInvoices {
                completePendingButton
            }

            if let feedback = viewModel.bulkActionFeedback {
                bulkFeedbackPill(text: feedback)
            }

            if viewModel.canUndoLastBulkAction {
                undoBulkButton
            }
        }
    }

    var clientFilter: some View {
        Menu {
            Button {
                viewModel.selectClient(withID: nil)
            } label: {
                if viewModel.selectedClientID == nil {
                    Label("All Clients", systemImage: "checkmark")
                } else {
                    Text("All Clients")
                }
            }

            if !viewModel.clientSummaries.isEmpty {
                Divider()
            }

            ForEach(viewModel.clientSummaries) { summary in
                Button {
                    viewModel.selectClient(withID: summary.id)
                } label: {
                    HStack {
                        clientBadge(clientId: summary.id)
                        Text(summary.name)
                        if viewModel.selectedClientID == summary.id {
                            Spacer()
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color("Primary", bundle: .sharedUI))
                        }
                    }
                }
            }
        } label: {
            Label {
                Text(viewModel.selectedClientName ?? "Client")
            } icon: {
                Image(systemName: viewModel.selectedClientID == nil ? "person.2" : "person.2.fill")
            }
        }
        .help("Filter by client")
        .pointerStyle(.link)
    }

    func clientBadge(clientId: UUID) -> some View {
        Circle()
            .fill(ColorSystem.Client.color(for: clientId).opacity(0.85))
            .frame(width: 8, height: 8)
    }

    var clearFiltersButton: some View {
        Button {
            withAnimation(BillingHubTheme.Animations.hover) {
                viewModel.clearFilters()
            }
        } label: {
            Label("Clear", systemImage: "line.3.horizontal.decrease.circle")
        }
        .help("Clear all filters")
        .pointerStyle(.link)
    }

    var refreshButton: some View {
        Button {
            withAnimation(BillingHubTheme.Animations.spring) {
                viewModel.refresh()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .help("Refresh billing data")
        .pointerStyle(.link)
    }

    var createDraftsButton: some View {
        Button {
            Task {
                await viewModel.createDraftInvoicesForGroupedSessions()
            }
        } label: {
            Label("Create Drafts (\(viewModel.groupedDraftBatchCount))", systemImage: "doc.badge.plus")
        }
        .help("Create draft invoices for grouped sessions")
        .pointerStyle(.link)
    }

    var sendReadyButton: some View {
        Button {
            Task {
                await viewModel.sendAllReadyToSendInvoices()
            }
        } label: {
            Label("Send Ready (\(viewModel.readyToSendCount))", systemImage: "paperplane")
        }
        .help("Send all ready invoices")
        .pointerStyle(.link)
    }

    var completePendingButton: some View {
        Button {
            Task {
                await viewModel.completeAllPendingInvoices()
            }
        } label: {
            Label("Complete Pending (\(viewModel.pendingPaymentCount))", systemImage: "checkmark.seal")
        }
        .help("Mark all pending invoices as paid")
        .pointerStyle(.link)
    }

    var undoBulkButton: some View {
        Button {
            Task {
                await viewModel.undoLastBulkAction()
            }
        } label: {
            Label("Undo Bulk", systemImage: "arrow.uturn.backward.circle")
        }
        .help("Undo last bulk action")
        .pointerStyle(.link)
    }

    func bulkFeedbackPill(text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(BillingHubTheme.Columns.payment)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(BillingHubTheme.Palette.textSecondary)
            Button {
                viewModel.clearBulkActionFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(BillingHubTheme.Palette.textMuted)
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
        }
    }
}
