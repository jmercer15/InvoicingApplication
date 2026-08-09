import SwiftUI
import Core
import SharedUI
import Feature_BillingHub
import Feature_Clients
import Feature_Invoices
import Feature_NDIS
import InvoiceTableLayoutEditor

struct WorkspaceFeatureContentColumn: View {
    let feature: AppTab
    let features: WorkspaceFeatureRegistries
    let navigationManager: AppNavigationManager

    var body: some View {
        content
    }

    private var entityNavigation: WorkspaceEntityNavigationHandlers {
        makeWorkspaceEntityNavigationHandlers(navigationManager: navigationManager)
    }

    @MainActor
    private func routeSelection(_ selection: AppSelection?) {
        guard let selection else {
            navigationManager.selection = nil
            return
        }

        switch selection {
        case .invoice(let id):
            entityNavigation.openInvoice(id)
        case .client(let id):
            entityNavigation.openClient(id)
        case .payee(let id):
            entityNavigation.openPayee(id)
        case .planManager(let id):
            entityNavigation.openPlanManager(id)
        case .ndisItem(let id):
            entityNavigation.openNDISItem(id)
        }
    }

    @MainActor
    private func createInvoiceFromColumn() {
        Task {
            guard !features.invoices.isCreatingInvoice else { return }
            do {
                let id = try await features.invoices.createInvoice()
                entityNavigation.openInvoice(id)
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice data could not be created. Try again."
                )
                features.invoices.reportActionError(
                    "New invoice could not be created. \(detail)"
                )
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch feature {
        case .invoices:
            InvoicesContentColumn(
                viewModel: features.invoices,
                onSelectionChanged: routeSelection,
                onCreateInvoice: createInvoiceFromColumn
            )
        case .relationships:
            VStack(spacing: 12) {
                WorkspaceShortcutsDiscoveryView()
                    .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                    .padding(.top, StyleGuide.Dimensions.paddingSmall)
                RelationshipsContentColumn(
                    viewModel: features.relationships,
                    onSelectionChanged: routeSelection
                )
            }
        case .ndisCatalogue:
            NDISCatalogueContentColumn(
                viewModel: features.ndisCatalogue,
                onSelectionChanged: routeSelection
            )
        default:
            EmptyView()
        }
    }
}
