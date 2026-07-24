import Foundation
import SwiftUI
import SwiftData
import Core
import SharedUI

struct WorkspaceInvoiceCommandRefreshToken: Equatable {
    let selectedInvoiceID: UUID?
    let isCreatingInvoice: Bool
}

struct ContentView: View {
    let features: WorkspaceFeatureRegistries
    let navigationManager: AppNavigationManager

    var body: some View {
        AppRootView(
            features: features,
            navigationManager: navigationManager
        )
    }
}

struct AppRootView: View {
    let features: WorkspaceFeatureRegistries
    let navigationManager: AppNavigationManager

    init(features: WorkspaceFeatureRegistries, navigationManager: AppNavigationManager) {
        self.features = features
        self.navigationManager = navigationManager
        _workspaceCommandActions = State(
            initialValue: WorkspaceCommandActionFactory.make(
                features: features,
                navigationManager: navigationManager
            )
        )
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(ToolWindowPresenceRegistry.self) private var toolWindowPresence
    @SceneStorage("Workspace.SelectedTab") private var restoredSelectedTabRaw = AppTab.invoices.rawValue
    @SceneStorage("Workspace.ColumnVisibility") private var restoredColumnVisibilityRaw = "automatic"
    @SceneStorage("Workspace.SelectionKind") private var restoredSelectionKind = ""
    @SceneStorage("Workspace.SelectionID") private var restoredSelectionID = ""
    @SceneStorage("Workspace.NavigationContext") private var restoredNavigationContextData: Data?
    @SceneStorage("Workspace.NavigationPath") private var restoredNavigationPathData: Data?
    @SceneStorage("Workspace.InspectorPresented") private var restoredInspectorPresented = false

    // Cached so we don't compute during layout (avoids layout recursion with NSFont/NSString sizing).
    @State private var sidebarMinWidth: CGFloat = 200

    /// Single window-level search field — macOS registers `com.apple.SwiftUI.search` on `NSToolbar`; multiple
    /// `.searchable` modifiers in one window crash with duplicate toolbar item identifiers.
    @State private var workspaceSearchFieldPresented = true
    @State private var workspaceCommandActions: WorkspaceCommandActions
    @State private var isRestoringSceneNavigation = false
    @State private var hasRestoredSceneNavigation = false

    private var nav: AppNavigationManager { navigationManager }

    var body: some View {
        WorkspaceSplitView(
            features: features,
            navigationManager: navigationManager,
            sidebarMinWidth: sidebarMinWidth
        )
            .workspaceSearchHost(
                isEnabled: WorkspaceSearchConfiguration.isPresented(for: nav.selectedTab),
                isPresented: $workspaceSearchFieldPresented,
                text: WorkspaceSearchConfiguration.textBinding(
                    for: nav.selectedTab,
                    features: features
                ),
                prompt: WorkspaceSearchConfiguration.prompt(for: nav.selectedTab)
            )
            .navigationTitle(nav.selectedTab.title)
            .navigationSplitViewStyle(.balanced)
            .windowToolbarFullScreenVisibility(.visible)
            .focusedSceneValue(\.workspaceCommandActions, workspaceCommandActions)
            .focusedSceneValue(\.workspaceInspectorSplitPresented, workspaceSplitInspectorIsPresented)
            .onAppear {
                refreshWorkspaceCommandActions()
                sidebarMinWidth = WorkspaceSidebarView.preferredMinimumWidth()
                workspaceSearchFieldPresented = WorkspaceSearchConfiguration.isPresented(for: nav.selectedTab)
                guard !hasRestoredSceneNavigation else { return }
                hasRestoredSceneNavigation = true
                Task { @MainActor in
                    isRestoringSceneNavigation = true
                    restoreSceneNavigationState()
                    isRestoringSceneNavigation = false
                }
            }
            .onChange(of: nav.selectedTab) { _, newValue in
                guard !isRestoringSceneNavigation else { return }
                refreshWorkspaceCommandActions()
                restoredSelectedTabRaw = newValue.rawValue
                nav.applyTabSelectionRules(newTab: newValue)
                persistNavigationContext()
                persistNavigationPath()
                workspaceSearchFieldPresented = WorkspaceSearchConfiguration.isPresented(for: newValue)
            }
            .onChange(of: nav.selection) { _, newValue in
                guard !isRestoringSceneNavigation else { return }
                persistSelection(newValue)
                persistNavigationContext()
                persistNavigationPath()
            }
            .onChange(of: nav.columnVisibility) { _, newValue in
                guard !isRestoringSceneNavigation else { return }
                restoredColumnVisibilityRaw = NavigationSplitViewStateCodec.encodeColumnVisibility(newValue)
            }
            .onChange(of: nav.navigationPersistenceToken) { _, _ in
                guard !isRestoringSceneNavigation else { return }
                refreshWorkspaceCommandActions()
                persistNavigationPath()
                persistNavigationContext()
            }
            .onChange(of: nav.inspectorIsPresented) { _, newValue in
                refreshWorkspaceCommandActions()
                restoredInspectorPresented = newValue
            }
            .onChange(of: invoiceCommandRefreshToken) { _, _ in
                refreshWorkspaceCommandActions()
            }
            .alert("Invoice Action Failed", isPresented: invoiceActionErrorPresented) {
                Button("OK") {
                    features.invoices.dismissActionError()
                }
            } message: {
                Text(
                    features.invoices.actionErrorMessage
                        ?? "Invoice action could not be completed."
                )
            }
            .inspector(isPresented: workspaceInspectorPresentation) {
                SmartInspectorResolverView(
                    features: features,
                    navigationManager: navigationManager
                )
                .inspectorColumnWidth(
                    min: StyleGuide.Dimensions.workspaceInspectorColumnMin,
                    ideal: StyleGuide.Dimensions.workspaceInspectorColumnIdeal
                )
            }
    }

    private func restoreSceneNavigationState() {
        if let restoredTab = AppTab(rawValue: restoredSelectedTabRaw),
           restoredTab != nav.selectedTab {
            nav.selectedTab = restoredTab
        }
        nav.columnVisibility = NavigationSplitViewStateCodec.decodeColumnVisibility(restoredColumnVisibilityRaw)
        if let restoredPath = restoredNavigationPath() {
            nav.restoreNavigationPath(restoredPath)
            restoredSelectedTabRaw = nav.selectedTab.rawValue
        } else {
            nav.selection = restoreSelection()
            nav.navigationContext = restoreNavigationContext()
        }
        nav.applyTabSelectionRules(newTab: nav.selectedTab)
        nav.inspectorIsPresented = restoredInspectorPresented
        nav.reconcileHistoryAfterSceneRestore()
        restoredSelectedTabRaw = nav.selectedTab.rawValue
        restoredColumnVisibilityRaw = NavigationSplitViewStateCodec.encodeColumnVisibility(nav.columnVisibility)
        Task { @MainActor in
            scheduleRestoredNavigationSanitization()
        }
    }

    private var workspaceInspectorPresentation: Binding<Bool> {
        Binding(
            get: {
                guard !nav.selectedTab.usesIntegratedInvoiceEditorInspector else { return false }
                return inspectorPresentation.splitPresented && !inspectorPresentation.standaloneOpen
            },
            set: { newValue in
                guard !nav.selectedTab.usesIntegratedInvoiceEditorInspector else { return }
                if nav.inspectorIsPresented != newValue {
                    nav.inspectorIsPresented = newValue
                }
            }
        )
    }

    /// Invoice creation can begin in Template Editor or through app commands. Present failures
    /// at workspace scope so navigation stays put until a persisted invoice is ready to open.
    private var invoiceActionErrorPresented: Binding<Bool> {
        Binding(
            get: { features.invoices.actionErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    features.invoices.dismissActionError()
                }
            }
        )
    }

    private var workspaceSplitInspectorIsPresented: Bool {
        !nav.selectedTab.usesIntegratedInvoiceEditorInspector
            && inspectorPresentation.splitPresented
            && !inspectorPresentation.standaloneOpen
    }

    private var invoiceCommandRefreshToken: WorkspaceInvoiceCommandRefreshToken {
        WorkspaceInvoiceCommandRefreshToken(
            selectedInvoiceID: features.invoices.selectedInvoice?.id,
            isCreatingInvoice: features.invoices.isCreatingInvoice
        )
    }

    private var inspectorPresentation: InspectorPresentationState {
        InspectorPresentationState(
            splitPresented: nav.inspectorIsPresented,
            standaloneOpen: toolWindowPresence.inspectorStandaloneOpen
        )
    }

    private func refreshWorkspaceCommandActions() {
        let refreshed = WorkspaceCommandActionFactory.make(
            features: features,
            navigationManager: navigationManager
        )
        workspaceCommandActions.apply(refreshed)
    }

    /// Validates restored UUIDs off the critical launch path; truncates stale path segments.
    private func scheduleRestoredNavigationSanitization() {
        let pathSnapshot = nav.navigationPath
        let selectionSnapshot = nav.selection
        Task { @MainActor in
            let sanitizedPath = WorkspaceNavigationRestoration.sanitizedPath(pathSnapshot, modelContext: modelContext)
            if sanitizedPath != pathSnapshot {
                nav.restoreNavigationPath(sanitizedPath)
                restoredSelectedTabRaw = nav.selectedTab.rawValue
                persistNavigationPath()
                persistNavigationContext()
            }

            let sanitizedSelection = WorkspaceNavigationRestoration.sanitizedSelection(
                selectionSnapshot,
                modelContext: modelContext
            )
            if sanitizedSelection != selectionSnapshot {
                nav.selection = sanitizedSelection
                persistSelection(sanitizedSelection)
                persistNavigationContext()
                persistNavigationPath()
            }
        }
    }

    private func persistSelection(_ selection: AppSelection?) {
        guard let selection else {
            restoredSelectionKind = ""
            restoredSelectionID = ""
            return
        }

        switch selection {
        case .invoice(let id):
            persistSelection(kind: "invoice", id: id)
        case .client(let id):
            persistSelection(kind: "client", id: id)
        case .payee(let id):
            persistSelection(kind: "payee", id: id)
        case .planManager(let id):
            persistSelection(kind: "planManager", id: id)
        case .ndisItem(let id):
            persistSelection(kind: "ndisItem", id: id)
        }
    }

    private func persistSelection(kind: String, id: UUID) {
        restoredSelectionKind = kind
        restoredSelectionID = id.uuidString
    }

    private func restoreSelection() -> AppSelection? {
        guard let id = UUID(uuidString: restoredSelectionID) else { return nil }
        switch restoredSelectionKind {
        case "invoice":
            return .invoice(id)
        case "client":
            return .client(id)
        case "payee":
            return .payee(id)
        case "planManager":
            return .planManager(id)
        case "ndisItem":
            return .ndisItem(id)
        default:
            return nil
        }
    }

    private func persistNavigationContext() {
        restoredNavigationContextData = RestorableNavigationContext(nav.navigationContext)
            .flatMap { try? JSONEncoder().encode($0) }
    }

    private func restoreNavigationContext() -> NavigationContext? {
        guard let data = restoredNavigationContextData,
              let context = try? JSONDecoder().decode(RestorableNavigationContext.self, from: data)
        else { return nil }
        return context.navigationContext
    }

    private func persistNavigationPath() {
        restoredNavigationPathData = try? JSONEncoder().encode(nav.navigationPath)
    }

    private func restoredNavigationPath() -> [WorkspaceRoute]? {
        guard let data = restoredNavigationPathData,
              let path = try? JSONDecoder().decode([WorkspaceRoute].self, from: data)
        else { return nil }
        return path
    }

}

private struct RestorableNavigationContext: Codable {
    let targetEntity: UUID?
    let targetEntityType: RestorableEntityType?
    let targetDate: Date?
    let searchQuery: String?

    init?(_ context: NavigationContext?) {
        guard let context else { return nil }
        self.targetEntity = context.targetEntity
        self.targetEntityType = RestorableEntityType(context.targetEntityType)
        self.targetDate = context.targetDate
        self.searchQuery = context.searchQuery
    }

    var navigationContext: NavigationContext {
        NavigationContext(
            targetEntity: targetEntity,
            targetEntityType: targetEntityType?.navigationEntityType,
            targetDate: targetDate,
            searchQuery: searchQuery
        )
    }
}

private enum RestorableEntityType: String, Codable {
    case client
    case session
    case invoice
    case payee
    case planManager
    case clientService
    case ndisItem

    init?(_ type: NavigationContext.EntityType?) {
        guard let type else { return nil }
        switch type {
        case .client:
            self = .client
        case .session:
            self = .session
        case .invoice:
            self = .invoice
        case .payee:
            self = .payee
        case .planManager:
            self = .planManager
        case .clientService:
            self = .clientService
        case .ndisItem:
            self = .ndisItem
        }
    }

    var navigationEntityType: NavigationContext.EntityType {
        switch self {
        case .client:
            return .client
        case .session:
            return .session
        case .invoice:
            return .invoice
        case .payee:
            return .payee
        case .planManager:
            return .planManager
        case .clientService:
            return .clientService
        case .ndisItem:
            return .ndisItem
        }
    }
}
