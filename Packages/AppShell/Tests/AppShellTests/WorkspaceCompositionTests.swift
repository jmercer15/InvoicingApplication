import Core
import SharedUI
@testable import AppShell
import Foundation
import Testing
import SwiftUI
import SwiftData
import Data
import InvoiceTableLayoutEditor

@MainActor
@Suite struct WorkspaceCompositionTests {
    @Test func TemplateCreationHandoffOpensOnlyMaterializedInvoice() async throws {
        let createdID = UUID()
        var openedIDs: [UUID] = []

        let result = try await WorkspaceInvoiceCreationHandoff.perform(
            createInvoice: { createdID },
            openInvoice: { openedIDs.append($0) }
        )

        #expect(result == createdID)
        #expect(openedIDs == [createdID])
    }

    @Test func TemplateCreationHandoffDoesNotNavigateAfterCreationFailure() async {
        var openedIDs: [UUID] = []

        do {
            try await WorkspaceInvoiceCreationHandoff.perform(
                createInvoice: { throw TestInvoiceCreationError.failed },
                openInvoice: { openedIDs.append($0) }
            )
            Issue.record("Expected creation failure")
        } catch {
            #expect(error as? TestInvoiceCreationError == .failed)
        }

        #expect(openedIDs.isEmpty)
    }

    @Test func WorkspaceSceneNavigationStatesOwnIndependentNavigationManagers() {
        let first = WorkspaceSceneNavigationState()
        let second = WorkspaceSceneNavigationState()

        first.navigationManager.navigateTo(tab: .billingHub)
        first.navigationManager.inspectorIsPresented = true

        #expect(first.navigationManager.selectedTab == .billingHub)
        #expect(second.navigationManager.selectedTab == .invoices)
        #expect(first.navigationManager.inspectorIsPresented)
        #expect(!(second.navigationManager.inspectorIsPresented))
    }

    @Test func CommandActionsRouteTabsInspectorAndCreationClosuresThroughNavigationManager() {
        let navigationManager = AppNavigationManager()
        let actions = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: { navigationManager.navigateTo(tab: .invoices) },
            createNewSession: { navigationManager.navigateTo(tab: .calendar) }
        )

        actions.switchToTab(.relationships)
        #expect(navigationManager.selectedTab == .relationships)

        #expect(!(navigationManager.inspectorIsPresented))
        actions.toggleInspector?()
        #expect(navigationManager.inspectorIsPresented)

        actions.createNewInvoice?()
        #expect(navigationManager.selectedTab == .invoices)

        actions.createNewSession?()
        #expect(navigationManager.selectedTab == .calendar)
    }

    @Test func EntityNavigationHandlersRouteRelatedFeatureEntitiesThroughWorkspacePath() {
        let navigationManager = AppNavigationManager()
        let handlers = makeWorkspaceEntityNavigationHandlers(navigationManager: navigationManager)
        let invoiceID = UUID()
        let sessionID = UUID()
        let clientID = UUID()

        handlers.openInvoice(invoiceID)
        #expect(navigationManager.selectedTab == .invoices)
        #expect(navigationManager.navigationPath == [.invoice(invoiceID)])

        handlers.openSession(sessionID)
        #expect(navigationManager.selectedTab == .calendar)
        #expect(navigationManager.navigationPath == [.session(sessionID)])

        handlers.openClient(clientID)
        #expect(navigationManager.selectedTab == .relationships)
        #expect(navigationManager.navigationPath == [.client(clientID)])

        navigationManager.navigateBack()
        #expect(navigationManager.selectedTab == .calendar)
        #expect(navigationManager.navigationPath == [.session(sessionID)])

        navigationManager.navigateBack()
        #expect(navigationManager.selectedTab == .invoices)
        #expect(navigationManager.navigationPath == [.invoice(invoiceID)])
    }

    @Test func WorkspaceCommandActionsExcludeEditorOwnedDocumentCommands() {
        let navigationManager = AppNavigationManager()
        navigationManager.navigateTo(tab: .invoices)

        let actions = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            canToggleInspector: true
        )

        #expect(!(actions.canCreateNewInvoice))
        #expect(!(actions.canCreateNewSession))
        #expect(actions.canToggleInspector)
    }

    @Test func WorkspaceCreationCommandCanBeDisabledWhileCreationIsInFlight() {
        let navigationManager = AppNavigationManager()
        let actions = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: {},
            canCreateNewInvoice: false
        )

        #expect(!(actions.canCreateNewInvoice))
    }

    @Test func InvoiceCommandRefreshTokenTracksSelectionAndCreationActivity() {
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

        #expect(idle != creating)
        #expect(idle != differentSelection)
    }

    @Test func WorkspaceCommandRefreshCoalescesEquivalentAvailability() {
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

        #expect(!(actions.apply(equivalent)))

        navigationManager.navigateTo(tab: .relationships)
        let changed = WorkspaceCommandActionFactory.make(
            navigationManager: navigationManager,
            createNewInvoice: {},
            createNewSession: {}
        )

        #expect(actions.apply(changed))
        #expect(!(actions.canSwitchToTab(.relationships)))
        #expect(actions.canSwitchToTab(.invoices))
        #expect(!(actions.apply(changed)))
    }

    @Test func FocusedInvoiceEditorConstrainsWorkspaceOwnedCreationWhileBusy() {
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

        #expect(AppInvoiceCommandRoutingPolicy.showsInvoiceDocumentCommands(editor))
        #expect(!(AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: true
            )))
        #expect(!(AppInvoiceCommandRoutingPolicy.canPrint(editor: editor)))
        #expect(!(AppInvoiceCommandRoutingPolicy.canExportPDF(editor: editor)))
        #expect(!(AppInvoiceCommandRoutingPolicy.canToggleInspector(
                editor: editor,
                workspaceCanToggle: true
            )))
    }

    @Test func FocusedTemplateEditorKeepsMockDocumentCommandsIsolated() {
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

        #expect(!(AppInvoiceCommandRoutingPolicy.showsInvoiceDocumentCommands(editor)))
        #expect(AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: true
            ))
        #expect(!(AppInvoiceCommandRoutingPolicy.canPrint(editor: editor)))
        #expect(!(AppInvoiceCommandRoutingPolicy.canExportPDF(editor: editor)))
        #expect(AppInvoiceCommandRoutingPolicy.canToggleInspector(
                editor: editor,
                workspaceCanToggle: false
            ))
    }

    @Test func FocusedTemplateEditorCanDisableCreationForInvalidFormatState() {
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

        #expect(!(AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: true
            )))
    }

    @Test func OnlyWorkspaceOwnedCommandsFallBackWithoutFocusedInvoiceEditor() {
        #expect(AppInvoiceCommandRoutingPolicy.canCreate(
                editor: nil,
                workspaceCanCreate: true
            ))
        #expect(!(AppInvoiceCommandRoutingPolicy.canPrint(editor: nil)))
        #expect(!(AppInvoiceCommandRoutingPolicy.canExportPDF(editor: nil)))
        #expect(AppInvoiceCommandRoutingPolicy.canToggleInspector(
                editor: nil,
                workspaceCanToggle: true
            ))
    }

    @Test func WorkspaceCreationGateStillAppliesWhenInvoiceEditorIsAvailable() {
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

        #expect(!(AppInvoiceCommandRoutingPolicy.canCreate(
                editor: editor,
                workspaceCanCreate: false
            )))
    }

    @Test func FocusedEditorPreparationCanStopWorkspaceOwnedCreation() async {
        let editor = InvoiceEditorCommandActions()
        var preparationCount = 0
        editor.prepareForInvoiceCreation = {
            preparationCount += 1
            return false
        }

        let focusedResult = await AppInvoiceCommandRoutingPolicy.prepareForCreate(editor: editor)
        let unfocusedResult = await AppInvoiceCommandRoutingPolicy.prepareForCreate(editor: nil)
        #expect(!(focusedResult))
        #expect(preparationCount == 1)
        #expect(unfocusedResult)
    }

    @Test func FocusedEditorExclusivelyPublishesPrintAndExportCapabilities() {
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

        #expect(AppInvoiceCommandRoutingPolicy.canPrint(editor: editor))
        #expect(AppInvoiceCommandRoutingPolicy.canExportPDF(editor: editor))
    }

    @Test func CommandActionsBackForwardUsesNavigationHistory() {
        let navigationManager = AppNavigationManager()
        let actions = WorkspaceCommandActionFactory.make(navigationManager: navigationManager)

        navigationManager.navigateTo(tab: .relationships)
        #expect(navigationManager.selectedTab == .relationships)
        #expect(actions.canNavigateBack())

        actions.navigateBack()
        #expect(navigationManager.selectedTab == .invoices)
        #expect(actions.canNavigateForward())

        actions.navigateForward()
        #expect(navigationManager.selectedTab == .relationships)
    }

    @Test func WorkspaceSearchConfigurationWritesToSearchBindingSource() {
        let source = TestWorkspaceSearchBindingSource()

        #expect(WorkspaceSearchConfiguration.isPresented(for: .invoices))
        #expect(!(WorkspaceSearchConfiguration.isPresented(for: .calendar)))
        #expect(!(WorkspaceSearchConfiguration.isPresented(for: .invoiceTemplateEditor)))

        let invoiceSearch = WorkspaceSearchConfiguration.textBinding(for: .invoices, source: source)
        invoiceSearch.wrappedValue = "priority"
        #expect(source.invoiceSearchText == "priority")

        let relationshipSearch = WorkspaceSearchConfiguration.textBinding(for: .relationships, source: source)
        relationshipSearch.wrappedValue = "client"
        #expect(source.relationshipSearchText == "client")

        let ndisSearch = WorkspaceSearchConfiguration.textBinding(for: .ndisCatalogue, source: source)
        ndisSearch.wrappedValue = "support"
        #expect(source.ndisSearchText == "support")

        let billingSearch = WorkspaceSearchConfiguration.textBinding(for: .billingHub, source: source)
        billingSearch.wrappedValue = "session"
        #expect(source.billingHubSearchText == "session")
    }

    @Test func ActiveWorkspaceSceneSessionKeyFocusedValues() {
        let keyPath = \FocusedValues.activeWorkspaceSceneSession
        #expect(keyPath == \FocusedValues.activeWorkspaceSceneSession)
    }

    @Test func ApplicationWorkspaceContextTracksLastActiveWindowSession() {
        let first = TestWorkspaceSessionReference()
        let second = TestWorkspaceSessionReference()
        let context = ApplicationWorkspaceContext()

        context.activate(first)
        #expect(context.isActive(first))

        context.activate(second)
        context.release(first)
        #expect(context.isActive(second))

        context.release(second)
        #expect(!(context.isActive(second)))
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
