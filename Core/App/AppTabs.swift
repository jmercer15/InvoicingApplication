import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case invoices
    case invoiceTemplateEditor
    case relationships
    case calendar
    case ndisCatalogue
    case ndisBilling
    case tax
    case settings
    case map
    // Old comments removed; this file now only provides tab metadata

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .invoices:
            return "Invoices"
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
        case .tax:
            return "Tax"
        case .settings:
            return "Settings"
        case .map:
            return "Map"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "chart.pie.fill" // Example icon
        case .invoices:
            return "doc.text.fill"  // Example icon
        case .invoiceTemplateEditor:
            return "doc.badge.plus"
        case .relationships:
            return "person.2.fill" // Example icon
        case .calendar:
            return "calendar"
        case .ndisCatalogue:
            return "list.bullet"
        case .ndisBilling:
            return "creditcard.fill"
        case .tax:
            return "banknote.fill"
        case .settings:
            return "gearshape.fill" // Example icon
        case .map:
            return "map.fill"
        }
    }
}
