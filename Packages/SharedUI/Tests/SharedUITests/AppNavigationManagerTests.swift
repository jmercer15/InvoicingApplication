import Core
import Observation
@testable import SharedUI
import XCTest

@MainActor
final class AppNavigationManagerTests: XCTestCase {
    func testRepeatedCurrentTabSelectionDoesNotRepublishNavigationState() {
        let manager = AppNavigationManager()
        let persistenceToken = manager.navigationPersistenceToken
        nonisolated(unsafe) var navigationStateChanged = false

        withObservationTracking {
            _ = manager.selectedTab
            _ = manager.navigationContext
            _ = manager.selection
            _ = manager.navigationPath
        } onChange: {
            navigationStateChanged = true
        }

        manager.selectTab(.invoices)

        XCTAssertFalse(navigationStateChanged)
        XCTAssertEqual(manager.navigationPersistenceToken, persistenceToken)
        XCTAssertEqual(manager.selectedTab, .invoices)
    }

    func testRepeatedEntityNavigationDoesNotRepublishCurrentRouteState() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        manager.navigateToInvoice(invoiceID)
        let persistenceToken = manager.navigationPersistenceToken
        nonisolated(unsafe) var routeStateChanged = false

        withObservationTracking {
            _ = manager.selectedTab
            _ = manager.navigationContext
            _ = manager.selection
            _ = manager.navigationPath
        } onChange: {
            routeStateChanged = true
        }

        manager.navigateToInvoice(invoiceID)

        XCTAssertFalse(routeStateChanged)
        XCTAssertEqual(manager.navigationPersistenceToken, persistenceToken)
        XCTAssertEqual(manager.navigationPath, [.invoice(invoiceID)])
    }

    func testRootNavigationClearsEntitySelectionContextAndPathTogether() {
        let manager = AppNavigationManager()
        manager.navigateToInvoice(UUID())

        manager.navigateTo(tab: .invoices)

        XCTAssertEqual(manager.selectedTab, .invoices)
        XCTAssertNil(manager.selection)
        XCTAssertNil(manager.navigationContext)
        XCTAssertTrue(manager.navigationPath.isEmpty)
    }

    func testRepeatedRootNavigationDoesNotRepublishNavigationState() {
        let manager = AppNavigationManager()
        manager.navigateTo(tab: .billingHub)
        let persistenceToken = manager.navigationPersistenceToken
        let historyDepth = manager.recentHistory.count
        nonisolated(unsafe) var navigationStateChanged = false

        withObservationTracking {
            _ = manager.selectedTab
            _ = manager.navigationContext
            _ = manager.selection
            _ = manager.navigationPath
        } onChange: {
            navigationStateChanged = true
        }

        manager.navigateTo(tab: .billingHub)

        XCTAssertFalse(navigationStateChanged)
        XCTAssertEqual(manager.navigationPersistenceToken, persistenceToken)
        XCTAssertEqual(manager.recentHistory.count, historyDepth)
    }

    func testNavigationHistoryRestoresTabAndContextWhenNavigatingBackAndForward() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        let clientID = UUID()

        manager.navigateToInvoice(invoiceID)
        manager.navigateToClient(clientID)

        XCTAssertEqual(manager.selectedTab, .relationships)
        XCTAssertEqual(manager.navigationContext?.targetEntity, clientID)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .client)
        XCTAssertTrue(manager.canNavigateBack)
        XCTAssertFalse(manager.canNavigateForward)

        manager.navigateBack()

        XCTAssertEqual(manager.selectedTab, .invoices)
        XCTAssertEqual(manager.navigationContext?.targetEntity, invoiceID)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .invoice)
        XCTAssertTrue(manager.canNavigateForward)

        manager.navigateForward()

        XCTAssertEqual(manager.selectedTab, .relationships)
        XCTAssertEqual(manager.navigationContext?.targetEntity, clientID)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .client)
    }

    func testSelectionUpdatesInspectorFallbackCoordinators() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()

        manager.selection = .invoice(invoiceID)

        XCTAssertEqual(manager.inspectorFallbackSelection(), .invoice(invoiceID))
    }

    func testSelectionUpdatesCentralNavigationPath() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()

        manager.selection = .invoice(invoiceID)

        XCTAssertEqual(manager.navigationPath, [.invoice(invoiceID)])
    }

    func testClearingCentralNavigationPathClearsSelectionAndContext() {
        let manager = AppNavigationManager()

        manager.navigateToInvoice(UUID())
        XCTAssertEqual(manager.navigationPath.count, 1)
        XCTAssertNotNil(manager.selection)
        XCTAssertNotNil(manager.navigationContext)

        manager.updateNavigationPathFromStack([])

        XCTAssertEqual(manager.navigationPath.count, 0)
        XCTAssertNil(manager.selection)
        XCTAssertNil(manager.navigationContext)
    }

    func testRestoresCodableCentralNavigationPath() throws {
        let path = [WorkspaceRoute.client(UUID())]
        let data = try JSONEncoder().encode(path)
        let restoredPath = try JSONDecoder().decode([WorkspaceRoute].self, from: data)

        let manager = AppNavigationManager()
        manager.restoreNavigationPath(restoredPath)

        XCTAssertEqual(manager.navigationPath.count, 1)
    }

    func testRestoresNavigationPathWithRouteToSelectionAndContext() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        let path = [WorkspaceRoute.invoice(invoiceID)]

        manager.restoreNavigationPath(path)

        XCTAssertEqual(manager.selectedTab, .invoices)
        XCTAssertEqual(manager.selection, .invoice(invoiceID))
        XCTAssertEqual(manager.navigationContext?.targetEntity, invoiceID)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .invoice)
    }

    func testRestoreNavigationPathWinsOverStaleSelectionAndContext() {
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

        XCTAssertEqual(manager.selectedTab, .calendar)
        XCTAssertNil(manager.selection)
        XCTAssertEqual(manager.navigationContext?.targetEntity, routeID)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .session)
        XCTAssertEqual(manager.navigationPath.count, 1)
    }

    func testRestoresMultiSegmentNavigationPathFromLastRoute() {
        let manager = AppNavigationManager()
        let invoiceID = UUID()
        let clientID = UUID()
        let path = [
            WorkspaceRoute.client(clientID),
            WorkspaceRoute.invoice(invoiceID)
        ]

        manager.restoreNavigationPath(path)

        XCTAssertEqual(manager.navigationPath.count, 2)
        XCTAssertEqual(manager.selectedTab, .invoices)
        XCTAssertEqual(manager.selection, .invoice(invoiceID))
        XCTAssertEqual(manager.navigationContext?.targetEntity, invoiceID)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .invoice)
    }

    func testSelectionClearedOnIncompatibleTabSwitch() {
        let manager = AppNavigationManager()
        let clientID = UUID()

        manager.navigateToClient(clientID)
        XCTAssertEqual(manager.selection, .client(clientID))
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .client)

        manager.applyTabSelectionRules(newTab: .calendar)

        XCTAssertNil(manager.selection)
        XCTAssertNil(manager.navigationContext)
    }

    func testClientServiceRouteRestoresDeterministicStateFromPath() {
        let manager = AppNavigationManager()
        let clientServiceID = UUID()
        let path = [WorkspaceRoute.clientService(clientServiceID)]

        manager.restoreNavigationPath(path)

        XCTAssertEqual(manager.selectedTab, .relationships)
        XCTAssertNil(manager.selection)
        XCTAssertEqual(manager.navigationContext?.targetEntity, clientServiceID)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .clientService)
    }

    func testSameDepthRouteChangeUpdatesNavigationPersistenceToken() {
        let manager = AppNavigationManager()

        manager.navigateToSession(UUID())
        let firstToken = manager.navigationPersistenceToken

        manager.navigateToSession(UUID())

        XCTAssertEqual(manager.navigationPath.count, 1)
        XCTAssertNotEqual(manager.navigationPersistenceToken, firstToken)
    }

    func testMismatchedContextDoesNotPushRouteForDifferentTab() {
        let manager = AppNavigationManager()

        manager.navigateTo(
            tab: .calendar,
            context: NavigationContext(
                targetEntity: UUID(),
                targetEntityType: .client
            )
        )

        XCTAssertEqual(manager.selectedTab, .calendar)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .client)
        XCTAssertEqual(manager.navigationPath.count, 0)
    }

    func testContextNavigationClearsStaleSelectionWhenNoMatchingRouteSelectionExists() {
        let manager = AppNavigationManager()

        manager.navigateToClient(UUID())
        XCTAssertNotNil(manager.selection)

        manager.navigateToClientService(UUID())

        XCTAssertEqual(manager.selectedTab, .relationships)
        XCTAssertNil(manager.selection)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .clientService)
        XCTAssertEqual(manager.navigationPath.count, 1)
    }

    func testAllowedContextWithoutMatchingRouteClearsStaleSelectionButKeepsContext() {
        let manager = AppNavigationManager()

        manager.navigateToInvoice(UUID())
        XCTAssertNotNil(manager.selection)

        manager.navigateTo(
            tab: .calendar,
            context: NavigationContext(
                targetEntity: UUID(),
                targetEntityType: .client
            )
        )

        XCTAssertEqual(manager.selectedTab, .calendar)
        XCTAssertNil(manager.selection)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .client)
        XCTAssertEqual(manager.navigationPath.count, 0)
    }

    func testHistoryForwardDoesNotPushMismatchedContextRoute() {
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

        XCTAssertEqual(manager.selectedTab, .calendar)
        XCTAssertEqual(manager.navigationContext?.targetEntityType, .client)
        XCTAssertEqual(manager.navigationPath.count, 0)
    }

    func testEnsureCurrentTabInHistoryDoesNotDuplicateLatestEntry() {
        let manager = AppNavigationManager()

        manager.ensureCurrentTabInHistory()

        XCTAssertEqual(manager.recentHistory.count, 1)
        XCTAssertFalse(manager.canNavigateBack)
    }

    /// SceneStorage restore must not append a spurious history entry (init default vs restored tab).
    func testReconcileHistoryAfterSceneRestoreReplacesCursorWithoutGrowingDepth() {
        let manager = AppNavigationManager()
        let clientID = UUID()

        manager.navigateToClient(clientID)
        let depthAfterDrillIn = manager.recentHistory.count
        XCTAssertGreaterThan(depthAfterDrillIn, 1)

        manager.selectedTab = .invoices
        manager.navigationContext = nil
        manager.reconcileHistoryAfterSceneRestore()

        XCTAssertEqual(manager.recentHistory.count, depthAfterDrillIn)
        XCTAssertEqual(manager.currentHistoryEntry?.tab, .invoices)
        XCTAssertNil(manager.currentHistoryEntry?.context?.targetEntity)
    }

    func testApplyRoutingIntentSelectTabNavigates() {
        let manager = AppNavigationManager()
        manager.applyRoutingIntent(.selectTab(.billingHub))
        XCTAssertEqual(manager.selectedTab, .billingHub)
    }

    /// Sidebar / ⌘-number: coalesce current history slot; no extra stack depth vs ``navigateTo(tab:)``.
    func testSelectTabReplacesHistoryCursorWithoutGrowingDepth() {
        let manager = AppNavigationManager()
        let clientID = UUID()

        manager.navigateToClient(clientID)
        let depthAfterDrillIn = manager.recentHistory.count

        manager.selectTab(.invoices)

        XCTAssertEqual(manager.recentHistory.count, depthAfterDrillIn)
        XCTAssertEqual(manager.selectedTab, .invoices)
        XCTAssertNil(manager.navigationContext)

        manager.navigateBack()

        XCTAssertEqual(manager.selectedTab, .invoices)
        XCTAssertNil(manager.navigationContext?.targetEntity)
    }

    func testApplyRoutingIntentToggleInspector() {
        let manager = AppNavigationManager()
        XCTAssertFalse(manager.inspectorIsPresented)
        manager.applyRoutingIntent(.toggleInspector)
        XCTAssertTrue(manager.inspectorIsPresented)
        manager.applyRoutingIntent(.toggleInspector)
        XCTAssertFalse(manager.inspectorIsPresented)
    }

    func testApplyRoutingIntentCreateInvoiceInvokesSideEffect() {
        let manager = AppNavigationManager()
        var calls = 0
        manager.applyRoutingIntent(.createNewInvoice, onCreateInvoice: { calls += 1 })
        XCTAssertEqual(calls, 1)
    }

    /// Each workspace window owns its own `AppNavigationManager` instance; selection, tab, and
    /// inspector visibility must not leak between windows.
    func testTwoInstancesAreFullyIndependent() {
        let firstWindow = AppNavigationManager()
        let secondWindow = AppNavigationManager()

        firstWindow.navigateTo(tab: .invoices)
        firstWindow.selection = .invoice(UUID())
        firstWindow.inspectorIsPresented = true

        secondWindow.navigateTo(tab: .relationships)

        XCTAssertEqual(firstWindow.selectedTab, .invoices)
        XCTAssertEqual(secondWindow.selectedTab, .relationships)

        XCTAssertNotNil(firstWindow.selection)
        XCTAssertNil(secondWindow.selection)

        XCTAssertTrue(firstWindow.inspectorIsPresented)
        XCTAssertFalse(secondWindow.inspectorIsPresented)

        XCTAssertNotEqual(firstWindow.recentHistory.count, 0)
        XCTAssertNotEqual(secondWindow.recentHistory.count, 0)
        XCTAssertNotEqual(firstWindow.recentHistory, secondWindow.recentHistory)
    }
}
