import Core
import Foundation
import SharedUI
import Testing
@testable import AppShell

@MainActor
@Suite(.tags(.unit))
struct WorkspaceSceneStorageRoundTripTests {
    @Test func sceneStorageKeysMatchContentViewSceneStorageFields() {
        #expect(WorkspaceSceneNavigationStorage.Key.selectedTab == "Workspace.SelectedTab")
        #expect(WorkspaceSceneNavigationStorage.Key.columnVisibility == "Workspace.ColumnVisibility")
        #expect(WorkspaceSceneNavigationStorage.Key.selectionKind == "Workspace.SelectionKind")
        #expect(WorkspaceSceneNavigationStorage.Key.selectionID == "Workspace.SelectionID")
        #expect(WorkspaceSceneNavigationStorage.Key.navigationContext == "Workspace.NavigationContext")
        #expect(WorkspaceSceneNavigationStorage.Key.navigationPath == "Workspace.NavigationPath")
        #expect(WorkspaceSceneNavigationStorage.Key.inspectorPresented == "Workspace.InspectorPresented")
    }

    @Test func twoWindowsCaptureDistinctSnapshotsWithoutCrossContamination() {
        let firstWindow = AppNavigationManager()
        let secondWindow = AppNavigationManager()

        let clientID = UUID()

        firstWindow.navigateTo(tab: .billingHub)
        firstWindow.columnVisibility = .detailOnly
        firstWindow.inspectorIsPresented = true

        secondWindow.navigateTo(tab: .relationships)
        secondWindow.columnVisibility = .all
        secondWindow.inspectorIsPresented = false
        secondWindow.navigateToClient(clientID)

        let firstSnapshot = WorkspaceSceneNavigationStorage(from: firstWindow)
        let secondSnapshot = WorkspaceSceneNavigationStorage(from: secondWindow)

        #expect(firstSnapshot != secondSnapshot)
        #expect(firstSnapshot.selectedTabRaw == AppTab.billingHub.rawValue)
        #expect(secondSnapshot.selectedTabRaw == AppTab.relationships.rawValue)
        #expect(firstSnapshot.inspectorPresented)
        #expect(!secondSnapshot.inspectorPresented)
        #expect(firstSnapshot.columnVisibilityRaw == "detailOnly")
        #expect(secondSnapshot.columnVisibilityRaw == "all")
    }

    @Test func roundTripRestoresTabSelectionPathAndInspector() {
        let source = AppNavigationManager()
        let invoiceID = UUID()
        let clientID = UUID()

        source.navigateToInvoice(invoiceID)
        source.navigateToClient(clientID)
        source.columnVisibility = .doubleColumn
        source.inspectorIsPresented = true

        let snapshot = WorkspaceSceneNavigationStorage(from: source)
        let restored = AppNavigationManager()
        snapshot.restore(into: restored)

        #expect(restored.selectedTab == .relationships)
        #expect(restored.selection == .client(clientID))
        #expect(restored.navigationPath == [.client(clientID)])
        #expect(restored.navigationContext?.targetEntity == clientID)
        #expect(restored.navigationContext?.targetEntityType == .client)
        #expect(restored.columnVisibility == .doubleColumn)
        #expect(restored.inspectorIsPresented)
    }

    @Test func roundTripPrefersNavigationPathOverStaleSelectionFields() {
        let source = AppNavigationManager()
        let sessionID = UUID()

        source.selection = .invoice(UUID())
        source.navigationContext = NavigationContext(
            targetEntity: UUID(), targetEntityType: .invoice)
        source.restoreNavigationPath([.session(sessionID)])

        let snapshot = WorkspaceSceneNavigationStorage(from: source)
        let restored = AppNavigationManager()
        snapshot.restore(into: restored)

        #expect(restored.selectedTab == .calendar)
        #expect(restored.selection == nil)
        #expect(restored.navigationPath == [.session(sessionID)])
        #expect(restored.navigationContext?.targetEntity == sessionID)
        #expect(restored.navigationContext?.targetEntityType == .session)
    }

    @Test func independentRoundTripsPreservePerWindowState() {
        let firstSource = AppNavigationManager()
        let secondSource = AppNavigationManager()
        let firstInvoiceID = UUID()

        firstSource.navigateTo(tab: .invoices)
        firstSource.navigateToInvoice(firstInvoiceID)
        firstSource.inspectorIsPresented = true

        secondSource.navigateTo(tab: .calendar)
        secondSource.restoreNavigationPath([.session(UUID())])
        secondSource.inspectorIsPresented = false

        let firstSnapshot = WorkspaceSceneNavigationStorage(from: firstSource)
        let secondSnapshot = WorkspaceSceneNavigationStorage(from: secondSource)

        let firstRestored = AppNavigationManager()
        let secondRestored = AppNavigationManager()
        firstSnapshot.restore(into: firstRestored)
        secondSnapshot.restore(into: secondRestored)

        #expect(firstRestored.selectedTab == .invoices)
        #expect(firstRestored.selection == .invoice(firstInvoiceID))
        #expect(firstRestored.inspectorIsPresented)

        #expect(secondRestored.selectedTab == .calendar)
        #expect(secondRestored.inspectorIsPresented == false)
        #expect(secondRestored.navigationPath.count == 1)
        #expect(firstRestored.selectedTab != secondRestored.selectedTab)
    }
}
