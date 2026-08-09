import AppIntents
import Core

/// Shortcuts-facing tab picker mapped to ``AppTab``.
public enum WorkspaceTabAppEnum: String, AppEnum {
    case invoices
    case billingHub
    case invoiceTemplateEditor
    case relationships
    case calendar
    case ndisCatalogue

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Workspace Tab")
    }

    public static var caseDisplayRepresentations: [WorkspaceTabAppEnum: DisplayRepresentation] {
        [
            .invoices: DisplayRepresentation(title: "Invoices"),
            .billingHub: DisplayRepresentation(title: "Billing Hub"),
            .invoiceTemplateEditor: DisplayRepresentation(title: "Template Editor"),
            .relationships: DisplayRepresentation(title: "Relationships"),
            .calendar: DisplayRepresentation(title: "Calendar"),
            .ndisCatalogue: DisplayRepresentation(title: "NDIS Catalogue"),
        ]
    }

    var appTab: AppTab {
        switch self {
        case .invoices: return .invoices
        case .billingHub: return .billingHub
        case .invoiceTemplateEditor: return .invoiceTemplateEditor
        case .relationships: return .relationships
        case .calendar: return .calendar
        case .ndisCatalogue: return .ndisCatalogue
        }
    }
}
