import SwiftUI
import SwiftData // Import SwiftData

struct EnhancedNDISCatalogueContainerView: View {
    @StateObject private var viewModel: NDISContainerViewModel
    @State private var columnVisibility = NavigationSplitViewVisibility.doubleColumn
    @State private var isSidebarVisible: Bool = true
    @State private var showingHistoricalChanges = false


    // Use @Query for NDIS items
    @Query(sort: [
        SortDescriptor(\NDISItemEntity.itemNumber, order: .forward),
        SortDescriptor(\NDISItemEntity.effectiveStartDate, order: .reverse) // Newest versions first
    ]) 
    private var allNdisItems: [NDISItemEntity]
    
    // Computed property to filter current items
    private var ndisItems: [NDISItemEntity] {
        allNdisItems.filter { $0.isCurrent }
    }

    init() {
        _viewModel = StateObject(wrappedValue: NDISContainerViewModel(
            // ModelContext will be injected from the environment later
            context: ModelContext(try! ModelContainer(for: NDISItemEntity.self))
        ))
    }

    var body: some View {
        CustomHSplitView(
            fraction: 0.4,
            minPFraction: 0.35,
            maxPFraction: 0.6,
            isPrimaryVisible: $isSidebarVisible,
            primary: {
                NDISItemsListView(viewModel: viewModel, showingHistoricalChanges: $showingHistoricalChanges)
            },
            secondary: {
                if let selectedItem = viewModel.selectedItem {
                    EnhancedSupportItemDetailView(
                        item: selectedItem
                    )
                    .id(selectedItem.id) // Use .id
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "list.bullet.rectangle.portrait")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("Select an Item")
                            .font(.title2)
                        Text("Choose an NDIS support item from the list to view its details.")
                            .foregroundColor(.secondary)
                    }
                }
            },
            splitter: { geo in
                ZStack {
                    Color.black.allowsHitTesting(false)
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 100)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.clear, lineWidth: 1))
                        .contentShape(Rectangle())
                        .appSplitterCursor()
                    VStack(spacing: 6) {
                        Circle().fill(Color.gray).frame(width: 4, height: 4)
                        Circle().fill(Color.gray).frame(width: 4, height: 4)
                        Circle().fill(Color.gray).frame(width: 4, height: 4)
                    }
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.3), value: false)
                }
            }
        )
        .background(Color.black)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { isSidebarVisible.toggle() } }) {
                    Image(systemName: "sidebar.left")
                }
                .help("Toggle Sidebar")
                .appInteractiveCursor()
            }
        }
        .onAppear {
            viewModel.setSourceItems(ndisItems: ndisItems) // Pass SwiftData array
        }
        .onChange(of: ndisItems) { oldItems, newItems in // Observe changes directly on @Query results
            viewModel.setSourceItems(ndisItems: newItems)
        }
        .sheet(isPresented: $showingHistoricalChanges) {
            NDISChangesSummaryView()
        }

    }
} 