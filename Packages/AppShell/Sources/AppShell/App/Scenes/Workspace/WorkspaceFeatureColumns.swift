import SwiftUI
import Core
import SharedUI
import Feature_Calendar
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

    @ViewBuilder
    private var content: some View {
        switch feature {
        case .invoices:
            InvoicesContentColumn(
                viewModel: features.invoices,
                onSelectionChanged: routeSelection,
                onCreateInvoice: {
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
            )
        case .relationships:
            RelationshipsContentColumn(
                viewModel: features.relationships,
                onSelectionChanged: routeSelection
            )
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
                selection: Binding(
                    get: { features.invoices.selectedInvoice?.id },
                    set: { id in
                        if let id {
                            entityNavigation.openInvoice(id)
                        } else {
                            features.invoices.clearSelection()
                            nav.selection = nil
                        }
                    }
                ),
                session: features.invoices.editorSession,
                onCreateInvoice: {
                    try await WorkspaceInvoiceCreationHandoff.perform(
                        createInvoice: features.invoices.createInvoice,
                        openInvoice: entityNavigation.openInvoice
                    )
                },
                onOpenTemplateEditor: {
                    nav.applyRoutingIntent(.selectTab(.invoiceTemplateEditor))
                },
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
                openInvoice: entityNavigation.openInvoice,
                openSession: entityNavigation.openSession
            )

        case .calendar:
            CalendarContentColumn(viewModel: features.calendar)

        case .invoiceTemplateEditor:
            TableLayoutInvoiceEditorView(
                onCreateInvoice: {
                    try await WorkspaceInvoiceCreationHandoff.perform(
                        createInvoice: features.invoices.createInvoice,
                        openInvoice: entityNavigation.openInvoice
                    )
                },
                onOpenInvoices: {
                    nav.applyRoutingIntent(.selectTab(.invoices))
                },
                isCreatingInvoice: features.invoices.isCreatingInvoice
            )
        }
    }
}
