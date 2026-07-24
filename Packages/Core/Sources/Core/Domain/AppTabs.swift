import Foundation

public enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case invoices
    case billingHub
    case invoiceTemplateEditor
    case relationships
    case calendar
    case ndisCatalogue
    // Old comments removed; this file now only provides tab metadata

    public var id: String { self.rawValue }

    public var title: String {
        switch self {
        case .invoices:
            return "Invoices"
        case .billingHub:
            return "Billing Hub"
        case .invoiceTemplateEditor:
            return "Template Editor"
        case .relationships:
            return "Relationships"
        case .calendar:
            return "Calendar"
        case .ndisCatalogue:
            return "NDIS Catalogue"
        }
    }

    public var iconName: String {
        switch self {
        case .invoices:
            return "doc.text"
        case .billingHub:
            return "square.grid.3x2"
        case .invoiceTemplateEditor:
            return "doc.richtext"
        case .relationships:
            return "person.2"
        case .calendar:
            return "calendar"
        case .ndisCatalogue:
            return "list.bullet.rectangle"
        }
    }

    /// Tabs that retain typed workspace routes for restoration and navigation history.
    public var usesWorkspaceRouteNavigation: Bool {
        switch self {
        case .invoices, .relationships, .ndisCatalogue, .calendar:
            return true
        case .billingHub, .invoiceTemplateEditor:
            return false
        }
    }
}
