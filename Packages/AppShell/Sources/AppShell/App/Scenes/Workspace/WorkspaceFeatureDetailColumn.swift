import SwiftUI
import Core
import PersistenceModels
import SharedUI
import Feature_Calendar
import Feature_BillingHub
import Feature_Clients
import Feature_Invoices
import Feature_NDIS
import InvoiceTableLayoutEditor

struct WorkspaceFeatureDetailColumn: View {
    let feature: AppTab
    let features: WorkspaceFeatureRegistries
    let navigationManager: AppNavigationManager

    private var nav: AppNavigationManager { navigationManager }

    private var entityNavigation: WorkspaceEntityNavigationHandlers {
        makeWorkspaceEntityNavigationHandlers(navigationManager: nav)
    }

    var body: some View {
        content
            .id(feature)
            .onAppear {
                syncRouteSelection(with: nav.navigationPath.last)
                nav.ensureCurrentTabInHistory()
            }
            .onChange(of: nav.navigationPath) { oldPath, newPath in
                guard oldPath != newPath else { return }
                syncRouteSelection(with: newPath.last)
            }
            .toolbar {
                WorkspaceHistoryToolbar(
                    canNavigateBack: nav.canNavigateBack,
                    canNavigateForward: nav.canNavigateForward,
                    navigateBack: nav.navigateBack,
                    navigateForward: nav.navigateForward
                )
            }
    }

    @MainActor
    private func syncRouteSelection(with route: WorkspaceRoute?) {
        guard feature == nav.selectedTab else { return }
        guard let route else {
            clearActiveFeatureSelection()
            return
        }
        switch route {
        case .invoice(let id) where feature == .invoices:
            features.invoices.selectInvoiceForDeepLink(id: id)
        case .client(let id):
            features.relationships.detailState = .client(id)
        case .payee(let id):
            features.relationships.detailState = .payee(id)
        case .planManager(let id):
            features.relationships.detailState = .planManager(id)
        case .clientService:
            features.relationships.clearSelection()
        case .ndisItem(let id) where feature == .ndisCatalogue:
            features.ndisCatalogue.selectItemForInspectorFocus(id: id)
        case .session(let id) where feature == .calendar:
            Task {
                await features.calendar.openSession(sessionID: id)
            }
        default:
            break
        }
    }

    @MainActor
    private func clearActiveFeatureSelection() {
        switch feature {
        case .invoices:
            features.invoices.clearSelection()
        case .relationships:
            features.relationships.clearSelection()
        case .ndisCatalogue:
            features.ndisCatalogue.clearSelection()
        case .calendar:
            features.calendar.clearSelectedSession()
        default:
            break
        }
    }

    @ViewBuilder
    private var content: some View {
        switch feature {
        case .invoices:
            TableLayoutInvoiceEditorView(
                selection: invoiceSelectionBinding,
                session: features.invoices.editorSession,
                documentRefreshRevision: features.invoices.dataRevision,
                onCreateInvoice: createInvoiceHandoff,
                onOpenTemplateEditor: {
                    nav.applyRoutingIntent(.selectTab(.invoiceTemplateEditor))
                },
                onBackToBillingHub: billingHubBackAction,
                isCreatingInvoice: features.invoices.isCreatingInvoice
            )

        case .relationships:
            RelationshipsDetailColumn(
                viewModel: features.relationships,
                onOpenInvoice: entityNavigation.openInvoice,
                onOpenClient: entityNavigation.openClient
            )

        case .ndisCatalogue:
            NDISCatalogueDetailColumn(viewModel: features.ndisCatalogue)

        case .billingHub:
            BillingHubView(
                viewModel: features.billingHub,
                openInvoice: { invoiceID in
                    let focusID = BillingHubInvoiceNavigationFocus.focusCardID(
                        forOpenedInvoice: invoiceID
                    )
                    entityNavigation.openInvoiceFromBillingHub(invoiceID, focusID)
                },
                openSession: entityNavigation.openSession
            )

        case .calendar:
            CalendarContentColumn(
                viewModel: features.calendar,
                openBillingHub: { focusSessionIDs in
                    nav.applyRoutingIntent(
                        .openBillingHub(focusSessionIDs: focusSessionIDs),
                        onOpenBillingHub: { ids in
                            features.billingHub.queueFocus(cardIDs: ids)
                            nav.selectTab(.billingHub)
                        }
                    )
                }
            )

        case .invoiceTemplateEditor:
            TableLayoutInvoiceEditorView(
                onCreateInvoice: createInvoiceHandoff,
                onOpenInvoices: {
                    nav.applyRoutingIntent(.selectTab(.invoices))
                },
                isCreatingInvoice: features.invoices.isCreatingInvoice
            )
        }
    }

    private var invoiceSelectionBinding: Binding<UUID?> {
        Binding(
            get: { features.invoices.selectedInvoice?.id },
            set: { id in
                if let id {
                    entityNavigation.openInvoice(id)
                } else {
                    features.invoices.clearSelection()
                    nav.selection = nil
                }
            }
        )
    }

    @MainActor
    private func createInvoiceHandoff() async throws {
        try await WorkspaceInvoiceCreationHandoff.perform(
            createInvoice: features.invoices.createInvoice,
            openInvoice: entityNavigation.openInvoice
        )
    }

    private var billingHubBackAction: (@MainActor () -> Void)? {
        guard nav.navigationContext?.sourceTab == .billingHub else { return nil }
        return { @MainActor [navigationManager, features] in
            let focusID = navigationManager.navigationContext?.sourceFocusID
            if let focusID {
                features.billingHub.queueFocus(cardIDs: [focusID])
            }
            navigationManager.selectTab(.billingHub)
        }
    }
}
