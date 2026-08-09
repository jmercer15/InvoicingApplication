import Core
import Observation
@testable import SharedUI
import Foundation
import Synchronization
import Testing
@MainActor
@Suite struct AppNavigationManagerTests {
    @Test func RepeatedCurrentTabSelectionDoesNotRepublishNavigationState() {
        let manager = AppNavigationManager()
        let persistenceToken = manager.navigationPersistenceToken
        let navigationStateChanged = Mutex(false)

        withObservationTracking {
            _ = manager.selectedTab
            _ = manager.navigationContext
            _ = manager.selection
            _ = manager.navigationPath
        } onChange: {
            navigationStateChanged.withLock { $0 = true }
        }

        manager.selectTab(.invoices)

        #expect(!navigationStateChanged.withLock { $0 })
        #expect(manager.navigationPersistenceToken == persistenceToken)
        #expect(manager.selectedTab == .invoices)
    }

    @Test func RepeatedEntityNavigationDoesNotRepublishCurrentRouteState() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        manager.navigateToInvoice(invoiceID)
        let persistenceToken = manager.navigationPersistenceToken
        let routeStateChanged = Mutex(false)

        withObservationTracking {
            _ = manager.selectedTab
            _ = manager.navigationContext
            _ = manager.selection
            _ = manager.navigationPath
        } onChange: {
            routeStateChanged.withLock { $0 = true }
        }

        manager.navigateToInvoice(invoiceID)

        #expect(!routeStateChanged.withLock { $0 })
        #expect(manager.navigationPersistenceToken == persistenceToken)
        #expect(manager.navigationPath == [.invoice(invoiceID)])
    }

    @Test func RootNavigationClearsEntitySelectionContextAndPathTogether() {
        let manager = AppNavigationManager()
        manager.navigateToInvoice(UUID())

        manager.navigateTo(tab: .invoices)

        #expect(manager.selectedTab == .invoices)
        #expect(manager.selection == nil)
        #expect(manager.navigationContext == nil)
        #expect(manager.navigationPath.isEmpty)
    }

    @Test func RepeatedRootNavigationDoesNotRepublishNavigationState() {
        let manager = AppNavigationManager()
        manager.navigateTo(tab: .billingHub)
        let persistenceToken = manager.navigationPersistenceToken
        let historyDepth = manager.recentHistory.count
        let navigationStateChanged = Mutex(false)

        withObservationTracking {
            _ = manager.selectedTab
            _ = manager.navigationContext
            _ = manager.selection
            _ = manager.navigationPath
        } onChange: {
            navigationStateChanged.withLock { $0 = true }
        }

        manager.navigateTo(tab: .billingHub)

        #expect(!navigationStateChanged.withLock { $0 })
        #expect(manager.navigationPersistenceToken == persistenceToken)
        #expect(manager.recentHistory.count == historyDepth)
    }

    @Test func NavigationHistoryRestoresTabAndContextWhenNavigatingBackAndForward() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        let clientID = UUID()

        manager.navigateToInvoice(invoiceID)
        manager.navigateToClient(clientID)

        #expect(manager.selectedTab == .relationships)
        #expect(manager.navigationContext?.targetEntity == clientID)
        #expect(manager.navigationContext?.targetEntityType == .client)
        #expect(manager.canNavigateBack)
        #expect(!(manager.canNavigateForward))

        manager.navigateBack()

        #expect(manager.selectedTab == .invoices)
        #expect(manager.navigationContext?.targetEntity == invoiceID)
        #expect(manager.navigationContext?.targetEntityType == .invoice)
        #expect(manager.canNavigateForward)

        manager.navigateForward()

        #expect(manager.selectedTab == .relationships)
        #expect(manager.navigationContext?.targetEntity == clientID)
        #expect(manager.navigationContext?.targetEntityType == .client)
    }

    @Test func SelectionUpdatesInspectorFallbackCoordinators() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()

        manager.selection = .invoice(invoiceID)

        #expect(manager.inspectorFallbackSelection() == .invoice(invoiceID))
    }

    @Test func SelectionUpdatesCentralNavigationPath() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()

        manager.selection = .invoice(invoiceID)

        #expect(manager.navigationPath == [.invoice(invoiceID)])
    }

    @Test func ClearingCentralNavigationPathClearsSelectionAndContext() {
        let manager = AppNavigationManager()

        manager.navigateToInvoice(UUID())
        #expect(manager.navigationPath.count == 1)
        #expect(manager.selection != nil)
        #expect(manager.navigationContext != nil)

        manager.updateNavigationPathFromStack([])

        #expect(manager.navigationPath.count == 0)
        #expect(manager.selection == nil)
        #expect(manager.navigationContext == nil)
    }

    @Test func RestoresCodableCentralNavigationPath() throws {
        let path = [WorkspaceRoute.client(UUID())]
        let data = try JSONEncoder().encode(path)
        let restoredPath = try JSONDecoder().decode([WorkspaceRoute].self, from: data)

        let manager = AppNavigationManager()
        manager.restoreNavigationPath(restoredPath)

        #expect(manager.navigationPath.count == 1)
    }

    @Test func RestoresNavigationPathWithRouteToSelectionAndContext() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        let path = [WorkspaceRoute.invoice(invoiceID)]

        manager.restoreNavigationPath(path)

        #expect(manager.selectedTab == .invoices)
        #expect(manager.selection == .invoice(invoiceID))
        #expect(manager.navigationContext?.targetEntity == invoiceID)
        #expect(manager.navigationContext?.targetEntityType == .invoice)
    }

    @Test func RestoreNavigationPathWinsOverStaleSelectionAndContext() {
        let manager = AppNavigationManager()
        let staleSelectionID = UUID()
        let staleContextID = UUID()
        let routeID = UUID()

        manager.selection = .invoice(staleSelectionID)
        manager.navigationContext = NavigationContext(
            targetEntity: staleContextID,
            targetEntityType: .client
        )
        manager.restoreNavigationPath([.session(routeID)])

        #expect(manager.selectedTab == .calendar)
        #expect(manager.selection == nil)
        #expect(manager.navigationContext?.targetEntity == routeID)
        #expect(manager.navigationContext?.targetEntityType == .session)
        #expect(manager.navigationPath.count == 1)
    }

    @Test func RestoresMultiSegmentNavigationPathFromLastRoute() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        let clientID = UUID()
        let path = [
            WorkspaceRoute.client(clientID),
            WorkspaceRoute.invoice(invoiceID)
        ]

        manager.restoreNavigationPath(path)

        #expect(manager.navigationPath.count == 2)
        #expect(manager.selectedTab == .invoices)
        #expect(manager.selection == .invoice(invoiceID))
        #expect(manager.navigationContext?.targetEntity == invoiceID)
        #expect(manager.navigationContext?.targetEntityType == .invoice)
    }

    @Test func SelectionClearedOnIncompatibleTabSwitch() {
        let manager = AppNavigationManager()
        let clientID = UUID()

        manager.navigateToClient(clientID)
        #expect(manager.selection == .client(clientID))
        #expect(manager.navigationContext?.targetEntityType == .client)

        manager.applyTabSelectionRules(newTab: .calendar)

        #expect(manager.selection == nil)
        #expect(manager.navigationContext == nil)
    }

    @Test func ClientServiceRouteRestoresDeterministicStateFromPath() {
        let manager = AppNavigationManager()
        let clientServiceID = UUID()
        let path = [WorkspaceRoute.clientService(clientServiceID)]

        manager.restoreNavigationPath(path)

        #expect(manager.selectedTab == .relationships)
        #expect(manager.selection == nil)
        #expect(manager.navigationContext?.targetEntity == clientServiceID)
        #expect(manager.navigationContext?.targetEntityType == .clientService)
    }

    @Test func SameDepthRouteChangeUpdatesNavigationPersistenceToken() {
        let manager = AppNavigationManager()

        manager.navigateToSession(UUID())
        let firstToken = manager.navigationPersistenceToken

        manager.navigateToSession(UUID())

        #expect(manager.navigationPath.count == 1)
        #expect(manager.navigationPersistenceToken != firstToken)
    }

    @Test func MismatchedContextDoesNotPushRouteForDifferentTab() {
        let manager = AppNavigationManager()

        manager.navigateTo(
            tab: .calendar,
            context: NavigationContext(
                targetEntity: UUID(),
                targetEntityType: .client
            )
        )

        #expect(manager.selectedTab == .calendar)
        #expect(manager.navigationContext?.targetEntityType == .client)
        #expect(manager.navigationPath.count == 0)
    }

    @Test func ContextNavigationClearsStaleSelectionWhenNoMatchingRouteSelectionExists() {
        let manager = AppNavigationManager()

        manager.navigateToClient(UUID())
        #expect(manager.selection != nil)

        manager.navigateToClientService(UUID())

        #expect(manager.selectedTab == .relationships)
        #expect(manager.selection == nil)
        #expect(manager.navigationContext?.targetEntityType == .clientService)
        #expect(manager.navigationPath.count == 1)
    }

    @Test func AllowedContextWithoutMatchingRouteClearsStaleSelectionButKeepsContext() {
        let manager = AppNavigationManager()

        manager.navigateToInvoice(UUID())
        #expect(manager.selection != nil)

        manager.navigateTo(
            tab: .calendar,
            context: NavigationContext(
                targetEntity: UUID(),
                targetEntityType: .client
            )
        )

        #expect(manager.selectedTab == .calendar)
        #expect(manager.selection == nil)
        #expect(manager.navigationContext?.targetEntityType == .client)
        #expect(manager.navigationPath.count == 0)
    }

    @Test func HistoryForwardDoesNotPushMismatchedContextRoute() {
        let manager = AppNavigationManager()

        manager.navigateToInvoice(UUID())
        manager.navigateTo(
            tab: .calendar,
            context: NavigationContext(
                targetEntity: UUID(),
                targetEntityType: .client
            )
        )
        manager.navigateBack()
        manager.navigateForward()

        #expect(manager.selectedTab == .calendar)
        #expect(manager.navigationContext?.targetEntityType == .client)
        #expect(manager.navigationPath.count == 0)
    }

    @Test func EnsureCurrentTabInHistoryDoesNotDuplicateLatestEntry() {
        let manager = AppNavigationManager()

        manager.ensureCurrentTabInHistory()

        #expect(manager.recentHistory.count == 1)
        #expect(!(manager.canNavigateBack))
    }

    /// SceneStorage restore must not append a spurious history entry (init default vs restored tab).
    @Test func ReconcileHistoryAfterSceneRestoreReplacesCursorWithoutGrowingDepth() {
        let manager = AppNavigationManager()
        let clientID = UUID()

        manager.navigateToClient(clientID)
        let depthAfterDrillIn = manager.recentHistory.count
        #expect(depthAfterDrillIn > 1)

        manager.selectedTab = .invoices
        manager.navigationContext = nil
        manager.reconcileHistoryAfterSceneRestore()

        #expect(manager.recentHistory.count == depthAfterDrillIn)
        #expect(manager.currentHistoryEntry?.tab == .invoices)
        #expect(manager.currentHistoryEntry?.context?.targetEntity == nil)
    }

    @Test func ApplyRoutingIntentSelectTabNavigates() {
        let manager = AppNavigationManager()
        manager.applyRoutingIntent(.selectTab(.billingHub))
        #expect(manager.selectedTab == .billingHub)
    }

    /// Sidebar / ⌘-number: coalesce current history slot; no extra stack depth vs ``navigateTo(tab:)``.
    @Test func SelectTabReplacesHistoryCursorWithoutGrowingDepth() {
        let manager = AppNavigationManager()
        let clientID = UUID()

        manager.navigateToClient(clientID)
        let depthAfterDrillIn = manager.recentHistory.count

        manager.selectTab(.invoices)

        #expect(manager.recentHistory.count == depthAfterDrillIn)
        #expect(manager.selectedTab == .invoices)
        #expect(manager.navigationContext == nil)

        manager.navigateBack()

        #expect(manager.selectedTab == .invoices)
        #expect(manager.navigationContext?.targetEntity == nil)
    }

    @Test func ApplyRoutingIntentToggleInspector() {
        let manager = AppNavigationManager()
        #expect(!(manager.inspectorIsPresented))
        manager.applyRoutingIntent(.toggleInspector)
        #expect(manager.inspectorIsPresented)
        manager.applyRoutingIntent(.toggleInspector)
        #expect(!(manager.inspectorIsPresented))
    }

    @Test func ApplyRoutingIntentCreateInvoiceInvokesSideEffect() {
        let manager = AppNavigationManager()
        var calls = 0
        manager.applyRoutingIntent(.createNewInvoice, onCreateInvoice: { calls += 1 })
        #expect(calls == 1)
    }

    /// Each workspace window owns its own `AppNavigationManager` instance; selection, tab, and
    /// inspector visibility must not leak between windows.
    @Test func TwoInstancesAreFullyIndependent() {
        let firstWindow = AppNavigationManager()
        let secondWindow = AppNavigationManager()

        firstWindow.navigateTo(tab: .invoices)
        firstWindow.selection = .invoice(UUID())
        firstWindow.inspectorIsPresented = true

        secondWindow.navigateTo(tab: .relationships)

        #expect(firstWindow.selectedTab == .invoices)
        #expect(secondWindow.selectedTab == .relationships)

        #expect(firstWindow.selection != nil)
        #expect(secondWindow.selection == nil)

        #expect(firstWindow.inspectorIsPresented)
        #expect(!(secondWindow.inspectorIsPresented))

        #expect(firstWindow.recentHistory.count != 0)
        #expect(secondWindow.recentHistory.count != 0)
        #expect(firstWindow.recentHistory != secondWindow.recentHistory)
    }
}
