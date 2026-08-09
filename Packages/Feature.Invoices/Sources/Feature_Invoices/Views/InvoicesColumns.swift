import SwiftUI
import SwiftData
import SharedUI
import Core
import PersistenceModels
import Observation

public struct InvoicesContentColumn: View {
    @Bindable private var viewModel: InvoicesContainerViewModel
    @State private var showingFilterPopover = false
    @State private var cachedProjection: InvoicesListProjection?
    @AccessibilityFocusState private var isActionErrorFocused: Bool
    @AccessibilityFocusState private var isRefreshErrorFocused: Bool
    private let onSelectionChanged: ((AppSelection?) -> Void)?
    private let onCreateInvoice: @MainActor () -> Void

    private var invoices: [Invoice] {
        viewModel.invoiceEntities
    }

    private var persistenceQuerySpec: InvoicePersistenceQuerySpec {
        InvoicesListQueryEngine.buildPersistenceQuerySpec(from: viewModel.listQuerySpec)
    }

    private var reloadTaskID: InvoicesReloadTaskID {
        InvoicesReloadTaskID(
            persistenceSpec: persistenceQuerySpec,
            storeRevision: viewModel.dataRevision
        )
    }

    /// Mirrors `BillingHubProjectionTaskID`: memoizes the O(n) projection so it
    /// only recomputes when invoice rows or list filters actually change.
    private var projectionTaskID: InvoicesProjectionTaskID {
        InvoicesProjectionTaskID(
            invoices: invoices,
            contentRevision: viewModel.listContentRevision,
            spec: viewModel.listQuerySpec
        )
    }

    public init(
        viewModel: InvoicesContainerViewModel,
        onSelectionChanged: ((AppSelection?) -> Void)? = nil,
        onCreateInvoice: @escaping @MainActor () -> Void
    ) {
        self.viewModel = viewModel
        self.onSelectionChanged = onSelectionChanged
        self.onCreateInvoice = onCreateInvoice
    }

    public var body: some View {
        let reloadID = reloadTaskID
        let projectionID = projectionTaskID
        return content
            .toolbar {
                InvoicesContentToolbar(
                    viewModel: viewModel,
                    showingFilterPopover: $showingFilterPopover,
                    uniqueClientNames: cachedProjection?.availableClientNames ?? [],
                    onCreateInvoice: onCreateInvoice
                )
            }
            .navigationTitle("Invoices")
            .task(id: reloadID) {
                do {
                    try await Task.sleep(for: .milliseconds(150))
                    try Task.checkCancellation()
                } catch {
                    return
                }
                await viewModel.reloadInvoices(
                    matching: InvoicesListQueryEngine.buildPersistenceDescriptor(from: viewModel.listQuerySpec)
                )
            }
            .task(id: projectionID) {
                guard viewModel.canProjectCurrentListSpec else { return }
                let projection = InvoicesListQueryEngine.project(
                    invoices: invoices,
                    spec: viewModel.listQuerySpec
                )
                guard !Task.isCancelled,
                      projectionTaskID == projectionID,
                      viewModel.canProjectCurrentListSpec
                else { return }
                cachedProjection = projection
            }
    }

    @ViewBuilder
    private var content: some View {
        switch InvoicesListPresentationPolicy.surface(
            hasProjection: cachedProjection != nil,
            hasCompletedSuccessfulLoad: viewModel.hasCompletedSuccessfulListLoad,
            loadError: viewModel.listLoadError
        ) {
        case .list(let refreshError):
            if let projection = cachedProjection {
                VStack(spacing: 0) {
                    if let actionError = viewModel.actionErrorMessage {
                        actionErrorBanner(actionError)
                    }
                    if let refreshError {
                        refreshErrorBanner(refreshError)
                    } else if viewModel.isLoading || viewModel.isShowingPreviousQueryResults {
                        refreshProgressBanner
                    }
                    invoiceList(projection: projection)
                }
            }
        case .blockingError(let error):
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                EmptyStateView(
                    icon: "exclamationmark.triangle.fill",
                    title: "Failed to Load Invoices",
                    message: error
                )

                if viewModel.isLoading {
                    ProgressView("Trying again…")
                        .controlSize(.small)
                } else {
                    Button("Try Again", systemImage: "arrow.clockwise") {
                        retryListLoad()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading:
            LoadingView("Loading invoices...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func actionErrorBanner(_ error: String) -> some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Label("Invoice action failed", systemImage: "exclamationmark.octagon.fill")
                .font(StyleGuide.Typography.bodyMedium)
                .foregroundStyle(.red)

            Text(error)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .lineLimit(3)

            Spacer(minLength: StyleGuide.Dimensions.paddingSmall)

            Button("Dismiss", systemImage: "xmark") {
                viewModel.dismissActionError()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Dismiss invoice action error")
            .accessibilityLabel("Dismiss invoice action error")
            .accessibilityFocused($isActionErrorFocused)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Invoice action failed")
        .onAppear {
            isActionErrorFocused = true
            InvoiceAccessibilityAnnouncement.announce(
                InvoiceAccessibilityAnnouncement.actionFailed(error)
            )
        }
        .onChange(of: error) { _, newError in
            isActionErrorFocused = true
            InvoiceAccessibilityAnnouncement.announce(
                InvoiceAccessibilityAnnouncement.actionFailed(newError)
            )
        }
    }

    private func refreshErrorBanner(_ error: String) -> some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Label("Invoices couldn't refresh", systemImage: "exclamationmark.triangle.fill")
                .font(StyleGuide.Typography.bodyMedium)
                .foregroundStyle(.orange)

            Text(refreshErrorDetail(error))
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .lineLimit(2)

            Spacer(minLength: StyleGuide.Dimensions.paddingSmall)

            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Retrying invoice refresh")
            } else {
                Button("Try Again", systemImage: "arrow.clockwise") {
                    retryListLoad()
                }
                .buttonStyle(.borderless)
                .accessibilityFocused($isRefreshErrorFocused)
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Invoices couldn't refresh")
        .onAppear {
            if !viewModel.isLoading {
                isRefreshErrorFocused = true
            }
            InvoiceAccessibilityAnnouncement.announce(
                InvoiceAccessibilityAnnouncement.refreshFailed(refreshErrorDetail(error))
            )
        }
        .onChange(of: error) { _, newError in
            if !viewModel.isLoading {
                isRefreshErrorFocused = true
            }
            InvoiceAccessibilityAnnouncement.announce(
                InvoiceAccessibilityAnnouncement.refreshFailed(refreshErrorDetail(newError))
            )
        }
    }

    private var refreshProgressBanner: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)
            Text(
                viewModel.isShowingPreviousQueryResults
                    ? "Updating invoice results… Showing previous results for now."
                    : "Refreshing invoices…"
            )
            .font(StyleGuide.Typography.caption)
            .foregroundStyle(StyleGuide.Colors.textSecondary)
            Spacer(minLength: StyleGuide.Dimensions.paddingSmall)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .combine)
    }

    private func refreshErrorDetail(_ error: String) -> String {
        if viewModel.isShowingPreviousQueryResults {
            return "\(error) Showing results from before the filter change."
        }
        return "\(error) Showing last loaded results."
    }

    private func retryListLoad() {
        Task {
            await viewModel.reloadInvoices(
                matching: InvoicesListQueryEngine.buildPersistenceDescriptor(
                    from: viewModel.listQuerySpec
                )
            )
        }
    }

    private func invoiceList(projection: InvoicesListProjection) -> some View {
        InvoicesView(
            selectedInvoice: $viewModel.selectedInvoice,
            projection: projection,
            containerViewModel: viewModel,
            onSelectionChanged: onSelectionChanged,
            onCreateInvoice: onCreateInvoice
        )
        .scrollContentBackground(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

enum InvoicesListSurface: Equatable {
    case loading
    case blockingError(String)
    case list(refreshError: String?)
}

enum InvoicesListPresentationPolicy {
    static func surface(
        hasProjection: Bool,
        hasCompletedSuccessfulLoad: Bool,
        loadError: String?
    ) -> InvoicesListSurface {
        if hasProjection, hasCompletedSuccessfulLoad {
            return .list(refreshError: loadError)
        }
        if let loadError {
            return .blockingError(loadError)
        }
        return .loading
    }
}

struct InvoicesReloadTaskID: Equatable {
    let persistenceSpec: InvoicePersistenceQuerySpec
    let storeRevision: Int
}

/// Lightweight identity for invoice list projection rebuilds — avoids
/// recomputing the O(n) projection on every layout pass.
private struct InvoicesProjectionTaskID: Equatable {
    let invoiceCount: Int
    let contentRevision: Int
    let spec: InvoicesListQuerySpec

    init(invoices: [Invoice], contentRevision: Int, spec: InvoicesListQuerySpec) {
        self.invoiceCount = invoices.count
        self.contentRevision = contentRevision
        self.spec = spec
    }
}
