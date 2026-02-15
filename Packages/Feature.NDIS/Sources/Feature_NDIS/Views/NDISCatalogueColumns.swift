import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

public struct NDISCatalogueContentColumn: View {
    @ObservedObject private var viewModel: NDISContainerViewModel

    @State private var showingHistoricalChanges = false
    
    public init(viewModel: NDISContainerViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }

    public var body: some View {
        NDISCatalogueNavigationView(viewModel: viewModel, showingHistoricalChanges: $showingHistoricalChanges)
            .toolbar(content: filterToolbar)

            .navigationTitle("NDIS Catalogue")
            .sheet(isPresented: $showingHistoricalChanges) {
                NDISChangesSummaryView(viewModel: viewModel)
            }
    }
    
    // ... toolbar code ...



    @ToolbarContentBuilder
    private func filterToolbar() -> some ToolbarContent {
        // MARK: - Filters & Sort
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
                Label {
                    Text(viewModel.selectedCategoryId == nil ? "Category" : "Category (1)")
                } icon: {
                    Image(systemName: viewModel.selectedCategoryId == nil ? "folder" : "folder.fill")
                }
            }
            .help("Filter by category")
            .pointerStyle(.link)

            Menu {
                ForEach(viewModel.registrationGroupsForMenu, id: \.self) { group in
                    Button(group) {
                        viewModel.selectedRegistrationGroup = group
                    }
                }
            } label: {
                Label {
                    Text(viewModel.selectedRegistrationGroup == nil ? "Region" : "Region (1)")
                } icon: {
                    Image(systemName: viewModel.selectedRegistrationGroup == nil ? "tag" : "tag.fill")
                }
            }
            .help("Filter by registration group")
            .pointerStyle(.link)

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
                Label {
                    Text(viewModel.currentSelectedFeatures.isEmpty ? "Features" : "Features (\(viewModel.currentSelectedFeatures.count))")
                } icon: {
                    Image(systemName: viewModel.currentSelectedFeatures.isEmpty ? "star" : "star.fill")
                }
            }
            .help("Filter by support item features")
            .pointerStyle(.link)

            Menu {
                ForEach(NDISContainerViewModel.SortOrder.allCases) { order in
                    Button(order.rawValue) {
                        viewModel.sortOrder = order
                    }
                }
            } label: {
                Label {
                    Text("Sort: \(viewModel.sortOrder.rawValue)")
                } icon: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                }
            }
            .help("Sort support items by \(viewModel.sortOrder.rawValue)")
            .pointerStyle(.link)

            Button("Clear") {
                viewModel.clearAllFilters()
            }
            .help("Clear all filters")
            .pointerStyle(.link)
        }

        // MARK: - Utilities
        ToolbarItem(placement: .automatic) {
            Button(action: { showingHistoricalChanges = true }) {
                Label("Historical Changes", systemImage: "clock.arrow.circlepath")
            }
            .help("Show change history for items")
            .pointerStyle(.link)
        }
    }

    private func synchroniseContext() {
        // No-op for UoW compatibility
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
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
