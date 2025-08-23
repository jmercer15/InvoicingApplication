import SwiftUI
import SwiftData // Import SwiftData
import Combine

class TaxContainerViewModel: ObservableObject {
    private let modelContext: ModelContext // Change to ModelContext
    private var cancellables = Set<AnyCancellable>()

    @Published var allExpenses: [ExpenseEntity] = []
    @Published var categories: [ExpenseCategoryEntity] = []
    
    // UI State
    @Published var selectedFinancialYear: String = "2024/2025" {
        didSet {
            if oldValue != selectedFinancialYear {
                fetchData()
            }
        }
    }
    @Published var showingAddExpenseSheet = false
    @Published var selectedQuarter: String = "Jul-Sep"

    // Expense List State
    @Published var expenseSearchText = ""
    @Published var expenseSortOrder: ExpenseSortOrder = .dateDesc
    @Published var expenseCategoryFilter: ExpenseCategoryEntity? = nil

    // Summary Data
    @Published var totalTaxableIncome: Double = 0.0
    @Published var totalGSTFreeIncome: Double = 0.0
    @Published var totalExpenses: Double = 0.0
    @Published var totalOperatingExpenses: Double = 0.0
    @Published var totalCapitalExpenses: Double = 0.0
    @Published var totalDepreciationClaim: Double = 0.0
    @Published var gstCollected: Double = 0.0
    @Published var gstPaid: Double = 0.0
    @Published var expensesByCategory: [ExpenseCategoryEntity: Double] = [:]

    // BAS Data
    @Published var basTotalSales: Double = 0.0
    @Published var basGstOnSales: Double = 0.0
    @Published var basGstOnPurchases: Double = 0.0

    private var business: BusinessEntity?

    var totalIncome: Double {
        totalTaxableIncome + totalGSTFreeIncome
    }
    var taxableOperatingProfit: Double {
        totalIncome - totalOperatingExpenses - totalDepreciationClaim
    }
    var netCashPosition: Double {
        totalIncome - (totalOperatingExpenses + totalCapitalExpenses)
    }
    var gstBalance: Double {
        gstCollected - gstPaid
    }

    // A computed property to handle filtering and sorting for the view
    var displayedExpenses: [ExpenseEntity] {
        var filtered = allExpenses

        if !expenseSearchText.isEmpty {
            filtered = filtered.filter { $0.name.localizedCaseInsensitiveContains(expenseSearchText) }
        }

        if let category = expenseCategoryFilter {
            filtered = filtered.filter { $0.category?.id == category.id }
        }

        // Apply sorting
        switch expenseSortOrder {
        case .dateDesc:
            filtered.sort { $0.date ?? .distantPast > $1.date ?? .distantPast }
        case .dateAsc:
            filtered.sort { $0.date ?? .distantPast < $1.date ?? .distantPast }
        case .amountDesc:
            filtered.sort { ($0.amount + $0.gstAmount) > ($1.amount + $1.gstAmount) }
        case .amountAsc:
            filtered.sort { ($0.amount + $1.gstAmount) < ($1.amount + $1.gstAmount) }
        }
        
        return filtered
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        fetchBusinessEntity()
        fetchData()
        seedDefaultCategoriesIfNeeded()
    }

    func fetchData() {
        fetchExpensesForCurrentPeriod()
        fetchExpenseCategories()
        calculateSummary()
    }

    private func fetchBusinessEntity() {
        let descriptor = FetchDescriptor<BusinessEntity>()
        do {
            business = try modelContext.fetch(descriptor).first
        } catch {
            print("Error fetching business entity: \(error)")
        }
    }

    private func fetchExpensesForCurrentPeriod() {
        let dates = financialYearDates(for: selectedFinancialYear)
        guard let startDate = dates.start, let endDate = dates.end else {
            self.allExpenses = []
            return
        }

        let isCashBasis = business?.accountingMethod == "Cash"
        _ = isCashBasis ? "paidDate" : "date"

        let descriptor = FetchDescriptor<ExpenseEntity>()

        do {
            let possibleExpenses = try modelContext.fetch(descriptor)
            allExpenses = possibleExpenses.filter { ($0.date ?? Date.distantPast) >= startDate && ($0.date ?? Date.distantFuture) <= endDate }
        } catch {
            print("Error fetching expenses: \(error)")
            allExpenses = []
        }
    }

    private func fetchExpenseCategories() {
        let descriptor = FetchDescriptor<ExpenseCategoryEntity>(sortBy: [SortDescriptor(\.name, order: .forward)])
        do {
            categories = try modelContext.fetch(descriptor)
        } catch {
            print("Error fetching expense categories: \(error)")
        }
    }
    
    func deleteExpense(at offsets: IndexSet) {
        let expensesToDelete = offsets.map { displayedExpenses[$0] }
        for expense in expensesToDelete {
            modelContext.delete(expense)
        }
        
        do {
            try modelContext.save()
            fetchData() // Refresh the list and summary
        } catch {
            print("Error saving context after deleting expense: \(error)")
        }
    }

    func addCategory(name: String, iconName: String) {
        let newCategory = ExpenseCategoryEntity(id: UUID(), name: name)
        newCategory.iconName = iconName
        modelContext.insert(newCategory)

        do {
            try modelContext.save()
            fetchExpenseCategories()
        } catch {
            print("Error saving new category: \(error)")
        }
    }

    func deleteCategory(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            modelContext.delete(category)
        }

        do {
            try modelContext.save()
            fetchExpenseCategories()
        } catch {
            print("Error saving context after deleting category: \(error)")
        }
    }

    func calculateSummary() {
        let dates = financialYearDates(for: selectedFinancialYear)
        guard let startDate = dates.start, let endDate = dates.end else { return }

        let isCashBasis = business?.accountingMethod == "Cash"
        // Determine which date field to use based on accounting method
        let _ = isCashBasis ? "paidDate" : "date"

        // Reset values
        totalTaxableIncome = 0
        totalGSTFreeIncome = 0
        totalExpenses = 0
        totalOperatingExpenses = 0
        totalCapitalExpenses = 0
        totalDepreciationClaim = calculateDepreciationForFinancialYear(startDate: startDate, endDate: endDate)
        gstCollected = 0
        gstPaid = 0
        expensesByCategory = [:]

        // Calculate from invoices
        let invoiceDescriptor = FetchDescriptor<InvoiceItemEntity>()
        do {
            let possibleInvoiceItems = try modelContext.fetch(invoiceDescriptor)
            let invoiceItems = possibleInvoiceItems.filter { $0.date >= startDate && $0.date <= endDate }
            for item in invoiceItems {
                if item.taxRate > 0 {
                    totalTaxableIncome += item.amount
                    gstCollected += item.amount * item.taxRate
                } else {
                    totalGSTFreeIncome += item.amount
                }
            }
        } catch {
            print("Error fetching invoice items: \(error)")
        }

        // Calculate from the already fetched expenses
        let operating = self.allExpenses.filter { !$0.isCapitalExpense }
        let capital = self.allExpenses.filter { $0.isCapitalExpense }

        totalOperatingExpenses = operating.reduce(0) { $0 + $1.amount }
        totalCapitalExpenses = capital.reduce(0) { $0 + $1.amount }
        
        gstPaid = self.allExpenses.reduce(0) { $0 + $1.gstAmount }

        // Group by category (considering only operating expenses for this breakdown)
        expensesByCategory = Dictionary(grouping: operating, by: { $0.category ?? uncat() })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    private func calculateDepreciationForFinancialYear(startDate: Date, endDate: Date) -> Double {
        let isCashBasis = business?.accountingMethod == "Cash"
        let descriptor = FetchDescriptor<ExpenseEntity>(predicate: #Predicate<ExpenseEntity> { $0.isCapitalExpense == true })
        
        guard let capitalExpenses = try? modelContext.fetch(descriptor) else {
            return 0.0
        }

        let calendar = Calendar.current
        var totalClaim = 0.0

        for expense in capitalExpenses {
            guard expense.assetUsefulLife > 0 else { continue }

            let purchaseDate = isCashBasis ? (expense.paidDate ?? expense.date) : expense.date
            guard let purchaseDate = purchaseDate else { continue }
            
            guard let endOfUsefulLife = calendar.date(byAdding: .year, value: Int(expense.assetUsefulLife), to: purchaseDate) else { continue }

            // Asset is only depreciable in the current financial year if its life hasn't ended before the start of the FY
            // and it was purchased before the end of the FY.
            if endOfUsefulLife > startDate && purchaseDate < endDate {
                let annualDepreciation = expense.amount / Double(expense.assetUsefulLife)

                // Determine the financial year of purchase
                let purchaseYearComponent = calendar.component(.year, from: purchaseDate)
                let purchaseMonthComponent = calendar.component(.month, from: purchaseDate)
                
                let purchaseFinancialYearStart: Date
                if purchaseMonthComponent >= 7 { // Part of the first half of an Aus FY
                    purchaseFinancialYearStart = calendar.date(from: DateComponents(year: purchaseYearComponent, month: 7, day: 1))!
                } else { // Part of the second half of an Aus FY
                    purchaseFinancialYearStart = calendar.date(from: DateComponents(year: purchaseYearComponent - 1, month: 7, day: 1))!
                }
                
                let purchaseFinancialYearEnd = calendar.date(byAdding: .year, value: 1, to: purchaseFinancialYearStart)!.addingTimeInterval(-1)

                if calendar.isDate(startDate, equalTo: purchaseFinancialYearStart, toGranularity: .year) {
                    // It's the first year of ownership, calculate pro-rata
                    let daysOwned = calendar.dateComponents([.day], from: purchaseDate, to: purchaseFinancialYearEnd).day ?? 0
                    totalClaim += (annualDepreciation / 365.0) * Double(daysOwned)
                } else {
                    // It's a subsequent year, claim full amount (or remaining if last year)
                    // Simplified: for now, we claim the full amount until we add more complex end-of-life logic
                    totalClaim += annualDepreciation
                }
            }
        }
        return totalClaim
    }

    func calculateBASSummary() {
        let dates = quarterDates(for: selectedQuarter, in: selectedFinancialYear)
        guard let startDate = dates.start, let endDate = dates.end else { return }
        
        _ = business?.accountingMethod == "Cash"

        // Reset values
        basTotalSales = 0
        basGstOnSales = 0
        basGstOnPurchases = 0

        // Calculate from invoices
        let invoiceDescriptor = FetchDescriptor<InvoiceItemEntity>()
        do {
            let possibleInvoiceItems = try modelContext.fetch(invoiceDescriptor)
            let invoiceItems = possibleInvoiceItems.filter { $0.date >= startDate && $0.date <= endDate }
            for item in invoiceItems {
                basTotalSales += item.amount
                if item.taxRate > 0 {
                    basGstOnSales += item.amount * item.taxRate
                }
            }
        } catch {
            print("Error fetching invoice items for BAS: \(error)")
        }

        // Calculate from expenses
        let descriptor = FetchDescriptor<ExpenseEntity>()
        do {
            let possibleExpenses = try modelContext.fetch(descriptor)
            let expenses = possibleExpenses.filter { ($0.date ?? Date.distantPast) >= startDate && ($0.date ?? Date.distantFuture) <= endDate }
            for expense in expenses {
                basGstOnPurchases += expense.gstAmount
            }
        } catch {
            print("Error fetching expenses for BAS: \(error)")
        }
    }

    private func financialYearDates(for yearString: String) -> (start: Date?, end: Date?) {
        let years = yearString.split(separator: "/").compactMap { Int($0) }
        guard years.count == 2 else { return (nil, nil) }
        let startYear = years[0]

        var startComponents = DateComponents()
        startComponents.year = startYear
        startComponents.month = 7
        startComponents.day = 1

        var endComponents = DateComponents()
        endComponents.year = startYear + 1
        endComponents.month = 6
        endComponents.day = 30

        let calendar = Calendar.current
        return (calendar.date(from: startComponents), calendar.date(from: endComponents))
    }

    private func quarterDates(for quarter: String, in financialYear: String) -> (start: Date?, end: Date?) {
        let years = financialYear.split(separator: "/").compactMap { Int($0) }
        guard years.count == 2 else { return (nil, nil) }
        
        var startMonth = 0
        var startYear = 0
        
        switch quarter {
            case "Jul-Sep":
                startMonth = 7
                startYear = years[0]
            case "Oct-Dec":
                startMonth = 10
                startYear = years[0]
            case "Jan-Mar":
                startMonth = 1
                startYear = years[1]
            case "Apr-Jun":
                startMonth = 4
                startYear = years[1]
            default:
                return(nil, nil)
        }
        
        let calendar = Calendar.current
        var startComponents = DateComponents()
        startComponents.year = startYear
        startComponents.month = startMonth
        startComponents.day = 1
        
        guard let startDate = calendar.date(from: startComponents) else { return (nil, nil) }
        
        // Find the start of the next quarter, then subtract one day to get the end of the current quarter
        let nextQuarterStartDate = calendar.date(byAdding: .month, value: 3, to: startDate)!
        let endDate = calendar.date(byAdding: .day, value: -1, to: nextQuarterStartDate)
        
        return (startDate, endDate)
    }

    func exportTaxSummaryToCSV() {
        let dates = financialYearDates(for: selectedFinancialYear)
        guard let startDate = dates.start, let endDate = dates.end else { return }

        // 1. Generate CSV String
        var csvString = "Type,Date,Description,Category,Amount,Tax/GST\n"

        // Add Income Items
        let invoiceDescriptor = FetchDescriptor<InvoiceItemEntity>()
        do {
            let possibleInvoiceItems = try modelContext.fetch(invoiceDescriptor)
            let invoiceItems = possibleInvoiceItems.filter { $0.date >= startDate && $0.date <= endDate }
            for item in invoiceItems {
                let gst = item.taxRate > 0 ? item.amount * item.taxRate : 0.0
                csvString += "Income,\(item.date.formatted(.iso8601))," +
                             "\"\(item.itemDescription)\",N/A," +
                             "\(item.amount),\(gst)\n"
            }
        } catch {
            print("Error fetching invoice items for CSV export: \(error)")
        }

        // Add Expense Items
        for expense in allExpenses {
            csvString += "Expense,\((expense.date ?? Date.distantPast).formatted(.iso8601))," +
                         "\"\(expense.name)\"," +
                         "\"\(expense.category?.name ?? "Uncategorized")\"," +
                         "\(expense.amount),\(expense.gstAmount)\n"
        }

        // 2. Show Save Panel
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.allowedContentTypes = [.commaSeparatedText]
        savePanel.nameFieldStringValue = "Tax_Summary_\(selectedFinancialYear.replacingOccurrences(of: "/", with: "-")).csv"

        if savePanel.runModal() == .OK {
            guard let url = savePanel.url else { return }
            do {
                try csvString.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save CSV file: \(error.localizedDescription)")
            }
        }
    }

    private func seedDefaultCategoriesIfNeeded() {
        let descriptor = FetchDescriptor<ExpenseCategoryEntity>()
        do {
            let categories = try modelContext.fetch(descriptor)
            if categories.isEmpty {
                // No categories exist, so let's seed them.
                addCategory(name: "Motor Vehicle Expenses", iconName: "car.fill")
                addCategory(name: "Travel Expenses", iconName: "airplane")
                addCategory(name: "Utilities", iconName: "bolt.fill")
                addCategory(name: "Office Supplies", iconName: "pencil.and.ruler.fill")
                addCategory(name: "Rent", iconName: "house.fill")
                addCategory(name: "Insurance", iconName: "shield.fill")
                addCategory(name: "Professional Development", iconName: "book.fill")
                addCategory(name: "Bank Fees", iconName: "dollarsign.circle.fill")
                addCategory(name: "Superannuation", iconName: "person.3.fill")
                addCategory(name: "Other", iconName: "tag.fill")
            }
        } catch {
            print("Error checking for existing categories: \(error)")
        }
    }

    private func uncat() -> ExpenseCategoryEntity {
        let category = ExpenseCategoryEntity(id: UUID(), name: "Uncategorized")
        return category
    }
}

enum ExpenseSortOrder: String, CaseIterable, Identifiable {
    case dateDesc = "Newest First"
    case dateAsc = "Oldest First"
    case amountDesc = "Amount (High to Low)"
    case amountAsc = "Amount (Low to High)"

    var id: String { self.rawValue }

    var sortDescriptors: [SortDescriptor<ExpenseEntity>] {
        switch self {
        case .dateDesc:
            return [SortDescriptor(\.date, order: .reverse)]
        case .dateAsc:
            return [SortDescriptor(\.date, order: .forward)]
        case .amountDesc:
            return [SortDescriptor(\.amount, order: .reverse)]
        case .amountAsc:
            return [SortDescriptor(\.amount, order: .forward)]
        }
    }
} 
