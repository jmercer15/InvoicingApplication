import SwiftUI
import Combine
import SwiftData

// MARK: - Dashboard Error Types
enum DashboardError: LocalizedError {
    case dataFetchFailed(String)
    case metricsCalculationFailed(String)
    case exportFailed(String)
    case navigationFailed(String)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .dataFetchFailed(let details):
            return "Failed to fetch dashboard data: \(details)"
        case .metricsCalculationFailed(let details):
            return "Failed to calculate metrics: \(details)"
        case .exportFailed(let details):
            return "Failed to export data: \(details)"
        case .navigationFailed(let details):
            return "Navigation failed: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .dataFetchFailed:
            return "Please try refreshing the dashboard or restart the app."
        case .metricsCalculationFailed:
            return "Please try refreshing the dashboard."
        case .exportFailed:
            return "Please check your file permissions and try again."
        case .navigationFailed:
            return "Please try navigating again."
        case .networkError:
            return "Please check your internet connection and try again."
        }
    }
}

class DashboardContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    private let modelContext: ModelContext
    private let navigationManager: AppNavigationManager
    
    // MARK: - Published State
    @Published var selectedPeriod: String = "This Month"
    @Published var showingQuickActions: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var isLoading: Bool = true
    @Published var hoveredCard: String?
    
    // Error handling
    @Published var errorMessage: String?
    @Published var hasError: Bool = false
    @Published var lastError: DashboardError?
    
    // Performance optimization: Cache computed properties
    @Published private(set) var cachedMetrics: DashboardMetrics?
    @Published private(set) var cachedActivities: [DashboardActivity] = []
    @Published private(set) var cachedUrgentItems: [UrgentItem] = []
    
    // Data tracking
    private var lastMetricsUpdate = Date()
    private var lastDataUpdate = Date()
    
    // Debounced update timer
    private var updateTimer: Timer?
    
    // Metrics calculator
    @Published private(set) var metricsCalculator: DashboardMetricsCalculator
    
    private var cancellables = Set<AnyCancellable>()
    
    // Constants
    let periodOptions = ["This Week", "This Month", "This Quarter", "This Year"]
    
    // MARK: - Initializer
    init(context: ModelContext, navigationManager: AppNavigationManager = .shared) {
        self.modelContext = context
        self.navigationManager = navigationManager
        self.metricsCalculator = DashboardMetricsCalculator()
        setupBindings()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        $selectedPeriod
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.debouncedRefresh()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Error Handling Methods
    private func handleError(_ error: DashboardError) {
        DispatchQueue.main.async {
            self.lastError = error
            self.errorMessage = error.localizedDescription
            self.hasError = true
            self.isLoading = false
            self.isRefreshing = false
        }
    }
    
    private func clearError() {
        DispatchQueue.main.async {
            self.lastError = nil
            self.errorMessage = nil
            self.hasError = false
        }
    }
    
    func retryOperation() {
        clearError()
        loadDashboardData()
    }
    
    func dismissError() {
        clearError()
    }
    
    // MARK: - Data Fetching Methods
    private func fetchInvoices() -> [InvoiceEntity] {
        do {
            let descriptor = FetchDescriptor<InvoiceEntity>(
                sortBy: [SortDescriptor(\.issueDate, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            let dashboardError = DashboardError.dataFetchFailed("Invoices: \(error.localizedDescription)")
            handleError(dashboardError)
            return []
        }
    }
    
    private func fetchClients() -> [ClientEntity] {
        do {
            let descriptor = FetchDescriptor<ClientEntity>(
                sortBy: [SortDescriptor(\.fullName, order: .forward)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            let dashboardError = DashboardError.dataFetchFailed("Clients: \(error.localizedDescription)")
            handleError(dashboardError)
            return []
        }
    }
    
    private func fetchSessions() -> [SessionEntity] {
        do {
            let descriptor = FetchDescriptor<SessionEntity>(
                sortBy: [SortDescriptor(\.startTime, order: .forward)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            let dashboardError = DashboardError.dataFetchFailed("Sessions: \(error.localizedDescription)")
            handleError(dashboardError)
            return []
        }
    }
    
    private func fetchCompletedSessions() -> [SessionEntity] {
        do {
            let descriptor = FetchDescriptor<SessionEntity>(
                predicate: #Predicate<SessionEntity> { $0.status == "completed" },
                sortBy: [SortDescriptor(\.startTime, order: .reverse)]
            )
            return try modelContext.fetch(descriptor)
        } catch {
            let dashboardError = DashboardError.dataFetchFailed("Completed Sessions: \(error.localizedDescription)")
            handleError(dashboardError)
            return []
        }
    }
    
    private func getUpcomingSessions(from allSessions: [SessionEntity]) -> [SessionEntity] {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return allSessions.filter { ($0.startTime ?? Date.distantPast) >= todayStart }
    }
    
    private func getNonDraftInvoices(from allInvoices: [InvoiceEntity]) -> [InvoiceEntity] {
        return allInvoices.filter { $0.status != AppConstants.invoiceStatusDraft }
    }
    
    // MARK: - Data Filtering Methods for DashboardView
    
    func getFilteredInvoices(for period: String) -> [InvoiceEntity] {
        let allInvoices = fetchInvoices()
        let nonDraftInvoices = getNonDraftInvoices(from: allInvoices)
        
        let calendar = Calendar.current
        let now = Date()
        
        return nonDraftInvoices.filter { invoice in
            let issueDate = invoice.issueDate
            
            switch period {
            case "This Week":
                return calendar.isDate(issueDate, equalTo: now, toGranularity: .weekOfYear)
            case "Last Week":
                let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
                return calendar.isDate(issueDate, equalTo: lastWeek, toGranularity: .weekOfYear)
            case "This Quarter":
                let quarterStart = calendar.dateInterval(of: .quarter, for: now)?.start ?? now
                return issueDate >= quarterStart
            case "Last Quarter":
                // Calculate last quarter manually since .quarterOfYear doesn't exist
                let currentQuarter = (calendar.component(.month, from: now) - 1) / 3
                let lastQuarterMonth = currentQuarter == 0 ? 9 : (currentQuarter - 1) * 3 + 1
                let lastQuarterStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: now) - (currentQuarter == 0 ? 1 : 0), month: lastQuarterMonth)) ?? now
                let lastQuarterEnd = calendar.date(byAdding: .month, value: 3, to: lastQuarterStart) ?? now
                return issueDate >= lastQuarterStart && issueDate < lastQuarterEnd
            case "This Year":
                return calendar.isDate(issueDate, equalTo: now, toGranularity: .year)
            case "Last Year":
                let lastYear = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                return calendar.isDate(issueDate, equalTo: lastYear, toGranularity: .year)
            case "Last Month":
                let lastMonth = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return calendar.isDate(issueDate, equalTo: lastMonth, toGranularity: .month)
            default: // "This Month"
                return calendar.isDate(issueDate, equalTo: now, toGranularity: .month)
            }
        }
    }
    
    func getTodaySessions() -> [SessionEntity] {
        let allSessions = fetchSessions()
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? Date()
        
        return allSessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= today && startTime < tomorrow
        }
    }
    
    func getThisWeekSessions() -> [SessionEntity] {
        let allSessions = fetchSessions()
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? Date()
        
        return allSessions.filter { session in
            guard let startTime = session.startTime else { return false }
            return startTime >= weekStart && startTime < weekEnd
        }
    }
    
    func calculateTotalHours() -> Double {
        let completedSessions = fetchCompletedSessions()
        
        let totalMinutes = completedSessions.reduce(0.0) { total, session in
            guard let startTime = session.startTime,
                  let endTime = session.endTime else { return total }
            
            let duration = endTime.timeIntervalSince(startTime)
            return total + duration
        }
        
        return totalMinutes / 3600.0 // Convert to hours
    }
    
    // MARK: - Public Methods
    func loadDashboardData() {
        Task {
            await loadDataAsync()
        }
    }
    
    @MainActor
    private func loadDataAsync() async {
        clearError()
        isLoading = true
        
        // Fetch actual data from SwiftData
        let allInvoices = fetchInvoices()
        let allClients = fetchClients()
        let allSessions = fetchSessions()
        let completedSessions = fetchCompletedSessions()
        
        // Check if we have critical errors
        if hasError {
            return // Error already handled by fetch methods
        }
        
        // Filter data
        let invoices = getNonDraftInvoices(from: allInvoices)
        let upcomingSessions = getUpcomingSessions(from: allSessions)
        
        // Calculate metrics with actual data
        cachedMetrics = metricsCalculator.calculateMetrics(
            invoices: invoices,
            clients: allClients,
            upcomingSessions: upcomingSessions,
            completedSessions: completedSessions
        )
        
        // Generate activities and urgent items with actual data
        cachedActivities = metricsCalculator.generateRecentActivities(
            invoices: invoices,
            upcomingSessions: upcomingSessions
        )
        
        cachedUrgentItems = metricsCalculator.generateUrgentItems(
            invoices: invoices,
            upcomingSessions: upcomingSessions
        )
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isLoading = false
        }
    }
    
    func refreshDashboard() {
        Task {
            await refreshDashboardAsync()
        }
    }
    
    @MainActor
    func refreshDashboardAsync() async {
        clearError()
        isRefreshing = true
        
        // Fetch fresh data from SwiftData
        let allInvoices = fetchInvoices()
        let allClients = fetchClients()
        let allSessions = fetchSessions()
        let completedSessions = fetchCompletedSessions()
        
        // Check if we have critical errors
        if hasError {
            return // Error already handled by fetch methods
        }
        
        // Filter data
        let invoices = getNonDraftInvoices(from: allInvoices)
        let upcomingSessions = getUpcomingSessions(from: allSessions)
        
        // Calculate metrics with fresh data
        cachedMetrics = metricsCalculator.calculateMetrics(
            invoices: invoices,
            clients: allClients,
            upcomingSessions: upcomingSessions,
            completedSessions: completedSessions
        )
        
        // Generate activities and urgent items with fresh data
        cachedActivities = metricsCalculator.generateRecentActivities(
            invoices: invoices,
            upcomingSessions: upcomingSessions
        )
        
        cachedUrgentItems = metricsCalculator.generateUrgentItems(
            invoices: invoices,
            upcomingSessions: upcomingSessions
        )
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isRefreshing = false
        }
    }
    
    func createNewInvoice() {
        // Navigate to invoices tab with context to create new invoice
        let context = NavigationContext(
            additionalData: ["action": "createNew"]
        )
        navigationManager.navigateTo(tab: .invoices, context: context, title: "Create New Invoice")
    }
    
    func sendPaymentReminders() {
        // Get overdue invoices
        let overdueInvoices = fetchInvoices().filter { invoice in
            guard let dueDate = invoice.dueDate else { return false }
            return dueDate < Date() && invoice.status != "paid"
        }
        
        if overdueInvoices.isEmpty {
            // Show notification that no reminders are needed
            print("No overdue invoices to send reminders for")
            return
        }
        
        // Navigate to invoices tab with overdue filter
        let context = NavigationContext(
            additionalData: [
                "filterType": "overdue",
                "action": "sendReminders",
                "count": overdueInvoices.count
            ]
        )
        navigationManager.navigateTo(tab: .invoices, context: context, title: "Send Payment Reminders")
    }
    
    func exportDashboardData() {
        Task {
            await exportDashboardDataAsync()
        }
    }
    
    @MainActor
    private func exportDashboardDataAsync() async {
        do {
            // Use the enhanced export service
            let (exportData, filename) = try SwiftDataExportImportService.exportToFile(context: modelContext, format: .json)
            
            // Create filename with dashboard prefix
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            let dashboardFilename = "Dashboard-Export-\(timestamp).json"
            
            // Save to desktop or documents folder
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let exportURL = documentsPath.appendingPathComponent(dashboardFilename)
            
            try exportData.write(to: exportURL)
            
            print("Dashboard data exported successfully to: \(exportURL.path)")
            
            // Show success notification
            // In a real app, you might want to show a proper notification or alert
            print("✅ Dashboard data exported successfully!")
            
        } catch {
            handleError(.exportFailed(error.localizedDescription))
        }
    }
    
    func onDataChange() {
        debouncedDataUpdate()
    }
    
    private func debouncedRefresh() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.cachedMetrics = nil
                self?.cachedActivities = []
                self?.cachedUrgentItems = []
                self?.loadDashboardData()
            }
        }
    }
    
    private func debouncedDataUpdate() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.lastDataUpdate = Date()
                self?.metricsCalculator.clearCache()
                self?.cachedMetrics = nil
                self?.cachedActivities = []
                self?.cachedUrgentItems = []
                self?.loadDashboardData()
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
}
