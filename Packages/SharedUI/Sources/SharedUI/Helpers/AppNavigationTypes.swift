import Foundation
import SwiftUI
import Core
import Observation

public enum AppSelection: Hashable {
    case invoice(UUID)
    case client(UUID)
    case payee(UUID)
    case planManager(UUID)
    case ndisItem(UUID)
}

public enum WorkspaceRoute: Hashable, Codable, Sendable {
    case invoice(UUID)
    case client(UUID)
    case payee(UUID)
    case planManager(UUID)
    case clientService(UUID)
    case ndisItem(UUID)
    case session(UUID)

    public init?(_ selection: AppSelection?) {
        guard let selection else { return nil }
        switch selection {
        case .invoice(let id): self = .invoice(id)
        case .client(let id): self = .client(id)
        case .payee(let id): self = .payee(id)
        case .planManager(let id): self = .planManager(id)
        case .ndisItem(let id): self = .ndisItem(id)
        }
    }

    public init?(_ context: NavigationContext?) {
        guard let id = context?.targetEntity,
              let type = context?.targetEntityType
        else { return nil }

        switch type {
        case .client: self = .client(id)
        case .session: self = .session(id)
        case .invoice: self = .invoice(id)
        case .payee: self = .payee(id)
        case .planManager: self = .planManager(id)
        case .clientService: self = .clientService(id)
        case .ndisItem: self = .ndisItem(id)
        }
    }

    public var workspaceTab: AppTab {
        switch self {
        case .invoice:
            return .invoices
        case .client, .payee, .planManager, .clientService:
            return .relationships
        case .ndisItem:
            return .ndisCatalogue
        case .session:
            return .calendar
        }
    }

    public var selection: AppSelection? {
        switch self {
        case .invoice(let id):
            return .invoice(id)
        case .client(let id):
            return .client(id)
        case .payee(let id):
            return .payee(id)
        case .planManager(let id):
            return .planManager(id)
        case .clientService, .session:
            return nil
        case .ndisItem(let id):
            return .ndisItem(id)
        }
    }

    public var navigationContext: NavigationContext {
        switch self {
        case .invoice(let id):
            return NavigationContext(targetEntity: id, targetEntityType: .invoice)
        case .client(let id):
            return NavigationContext(targetEntity: id, targetEntityType: .client)
        case .payee(let id):
            return NavigationContext(targetEntity: id, targetEntityType: .payee)
        case .planManager(let id):
            return NavigationContext(targetEntity: id, targetEntityType: .planManager)
        case .clientService(let id):
            return NavigationContext(targetEntity: id, targetEntityType: .clientService)
        case .ndisItem(let id):
            return NavigationContext(targetEntity: id, targetEntityType: .ndisItem)
        case .session(let id):
            return NavigationContext(targetEntity: id, targetEntityType: .session)
        }
    }
}

// MARK: - Navigation History Entry
public struct NavigationHistoryEntry: Identifiable, Equatable {
    public let id = UUID()
    let tab: AppTab
    let context: NavigationContext?
    let timestamp: Date
    let title: String // Human-readable description of the navigation
    
    public init(tab: AppTab, context: NavigationContext? = nil, title: String? = nil) {
        self.tab = tab
        self.context = context
        self.timestamp = Date()
        
        // Generate a descriptive title based on tab and context
        if let customTitle = title {
            self.title = customTitle
        } else {
            self.title = Self.generateTitle(for: tab, context: context)
        }
    }
    
    static func generateTitle(for tab: AppTab, context: NavigationContext?) -> String {
        if let entityType = context?.targetEntityType {
            switch entityType {
            case .client:
                return "\(tab.title) - Client Details"
            case .session:
                return "\(tab.title) - Session Details"
            case .invoice:
                return "\(tab.title) - Invoice Details"
            case .payee:
                return "\(tab.title) - Payee Details"
            case .planManager:
                return "\(tab.title) - Plan Manager Details"
            case .clientService:
                return "\(tab.title) - Service Details"
            case .ndisItem:
                return "\(tab.title) - NDIS Item Details"
            }
        } else if let targetDate = context?.targetDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return "\(tab.title) - \(formatter.string(from: targetDate))"
        } else {
            return tab.title
        }
    }
    
    public static func == (lhs: NavigationHistoryEntry, rhs: NavigationHistoryEntry) -> Bool {
        return lhs.tab == rhs.tab &&
               lhs.context?.targetEntity == rhs.context?.targetEntity &&
               lhs.context?.targetEntityType == rhs.context?.targetEntityType &&
               lhs.context?.targetDate == rhs.context?.targetDate
    }
}

// MARK: - Navigation Context Data Models
public struct NavigationContext: Equatable {
    public var targetEntity: UUID?
    public var targetEntityType: EntityType?
    public var targetDate: Date?
    public var searchQuery: String?
    /// Tab the user left when opening this target (e.g. Billing Hub → Invoice).
    /// Used for "Back to …" chips; not part of workspace route identity.
    public var sourceTab: AppTab?
    /// Optional Hub card / selection id to restore when returning via `sourceTab`.
    public var sourceFocusID: UUID?

    public init(
        targetEntity: UUID? = nil,
        targetEntityType: EntityType? = nil,
        targetDate: Date? = nil,
        searchQuery: String? = nil,
        sourceTab: AppTab? = nil,
        sourceFocusID: UUID? = nil
    ) {
        self.targetEntity = targetEntity
        self.targetEntityType = targetEntityType
        self.targetDate = targetDate
        self.searchQuery = searchQuery
        self.sourceTab = sourceTab
        self.sourceFocusID = sourceFocusID
    }
    
    public enum EntityType: Equatable {
        case client
        case session
        case invoice
        case payee
        case planManager
        case clientService
        case ndisItem
    }
}
