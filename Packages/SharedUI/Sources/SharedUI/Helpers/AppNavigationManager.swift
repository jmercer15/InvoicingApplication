import Foundation
import SwiftUI
import Core
import Observation

// MARK: - App Navigation Manager
@Observable
@MainActor
public class AppNavigationManager {
    public var selectedTab: AppTab = .invoices
    public var navigationContext: NavigationContext?
    public private(set) var navigationPath: [WorkspaceRoute] = []
    public private(set) var navigationPersistenceToken = UUID()
    /// Workspace list/detail and deep links update this; tab coordinators mirror it for ``inspectorFallbackSelection()`` when `selection` is briefly nil (e.g. secondary window timing).
    public var selection: AppSelection? {
        didSet {
            guard selection != oldValue else { return }
            syncCoordinatorsWithInspectorFallback(selection)
            syncNavigationPathWithSelection(selection)
        }
    }
    public var inspectorIsPresented: Bool = false
    public var columnVisibility: NavigationSplitViewVisibility = .automatic

    /// Per-tab focused targets used by the standalone inspector when selection is briefly nil.
    public let invoicesCoordinator = InvoicesWorkspaceCoordinator()
    public let relationshipsCoordinator = RelationshipsWorkspaceCoordinator()
    public let ndisCoordinator = NDISWorkspaceCoordinator()

    // MARK: - Navigation History
    private var historyStore = NavigationHistoryStore()
    private var isNavigatingInternally: Bool = false
    private var isUpdatingNavigationPath: Bool = false

    public init() {
        // Add initial invoices entry to history
        addToHistory(tab: .invoices, context: nil, title: "Invoices")
    }

    /// Records inspector-fallback targets while central path ownership stays in explicit selection/navigation APIs.
    private func syncCoordinatorsWithInspectorFallback(_ selection: AppSelection?) {
        guard let selection else { return }
        switch selection {
        case .invoice(let id):
            invoicesCoordinator.recordFocusedInvoice(id)
        case .client, .payee, .planManager:
            relationshipsCoordinator.recordFocusedRelationship(selection: selection)
        case .ndisItem(let id):
            ndisCoordinator.recordFocusedNDISItem(id)
        }
    }

    private func syncNavigationPathWithSelection(_ selection: AppSelection?) {
        guard !isUpdatingNavigationPath else { return }
        let route = WorkspaceRoute(selection)
        navigationContext = route?.navigationContext
        setNavigationPath(to: route)
    }

    public func isSelectionCompatible(with tab: AppTab, _ selection: AppSelection?) -> Bool {
        guard let selection else { return true }

        switch tab {
        case .invoices:
            switch selection {
            case .invoice:
                return true
            default:
                return false
            }
        case .relationships:
            switch selection {
            case .client, .payee, .planManager:
                return true
            default:
                return false
            }
        case .ndisCatalogue:
            switch selection {
            case .ndisItem:
                return true
            default:
                return false
            }
        case .calendar, .billingHub, .invoiceTemplateEditor:
            return false
        }
    }

    public func isSelectionCompatible(with tab: AppTab) -> Bool {
        isSelectionCompatible(with: tab, selection)
    }

    public func isNavigationContextCompatible(with tab: AppTab, _ context: NavigationContext?) -> Bool {
        guard let context else { return true }

        switch tab {
        case .invoices:
            return context.targetEntityType == .invoice
        case .relationships:
            return context.targetEntityType == .client
            || context.targetEntityType == .payee
            || context.targetEntityType == .planManager
            || context.targetEntityType == .clientService
        case .ndisCatalogue:
            return context.targetEntityType == .ndisItem
        case .calendar:
            return context.targetEntityType == .session
            || context.targetEntityType == .client
        case .billingHub, .invoiceTemplateEditor:
            return false
        }
    }

    public func isNavigationContextCompatible(with tab: AppTab) -> Bool {
        isNavigationContextCompatible(with: tab, navigationContext)
    }

    public func applyTabSelectionRules(newTab: AppTab) {
        if !isSelectionCompatible(with: newTab, selection) || !isNavigationContextCompatible(with: newTab, navigationContext) {
            withNavigationPathSyncSuppressed {
                selection = nil
                navigationContext = nil
            }
            setNavigationPath(to: nil)
            return
        }
    }

    private func applyState(from route: WorkspaceRoute) {
        withNavigationPathSyncSuppressed {
            selectedTab = route.workspaceTab
            navigationContext = route.navigationContext
            selection = route.selection
        }
    }

    public func updateNavigationPathFromStack(_ path: [WorkspaceRoute]) {
        guard navigationPath != path else { return }
        withNavigationPathSyncSuppressed {
            navigationPath = path
            if let route = path.last {
                applyState(from: route)
            } else {
                selection = nil
                navigationContext = nil
            }
        }
        markNavigationChanged()
    }

    public func restoreNavigationPath(_ path: [WorkspaceRoute]) {
        guard navigationPath != path else { return }
        withNavigationPathSyncSuppressed {
            navigationPath = path
            if let route = path.last {
                applyState(from: route)
            } else {
                selection = nil
                navigationContext = nil
            }
        }
        markNavigationChanged()
    }

    public func setNavigationPath(to route: WorkspaceRoute?) {
        guard !isUpdatingNavigationPath else { return }
        let nextPath = route.map { [$0] } ?? []
        guard navigationPath != nextPath else { return }
        navigationPath = nextPath
        markNavigationChanged()
    }

    private func markNavigationChanged() {
        navigationPersistenceToken = UUID()
    }

    private func withNavigationPathSyncSuppressed(_ operation: () -> Void) {
        let previous = isUpdatingNavigationPath
        isUpdatingNavigationPath = true
        operation()
        isUpdatingNavigationPath = previous
    }

    private func route(for context: NavigationContext?, in tab: AppTab) -> WorkspaceRoute? {
        guard let route = WorkspaceRoute(context), route.workspaceTab == tab else { return nil }
        return route
    }

    // MARK: - History Management

    /// Add current navigation to history
    private func addToHistory(tab: AppTab, context: NavigationContext?, title: String? = nil) {
        historyStore.addToHistory(tab: tab, context: context, title: title)
    }

    /// Get current history entry
    public var currentHistoryEntry: NavigationHistoryEntry? {
        historyStore.currentHistoryEntry
    }
    
    /// Check if we can navigate back
    public var canNavigateBack: Bool {
        historyStore.canNavigateBack
    }
    
    /// Check if we can navigate forward
    public var canNavigateForward: Bool {
        historyStore.canNavigateForward
    }
    
    /// Navigate back in history
    public func navigateBack() {
        guard let entry = historyStore.navigateBack() else { return }

        isNavigatingInternally = true
        applyNavigation(to: entry.tab, context: entry.context)
        isNavigatingInternally = false
    }
    
    /// Navigate forward in history
    public func navigateForward() {
        guard let entry = historyStore.navigateForward() else { return }

        isNavigatingInternally = true
        applyNavigation(to: entry.tab, context: entry.context)
        isNavigatingInternally = false
    }
    
    /// Get navigation history for display (most recent first)
    public var recentHistory: [NavigationHistoryEntry] {
        historyStore.recentHistory
    }
    
    /// Get back navigation entry (previous entry)
    public var backNavigationEntry: NavigationHistoryEntry? {
        historyStore.backNavigationEntry
    }
    
    /// Get forward navigation entry (next entry)
    public var forwardNavigationEntry: NavigationHistoryEntry? {
        historyStore.forwardNavigationEntry
    }
    
    // MARK: - Primary Navigation Methods
    
    /// Navigate to a specific tab with optional context
    public func navigateTo(tab: AppTab, context: NavigationContext? = nil, title: String? = nil) {
        let nextRoute = route(for: context, in: tab)
        let nextContext = isNavigationContextCompatible(with: tab, context) ? context : nil
        let nextPath = tab.usesWorkspaceRouteNavigation
            ? nextRoute.map { [$0] } ?? []
            : []

        guard selectedTab != tab
                || navigationContext != nextContext
                || selection != nextRoute?.selection
                || navigationPath != nextPath
        else {
            return
        }
        addToHistory(tab: tab, context: context, title: title)
        isNavigatingInternally = true
        applyNavigation(to: tab, context: context)
        isNavigatingInternally = false
    }

    /// Tab switch without pushing history (sidebar, keyboard shortcuts). Replaces entry at current cursor.
    public func selectTab(_ tab: AppTab) {
        guard tab != selectedTab else { return }
        isNavigatingInternally = true
        applyNavigation(to: tab, context: navigationContext)
        historyStore.replaceCurrentEntry(tab: selectedTab, context: navigationContext)
        isNavigatingInternally = false
    }

    private func applyNavigation(to tab: AppTab, context: NavigationContext?) {
        let nextRoute = route(for: context, in: tab)
        withNavigationPathSyncSuppressed {
            navigationContext = context
            selectedTab = tab
            if let nextRoute {
                selection = nextRoute.selection
            } else if context == nil {
                selection = nil
                navigationContext = nil
            } else if !isNavigationContextCompatible(with: tab, context) {
                selection = nil
                navigationContext = nil
            } else {
                selection = nil
            }
        }
        if tab.usesWorkspaceRouteNavigation {
            setNavigationPath(to: nextRoute)
        } else {
            setNavigationPath(to: nil)
        }
    }
    
    /// Navigate to view a specific client in the relationships tab
    public func navigateToClient(_ clientID: UUID) {
        let context = NavigationContext(
            targetEntity: clientID,
            targetEntityType: .client
        )
        navigateTo(tab: .relationships, context: context, title: "Client Details")
    }
    
    /// Navigate to view a specific session in the calendar tab
    public func navigateToSession(_ sessionID: UUID, date: Date? = nil) {
        let context = NavigationContext(
            targetEntity: sessionID,
            targetEntityType: .session,
            targetDate: date
        )
        navigateTo(tab: .calendar, context: context, title: "Session Details")
    }
    
    /// Navigate to view a specific invoice in the invoices tab
    public func navigateToInvoice(_ invoiceID: UUID) {
        let context = NavigationContext(
            targetEntity: invoiceID,
            targetEntityType: .invoice
        )
        navigateTo(tab: .invoices, context: context, title: "Invoice Details")
    }
    
    /// Navigate to view a specific payee in the relationships tab
    public func navigateToPayee(_ payeeID: UUID) {
        let context = NavigationContext(
            targetEntity: payeeID,
            targetEntityType: .payee
        )
        navigateTo(tab: .relationships, context: context)
    }
    
    /// Navigate to view a specific plan manager in the relationships tab
    public func navigateToPlanManager(_ planManagerID: UUID) {
        let context = NavigationContext(
            targetEntity: planManagerID,
            targetEntityType: .planManager
        )
        navigateTo(tab: .relationships, context: context)
    }
    
    /// Navigate to view a specific client service in the relationships tab
    public func navigateToClientService(_ clientServiceID: UUID) {
        let context = NavigationContext(
            targetEntity: clientServiceID,
            targetEntityType: .clientService
        )
        navigateTo(tab: .relationships, context: context)
    }
    
    /// Navigate to view a specific NDIS item in the NDIS catalogue
    public func navigateToNDISItem(_ ndisItemID: UUID, searchQuery: String? = nil) {
        let context = NavigationContext(
            targetEntity: ndisItemID,
            targetEntityType: .ndisItem,
            searchQuery: searchQuery
        )
        navigateTo(tab: .ndisCatalogue, context: context)
    }
    
    /// Applies menu-driven intents; pure routing uses navigation history. Creation intents delegate to the supplied closures because they require feature view models.
    public func applyRoutingIntent(
        _ intent: WorkspaceRoutingIntent,
        onCreateInvoice: (() -> Void)? = nil,
        onCreateSession: (() -> Void)? = nil
    ) {
        switch intent {
        case .selectTab(let tab):
            selectTab(tab)
        case .createNewInvoice:
            onCreateInvoice?()
        case .createNewSession:
            onCreateSession?()
        case .toggleInspector:
            inspectorIsPresented.toggle()
        }
    }

    /// Aligns back/forward cursor with restored tab/path after ``SceneStorage`` restore. Replaces current slot; does not grow stack (per Apple scene state restoration).
    public func reconcileHistoryAfterSceneRestore() {
        isNavigatingInternally = true
        historyStore.replaceCurrentEntry(tab: selectedTab, context: navigationContext)
        isNavigatingInternally = false
    }

    /// Ensure current tab is properly tracked in history (safety net for external changes)
    public func ensureCurrentTabInHistory() {
        // Don't add to history if this change was initiated internally
        guard !isNavigatingInternally else { return }
        
        let currentEntry = NavigationHistoryEntry(tab: selectedTab, context: navigationContext)
        
        // Check if current state is already the latest entry
        if let lastEntry = historyStore.latestEntry,
           lastEntry == currentEntry {
            return // Already tracked
        }
        
        // Add current state to history
        addToHistory(tab: selectedTab, context: navigationContext)
    }
}
