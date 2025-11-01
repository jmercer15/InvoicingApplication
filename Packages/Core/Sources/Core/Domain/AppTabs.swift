import Foundation

public enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case invoices
    case billingHub
    case invoiceTemplateEditor
    case relationships
    case calendar
    case ndisCatalogue
    case ndisBilling
    case testingArea
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
        case .ndisBilling:
            return "NDIS Billing"
        case .testingArea:
            return "Testing Area"
        case .settings:
            return "Settings"
        }
    }

    public var iconName: String {
        switch self {
        case .invoices:
            return "doc.text"
        case .billingHub:
            return "kanban"
        case .invoiceTemplateEditor:
            return "doc.badge.plus"
        case .relationships:
            return "person.2"
        case .calendar:
            return "calendar"
        case .ndisCatalogue:
            return "list.bullet.rectangle"
        case .ndisBilling:
            return "creditcard"
        case .testingArea:
            return "testtube.2"
        case .settings:
            return "gearshape"
        }
    }
}
