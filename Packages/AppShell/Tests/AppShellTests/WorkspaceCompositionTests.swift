import Core
import SharedUI
@testable import AppShell
import XCTest
import SwiftUI
import SwiftData
import Data
import InvoiceTableLayoutEditor

@MainActor
final class WorkspaceCompositionTests: XCTestCase {
    func testTemplateCreationHandoffOpensOnlyMaterializedInvoice() async throws {
        let createdID = UUID()
        var openedIDs: [UUID] = []

        let result = try await WorkspaceInvoiceCreationHandoff.perform(
            createInvoice: { createdID },
            openInvoice: { openedIDs.append($0) }
        )

        XCTAssertEqual(result, createdID)
        XCTAssertEqual(openedIDs, [createdID])
    }

    func testTemplateCreationHandoffDoesNotNavigateAfterCreationFailure() async {
        var openedIDs: [UUID] = []

        do {
            try await WorkspaceInvoiceCreationHandoff.perform(
                createInvoice: { throw TestInvoiceCreationError.failed },
                openInvoice: { openedIDs.append($0) }
            )
            XCTFail("Expected creation failure")
        } catch {
            XCTAssertEqual(error as? TestInvoiceCreationError, .failed)
        }

        XCTAssertTrue(openedIDs.isEmpty)
    }

    func testWorkspaceSceneNavigationStatesOwnIndependentNavigationManagers() {
        let first = WorkspaceSceneNavigationState()
        let second = WorkspaceSceneNavigationState()

        first.navigationManager.navigateTo(tab: .billingHub)
        first.navigationManager.inspectorIsPresented = true

        XCTAssertEqual(first.navigationManager.selectedTab, .billingHub)
        XCTAssertEqual(second.navigationManager.selectedTab, .invoices)
        XCTAssertTrue(first.navigationManager.inspectorIsPresented)
        XCTAssertFalse(second.navigationManager.inspectorIsPresented)
    }

    func testCommandActionsRouteTabsInspectorAndCreationClosuresThroughNavigationManager() {
        let navigationManager = AppNavigationManager()
        let actions = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: { navigationManager.navigateTo(tab: .invoices) },
            createNewSession: { navigationManager.navigateTo(tab: .calendar) }
        )

        actions.switchToTab(.relationships)
        XCTAssertEqual(navigationManager.selectedTab, .relationships)

        XCTAssertFalse(navigationManager.inspectorIsPresented)
        actions.toggleInspector?()
        XCTAssertTrue(navigationManager.inspectorIsPresented)

        actions.createNewInvoice?()
        XCTAssertEqual(navigationManager.selectedTab, .invoices)

        actions.createNewSession?()
        XCTAssertEqual(navigationManager.selectedTab, .calendar)
    }

    func testEntityNavigationHandlersRouteRelatedFeatureEntitiesThroughWorkspacePath() {
        let navigationManager = AppNavigationManager()
        let handlers = makeWorkspaceEntityNavigationHandlers(navigationManager: navigationManager)
        let invoiceID = UUID()
        let sessionID = UUID()
        let clientID = UUID()

        handlers.openInvoice(invoiceID)
        XCTAssertEqual(navigationManager.selectedTab, .invoices)
        XCTAssertEqual(navigationManager.navigationPath, [.invoice(invoiceID)])

        handlers.openSession(sessionID)
        XCTAssertEqual(navigationManager.selectedTab, .calendar)
        XCTAssertEqual(navigationManager.navigationPath, [.session(sessionID)])

        handlers.openClient(clientID)
        XCTAssertEqual(navigationManager.selectedTab, .relationships)
        XCTAssertEqual(navigationManager.navigationPath, [.client(clientID)])

        navigationManager.navigateBack()
        XCTAssertEqual(navigationManager.selectedTab, .calendar)
        XCTAssertEqual(navigationManager.navigationPath, [.session(sessionID)])

        navigationManager.navigateBack()
        XCTAssertEqual(navigationManager.selectedTab, .invoices)
        XCTAssertEqual(navigationManager.navigationPath, [.invoice(invoiceID)])
    }

    func testWorkspaceCommandActionsExcludeEditorOwnedDocumentCommands() {
        let navigationManager = AppNavigationManager()
        navigationManager.navigateTo(tab: .invoices)

        let actions = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            canToggleInspector: true
        )

        XCTAssertFalse(actions.canCreateNewInvoice)
        XCTAssertFalse(actions.canCreateNewSession)
        XCTAssertTrue(actions.canToggleInspector)
    }

    func testWorkspaceCreationCommandCanBeDisabledWhileCreationIsInFlight() {
        let navigationManager = AppNavigationManager()
        let actions = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: {},
            canCreateNewInvoice: false
        )

        XCTAssertFalse(actions.canCreateNewInvoice)
    }

    func testInvoiceCommandRefreshTokenTracksSelectionAndCreationActivity() {
        let invoiceID = UUID()
        let idle = WorkspaceInvoiceCommandRefreshToken(
            selectedInvoiceID: invoiceID,
            isCreatingInvoice: false
        )
        let creating = WorkspaceInvoiceCommandRefreshToken(
            selectedInvoiceID: invoiceID,
            isCreatingInvoice: true
        )
        let differentSelection = WorkspaceInvoiceCommandRefreshToken(
            selectedInvoiceID: UUID(),
            isCreatingInvoice: false
        )

        XCTAssertNotEqual(idle, creating)
        XCTAssertNotEqual(idle, differentSelection)
    }

    func testWorkspaceCommandRefreshCoalescesEquivalentAvailability() {
        let navigationManager = AppNavigationManager()
        let actions = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: {},
            createNewSession: {}
        )
        let equivalent = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: {},
            createNewSession: {}
        )

        XCTAssertFalse(actions.apply(equivalent))

        navigationManager.navigateTo(tab: .relationships)
        let changed = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: {},
            createNewSession: {}
        )

        XCTAssertTrue(actions.apply(changed))
        XCTAssertFalse(actions.canSwitchToTab(.relationships))
        XCTAssertTrue(actions.canSwitchToTab(.invoices))
        XCTAssertFalse(actions.apply(changed))
    }

    func testFocusedInvoiceEditorConstrainsWorkspaceOwnedCreationWhileBusy() {
        let editor = InvoiceEditorCommandActions()
        editor.updateCapabilities(
            canCreate: false,
            canSave: false,
            canDuplicate: false,
            canDelete: false,
            canPrint: false,
            canExportPDF: false,
            canToggleInspector: false,
            isInvoiceContext: true
        )

        XCTAssertTrue(AppInvoiceCommandRoutingPolicy.showsInvoiceDocumentCommands(editor))
        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: true
            )
        )
        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canPrint(editor: editor)
        )
        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canExportPDF(editor: editor)
        )
        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canToggleInspector(
                editor: editor,
                workspaceCanToggle: true
            )
        )
    }

    func testFocusedTemplateEditorKeepsMockDocumentCommandsIsolated() {
        let editor = InvoiceEditorCommandActions()
        editor.updateCapabilities(
            canCreate: true,
            canSave: false,
            canDuplicate: false,
            canDelete: false,
            canPrint: false,
            canExportPDF: false,
            canToggleInspector: true,
            isInvoiceContext: false
        )

        XCTAssertFalse(AppInvoiceCommandRoutingPolicy.showsInvoiceDocumentCommands(editor))
        XCTAssertTrue(
            AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: true
            )
        )
        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canPrint(editor: editor)
        )
        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canExportPDF(editor: editor)
        )
        XCTAssertTrue(
            AppInvoiceCommandRoutingPolicy.canToggleInspector(
                editor: editor,
                workspaceCanToggle: false
            )
        )
    }

    func testFocusedTemplateEditorCanDisableCreationForInvalidFormatState() {
        let editor = InvoiceEditorCommandActions()
        editor.updateCapabilities(
            canCreate: false,
            canSave: false,
            canDuplicate: false,
            canDelete: false,
            canPrint: false,
            canExportPDF: false,
            canToggleInspector: true,
            isInvoiceContext: false
        )

        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: true
            )
        )
    }

    func testOnlyWorkspaceOwnedCommandsFallBackWithoutFocusedInvoiceEditor() {
        XCTAssertTrue(
            AppInvoiceCommandRoutingPolicy.canCreate(
                editor: nil,
                workspaceCanCreate: true
            )
        )
        XCTAssertFalse(AppInvoiceCommandRoutingPolicy.canPrint(editor: nil))
        XCTAssertFalse(AppInvoiceCommandRoutingPolicy.canExportPDF(editor: nil))
        XCTAssertTrue(
            AppInvoiceCommandRoutingPolicy.canToggleInspector(
                editor: nil,
                workspaceCanToggle: true
            )
        )
    }

    func testWorkspaceCreationGateStillAppliesWhenInvoiceEditorIsAvailable() {
        let editor = InvoiceEditorCommandActions()
        editor.updateCapabilities(
            canCreate: true,
            canSave: false,
            canDuplicate: false,
            canDelete: false,
            canPrint: false,
            canExportPDF: false,
            canToggleInspector: true,
            isInvoiceContext: true
        )

        XCTAssertFalse(
            AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: false
            )
        )
    }

    func testFocusedEditorPreparationCanStopWorkspaceOwnedCreation() async {
        let editor = InvoiceEditorCommandActions()
        var preparationCount = 0
        editor.prepareForInvoiceCreation = {
            preparationCount += 1
            return false
        }

        let focusedResult = await AppInvoiceCommandRoutingPolicy.prepareForCreate(editor: editor)
        let unfocusedResult = await AppInvoiceCommandRoutingPolicy.prepareForCreate(editor: nil)
        XCTAssertFalse(focusedResult)
        XCTAssertEqual(preparationCount, 1)
        XCTAssertTrue(unfocusedResult)
    }

    func testFocusedEditorExclusivelyPublishesPrintAndExportCapabilities() {
        let editor = InvoiceEditorCommandActions()
        editor.updateCapabilities(
            canCreate: false,
            canSave: false,
            canDuplicate: false,
            canDelete: false,
            canPrint: true,
            canExportPDF: true,
            canToggleInspector: true,
            isInvoiceContext: true
        )

        XCTAssertTrue(AppInvoiceCommandRoutingPolicy.canPrint(editor: editor))
        XCTAssertTrue(AppInvoiceCommandRoutingPolicy.canExportPDF(editor: editor))
    }

    func testCommandActionsBackForwardUsesNavigationHistory() {
        let navigationManager = AppNavigationManager()
        let actions = WorkspaceCommandActionFactory.make(navigationManager: navigationManager)

        navigationManager.navigateTo(tab: .relationships)
        XCTAssertEqual(navigationManager.selectedTab, .relationships)
        XCTAssertTrue(actions.canNavigateBack())

        actions.navigateBack()
        XCTAssertEqual(navigationManager.selectedTab, .invoices)
        XCTAssertTrue(actions.canNavigateForward())

        actions.navigateForward()
        XCTAssertEqual(navigationManager.selectedTab, .relationships)
    }

    func testWorkspaceSearchConfigurationWritesToSearchBindingSource() {
        let source = TestWorkspaceSearchBindingSource()

        XCTAssertTrue(WorkspaceSearchConfiguration.isPresented(for: .invoices))
        XCTAssertFalse(WorkspaceSearchConfiguration.isPresented(for: .calendar))
        XCTAssertFalse(WorkspaceSearchConfiguration.isPresented(for: .invoiceTemplateEditor))

        let invoiceSearch = WorkspaceSearchConfiguration.textBinding(for: .invoices, source: source)
        invoiceSearch.wrappedValue = "priority"
        XCTAssertEqual(source.invoiceSearchText, "priority")

        let relationshipSearch = WorkspaceSearchConfiguration.textBinding(for: .relationships, source: source)
        relationshipSearch.wrappedValue = "client"
        XCTAssertEqual(source.relationshipSearchText, "client")

        let ndisSearch = WorkspaceSearchConfiguration.textBinding(for: .ndisCatalogue, source: source)
        ndisSearch.wrappedValue = "support"
        XCTAssertEqual(source.ndisSearchText, "support")

        let billingSearch = WorkspaceSearchConfiguration.textBinding(for: .billingHub, source: source)
        billingSearch.wrappedValue = "session"
        XCTAssertEqual(source.billingHubSearchText, "session")
    }

    func testActiveWorkspaceSceneSessionKeyFocusedValues() {
        let keyPath = \FocusedValues.activeWorkspaceSceneSession
        XCTAssertEqual(keyPath, \FocusedValues.activeWorkspaceSceneSession)
    }

    func testApplicationWorkspaceContextTracksLastActiveWindowSession() {
        let first = TestWorkspaceSessionReference()
        let second = TestWorkspaceSessionReference()
        let context = ApplicationWorkspaceContext()

        context.activate(first)
        XCTAssertTrue(context.isActive(first))

        context.activate(second)
        context.release(first)
        XCTAssertTrue(context.isActive(second))

        context.release(second)
        XCTAssertFalse(context.isActive(second))
    }
}

private enum TestInvoiceCreationError: Error {
    case failed
}

@MainActor
private final class TestWorkspaceSearchBindingSource: WorkspaceSearchBindingSource {
    var invoiceSearchText = ""
    var relationshipSearchText = ""
    var ndisSearchText = ""
    var billingHubSearchText = ""
}

private final class TestWorkspaceSessionReference: WorkspaceSceneSessionReference {}
