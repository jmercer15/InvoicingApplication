import SwiftUI
import SwiftData
import Core
import PersistenceModels
import SharedUI
import Observation

private struct NDISCatalogueLoadTaskID: Equatable {
    let revision: Int
    let businessId: UUID?
}

public struct NDISCatalogueContentColumn: View {
    @Bindable private var viewModel: NDISContainerViewModel
    @Query(sort: \Business.name) private var businessEntities: [Business]

    @State private var showingHistoricalChanges = false
    private let selectionPath: Binding<[String]>?
    private let onSelectionChanged: ((AppSelection?) -> Void)?

    public init(
        viewModel: NDISContainerViewModel,
        selectionPath: Binding<[String]>? = nil,
        onSelectionChanged: ((AppSelection?) -> Void)? = nil
    ) {
        self.viewModel = viewModel
        self.selectionPath = selectionPath
        self.onSelectionChanged = onSelectionChanged
    }

    private var projection: NDISCatalogueProjection {
        viewModel.catalogueProjection
    }

    public var body: some View {
        NDISCatalogueNavigationView(
            viewModel: viewModel,
            projection: projection,
            showingHistoricalChanges: $showingHistoricalChanges,
            selectionPath: selectionPath,
            onSelectionChanged: onSelectionChanged
        )
            .toolbar(content: filterToolbar)
            .task(id: NDISCatalogueLoadTaskID(
                revision: viewModel.dataRevision,
                businessId: businessEntities.first?.id
            )) {
                guard await Task.waitUnlessCancelled(for: .milliseconds(150)) else { return }
                viewModel.refreshPreferredRegion(using: businessEntities.first)
                if viewModel.dataRevision > 0 {
                    viewModel.loadCatalogue(force: true)
                } else {
                    viewModel.loadCatalogueIfNeeded()
                }
            }

            .navigationTitle("NDIS Catalogue")
            .sheet(isPresented: $showingHistoricalChanges) {
                NDISChangesSummaryView(viewModel: viewModel)
            }
    }
    
    // ... toolbar code ...



    @ToolbarContentBuilder
    private func filterToolbar() -> some ToolbarContent {
        AppToolbarUtilityGroup {
            refineMenu

            if ndisFiltersAreActive {
                Button("Clear Filters") {
                    viewModel.clearAllFilters()
                }
                .appToolbarLinkStyle(help: "Clear all catalogue filters")
            }
        }

        ToolbarItem(placement: .primaryAction) {
            AppToolbarIconButton(
                systemName: "clock.arrow.circlepath",
                help: "Show change history for support items",
                action: { showingHistoricalChanges = true }
            )
        }
    }

    private var ndisFiltersAreActive: Bool {
        viewModel.selectedCategoryId != nil
            || viewModel.selectedRegistrationGroup != nil
            || !viewModel.currentSelectedFeatures.isEmpty
    }

    private var refineMenu: some View {
        Menu {
            Section("Category") {
                Button("All Categories") {
                    viewModel.selectedCategoryId = nil
                }
                ForEach(projection.categories, id: \.self) { category in
                    Button(category) {
                        viewModel.selectedCategoryId = category
                    }
                }
            }

            Section("Region") {
                Button("All Regions") {
                    viewModel.selectedRegistrationGroup = nil
                }
                ForEach(projection.registrationGroupsForMenu, id: \.self) { group in
                    Button(group) {
                        viewModel.selectedRegistrationGroup = group
                    }
                }
            }

            Section("Features") {
                if projection.featuresForToolbarMenu.isEmpty {
                    Text("No common features available")
                } else {
                    ForEach(projection.featuresForToolbarMenu, id: \.self) { feature in
                        let isSelected = viewModel.currentSelectedFeatures.contains(feature)
                        Button(action: { viewModel.toggleFeatureSelection(feature) }) {
                            HStack {
                                Text(feature)
                                Spacer()
                                AppToolbarMenuCheckmark(isSelected: isSelected)
                            }
                        }
                    }
                    Divider()
                    Button("Clear Feature Filters", role: .destructive) {
                        viewModel.clearFeatureFilters()
                    }
                }
            }

            Section("Sort") {
                ForEach(NDISContainerViewModel.SortOrder.allCases) { order in
                    Button {
                        viewModel.sortOrder = order
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            Spacer()
                            AppToolbarMenuCheckmark(isSelected: viewModel.sortOrder == order)
                        }
                    }
                }
            }
        } label: {
            Label {
                Text(ndisRefineMenuTitle)
            } icon: {
                Image(systemName: ndisFiltersAreActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
        }
        .appToolbarLinkStyle(help: "Refine and sort the catalogue")
    }

    private var ndisRefineMenuTitle: String {
        var parts: [String] = []
        if viewModel.selectedCategoryId != nil { parts.append("Category") }
        if viewModel.selectedRegistrationGroup != nil { parts.append("Region") }
        if !viewModel.currentSelectedFeatures.isEmpty {
            parts.append("Features (\(viewModel.currentSelectedFeatures.count))")
        }
        if parts.isEmpty {
            return "Refine · \(viewModel.sortOrder.rawValue)"
        }
        return parts.joined(separator: " · ")
    }
}

public struct NDISCatalogueDetailColumn: View {
    @Bindable private var viewModel: NDISContainerViewModel

    public init(viewModel: NDISContainerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let selectedItem = viewModel.resolvedSelectedItem

        Group {
            if let selectedItem {
                EnhancedSupportItemDetailView(item: selectedItem)
                    .id(selectedItem.id)
            } else {
                EmptyStateView(
                    icon: "list.bullet.rectangle.portrait",
                    title: "Select an Item",
                    message: "Choose an NDIS support item from the list to view its details."
                )
            }
        }
    }
}
