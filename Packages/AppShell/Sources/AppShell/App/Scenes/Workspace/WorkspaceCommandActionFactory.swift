import Core
import Feature_Invoices
import Foundation
import InvoiceTableLayoutEditor
import SharedUI

enum WorkspaceInvoiceCreationHandoff {
    /// Creation stays owned by Feature.Invoices. Navigation occurs only after created record is
    /// materialized and selected, so Template Editor never exposes a half-created real document.
    @MainActor
    @discardableResult
    static func perform(
        createInvoice: () async throws -> UUID,
        openInvoice: (UUID) -> Void
    ) async throws -> UUID {
        let id = try await createInvoice()
        openInvoice(id)
        return id
    }
}

enum WorkspaceCommandActionFactory {
    @MainActor
    static func make(
        features: WorkspaceFeatureRegistries,
        navigationManager nav: AppNavigationManager
    ) -> WorkspaceCommandActions {
        let onInvoicesTab = nav.selectedTab == .invoices
        let hasSelectedInvoice = onInvoicesTab && features.invoices.selectedInvoice != nil

        return make(
            navigationManager: nav,
            createNewInvoice: {
                guard !features.invoices.isCreatingInvoice else { return }
                Task {
                    do {
                        try await WorkspaceInvoiceCreationHandoff.perform(
                            createInvoice: features.invoices.createInvoice,
                            openInvoice: nav.navigateToInvoice
                        )
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
            },
            createNewSession: {
                nav.navigateTo(tab: .calendar)
                features.calendar.createNewSession()
            },
            canToggleInspector: hasSelectedInvoice,
            canCreateNewInvoice: !features.invoices.isCreatingInvoice
        )
    }

    @MainActor
    static func make(
        navigationManager nav: AppNavigationManager,
        createNewInvoice: (() -> Void)? = nil,
        createNewSession: (() -> Void)? = nil,
        canToggleInspector: Bool = true,
        canCreateNewInvoice: Bool = true
    ) -> WorkspaceCommandActions {
        WorkspaceCommandActions(
            availability: WorkspaceCommandAvailability(
                selectedTab: nav.selectedTab,
                canNavigateBack: nav.canNavigateBack,
                canNavigateForward: nav.canNavigateForward,
                canCreateNewInvoice: createNewInvoice != nil && canCreateNewInvoice,
                canCreateNewSession: createNewSession != nil,
                canToggleInspector: canToggleInspector
            ),
            switchToTab: { tab in
                nav.applyRoutingIntent(WorkspaceRoutingIntent.selectTab(tab))
            },
            navigateBack: { nav.navigateBack() },
            navigateForward: { nav.navigateForward() },
            createNewInvoice: {
                nav.applyRoutingIntent(.createNewInvoice, onCreateInvoice: createNewInvoice)
            },
            createNewSession: {
                nav.applyRoutingIntent(.createNewSession, onCreateSession: createNewSession)
            },
            toggleInspector: {
                nav.applyRoutingIntent(WorkspaceRoutingIntent.toggleInspector)
            },
            canSwitchToTab: { tab in
                nav.selectedTab != tab
            },
            canNavigateBack: { nav.canNavigateBack },
            canNavigateForward: { nav.canNavigateForward },
            canCreateNewInvoice: createNewInvoice != nil && canCreateNewInvoice,
            canCreateNewSession: createNewSession != nil,
            canToggleInspector: canToggleInspector
        )
    }
}
