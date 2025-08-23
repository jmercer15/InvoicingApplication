import SwiftUI
import SwiftData

struct TaxContainerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: TaxContainerViewModel
    @State private var expenseToEdit: ExpenseEntity?
    @State private var showingExpenseEditor = false
    @State private var showingCategoryManager = false
    @State private var selectedTab: Int = 0
    
    private var categoryFilterBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.expenseCategoryFilter?.id },
            set: { newId in
                viewModel.expenseCategoryFilter = viewModel.categories.first(where: { $0.id == newId })
            }
        )
    }

    init(modelContext: ModelContext) {
        _viewModel = StateObject(wrappedValue: TaxContainerViewModel(modelContext: modelContext))
    }

    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $selectedTab) {
                    ExpensesView(
                        expenses: viewModel.displayedExpenses,
                        onEdit: { expense in
                            self.expenseToEdit = expense
                            self.showingExpenseEditor = true
                        },
                        onDelete: viewModel.deleteExpense
                    )
                    .tabItem {
                        Label("Expenses", systemImage: "list.bullet")
                    }
                    .tag(0)

                    TaxSummaryView(viewModel: viewModel)
                        .tabItem {
                            Label("Summary", systemImage: "chart.bar.doc.horizontal")
                        }
                        .tag(1)
                    
                    BASReportView(viewModel: viewModel)
                        .tabItem {
                            Label("BAS Report", systemImage: "doc.text.magnifyingglass")
                        }
                        .tag(2)
                }
                .searchable(text: $viewModel.expenseSearchText, prompt: "Search Expenses")
            }
            .navigationTitle("Tax")
            .background(Color.black)
            .toolbar {
                // Filters and category manager in secondary actions
                ToolbarItemGroup(placement: .secondaryAction) {
                    Menu {
                        Picker("Sort", selection: $viewModel.expenseSortOrder) {
                            ForEach(ExpenseSortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                        Picker("Category", selection: categoryFilterBinding) {
                            Text("All Categories").tag(nil as UUID?)
                            ForEach(viewModel.categories) { category in
                                Text(category.name).tag(category.id as UUID?)
                            }
                        }
                    } label: {
                        Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    .help("Filter and sort expenses")
                    .appInteractiveCursor()
                    Button(action: { showingCategoryManager = true }) {
                        Label("Categories", systemImage: "folder")
                    }
                    .help("Manage expense categories")
                    .appInteractiveCursor()
                }
                // Primary creation action on the trailing side
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        expenseToEdit = nil
                        showingExpenseEditor = true
                    }) {
                        Label("Add Expense", systemImage: "plus")
                    }
                    .help("Add a new expense")
                    .appInteractiveCursor()
                }
            }
            .sheet(isPresented: $showingExpenseEditor) {
                NavigationStack {
                    ExpenseEditorView(viewModel: viewModel, expenseToEdit: expenseToEdit)
                }
            }
            .sheet(isPresented: $showingCategoryManager) {
                ExpenseCategoryManagerView(viewModel: viewModel)
            }
        }
        
    }
} 
 