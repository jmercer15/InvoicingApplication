import Foundation

public enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case invoices
    case billingHub
    case invoiceTemplateEditor
    case relationships
    case calendar
    case ndisCatalogue
    case settings
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
        case .settings:
            return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .invoices:
            return "doc.text"
        case .billingHub:
            return "square.grid.3x2"
        case .invoiceTemplateEditor:
            return "doc.badge.plus"
        case .relationships:
            return "person.2"
        case .calendar:
            return "calendar"
        case .ndisCatalogue:
            return "list.bullet.rectangle"
        case .settings:
            return "gearshape"
        }
    }
}
