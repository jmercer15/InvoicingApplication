import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

public struct NDISCatalogueContentColumn: View {
    @ObservedObject private var viewModel: NDISContainerViewModel
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\NDISItemEntity.itemNumber, order: .forward),
        SortDescriptor(\NDISItemEntity.effectiveStartDate, order: .reverse)
    ])
    private var allItems: [NDISItemEntity]

    @State private var showingHistoricalChanges = false

    private var currentItems: [NDISItemEntity] {
        allItems.filter { $0.isCurrent }
    }

    public init(viewModel: NDISContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NDISCatalogueNavigationView(viewModel: viewModel, showingHistoricalChanges: $showingHistoricalChanges)
            .toolbar(content: filterToolbar)
            .background(Color("Background", bundle: .sharedUI))
            .onAppear(perform: synchroniseContext)
            .onChange(of: allItems) { _, _ in
                viewModel.setSourceItems(ndisItems: currentItems)
            }
            .sheet(isPresented: $showingHistoricalChanges) {
                NDISChangesSummaryView()
            }
    }

    @ToolbarContentBuilder
    private func filterToolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Menu {
                Button("All Categories") {
                    viewModel.selectedCategoryId = nil
                }
                ForEach(viewModel.cachedCategories, id: \.self) { category in
                    Button(category) {
                        viewModel.selectedCategoryId = category
                    }
                }
            } label: {
                Label("Category", systemImage: "folder")
            }
            .help("Filter by category")
            .labelStyle(.titleOnly)

            Menu {
                ForEach(viewModel.registrationGroupsForMenu, id: \.self) { group in
                    Button(group) {
                        viewModel.selectedRegistrationGroup = group
                    }
                }
            } label: {
                Label("Region", systemImage: "tag")
            }
            .help("Filter by registration group")
            .labelStyle(.titleOnly)

            Menu {
                if viewModel.featuresForToolbarMenu.isEmpty {
                    Text("No common features available")
                } else {
                    ForEach(viewModel.featuresForToolbarMenu, id: \.self) { feature in
                        let isSelected = viewModel.currentSelectedFeatures.contains(feature)
                        Button(action: { viewModel.toggleFeatureSelection(feature) }) {
                            Label(feature, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                        }
                    }
                    Divider()
                    Button("Clear Feature Filters", role: .destructive) {
                        viewModel.clearFeatureFilters()
                    }
                    .tint(Color("Red", bundle: .sharedUI).opacity(0.7))
                }
            } label: {
                Label("Features", systemImage: "star")
            }
            .help("Filter by support item features")
            .labelStyle(.titleOnly)

            Menu {
                ForEach(NDISContainerViewModel.SortOrder.allCases) { order in
                    Button(order.rawValue) {
                        viewModel.sortOrder = order
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down.circle")
            }
            .help("Sort support items")
            .labelStyle(.titleOnly)

            Button("Clear") {
                viewModel.clearAllFilters()
            }
            .help("Clear all filters")
        }

        ToolbarItem(placement: .automatic) {
            Button(action: { showingHistoricalChanges = true }) {
                Label("Historical Changes", systemImage: "clock.arrow.circlepath")
            }
            .help("Show change history for items")
            .appInteractiveCursor()
        }
    }

    private func synchroniseContext() {
        viewModel.updateContextIfNeeded(modelContext)
        viewModel.setSourceItems(ndisItems: currentItems)
    }
}

public struct NDISCatalogueDetailColumn: View {
    @ObservedObject private var viewModel: NDISContainerViewModel

    public init(viewModel: NDISContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            if let selectedItem = viewModel.selectedItem {
                EnhancedSupportItemDetailView(item: selectedItem)
                    .id(selectedItem.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .font(.largeTitle)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Text("Select an Item")
                        .font(.title2)
                    Text("Choose an NDIS support item from the list to view its details.")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Background", bundle: .sharedUI))
            }
        }
        .background(Color("Background", bundle: .sharedUI))
    }
}
