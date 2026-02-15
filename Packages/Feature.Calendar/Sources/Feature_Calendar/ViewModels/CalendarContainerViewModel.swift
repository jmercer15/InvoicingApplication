import SwiftUI
import Combine
import SwiftData
import Data
import Core

@MainActor
public final class CalendarContainerViewModel: ObservableObject {
    // MARK: - Dependencies
    private let unitOfWork: UnitOfWorkService
    private let sessionDomainService: SessionDomainServiceProtocol
    
    @Published private(set) var calendarViewModel: CalendarViewModel
    @Published var calendarSearchText: String = ""
    @Published var showDatePicker: Bool = false
    @Published var selectedDate: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Synchronization Flags
    private var isUpdatingFromCalendar = false
    private var isUpdatingFromContainer = false
    
    // MARK: - Initializer
    public init(
        unitOfWork: UnitOfWorkService,
        sessionDomainService: SessionDomainServiceProtocol
    ) {
        self.unitOfWork = unitOfWork
        self.sessionDomainService = sessionDomainService
        
        let eventKitService = EventKitSyncService.shared
        
        // Note: CalendarDataManager likely needs refactoring or we pass UoW to it?
        // For now, assuming CalendarDataManager construction might need adjustment or we init it inside CalendarViewModel
        // Or if CalendarDataManager is internal to Feature.Calendar, we can refactor it later.
        // Assuming CalendarViewModel will be refactored to take UnitOfWork.
        
        // We need to initialize CalendarViewModel.
        // Since I haven't refactored CalendarViewModel yet, this code would technically be invalid if I compiled now.
        // But I will refactor CalendarViewModel immediately after.
        
        self.calendarViewModel = CalendarViewModel(
            unitOfWork: unitOfWork,
            sessionDomainService: sessionDomainService,
            eventKitService: eventKitService
        )
        
        // Synchronize all properties with the calendar view model
        synchronizeProperties()
        configureBindings()
        validateSynchronization()
    }

    public func updateUnitOfWork(_ newUnitOfWork: UnitOfWorkService) {
        // Update dependencies with new UoW
        let eventKitService = EventKitSyncService.shared
        
        calendarViewModel = CalendarViewModel(
            unitOfWork: newUnitOfWork,
            sessionDomainService: sessionDomainService, // Domain service might need new UoW? Usually Services are recreated with new UoW.
            eventKitService: eventKitService
        )
        // Note: Ideally, SessionDomainService should be recreated if it depends on UoW.
        // But here we are injected with a protocol. The caller should potentially provide a new service?
        // For now, we update CalendarViewModel with new UoW.
        
        // Synchronize all properties with the new calendar view model
        synchronizeProperties()
        configureBindings()
        validateSynchronization()
    }
    
    /// Synchronizes all properties with the calendar view model
    private func synchronizeProperties() {
        print("🔄 Calendar: Synchronizing all properties with calendar view model")
        
        // Sync selectedDate
        if selectedDate != calendarViewModel.selectedDate {
            isUpdatingFromCalendar = true
            selectedDate = calendarViewModel.selectedDate
            isUpdatingFromCalendar = false
        }
        
        // Sync search text
        if calendarSearchText != calendarViewModel.filterState.searchText {
            calendarSearchText = calendarViewModel.filterState.searchText
        }
        
        // Reset UI state
        showDatePicker = false
        
        print("🔄 Calendar: Properties synchronized successfully")
    }
    
    /// Validates that all properties are properly synchronized
    private func validateSynchronization() {
        let isDateSynced = selectedDate == calendarViewModel.selectedDate
        let isSearchSynced = calendarSearchText == calendarViewModel.filterState.searchText
        
        print("🔄 Calendar: Synchronization validation - Date: \(isDateSynced), Search: \(isSearchSynced)")
        
        if !isDateSynced {
            print("⚠️ Calendar: Date synchronization issue detected!")
        }
        if !isSearchSynced {
            print("⚠️ Calendar: Search text synchronization issue detected!")
        }
    }
    
    /// Forces a complete resynchronization of all properties
    public func forceResynchronization() {
        print("🔄 Calendar: Forcing complete resynchronization")
        synchronizeProperties()
        validateSynchronization()
    }
    
    // MARK: - Direct Property Access (Simplified)
    var calendarViewType: CalendarViewType {
        get { calendarViewModel.calendarViewType }
        set { 
            print("🔄 Calendar: View type changing from \(calendarViewModel.calendarViewType) to \(newValue)")
            calendarViewModel.calendarViewType = newValue
        }
    }
    
    var hourHeight: Double {
        get { Double(calendarViewModel.hourHeight) }
        set { 
            calendarViewModel.hourHeight = CGFloat(newValue)
            UserDefaults.standard.set(newValue, forKey: "hourHeightDouble")
        }
    }
    
    // MARK: - Direct Property Access for Filters
    var selectedStatusFilter: String? {
        get { calendarViewModel.selectedStatusFilter }
        set { calendarViewModel.selectedStatusFilter = newValue }
    }
    
    var selectedClientFilter: UUID? {
        get { calendarViewModel.selectedClientFilter }
        set { calendarViewModel.selectedClientFilter = newValue }
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
    
    // MARK: - Multi-Selection Filter Access
    var selectedStatusFilters: Set<String> {
        get { calendarViewModel.filterStatuses }
        set { calendarViewModel.filterStatuses = newValue }
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
    
    var selectedClientFilters: Set<UUID> {
        get { calendarViewModel.selectedClientFilterIDs }
        set { calendarViewModel.selectedClientFilterIDs = newValue }
    }
    
    // MARK: - Private Methods
    private func configureBindings() {
        cancellables.removeAll()

        // MARK: - Search Text Synchronization
        $calendarSearchText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] searchText in
                self?.calendarViewModel.filterState.searchText = searchText
            }
            .store(in: &cancellables)

        // MARK: - Date Synchronization (Bidirectional)
        $selectedDate
            .removeDuplicates()
            .sink { [weak self] newDate in
                guard let self = self, !self.isUpdatingFromCalendar else { return }
                if self.calendarViewModel.selectedDate != newDate {
                    print("🔄 Calendar: Syncing selectedDate from container (\(newDate)) to calendar view model")
                    self.isUpdatingFromContainer = true
                    self.calendarViewModel.selectedDate = newDate
                    self.isUpdatingFromContainer = false
                }
            }
            .store(in: &cancellables)
        
        calendarViewModel.$selectedDate
            .removeDuplicates()
            .sink { [weak self] newDate in
                guard let self = self, !self.isUpdatingFromContainer else { return }
                if self.selectedDate != newDate {
                    print("🔄 Calendar: Syncing selectedDate from calendar view model (\(newDate)) to container")
                    self.isUpdatingFromCalendar = true
                    self.selectedDate = newDate
                    self.isUpdatingFromCalendar = false
                }
            }
            .store(in: &cancellables)

        // MARK: - View Type Synchronization
        // No synchronization needed since calendarViewType is a computed property

        // MARK: - Filter Synchronization
        calendarViewModel.$filterStatuses
            .removeDuplicates()
            .sink { [weak self] newStatuses in
                print("🔄 Calendar: Filter statuses updated: \(newStatuses)")
            }
            .store(in: &cancellables)

        calendarViewModel.$selectedClientFilterIDs
            .removeDuplicates()
            .sink { [weak self] newClientIDs in
                print("🔄 Calendar: Client filter IDs updated: \(newClientIDs)")
            }
            .store(in: &cancellables)

        // MARK: - UI State Synchronization
        $showDatePicker
            .removeDuplicates()
            .sink { [weak self] isShowing in
                print("🔄 Calendar: Date picker visibility changed to \(isShowing)")
            }
            .store(in: &cancellables)

        // MARK: - Data Updates
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.calendarViewModel.updateDisplayableItems()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Simplified Date Navigation
    func goToPreviousWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    func goToNextWeek() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    func goToPreviousMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    func goToNextMonth() {
        let calendar = Calendar.current
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    func goToToday() {
        selectedDate = Date()
    }
    
    func goToDate(_ date: Date) {
        selectedDate = date
    }
    
    // MARK: - Smart Navigation
    func goToPrevious() {
        switch calendarViewType {
        case .week:
            goToPreviousWeek()
        case .month:
            goToPreviousMonth()
        }
    }
    
    func goToNext() {
        switch calendarViewType {
        case .week:
            goToNextWeek()
        case .month:
            goToNextMonth()
        }
    }
    
    /// Creates a new session by setting the selected session info on the calendar view model.
    func createNewSession() {
        let calendar = Calendar.current
        let selectedDay = selectedDate
        // Default to 9 AM on the selected day.
        let startTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        let endTime = calendar.date(byAdding: .hour, value: 1, to: startTime) ?? startTime
        
        // Set the session to nil to indicate a new session, triggering the sheet.
        calendarViewModel.selectedSessionInfo = (session: nil, instanceStart: startTime, instanceEnd: endTime)
        
    }

    /// Opens an existing session in the calendar editor and focuses its day.
    public func openSession(sessionID: UUID) async {
        do {
            guard let session = try await unitOfWork.sessions.fetch(byId: sessionID) else { return }
            if let start = session.startTime {
                selectedDate = start
            }
            calendarViewModel.selectedSessionInfo = (
                session: session,
                instanceStart: session.startTime,
                instanceEnd: session.endTime
            )
        } catch {
            print("❌ Calendar: Failed to open session \(sessionID): \(error)")
        }
    }
}

// MARK: - Calendar Navigation Extensions
extension CalendarContainerViewModel {
    /// Get the current date being displayed
    var currentDate: Date {
        calendarViewModel.selectedDate
    }
    
    /// Get the current view type
    var currentViewType: CalendarViewType {
        calendarViewType
    }
    
    /// Navigate to a specific week containing the given date
    func goToWeek(containing date: Date) {
        calendarViewModel.selectedDate = date
    }
    
    /// Navigate to a specific month containing the given date
    func goToMonth(containing date: Date) {
        calendarViewModel.selectedDate = date
    }
    
    /// Update the context if needed (called from views when context becomes available)

}
