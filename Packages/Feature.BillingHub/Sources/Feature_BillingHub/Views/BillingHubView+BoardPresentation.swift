import SwiftUI
import SwiftData
import SharedUI
import Observation

enum BillingHubActiveConfirmation: Identifiable {
    case invoicedSession(BillingHubInvoicedSessionAction)
    case bulkPaymentReceived(count: Int)

    var id: String {
        switch self {
        case .invoicedSession(let action):
            "invoiced-\(action.id.uuidString)"
        case .bulkPaymentReceived(let count):
            "bulk-payment-\(count)"
        }
    }

    var title: String {
        switch self {
        case .invoicedSession:
            "Session Linked to Invoice"
        case .bulkPaymentReceived(let count):
            BillingHubConfirmationCopy.bulkPaymentTitle(count: count)
        }
    }
}

extension BillingHubView {
    var activeConfirmation: BillingHubActiveConfirmation? {
        if let action = viewModel.pendingInvoicedSessionAction {
            return .invoicedSession(action)
        }
        if viewModel.pendingBulkPaymentReceivedConfirm {
            return .bulkPaymentReceived(count: pendingPaymentCount)
        }
        return nil
    }

    var activeConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { activeConfirmation != nil },
            set: { isPresented in
                guard !isPresented else { return }
                viewModel.cancelPendingInvoicedSessionAction()
                viewModel.cancelBulkMarkPaymentReceived()
            }
        )
    }
}

extension BillingHubView {
    func boardContent(projection: BillingHubBoardProjection) -> some View {
        KanbanBoardView(
            displayState: KanbanBoardDisplayState(
                searchText: viewModel.searchText,
                hasActiveFilters: viewModel.hasActiveFilters
            ),
            actions: viewModel.kanbanBoardActionsForCurrentSortOptions(),
            cardActions: viewModel.kanbanCardActionsForCurrentSortOptions(),
            projection: projection,
            boardRevision: viewModel.dataRevision,
            selectedCardID: selectedCardBinding,
            onOpenCard: { cardID in
                viewModel.presentedCardID = cardID
                viewModel.selectedCardID = cardID
            },
            focusScrollID: viewModel.selectedCardID
        )
    }

    func boardLoadErrorState(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Billing Hub Couldn’t Refresh", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again", systemImage: "arrow.clockwise") {
                viewModel.scheduleProjectionRefresh()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    func boardLoadErrorBanner(_ message: String) -> some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ColorSystem.Status.error)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingTiny) {
                Text("Board refresh failed")
                    .font(StyleGuide.Typography.itemTitle)
                Text("\(message) Existing billing work remains visible.")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
            }

            Spacer(minLength: StyleGuide.Dimensions.paddingMedium)

            Button("Try Again", systemImage: "arrow.clockwise") {
                viewModel.scheduleProjectionRefresh()
            }
            .buttonStyle(.borderedProminent)

            Button {
                viewModel.clearProjectionLoadError()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss refresh error")
        }
        .padding(StyleGuide.Dimensions.paddingMediumLarge)
        .frame(maxWidth: 620)
        .background(
            .regularMaterial,
            in: RoundedRectangle(
                cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: StyleGuide.Dimensions.cornerRadiusLarge,
                style: .continuous
            )
            .strokeBorder(ColorSystem.Status.error.opacity(0.24))
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .accessibilityElement(children: .contain)
    }

    var selectedCardBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.selectedCardID },
            set: { viewModel.selectedCardID = $0 }
        )
    }

    var presentedCardBinding: Binding<KanbanCardData?> {
        Binding(
            get: { viewModel.boardProjection.card(for: viewModel.presentedCardID) },
            set: { viewModel.presentedCardID = $0?.id }
        )
    }

    func applyPendingFocusIfPossible() {
        guard !viewModel.isLoading else { return }
        switch viewModel.settlePendingFocus(from: viewModel.boardProjection) {
        case .focused(let cardID):
            viewModel.selectedCardID = cardID
            viewModel.presentedCardID = cardID
        case .retryNeeded:
            viewModel.scheduleProjectionRefresh()
        case .missed, .idle:
            break
        }
    }
}

/// Lightweight identity for board projection rebuilds — avoids recomputing the Kanban graph on every layout pass.
struct BillingHubProjectionTaskID: Equatable {
    let revision: Int
    let searchText: String
    let selectedClientID: UUID?
    let sortOptions: [KanbanCardData.BillingColumnType: ColumnSortOption]
}

extension BillingHubBoardProjection {
    public var isEmpty: Bool {
        sessionsByStatus.values.allSatisfy(\.isEmpty) &&
        invoicesByStatus.values.allSatisfy(\.isEmpty) &&
        groupedSessions.isEmpty
    }
}
