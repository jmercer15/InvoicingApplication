import Core
import Foundation
import SharedUI
import SwiftUI

/// SceneStorage field bundle for one workspace window. Keys match ``AppRootView`` / ``ContentView``.
struct WorkspaceSceneNavigationStorage: Equatable {
    enum Key {
        static let selectedTab = "Workspace.SelectedTab"
        static let columnVisibility = "Workspace.ColumnVisibility"
        static let selectionKind = "Workspace.SelectionKind"
        static let selectionID = "Workspace.SelectionID"
        static let navigationContext = "Workspace.NavigationContext"
        static let navigationPath = "Workspace.NavigationPath"
        static let inspectorPresented = "Workspace.InspectorPresented"
    }

    var selectedTabRaw: String = AppTab.invoices.rawValue
    var columnVisibilityRaw: String = "automatic"
    var selectionKind: String = ""
    var selectionID: String = ""
    var navigationContextData: Data?
    var navigationPathData: Data?
    var inspectorPresented: Bool = false

    init(
        selectedTabRaw: String = AppTab.invoices.rawValue,
        columnVisibilityRaw: String = "automatic",
        selectionKind: String = "",
        selectionID: String = "",
        navigationContextData: Data? = nil,
        navigationPathData: Data? = nil,
        inspectorPresented: Bool = false
    ) {
        self.selectedTabRaw = selectedTabRaw
        self.columnVisibilityRaw = columnVisibilityRaw
        self.selectionKind = selectionKind
        self.selectionID = selectionID
        self.navigationContextData = navigationContextData
        self.navigationPathData = navigationPathData
        self.inspectorPresented = inspectorPresented
    }

    @MainActor
    init(from navigationManager: AppNavigationManager) {
        selectedTabRaw = navigationManager.selectedTab.rawValue
        columnVisibilityRaw = NavigationSplitViewStateCodec.encodeColumnVisibility(navigationManager.columnVisibility)
        inspectorPresented = navigationManager.inspectorIsPresented

        if let selection = navigationManager.selection {
            let encoded = Self.encodeSelection(selection)
            selectionKind = encoded.kind
            selectionID = encoded.id
        } else {
            selectionKind = ""
            selectionID = ""
        }

        navigationContextData = Self.encodeNavigationContext(navigationManager.navigationContext)
        navigationPathData = try? JSONEncoder().encode(navigationManager.navigationPath)
    }

    @MainActor
    func restore(into navigationManager: AppNavigationManager) {
        if let restoredTab = AppTab(rawValue: selectedTabRaw),
           restoredTab != navigationManager.selectedTab {
            navigationManager.selectedTab = restoredTab
        }
        navigationManager.columnVisibility = NavigationSplitViewStateCodec.decodeColumnVisibility(columnVisibilityRaw)

        if let restoredPath = Self.decodeNavigationPath(navigationPathData) {
            navigationManager.restoreNavigationPath(restoredPath)
        } else {
            navigationManager.selection = Self.decodeSelection(kind: selectionKind, id: selectionID)
            navigationManager.navigationContext = Self.decodeNavigationContext(navigationContextData)
        }

        navigationManager.applyTabSelectionRules(newTab: navigationManager.selectedTab)
        navigationManager.inspectorIsPresented = inspectorPresented
        navigationManager.reconcileHistoryAfterSceneRestore()
    }

    static func encodeSelection(_ selection: AppSelection?) -> (kind: String, id: String) {
        guard let selection else { return ("", "") }
        switch selection {
        case .invoice(let id):
            return ("invoice", id.uuidString)
        case .client(let id):
            return ("client", id.uuidString)
        case .payee(let id):
            return ("payee", id.uuidString)
        case .planManager(let id):
            return ("planManager", id.uuidString)
        case .ndisItem(let id):
            return ("ndisItem", id.uuidString)
        }
    }

    static func decodeSelection(kind: String, id: String) -> AppSelection? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        switch kind {
        case "invoice":
            return .invoice(uuid)
        case "client":
            return .client(uuid)
        case "payee":
            return .payee(uuid)
        case "planManager":
            return .planManager(uuid)
        case "ndisItem":
            return .ndisItem(uuid)
        default:
            return nil
        }
    }

    static func encodeNavigationContext(_ context: NavigationContext?) -> Data? {
        RestorableNavigationContext(context)
            .flatMap { try? JSONEncoder().encode($0) }
    }

    static func decodeNavigationContext(_ data: Data?) -> NavigationContext? {
        guard let data,
              let context = try? JSONDecoder().decode(RestorableNavigationContext.self, from: data)
        else { return nil }
        return context.navigationContext
    }

    static func decodeNavigationPath(_ data: Data?) -> [WorkspaceRoute]? {
        guard let data,
              let path = try? JSONDecoder().decode([WorkspaceRoute].self, from: data)
        else { return nil }
        return path
    }
}

struct RestorableNavigationContext: Codable {
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

enum RestorableEntityType: String, Codable {
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
