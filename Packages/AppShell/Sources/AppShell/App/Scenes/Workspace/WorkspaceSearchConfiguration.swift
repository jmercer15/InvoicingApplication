import SwiftUI
import Core
import Feature_BillingHub
import Feature_Clients
import Feature_Invoices
import Feature_NDIS

@MainActor
protocol WorkspaceSearchBindingSource: AnyObject {
    var invoiceSearchText: String { get set }
    var relationshipSearchText: String { get set }
    var ndisSearchText: String { get set }
    var billingHubSearchText: String { get set }
}

enum WorkspaceSearchConfiguration {
    private static let searchableTabs: Set<AppTab> = [
        .invoices, .relationships, .ndisCatalogue, .billingHub
    ]

    static func isPresented(for tab: AppTab) -> Bool {
        searchableTabs.contains(tab)
    }

    @MainActor
    static func textBinding(
        for tab: AppTab,
        features: WorkspaceFeatureRegistries
    ) -> Binding<String> {
        textBinding(for: tab, source: WorkspaceFeatureSearchBindingSource(features: features))
    }

    @MainActor
    static func textBinding(
        for tab: AppTab,
        source: any WorkspaceSearchBindingSource
    ) -> Binding<String> {
        switch tab {
        case .invoices:
            return Binding(
                get: { source.invoiceSearchText },
                set: { source.invoiceSearchText = $0 }
            )
        case .relationships:
            return Binding(
                get: { source.relationshipSearchText },
                set: { source.relationshipSearchText = $0 }
            )
        case .ndisCatalogue:
            return Binding(
                get: { source.ndisSearchText },
                set: { source.ndisSearchText = $0 }
            )
        case .billingHub:
            return Binding(
                get: { source.billingHubSearchText },
                set: { source.billingHubSearchText = $0 }
            )
        default:
            return .constant("")
        }
    }

    static func prompt(for tab: AppTab) -> LocalizedStringKey {
        switch tab {
        case .invoices: "Search invoices..."
        case .relationships: "Search clients..."
        case .ndisCatalogue: "Search NDIS items..."
        case .billingHub: "Search sessions or invoices"
        default: ""
        }
    }
}

@MainActor
private final class WorkspaceFeatureSearchBindingSource: WorkspaceSearchBindingSource {
    private let features: WorkspaceFeatureRegistries

    init(features: WorkspaceFeatureRegistries) {
        self.features = features
    }

    var invoiceSearchText: String {
        get { features.invoices.invoiceSearchText }
        set { features.invoices.invoiceSearchText = newValue }
    }

    var relationshipSearchText: String {
        get { features.relationships.relationshipSearchText }
        set { features.relationships.relationshipSearchText = newValue }
    }

    var ndisSearchText: String {
        get { features.ndisCatalogue.searchText }
        set { features.ndisCatalogue.searchText = newValue }
    }

    var billingHubSearchText: String {
        get { features.billingHub.searchText }
        set { features.billingHub.searchText = newValue }
    }
}
