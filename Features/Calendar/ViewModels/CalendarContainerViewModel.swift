import SwiftUI
import Combine
import SwiftData // Import SwiftData

@MainActor
class CalendarContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    private let modelContext: ModelContext // Change to ModelContext
    @Published private(set) var calendarViewModel: CalendarViewModel
    @Published var calendarSearchText: String = ""
    @Published var showDatePicker: Bool = false
    @Published var selectedDate: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
    init(modelContext: ModelContext) { // Change context type
        self.modelContext = modelContext
        // The actual EventKitSyncService will be injected into CalendarViewModel by the parent view
        // Here, we use a placeholder; the real service will be set in the view
        self.calendarViewModel = CalendarViewModel(
            context: modelContext, // Pass context
            eventKitService: EventKitSyncService.shared,
            dataManager: CalendarDataManager(context: modelContext, eventKitService: EventKitSyncService.shared) // Pass dataManager
        )
        setupBindings()
        
        // Observe changes to the ModelContext - let calendarViewModel handle its own updates
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                // CalendarViewModel will handle its own data updates through its own bindings
                // No need to manually trigger objectWillChange here
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties for View Bindings
    var calendarViewTypeBinding: Binding<CalendarViewType> {
        Binding(
            get: { [weak self] in self?.calendarViewModel.calendarViewType ?? .week },
            set: { [weak self] newValue in
                self?.calendarViewModel.calendarViewType = newValue
            }
        )
    }
    
    var hourHeightBinding: Binding<Double> {
        Binding(
            get: { [weak self] in Double(self?.calendarViewModel.hourHeight ?? 60) },
            set: { [weak self] newValue in
                self?.calendarViewModel.hourHeight = CGFloat(newValue)
                UserDefaults.standard.set(newValue, forKey: "hourHeightDouble")
            }
        )
    }
    
    var selectedStatusFilterBinding: Binding<String?> {
        Binding(
            get: { [weak self] in self?.calendarViewModel.selectedStatusFilter },
            set: { [weak self] newValue in
                self?.calendarViewModel.selectedStatusFilter = newValue
            }
        )
    }
    
    var selectedClientFilterBinding: Binding<UUID?> {
        Binding(
            get: { [weak self] in self?.calendarViewModel.selectedClientFilter },
            set: { [weak self] newValue in
                self?.calendarViewModel.selectedClientFilter = newValue
            }
        )
    }
    
    // MARK: - Computed Properties for Picker Bindings (Hashable)
    var selectedStatusFilterString: String {
        get { self.calendarViewModel.selectedStatusFilter ?? "All" }
        set { 
            if newValue == "All" {
                self.calendarViewModel.selectedStatusFilter = nil
            } else {
                self.calendarViewModel.selectedStatusFilter = newValue
            }
        }
    }
    
    var selectedClientFilterString: String {
        get { 
            if let clientId = self.calendarViewModel.selectedClientFilter,
               let client = self.calendarViewModel.availableFilterClients.first(where: { $0.value == clientId }) {
                return client.label
            }
            return "All Clients"
        }
        set { 
            if newValue == "All Clients" {
                self.calendarViewModel.selectedClientFilter = nil
            } else if let client = self.calendarViewModel.availableFilterClients.first(where: { $0.label == newValue }) {
                self.calendarViewModel.selectedClientFilter = client.value
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Sync search text changes to the calendar view model
        $calendarSearchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                DispatchQueue.main.async {
                    self?.calendarViewModel.searchText = searchText
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    func moveToPreviousPeriod() {
        let calendar = Calendar.current
        let dateComponent: Calendar.Component
        let value: Int
        
        switch calendarViewModel.calendarViewType {
        case .week:
            dateComponent = .day
            value = -7
        case .timeline:
            dateComponent = .day
            value = -1
        default:
            dateComponent = .month
            value = -1
        }
        
        if let newDate = calendar.date(byAdding: dateComponent, value: value, to: calendarViewModel.selectedDate) {
            calendarViewModel.selectedDate = newDate
        }
    }
    
    func moveToNextPeriod() {
        let calendar = Calendar.current
        let dateComponent: Calendar.Component
        let value: Int
        
        switch calendarViewModel.calendarViewType {
        case .week:
            dateComponent = .day
            value = 7
        case .timeline:
            dateComponent = .day
            value = 1
        default:
            dateComponent = .month
            value = 1
        }
        
        if let newDate = calendar.date(byAdding: dateComponent, value: value, to: calendarViewModel.selectedDate) {
            calendarViewModel.selectedDate = newDate
        }
    }
    
    func moveToToday() {
        calendarViewModel.moveToToday()
    }
    
    func goToDate(_ date: Date) {
        calendarViewModel.selectedDate = date
    }
    
    /// Creates a new session by setting the selected session info on the calendar view model.
    func createNewSession() {
        let calendar = Calendar.current
        let selectedDay = calendarViewModel.selectedDate
        // Default to 9 AM on the selected day.
        let startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
        
        // Set the session to nil to indicate a new session, triggering the sheet.
        calendarViewModel.selectedSessionInfo = (session: nil, instanceStart: startTime, instanceEnd: endTime)
        
        // Trigger the sheet presentation
        calendarViewModel.isShowingNewSessionSheet = true
    }
} 
