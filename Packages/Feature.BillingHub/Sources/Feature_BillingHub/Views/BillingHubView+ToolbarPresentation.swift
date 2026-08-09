import SwiftUI
import Core
import SharedUI

extension BillingHubView {
    @ToolbarContentBuilder
    var toolbarContent: some ToolbarContent {
        AppToolbarUtilityGroup {
            clientFilter

            if viewModel.hasActiveFilters {
                clearFiltersButton
            }
        }

        AppToolbarStatusGroup {
            if isBulkActionInFlight {
                bulkProgressPill(progress: viewModel.bulkProgress.bulkActionProgress)
            }

            if let feedback = viewModel.bulkActionFeedback {
                bulkFeedbackPill(text: feedback)
            }

            if viewModel.canUndoLastBulkAction {
                undoBulkButton
            }
        }

        if completedSessionCount > 0 || groupedDraftBatchCount > 0 || readyToSendCount > 0 || pendingPaymentCount > 0 {
            ToolbarItem(placement: .primaryAction) {
                bulkActionsMenu
            }
        }

        if let selectedCardID = viewModel.selectedCardID,
           viewModel.boardProjection.card(for: selectedCardID) != nil {
            ToolbarItem(placement: .primaryAction) {
                Button("Open Selected", systemImage: "rectangle.portrait.and.arrow.forward") {
                    viewModel.presentedCardID = selectedCardID
                }
                .appToolbarLinkStyle(help: "Open selected billing card. You can also press Return while its card is focused.")
            }
        }
    }

    /// Any bulk action in flight — disables the whole menu so a rapid double-click can't
    /// re-process the same board snapshot (e.g. double-moving or double-marking-sent).
    var isBulkActionInFlight: Bool {
        viewModel.bulkProgress.isCreatingDrafts || viewModel.bulkProgress.isBulkProcessing
    }

    @ViewBuilder
    var bulkActionsMenu: some View {
        if completedSessionCount > 0 || groupedDraftBatchCount > 0 || readyToSendCount > 0 || pendingPaymentCount > 0 {
            AppToolbarActionsMenu(
                title: "Bulk Actions",
                systemImage: isBulkActionInFlight ? "hourglass" : "tray.2.fill",
                help: isBulkActionInFlight ? "A bulk action is in progress" : "Batch invoice workflow actions"
            ) {
                if completedSessionCount > 0 {
                    Button {
                        Task {
                            await viewModel.moveAllCompletedSessionsToGrouped(from: viewModel.boardProjection)
                        }
                    } label: {
                        Label("Move to Grouped (\(completedSessionCount))", systemImage: "rectangle.stack.badge.plus")
                    }
                    .help("Moves every Completed session into Grouped so drafts can be created")
                }

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
                            await viewModel.markReadyToSendInvoicesSent(from: viewModel.boardProjection)
                        }
                    } label: {
                        Label(
                            BillingHubWorkflowCopy.bulkMarkSentActionTitle(count: readyToSendCount),
                            systemImage: "paperplane"
                        )
                    }
                    .help("Changes status to Sent without opening Mail or sending a PDF")
                }

                if pendingPaymentCount > 0 {
                    Button {
                        viewModel.requestBulkMarkPaymentReceived()
                    } label: {
                        Label(
                            BillingHubWorkflowCopy.bulkPaymentActionTitle(count: pendingPaymentCount),
                            systemImage: "checkmark.seal"
                        )
                    }
                    .help("Moves Sent invoices to Payment Received with today’s paid date but no amount, method, or reference")
                }
            }
            .disabled(isBulkActionInFlight)
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
        .disabled(isBulkActionInFlight)
    }

    func bulkProgressPill(progress: BillingHubBulkActionProgress?) -> some View {
        let text = progress?.message ?? "Processing billing batch…"
        return HStack(spacing: 6) {
            ProgressView()
                .controlSize(.small)
            if let progress, progress.totalCount > 0 {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(.linear)
                    .frame(width: 72)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(BillingHubTheme.Typography.bulkFeedbackText)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .lineLimit(1)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
    }

    func bulkFeedbackPill(text: String) -> some View {
        let severity = BillingHubBulkFeedbackSeverity.classify(text)
        return HStack(spacing: 6) {
            Image(systemName: severity.symbolName)
                .font(BillingHubTheme.Typography.bulkFeedbackIcon)
                .foregroundStyle(severity.tint)
                .accessibilityHidden(true)
            Text(text)
                .font(BillingHubTheme.Typography.bulkFeedbackText)
                .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                .accessibilityLabel(text)
            if viewModel.hasActiveFilters,
               BillingHubBoardCopy.offersClearFiltersRecovery(for: text) {
                Button("Clear Filters") {
                    viewModel.clearBulkActionFeedback()
                    viewModel.clearFilters()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityHint("Restores all Billing Hub work to the board.")
            }
            Button {
                viewModel.clearBulkActionFeedback()
            } label: {
                Image(systemName: "xmark")
                    .font(BillingHubTheme.Typography.bulkFeedbackDismiss)
                    .foregroundStyle(BillingHubTheme.Palette.textMuted)
            }
            .buttonStyle(.plain)
            .billingHubPointerStyle(.link)
            .accessibilityLabel("Dismiss feedback")
        }
        .accessibilityElement(children: .contain)
    }
}
