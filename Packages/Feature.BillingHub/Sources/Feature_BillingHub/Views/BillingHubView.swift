import SwiftUI
import SwiftData
import Core
import SharedUI
import Observation

public struct BillingHubView: View {
    @Bindable var viewModel: BillingHubViewModel
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    let openInvoice: (UUID) -> Void
    let openSession: (UUID) -> Void

    var projectionTaskID: BillingHubProjectionTaskID {
        BillingHubProjectionTaskID(
            revision: viewModel.dataRevision,
            searchText: viewModel.searchText,
            selectedClientID: viewModel.selectedClientID,
            sortOptions: viewModel.columnSortOptions
        )
    }

    var completedSessionCount: Int {
        viewModel.boardProjection.sessionsByStatus[.completed]?.count ?? 0
    }

    var readyToSendCount: Int {
        viewModel.boardProjection.invoicesByStatus[.readyToSend]?.count ?? 0
    }

    var pendingPaymentCount: Int {
        viewModel.boardProjection.invoicesByStatus[.pending]?.count ?? 0
    }

    var groupedDraftBatchCount: Int {
        viewModel.boardProjection.groupedSessions.count
    }

    var focusTaskID: String {
        let ids = viewModel.pendingFocusCardIDs.map(\.uuidString).joined(separator: ",")
        let projectionToken = viewModel.boardProjection.isEmpty ? "empty" : "ready"
        // Re-run when refresh finishes so a miss is reported only after projection is idle.
        let loadingToken = viewModel.isLoading ? "loading" : "idle"
        return "\(ids)|\(projectionToken)|\(viewModel.dataRevision)|\(loadingToken)"
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
            
            if viewModel.isLoading {
                ProgressView(viewModel.bulkProgress.bulkActionProgressMessage ?? "Refreshing Board…")
                    .padding()
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            } else if let loadError = viewModel.projectionLoadError,
                      viewModel.boardProjection.isEmpty {
                boardLoadErrorState(loadError)
            } else if viewModel.boardProjection.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.hasActiveFilters ? "No Matching Billing Work" : "No Billing Work Yet",
                        systemImage: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle" : "tray.fill"
                    )
                } description: {
                    Text(
                        viewModel.hasActiveFilters
                            ? "This filter has no matching sessions or invoices. Clear it to see all billing work."
                            : "Completed sessions and draft invoices will appear here when they are ready to process."
                    )
                } actions: {
                    if viewModel.hasActiveFilters {
                        Button("Clear Filters", systemImage: "xmark.circle") {
                            viewModel.clearFilters()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            if let loadError = viewModel.projectionLoadError,
               !viewModel.isLoading,
               !viewModel.boardProjection.isEmpty {
                VStack {
                    Spacer()
                    boardLoadErrorBanner(loadError)
                }
                .padding(BillingHubTheme.Dimensions.boardPadding)
            }
        }
        .task(id: projectionTaskID) {
            // Debounce: on cancel during sleep, return without refreshProjection.
            await BillingHubProjectionDebounce.run {
                await viewModel.refreshProjection()
            }
        }
        .task(id: focusTaskID) {
            applyPendingFocusIfPossible()
        }
        .toolbar {
            toolbarContent
        }
        .navigationTitle("Billing Hub")
        .task(id: viewModel.bulkActionFeedback) {
            guard let feedback = viewModel.bulkActionFeedback else { return }
            if voiceOverEnabled {
                AppAccessibilityAnnouncement.post(feedback)
                return
            }
            guard await Task.waitUnlessCancelled(for: .seconds(10)) else { return }
            if viewModel.bulkActionFeedback == feedback {
                viewModel.clearBulkActionFeedback()
            }
        }
        .task(id: viewModel.projectionLoadError) {
            guard voiceOverEnabled, let error = viewModel.projectionLoadError else { return }
            AppAccessibilityAnnouncement.post(error)
        }
        .sheet(item: presentedCardBinding) { card in
            EditingPanel(
                card: card,
                viewModel: viewModel,
                openInvoice: openInvoice,
                openSession: openSession
            )
        }
        .confirmationDialog(
            activeConfirmation?.title ?? "",
            isPresented: activeConfirmationIsPresented,
            presenting: activeConfirmation,
            actions: { confirmation in
                switch confirmation {
                case .invoicedSession(let action):
                    Button(action.confirmTitle) {
                        viewModel.confirmPendingInvoicedSessionAction()
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.cancelPendingInvoicedSessionAction()
                    }
                case .bulkPaymentReceived(let count):
                    Button(BillingHubConfirmationCopy.bulkPaymentButtonTitle(count: count)) {
                        Task {
                            await viewModel.completeAllPendingInvoices(from: viewModel.boardProjection)
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.cancelBulkMarkPaymentReceived()
                    }
                }
            },
            message: { confirmation in
                switch confirmation {
                case .invoicedSession(let action):
                    Text(action.message)
                case .bulkPaymentReceived(let count):
                    Text(BillingHubConfirmationCopy.bulkPaymentMessage(count: count))
                }
            }
        )
        .appRespectsReduceMotion()
    }
}
