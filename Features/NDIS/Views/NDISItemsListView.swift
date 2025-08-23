import SwiftUI
import SwiftData

struct NDISItemsListView: View {
    @ObservedObject var viewModel: NDISContainerViewModel
    @Binding var showingHistoricalChanges: Bool


    var body: some View {
        VStack(spacing: 0) {
            listContent
        }
        .toolbar {
            // Principal title removed per unified toolbar guidelines

            // Navigation controls (filters)
            ToolbarItemGroup(placement: .navigation) {
                // Category picker
                Menu {
                    Picker("Category", selection: $viewModel.selectedCategoryId) {
                        Text("All Categories").tag(nil as String?)
                        ForEach(viewModel.cachedCategories, id: \.self) { category in
                            Text(category).tag(Optional(category))
                        }
                    }
                } label: {
                    Label("Category", systemImage: "folder")
                }
                .help("Filter by category")
                .appInteractiveCursor()

                // Registration group picker (contextual to category)
                Menu {
                    Picker("Registration Group", selection: Binding<String?>(
                        get: { viewModel.selectedRegistrationGroup },
                        set: { viewModel.selectedRegistrationGroup = $0 }
                    )) {
                        ForEach(viewModel.registrationGroupsForMenu, id: \.self) { group in
                            Text(group).tag(Optional(group))
                        }
                    }
                } label: {
                    Label("Region", systemImage: "tag")
                }
                .help("Filter by registration group")
                .appInteractiveCursor()

                // Feature multi-select shortcuts
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
                        .tint(Color.red.opacity(0.7))
                    }
                } label: {
                    Label("Features", systemImage: "star")
                }
                .help("Filter by support item features")
                .appInteractiveCursor()

                // Sort order
                Menu {
                    Picker("Sort Order", selection: $viewModel.sortOrder) {
                        ForEach(NDISContainerViewModel.SortOrder.allCases) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }
                .help("Sort support items")
                .appInteractiveCursor()

                // Clear all filters
                Button("Clear Filters") { viewModel.clearAllFilters() }
                .help("Clear all filters")
                .appInteractiveCursor()
            }

            // Secondary actions
            ToolbarItemGroup(placement: .secondaryAction) {
                Button(action: { showingHistoricalChanges = true }) {
                    Label("Historical Changes", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.glass)
                .help("Show change history for items")
                .appInteractiveCursor()
            }
        }
        .searchable(text: $viewModel.searchText)
        .searchToolbarBehavior(.automatic)
        .padding(.horizontal, 16)
        .background(Color.black)
        
    }

    // MARK: - Subviews
    private var listContent: some View {
        Group {
            if viewModel.paginatedItems.isEmpty {
                emptyListView
            } else {
                itemsListView
            }
        }
    }

    private var emptyListView: some View {
        EmptyStateView(
            icon: "list.bullet.clipboard",
            title: "No NDIS Items Found",
            message: "Try adjusting your search or filter criteria."
        )
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .transition(.opacity.animation(.easeInOut(duration: 0.3)))
    }

    private var itemsListView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(viewModel.paginatedItems) { item in
                    let isSelected = (viewModel.selectedItem?.id == item.id)
                    NDISItemRow(item: item, isSelected: isSelected) {
                        viewModel.selectedItem = item
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
                    .onTapGesture { viewModel.selectedItem = item }
                    .appInteractiveCursor()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }

                if viewModel.hasMoreItemsToLoad() {
                    loadMoreButton
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color.black)
    }

    

    private var loadMoreButton: some View {
        let remaining = max(0, viewModel.filteredItems.count - viewModel.paginatedItems.count)
        return Button(action: { viewModel.loadMoreItems() }) {
            HStack {
                Image(systemName: "arrow.down.circle")
                Text("Load More (\(remaining) remaining)")
            }
            .font(.subheadline)
            .foregroundColor(.accentColor)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .appInteractiveCursor()
    }

    private var toolbarTitle: some View {
        let count = viewModel.filteredItems.count
        let subtitle = count > 0 ? "\(count) items" : nil
        return VStack(alignment: .leading, spacing: 2) {
            Text("NDIS Catalogue").font(.title3).fontWeight(.semibold)
            if let subtitle {
                Text(subtitle).font(.footnote).foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - NDISItemRow

struct NDISItemRow: View {
    let item: NDISItemEntity // Change to NDISItemEntity
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                Text(item.name) // Use non-optional name
                    .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Version status indicator
                    if !item.isCurrent {
                        Text("HIST")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                }
                
                Text(item.itemNumber) // Use non-optional itemNumber
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .trailing, spacing: 2) {
                if let prices = item.regionalPrices, !prices.isEmpty {
                    let nationalPrice = prices.first { $0.regionIdentifier == "NATIONAL" }?.amount
                    Text(nationalPrice.map { "$\(String(format: "%.2f", $0))" } ?? "")
                        .font(.body)
                        .foregroundColor(.accentColor)
                } else if item.quoteRequired == true {
                    Text("Quote Required")
                        .font(.body)
                        .foregroundColor(.orange)
                } else {
                    Text("No Price")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Show effective date for historical items
                if !item.isCurrent, let endDate = item.effectiveEndDate {
                    Text("Until \(endDate, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            // Add context menu actions if needed, e.g. copy item number
            Button("Copy Item Number") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.itemNumber, forType: .string)
            }
        }
    }
} 
