import SwiftUI
import Combine
import Core
import Data
import EventKit
import Foundation
import SwiftData
import SharedUI

// MARK: - DisplayableCalendarItem Enum Definition

enum DisplayableCalendarItem: Identifiable {
    case session(Session)
    case event(EKEvent)
    case recurringSessionInstance(template: Session, instanceStartDate: Date, instanceEndDate: Date, instanceIsAllDay: Bool)
    case eventSegment(originalEvent: EKEvent, segmentStartDate: Date, segmentEndDate: Date, segmentIsAllDay: Bool)

    // --- Identifiable Conformance ---
    var id: String {
        switch self {
        case .session(let session):
            return session.id.uuidString
        case .event(let event):
            let base = event.eventIdentifier ?? "unsaved_event"
            let startAnchor = event.startDate.timeIntervalSinceReferenceDate
            return "\(base)_\(startAnchor)"
        case .recurringSessionInstance(let template, let instanceStartDate, _, _):
            return "\(template.id.uuidString)_\(instanceStartDate.timeIntervalSinceReferenceDate)"
        case .eventSegment(let originalEvent, let segmentStartDate, _, _):
            // Create a unique, stable ID from the original event and the segment's start time.
            return "\(originalEvent.eventIdentifier ?? "unsaved_event")_\(segmentStartDate.timeIntervalSinceReferenceDate)"
        }
    }

    // --- Common Data Properties ---
    var startDate: Date? {
        switch self {
        case .session(let session): return session.startTime
        case .event(let event): return event.startDate
        case .recurringSessionInstance(_, let instanceStartDate, _, _): return instanceStartDate
        case .eventSegment(_, let segmentStartDate, _, _): return segmentStartDate
        }
    }

    var endDate: Date? {
        switch self {
        case .session(let session): return session.endTime
        case .event(let event): return event.endDate
        case .recurringSessionInstance(_, _, let instanceEndDate, _): return instanceEndDate
        case .eventSegment(_, _, let segmentEndDate, _): return segmentEndDate
        }
    }

    var title: String {
         switch self {
         case .session(let session): return session.title
         case .event(let event): return event.title ?? "Calendar Event"
         case .recurringSessionInstance(let template, _, _, _): return template.title
         case .eventSegment(let originalEvent, _, _, _): return originalEvent.title ?? "Calendar Event"
         }
     }

    var isAllDay: Bool {
         switch self {
         case .session(let session): return session.isAllDay
         case .event(let event): return event.isAllDay
         case .recurringSessionInstance(_, _, _, let instanceIsAllDay): return instanceIsAllDay
         case .eventSegment(_, _, _, let segmentIsAllDay): return segmentIsAllDay
         }
     }

    // --- Display & Styling ---
    var displayColor: Color {

        switch self {
        case .session(let session), .recurringSessionInstance(let session, _, _, _):
            if session.isTravel { return Color("Travel", bundle: .sharedUI) } // Blue for travel sessions

            if let colorId = session.googleColorId,
               let googleColor = GoogleCalendarColors.googleColorMap[colorId] {
                return googleColor
            }
        
            // Parse status string to SessionStatus enum equivalent
            let statusToken = SessionStatus(normalized: session.status ?? "")?.token
            let isCompleted = statusToken == SessionStatus.completed.token
            let isCancelled = statusToken == SessionStatus.cancelled.token
            let currentEndDate = self.endDate ?? Date()
            let isPast = currentEndDate < Date()
            let isConfirmed = statusToken == SessionStatus.scheduled.token
            let isPending = statusToken == SessionStatus.scheduled.token

            // Use clientId from domain model instead of client relationship
            if let clientId = session.clientId {
                return ColorSystem.Client.color(for: clientId)
            } else if isCompleted { return .green }
            else if isCancelled { return .red }
            else if isPast { return .gray }
            else if isConfirmed { return .blue }
            else if isPending { return .orange }
            else { return .blue }

        case .event(let event), .eventSegment(let event, _, _, _):
             // Use the new color provider system
             let provider = ExternalCalendarColorProviderFactory.provider(for: event.calendar)
             if let color = provider.color(for: event) {
                 return color
             }
             
             // Fallback to calendar's default color
             if let nsColor = event.calendar.color {
                  return Color(nsColor)
              } else {
                  return .gray
              }
        }
    }
    
    var isSession: Bool {
        switch self {
        case .session, .recurringSessionInstance: return true
        case .event: return false
        case .eventSegment: return false // Segments of events are not travel sessions themselves
        }
    }

    var isTravel: Bool {
        switch self {
        case .session(let session), .recurringSessionInstance(let session, _, _, _):
            return session.isTravel
        case .event(_):
            return false
        case .eventSegment(_, _, _, _):
            // A segment's travel status is determined by the original event.
            // This assumes some logic exists to determine if an EKEvent is "travel".
            // For now, we'll keep it consistent with how raw EKEvents are handled.
            return false
        }
    }

    var isEvent: Bool {
        switch self {
        case .event, .eventSegment: return true
        default: return false
        }
     }

    // --- Layout Calculation Properties ---
    var startHour: CGFloat {
        guard let startTime = self.startDate else { return 0 }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)
        return CGFloat(hour) + CGFloat(minute) / 60.0
    }

    var durationHours: CGFloat {
        guard let startTime = self.startDate, let endTime = self.endDate, endTime > startTime else {
            return self.isSession ? 0.5 : 0.25
        }
        let calculatedDuration = CGFloat(endTime.timeIntervalSince(startTime) / 3600.0)
        let minDuration: CGFloat = self.isSession ? 0.5 : 0.25
        return max(minDuration, calculatedDuration)
    }
    
    // --- Access underlying object if needed ---
    var underlyingSession: Session? {
        switch self {
        case .session(let session): return session
        case .recurringSessionInstance(let template, _, _, _): return template
        case .event: return nil
        case .eventSegment: return nil
        }
    }
    
    var underlyingEvent: EKEvent? {
        switch self {
        case .event(let event): return event
        case .eventSegment(let originalEvent, _, _, _): return originalEvent
        default: return nil
        }
    }
}

// MARK: - CalendarViewModel Class

@MainActor
public class CalendarViewModel: ObservableObject {
    // MARK: - Published State
    @Published var selectedDate: Date
    @Published var calendarViewType: CalendarViewType
    @Published var searchText: String
    @Published var selectedSessionInfo: (session: Session?, instanceStart: Date?, instanceEnd: Date?)?
    @Published var selectedClientFilterIDs: Set<UUID> = []
    @Published var showCancelledSessions: Bool = false
    @Published var isLoading: Bool = false
    @Published var hourHeight: CGFloat
    @Published private(set) var filteredSessions: [Session] = []

    // --- Travel Charge Sheet State ---
    @Published var isShowingTravelChargeSheet: Bool = false
    @Published var selectedSessionForTravel: Session?
    @Published var selectedInstanceStartDateForTravel: Date?
    @Published var selectedInstanceEndDateForTravel: Date?
    
    // --- Interaction State ---
    @Published var interactionHandler: CalendarInteractionHandler
    
    // --- ADD State for Event Conversion ---
    @Published var eventToConvert: EKEvent? = nil
    
    // --- Bulk Selection Mode ---
    @Published var isBulkSelectionMode: Bool = false
    @Published var bulkSelectedSessionIDs: Set<UUID> = []
    
    // --- Available Calendars from EventKit ---
    var availableCalendars: [EKCalendar] {
        eventKitService.eventStore.calendars(for: .event)
    }
    
    // --- ADD Unified Item State ---
    @Published private(set) var allDayItems: [DisplayableCalendarItem] = []
    @Published private(set) var timedItems: [DisplayableCalendarItem] = []
    // --- Dynamic Filter Options ---
    @Published private(set) var availableFilterStatuses: [(label: String, value: String?)] = [("All", nil)]
    @Published private(set) var availableFilterClients: [(label: String, value: UUID?, color: Color?)] = [("All", nil, nil)]
    
    // --- Selected Filters (Remain as Sets) ---
    @Published var filterStatuses: Set<String> = []
    
    // Centralized filter state (initially mirrored)
    @Published var filterState: CalendarFilterState
    
    // --- Single Selection Filter Properties for Toolbar ---
    var selectedStatusFilter: String? {
        get {
            if filterStatuses.isEmpty {
                return nil
            } else if filterStatuses.count == 1 {
                return filterStatuses.first
            } else {
                return nil // Multiple selections, show as "All"
            }
        }
        set {
            if let newValue = newValue {
                filterStatuses = [newValue]
            } else {
                filterStatuses.removeAll()
            }
        }
    }
    
    var selectedClientFilter: UUID? {
        get {
            if selectedClientFilterIDs.isEmpty {
                return nil
            } else if selectedClientFilterIDs.count == 1 {
                return selectedClientFilterIDs.first
            } else {
                return nil // Multiple selections, show as "All"
            }
        }
        set {
            if let newValue = newValue {
                selectedClientFilterIDs = [newValue]
            } else {
                selectedClientFilterIDs.removeAll()
            }
        }
    }
    
    // --- Calendar Visibility State ---
    @Published var visibleCalendarIdentifiers: Set<String> = []
    @Published var showCalendarVisibilityControls: Bool = false

    // --- Mini Calendar State (Moved from MiniMonthView) ---
    @Published var miniCalendarDisplayMonth: Date

    // --- State for Recurring Modification Dialog ---
    @Published var showingRecurringModificationDialog = false
    @Published var pendingRecurringModification: (session: Session, modification: RecurringModificationType, originalInstanceDate: Date)?
    @Published var mode: RecurringEditMode = .thisOnly

    var recurringModificationModes: [RecurringEditMode] {
        pendingRecurringModification == nil ? [] : [.thisOnly, .thisAndFuture, .all]
    }

    var recommendedRecurringModificationMode: RecurringEditMode? {
        recurringModificationModes.contains(.thisAndFuture) ? .thisAndFuture : recurringModificationModes.first
    }

    // MARK: - Dependencies
    let unitOfWork: UnitOfWorkService
    private let sessionDomainService: SessionDomainServiceProtocol
    let eventKitService: EventKitSyncService
    
    // MARK: - Data Manager
    private let dataManager: CalendarDataManager
    
    // Computed proxy properties for legacy compatibility with Views
    public var sessionsRepository: SessionsRepository { unitOfWork.sessions }
    public var clientsRepository: ClientsRepository { unitOfWork.clients }
    public var clientServicesRepository: ClientServicesRepository { unitOfWork.clientServices }
    public var addressRepository: AddressRepository { unitOfWork.addresses }
    

    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Session Modification Service
    private let sessionModificationService: SessionModificationService
    
    // MARK: - Client/Service Name Caching
    private var clientNameCache: [UUID: String] = [:]
    private var clientServiceCache: [UUID: ClientService] = [:]

    public init(
        unitOfWork: UnitOfWorkService,
        sessionDomainService: SessionDomainServiceProtocol,
        eventKitService: EventKitSyncService,
        selectedDate: Date = Date(),
        calendarViewType: CalendarViewType = .week,
        searchText: String = ""
    ) {
        self.unitOfWork = unitOfWork
        self.sessionDomainService = sessionDomainService
        self.eventKitService = eventKitService
        self.selectedDate = selectedDate
        self.calendarViewType = calendarViewType
        self.searchText = searchText
        self.hourHeight = CGFloat(UserDefaults.standard.double(forKey: "hourHeightDouble"))
        self.miniCalendarDisplayMonth = selectedDate.startOfMonth
        self.interactionHandler = CalendarInteractionHandler()
        self.filterState = CalendarFilterState()
        
        // Initialize DataManager with repositories from UoW
        self.dataManager = CalendarDataManager(
            sessionsRepository: unitOfWork.sessions,
            eventKitService: eventKitService
        )
        
        // Initialize SessionModificationService
        self.sessionModificationService = SessionModificationService(
            unitOfWork: unitOfWork,
            eventKitService: eventKitService,
            recurrenceRuleBuilder: RecurrenceRuleBuilder()
        )
        
        initializeCalendarVisibility()
        setupBindings()
    }

    private func setupBindings() {
        // This publisher now triggers a single fetch from Core Data
        Publishers.CombineLatest3($selectedDate, $calendarViewType, $searchText)
             .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
             .sink { [weak self] _ in
                 self?.updateDisplayableItems()
             }
             .store(in: &cancellables)
             
        // Listen for changes from the sync service and model context
        eventKitService.$accessGranted
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
             .sink { [weak self] _ in
                self?.updateDisplayableItems()
             }
             .store(in: &cancellables)
        
        // Observe changes to the ModelContext - SwiftData will automatically trigger updates
        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
             .sink { [weak self] _ in
                self?.updateDisplayableItems()
             }
             .store(in: &cancellables)

        // Listen for invoice changes that can transition linked session billing states.
        InvoiceChangePublisher.shared.invoicesRefreshNeeded
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDisplayableItems()
            }
            .store(in: &cancellables)

        // Listen for session changes from other features (Billing Hub, editor flows, imports).
        SessionChangePublisher.shared.sessionsRefreshNeeded
            .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateDisplayableItems()
            }
            .store(in: &cancellables)
        
        // Handle EventKit external changes
        NotificationCenter.default.publisher(for: .eventKitExternalChangesDetected)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleEventKitExternalChanges()
                }
            }
            .store(in: &cancellables)

        // Keep legacy fields in sync with new filterState and trigger updates
        filterState.$searchText
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self = self else { return }
                if self.searchText != value { self.searchText = value }
            }
            .store(in: &cancellables)

        filterState.$selectedClientFilterIDs
            .sink { [weak self] value in
                guard let self = self else { return }
                if self.selectedClientFilterIDs != value { self.selectedClientFilterIDs = value }
            }
            .store(in: &cancellables)

        filterState.$showCancelledSessions
            .sink { [weak self] value in
                guard let self = self else { return }
                if self.showCancelledSessions != value { self.showCancelledSessions = value }
            }
            .store(in: &cancellables)

        filterState.$filterStatuses
            .sink { [weak self] value in
                guard let self = self else { return }
                if self.filterStatuses != value { self.filterStatuses = value }
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Properties
    var currentWeekDays: [Date] {
        selectedDate.currentWeek
    }

    // --- ADDED: Computed property for the current view's date range ---
    var currentViewDateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let startDate: Date
        let endDate: Date

        switch calendarViewType {
        case .week:
            startDate = calendar.startOfDay(for: selectedDate.startOfWeek)
            let weekEndDay = selectedDate.endOfWeek
            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: weekEndDay)) ?? weekEndDay
        case .month:
            startDate = calendar.startOfDay(for: selectedDate.startOfMonth)
            guard let monthEndDayBase = calendar.date(byAdding: .month, value: 1, to: startDate),
                  let actualEndOfMonth = calendar.date(byAdding: .day, value: -1, to: monthEndDayBase) else {
                // Fallback to a 30-day interval from selectedDate if calculation fails
                return (selectedDate.startOfMonth, selectedDate.startOfMonth.addingTimeInterval(30*24*60*60))
            }
            // End date should be the start of the day *after* the last day of the month.
            endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: actualEndOfMonth)) ?? actualEndOfMonth.addingTimeInterval(24*60*60)

        }
        return (startDate, endDate)
    }

    // --- ADDED: Computed property for Month View Grid --- 
    var monthGridWeeks: [[Date?]] {
        CalendarDisplayDataProvider().buildMonthGridWeeks(for: selectedDate)
    }
    // -----------------------------------------------------

    var calendarTitle: String {
        switch calendarViewType {
        case .week:
            let start = selectedDate.startOfWeek
            let end = selectedDate.endOfWeek
            let calendar = Calendar.current
            
            // Check if the week spans multiple months
            let startMonth = calendar.component(.month, from: start)
            let endMonth = calendar.component(.month, from: end)
            let startYear = calendar.component(.year, from: start)
            let endYear = calendar.component(.year, from: end)
            
            if startMonth == endMonth && startYear == endYear {
                // Same month and year
                return start.formatted(.dateTime.month(.wide).year())
            } else if startYear == endYear {
                // Same year, different months
                let startMonthStr = start.formatted(.dateTime.month(.wide))
                let endMonthStr = end.formatted(.dateTime.month(.wide))
                let yearStr = start.formatted(.dateTime.year())
                return "\(startMonthStr) - \(endMonthStr) \(yearStr)"
            } else {
                // Different years
                let startStr = start.formatted(.dateTime.month(.wide).year())
                let endStr = end.formatted(.dateTime.month(.wide).year())
            return "\(startStr) - \(endStr)"
            }
        case .month:
            return selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }

    // --- ADDED: Computed property for all displayable items ---
    var displayableItems: [DisplayableCalendarItem] {
        return allDayItems + timedItems
    }

    var totalBillableHours: Double {
        let totalDurationInSeconds = filteredSessions.reduce(
            into: 0.0 // Use Double for accumulation
        ) { total, session in
            // Calculate duration only if both start and end times exist
            if let startTime = session.startTime, let endTime = session.endTime {
                let sessionDuration = endTime.timeIntervalSince(startTime)
                // Add duration only if it's positive
                if sessionDuration > 0 {
                    total += sessionDuration
                }
            }
        }
        let hours = totalDurationInSeconds / 3600.0
        // Convert total seconds to hours
        return hours
    }
    
    // --- Added: Computed property for total gross income ---
    var totalGrossIncome: Double {
        // Synchronous estimate from the currently loaded sessions.
        visibleGrossIncome
    }
    
    /// Calculate total gross income asynchronously
    func calculateTotalGrossIncome() async -> Double {
        var total: Double = 0.0
        let sessions = filteredSessions
        
        for session in sessions {
            guard let serviceId = session.clientServiceId else { continue }
            
            // Fetch service data
            let service = await fetchClientService(for: serviceId)
            guard let service = service, service.rate > 0 else { continue }
            
            let serviceUnit = service.unit.lowercased()
            let serviceRate = service.rate
            
            // Calculate session duration in hours for hourly rates
            if serviceUnit == "hour" {
                if let startTime = session.startTime, let endTime = session.endTime, endTime > startTime {
                    let durationInSeconds = endTime.timeIntervalSince(startTime)
                    let durationInHours = durationInSeconds / 3600.0
                    total += serviceRate * durationInHours
                }
            } else if !serviceUnit.isEmpty {
                // For non-hourly units (e.g., 'session', 'item'), add the rate directly
                total += serviceRate
            }
        }
        
        return total
    }
    
    // --- Added: Currency Formatter Helper ---
    private var currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD" // Adjust currency code if needed
        return formatter
    }()

    func formatCurrency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? "$\(String(format: "%.2f", value))"
    }

    func moveToToday() {
        selectedDate = Date()
    }

    // --- ADDED: Helper functions to get items for a specific day ---
    func getTimedItems(for day: Date) -> [DisplayableCalendarItem] {
        timedItems.filter { item in
            guard let itemDate = item.startDate else { return false }
            return Calendar.current.isDate(itemDate, inSameDayAs: day)
        }
    }

    func getAllDayItems(for day: Date) -> [DisplayableCalendarItem] {
        allDayItems.filter { item in
            guard let itemDate = item.startDate else { return false }
            return Calendar.current.isDate(itemDate, inSameDayAs: day)
        }
    }

    func isSelectedDay(_ day: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: selectedDate)
    }

    // --- ADDED: Mini Calendar Helper Properties and Methods ---
    var miniCalendarWeeks: [[Date?]] {
        let calendar = Calendar.current
        let month = miniCalendarDisplayMonth.startOfMonth

        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else {
            print("Error: Could not get month interval for mini calendar \(month)")
            return []
        }

        let firstDayOfMonthWeekday = calendar.component(.weekday, from: monthInterval.start)
        let firstWeekday = calendar.firstWeekday
        let daysToPrepend = (firstDayOfMonthWeekday - firstWeekday + 7) % 7

        var dates: [Date?] = Array(repeating: nil, count: daysToPrepend)
        var currentDate = monthInterval.start
        while currentDate < monthInterval.end {
            dates.append(currentDate)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                 print("Error: Could not advance day from mini calendar \(currentDate)")
                 return dates.chunked(into: 7)
            }
            currentDate = nextDay
        }
        let remainingDaysInLastWeek = (7 - (dates.count % 7)) % 7
        if remainingDaysInLastWeek > 0 {
            dates.append(contentsOf: Array(repeating: nil as Date?, count: remainingDaysInLastWeek))
        }
        return dates.chunked(into: 7)
    }

    var miniCalendarFormattedMonth: String {
        miniCalendarDisplayMonth.formatted(.dateTime.month(.wide))
    }

    var miniCalendarFormattedYear: String {
        miniCalendarDisplayMonth.formatted(.dateTime.year())
    }

    var miniCalendarSelectableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 5)...(currentYear + 5))
    }

    func selectMiniCalendarMonth(_ month: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: miniCalendarDisplayMonth)
        components.month = month
        if let newDate = calendar.date(from: components) {
            miniCalendarDisplayMonth = newDate
        }
    }

    func selectMiniCalendarYear(_ year: Int) {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: miniCalendarDisplayMonth)
        components.year = year
        if let newDate = calendar.date(from: components) {
            miniCalendarDisplayMonth = newDate
        }
    }

    func changeMiniCalendarMonth(by delta: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: delta, to: miniCalendarDisplayMonth) {
            miniCalendarDisplayMonth = newDate
        }
    }

    // MARK: - Event Fetching and Processing

    private func splitMultiDayItem(_ item: DisplayableCalendarItem, into allDay: inout [DisplayableCalendarItem], and timed: inout [DisplayableCalendarItem]) {
        guard let startDate = item.startDate, let endDate = item.endDate else {
            if item.isAllDay { allDay.append(item) } else { timed.append(item) }
            return
        }

        let calendar = Calendar.current
        
        // If an event ends exactly at midnight, treat it as ending on the last second of the previous day.
        // This prevents creating a zero-length segment for the new day.
        let effectiveEndDate = (calendar.startOfDay(for: endDate) == endDate)
            ? calendar.date(byAdding: .second, value: -1, to: endDate)!
            : endDate
        
        // If the item is no longer multi-day after this adjustment, just add it and finish.
        if calendar.isDate(startDate, inSameDayAs: effectiveEndDate) {
            if item.isAllDay { allDay.append(item) } else { timed.append(item) }
            return
        }

        var currentDate = calendar.startOfDay(for: startDate)
        let finalDayStart = calendar.startOfDay(for: effectiveEndDate)

        while currentDate <= finalDayStart {
            let isFirstDay = calendar.isDate(currentDate, inSameDayAs: startDate)
            let isLastDay = calendar.isDate(currentDate, inSameDayAs: effectiveEndDate)

            let instanceStartDate: Date
            let instanceEndDate: Date
            let instanceIsAllDay: Bool

            if isFirstDay {
                instanceStartDate = startDate
                instanceEndDate = isLastDay ? effectiveEndDate : calendar.endOfDay(for: currentDate)
                instanceIsAllDay = item.isAllDay
            } else if isLastDay {
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = effectiveEndDate
                instanceIsAllDay = item.isAllDay
            } else { // Middle day
                instanceStartDate = calendar.startOfDay(for: currentDate)
                instanceEndDate = calendar.endOfDay(for: currentDate)
                instanceIsAllDay = true // Any full day segment of a multi-day event is considered "all-day" for display
            }

            let newItem = self.createSegment(for: item, startDate: instanceStartDate, endDate: instanceEndDate, isAllDay: instanceIsAllDay)
            
            if newItem.isAllDay {
                allDay.append(newItem)
            } else {
                timed.append(newItem)
            }

            // Move to the next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
    }

    // Helper to create item segments to avoid duplicating logic in splitMultiDayItem
    private func createSegment(for originalItem: DisplayableCalendarItem, startDate: Date, endDate: Date, isAllDay: Bool) -> DisplayableCalendarItem {
        switch originalItem {
        case .session(let session):
            return .recurringSessionInstance(template: session, instanceStartDate: startDate, instanceEndDate: endDate, instanceIsAllDay: isAllDay)
        case .event(let event):
             return .eventSegment(originalEvent: event, segmentStartDate: startDate, segmentEndDate: endDate, segmentIsAllDay: isAllDay)
        case .recurringSessionInstance(let template, _, _, _):
            return .recurringSessionInstance(template: template, instanceStartDate: startDate, instanceEndDate: endDate, instanceIsAllDay: isAllDay)
        case .eventSegment(let originalEvent, _, _, _):
            return .eventSegment(originalEvent: originalEvent, segmentStartDate: startDate, segmentEndDate: endDate, segmentIsAllDay: isAllDay)
        }
    }

    func updateDisplayableItems() {
        Task { @MainActor in
            self.isLoading = true
            defer { self.isLoading = false }
            
            let (viewStartDate, viewEndDate) = currentViewDateRange
            // Fetch both sessions and events in a single call from dataManager (now async)
            let (fetchedSessions, fetchedEvents) = await dataManager.fetchCalendarData(from: viewStartDate, to: viewEndDate)
        
        var localAllDayItems: [DisplayableCalendarItem] = []
        var localTimedItems: [DisplayableCalendarItem] = []
        let calendar = Calendar.current
        let normalizeOccurrenceAnchor: (Date, Bool) -> Date = { date, isAllDay in
            if isAllDay {
                return calendar.startOfDay(for: date)
            }
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            return calendar.date(from: comps) ?? date
        }

        // Detached sessions override generated master occurrences with the same temporal anchor.
        let detachedOverridesByMaster: [UUID: Set<Date>] = {
            var overrides: [UUID: Set<Date>] = [:]
            for session in fetchedSessions where session.isDetached {
                guard let masterIDRaw = session.derivedFromEKEventID,
                      let masterID = UUID(uuidString: masterIDRaw) else {
                    continue
                }

                let anchor = session.occurrenceDate ?? session.startTime
                guard let anchor else { continue }
                let normalizedAnchor = normalizeOccurrenceAnchor(anchor, session.isAllDay)

                var values = overrides[masterID] ?? []
                values.insert(normalizedAnchor)
                overrides[masterID] = values
            }
            return overrides
        }()

        // Expand recurring sessions using RecurrenceService
        let expandedSessionData = RecurrenceService().expandRecurringSessions(
            fetchedSessions.filter { $0.recurrenceRuleData != nil },
                    rangeStart: viewStartDate,
                    rangeEnd: viewEndDate
                )
        
        // Process expanded recurring sessions
        for sessionData in expandedSessionData {
            // Use domain model from SessionRecurrenceData
            let masterSession = sessionData.masterSession
            let overriddenAnchors = detachedOverridesByMaster[masterSession.id] ?? []
            for instance in sessionData.instances {
                    let instanceAnchor = normalizeOccurrenceAnchor(instance.instanceStart, masterSession.isAllDay)
                    if overriddenAnchors.contains(instanceAnchor) {
                        continue
                    }
                    let item = DisplayableCalendarItem.recurringSessionInstance(
                    template: masterSession,
                        instanceStartDate: instance.instanceStart,
                        instanceEndDate: instance.instanceEnd,
                    instanceIsAllDay: masterSession.isAllDay
                    )
                splitMultiDayItem(item, into: &localAllDayItems, and: &localTimedItems)
                    }
        }
        
        // Process non-recurring sessions AND master sessions that fall within the view range
        for session in fetchedSessions.filter({ $0.recurrenceRuleData == nil }) {
                let item = DisplayableCalendarItem.session(session)
                splitMultiDayItem(item, into: &localAllDayItems, and: &localTimedItems)
        }
        
        

        // Add the filtered EKEvents to display items
        for event in fetchedEvents {
            // Filter events based on visible calendars
            let shouldShowEvent = visibleCalendarIdentifiers.contains(event.calendar.calendarIdentifier)
            
            if shouldShowEvent {
                let item = DisplayableCalendarItem.event(event)
                splitMultiDayItem(item, into: &localAllDayItems, and: &localTimedItems)
            }
        }

            let normalizedSearchText = searchText
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            self.filteredSessions = fetchedSessions.filter { session in
                let statusToken = SessionStatus(normalized: session.status ?? "")?.token
                if !showCancelledSessions && statusToken == SessionStatus.cancelled.token {
                    return false
                }

                if !filterStatuses.isEmpty {
                    let allowedStatuses = Set(filterStatuses.compactMap { SessionStatus(normalized: $0)?.token })
                    guard let statusToken else { return false }
                    if !allowedStatuses.contains(statusToken) {
                        return false
                    }
                }

                if !selectedClientFilterIDs.isEmpty {
                    guard let clientId = session.clientId,
                          selectedClientFilterIDs.contains(clientId) else {
                        return false
                    }
                }

                if !normalizedSearchText.isEmpty {
                    let haystack = [
                        session.title,
                        session.location ?? "",
                        session.notes ?? ""
                    ]
                        .joined(separator: " ")
                        .lowercased()
                    if !haystack.contains(normalizedSearchText) {
                        return false
                    }
                }

                return true
            }

            self.allDayItems = localAllDayItems.sorted { $0.startDate ?? .distantPast < $1.startDate ?? .distantPast }
            self.timedItems = localTimedItems.sorted { $0.startDate ?? .distantPast < $1.startDate ?? .distantPast }
            updateAvailableFilters()
        }
    }

    func saveSession(_ session: Session) {
        Task {
            do {
                // Check if session exists, then create or update
                let savedSession: Session
                if try await sessionsRepository.fetch(byId: session.id) != nil {
                    // Update existing session
                    savedSession = try await sessionsRepository.update(session)
                } else {
                    // Create new session
                    savedSession = try await sessionsRepository.create(session)
                }
                
                // Sync with EventKit using domain model
                Task { @MainActor in
                    eventKitService.sync(session: savedSession, unitOfWork: unitOfWork)
                }
                
                // Refresh data
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("Error saving session: \(error)")
            }
        }
    }
    
    // MARK: - Recurring Editing Support
    
    func handleDeleteFromEditor(with mode: RecurringEditMode, viewModel: NewSessionViewModel) {
        Task {
            // Delete logic using editor ViewModel or SessionDomainService?
            // The editor VM has already called its delete.
            // This handler is just for refreshing?
            // Checking CalendarView:
            // newSessionViewModel.onDelete = { mode in viewModel.handleDeleteFromEditor(...) }
            // So NewSessionViewModel delegates deletion to CalendarViewModel?
            // No, NewSessionViewModel should handle deletion internally now that it has UoW.
            // BUT let's check CalendarView again.
            // `newSessionViewModel.onDelete` logic is: `viewModel.handleDeleteFromEditor(...)`
            // So NewSessionViewModel might trigger it.
            
            // Wait, NewSessionViewModel refactor: `executeDelete` accesses `onDelete?()`.
            // If NewSessionViewModel handles deletion via UoW, then `handleDeleteFromEditor` just needs to dismiss and refresh.
            // But if `handleDeleteFromEditor` previously did the logic...
            
            // NewSessionViewModel code (viewed): `executeDelete` calls `unitOfWork.sessions.delete(...)`.
            // So logic IS in NewSessionViewModel.
            // `onDelete` is just a callback "Delete performed".
            
            self.selectedSessionInfo = nil
            self.eventToConvert = nil
            self.updateDisplayableItems()
        }
    }
    
    func handleSaveFromEditor(with mode: RecurringEditMode, viewModel: NewSessionViewModel) {
        // Refresh and dismiss
        self.selectedSessionInfo = nil
        self.eventToConvert = nil
        self.updateDisplayableItems()
    }
    
    // MARK: - Recurring Modification Execution (for drag/drop or resize)
    
    func executeRecurringModification(with mode: RecurringEditMode) {
        guard let (session, modification, originalDate) = pendingRecurringModification else { return }
        
        Task {
            do {
                _ = try await sessionModificationService.processRecurringModification(
                    session: session,
                    modification: modification,
                    mode: mode,
                    originalInstanceDate: originalDate
                )
                
                await MainActor.run {
                    self.pendingRecurringModification = nil
                    self.showingRecurringModificationDialog = false
                    self.updateDisplayableItems()
                }
            } catch {
                print("Error processing recurring modification: \(error)")
            }
        }
    }

    // MARK: - Helpers
    
    // --- Session Manipulation Methods (called from Views) ---
    
    /// Convert an EKEvent to a Session (triggers the event conversion sheet)
    func convertEventToSession(_ event: EKEvent) {
        selectedSessionInfo = nil
        eventToConvert = event
    }
    
    /// Duplicate a session
    func duplicateSession(_ session: Session) {
        Task {
            do {
                // Safely unwrap optional dates
                guard let startTime = session.startTime,
                      let endTime = session.endTime else {
                    print("[CalendarViewModel] Cannot duplicate session without start/end times")
                    return
                }
                
                // Create a duplicate with a new ID and slightly adjusted start time
                let newSession = Session(
                    id: UUID(),
                    title: session.title,
                    startTime: startTime.addingTimeInterval(3600), // +1 hour
                    endTime: endTime.addingTimeInterval(3600),
                    isAllDay: session.isAllDay,
                    location: session.location,
                    notes: session.notes,
                    status: session.status,
                    isTravel: session.isTravel,
                    isDetached: false,
                    occurrenceDate: nil,
                    clientId: session.clientId,
                    clientServiceId: session.clientServiceId,
                    addressId: session.addressId
                )
                _ = try await sessionsRepository.create(newSession)
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("[CalendarViewModel] Failed to duplicate session: \(error)")
            }
        }
    }
    
    /// Reschedule a session to a new date/time
    func rescheduleSession(with sessionId: UUID, originalInstanceDate: Date?, to newStartDate: Date, isAllDay: Bool = false) {
        Task {
            do {
                guard let session = try await sessionsRepository.fetch(byId: sessionId) else {
                    print("[CalendarViewModel] Session not found for reschedule")
                    return
                }
                
                // Safely unwrap optional dates
                guard let sessionStartTime = session.startTime,
                      let sessionEndTime = session.endTime else {
                    print("[CalendarViewModel] Cannot reschedule session without start/end times")
                    return
                }
                
                // Calculate duration
                let duration = sessionEndTime.timeIntervalSince(sessionStartTime)
                let newEndDate = newStartDate.addingTimeInterval(duration)

                if session.recurrenceRuleData != nil,
                   let occurrenceDate = originalInstanceDate {
                    await MainActor.run {
                        self.pendingRecurringModification = (
                            session: session,
                            modification: .move(newStartTime: newStartDate),
                            originalInstanceDate: occurrenceDate
                        )
                        self.showingRecurringModificationDialog = true
                    }
                    return
                }
                
                // Create updated session
                let updatedSession = Session(
                    id: session.id,
                    title: session.title,
                    startTime: newStartDate,
                    endTime: newEndDate,
                    isAllDay: isAllDay,
                    location: session.location,
                    notes: session.notes,
                    status: session.status,
                    isTravel: session.isTravel,
                    isDetached: session.isDetached,
                    occurrenceDate: session.occurrenceDate,
                    clientId: session.clientId,
                    clientServiceId: session.clientServiceId,
                    addressId: session.addressId
                )
                
                _ = try await sessionsRepository.update(updatedSession)
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("[CalendarViewModel] Failed to reschedule session: \(error)")
            }
        }
    }
    
    /// Resize a session (change end time)
    func resizeSession(_ session: Session, newEndTime: Date) {
        Task {
            do {
                let updatedSession = Session(
                    id: session.id,
                    title: session.title,
                    startTime: session.startTime,
                    endTime: newEndTime,
                    isAllDay: session.isAllDay,
                    location: session.location,
                    notes: session.notes,
                    status: session.status,
                    isTravel: session.isTravel,
                    isDetached: session.isDetached,
                    occurrenceDate: session.occurrenceDate,
                    clientId: session.clientId,
                    clientServiceId: session.clientServiceId,
                    addressId: session.addressId
                )
                
                _ = try await sessionsRepository.update(updatedSession)
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("[CalendarViewModel] Failed to resize session: \(error)")
            }
        }
    }
    
    /// Resize a session from the calendar view (drag handle interaction)
    func resizeSession(with instanceId: UUID, originalInstanceDate: Date, edge: CalendarInteractionHandler.ResizeEdge, timeDelta: TimeInterval) {
        Task {
            var session = visibleSessionInstances.first(where: { $0.id == instanceId })
            if session == nil {
                session = try? await sessionsRepository.fetch(byId: instanceId)
            }
            guard let session else {
                print("Session not found for resize: \(instanceId)")
                return
            }

            // Determine new start/end times based on edge
            var newStartTime = session.startTime ?? originalInstanceDate
            var newEndTime = session.endTime ?? originalInstanceDate.addingTimeInterval(3600)
            
            if edge == .top {
                newStartTime = newStartTime.addingTimeInterval(timeDelta)
            } else {
                newEndTime = newEndTime.addingTimeInterval(timeDelta)
            }
            
            // Check validity
            if newEndTime <= newStartTime { return }

            if session.recurrenceRuleData != nil {
                await MainActor.run {
                    self.pendingRecurringModification = (
                        session: session,
                        modification: .resize(newStartTime: newStartTime, newEndTime: newEndTime),
                        originalInstanceDate: originalInstanceDate
                    )
                    self.showingRecurringModificationDialog = true
                }
                return
            }
            
            // Create updated session
            let updatedSession = Session(
                id: session.id,
                title: session.title,
                startTime: newStartTime,
                endTime: newEndTime,
                isAllDay: session.isAllDay,
                location: session.location,
                notes: session.notes,
                status: session.status,
                isTravel: session.isTravel,
                isDetached: session.isDetached,
                occurrenceDate: session.occurrenceDate,
                clientId: session.clientId,
                clientServiceId: session.clientServiceId,
                addressId: session.addressId
            )
            
            do {
                _ = try await sessionsRepository.update(updatedSession)
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("[CalendarViewModel] Failed to resize session: \(error)")
            }
        }
    }
    
    /// Format a date as time string
    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Visible session instances for the current view
    var visibleSessionInstances: [Session] {
        return filteredSessions
    }
    
    /// Check if a calendar is visible
    func isCalendarVisible(id: String) -> Bool {
        visibleCalendarIdentifiers.contains(id)
    }
    
    /// Total billable hours from visible sessions
    var visibleBillableHours: Double {
        filteredSessions.reduce(0) { total, session in
            guard let start = session.startTime, let end = session.endTime else { return total }
            let hours = end.timeIntervalSince(start) / 3600
            return total + hours
        }
    }
    
    /// Estimated gross income from visible sessions
    var visibleGrossIncome: Double {
        filteredSessions.reduce(0) { total, session in
            guard let rate = session.assignedRate,
                  let start = session.startTime,
                  let end = session.endTime else { return total }
            let hours = end.timeIntervalSince(start) / 3600
            return total + (rate * hours)
        }
    }
    
    /// Selected sessions for bulk operations
    var selectedSessions: [Session] {
        filteredSessions.filter { bulkSelectedSessionIDs.contains($0.id) }
    }
    
    /// Selected item IDs (alias for bulk selection)
    var selectedItemIDs: Set<UUID> {
        bulkSelectedSessionIDs
    }
    
    /// Bulk delete selected sessions
    func bulkDeleteSessions() {
        Task {
            for sessionId in bulkSelectedSessionIDs {
                do {
                    try await sessionsRepository.delete(id: sessionId)
                } catch {
                    print("[CalendarViewModel] Failed to delete session \(sessionId): \(error)")
                }
            }
            await MainActor.run {
                bulkSelectedSessionIDs.removeAll()
                isBulkSelectionMode = false
                updateDisplayableItems()
            }
        }
    }

    func fetchClientService(for serviceId: UUID) async -> ClientService? {
        if let cached = clientServiceCache[serviceId] {
            return cached
        }
        
        // Use repo
        if let service = try? await clientServicesRepository.fetch(by: serviceId) {
            clientServiceCache[serviceId] = service
            return service
        }
        return nil
    }
    
    // --- Calendar Visibility ---
    
    func initializeCalendarVisibility() {
        let calendars = eventKitService.getCalendars()
        // If no preference saved, show all by default
        if UserDefaults.standard.object(forKey: "VisibleCalendars") == nil {
            visibleCalendarIdentifiers = Set(calendars.map { $0.calendarIdentifier })
        } else {
            let savedIds = UserDefaults.standard.stringArray(forKey: "VisibleCalendars") ?? []
            visibleCalendarIdentifiers = Set(savedIds)
        }
    }
    
    func toggleCalendarVisibility(id: String) {
        if visibleCalendarIdentifiers.contains(id) {
            visibleCalendarIdentifiers.remove(id)
        } else {
            visibleCalendarIdentifiers.insert(id)
        }
        saveCalendarVisibility()
        updateDisplayableItems() // Refresh to hide/show events
    }
    
    func saveCalendarVisibility() {
        UserDefaults.standard.set(Array(visibleCalendarIdentifiers), forKey: "VisibleCalendars")
    }
    
    // --- EventKit External Changes ---
    
    func handleEventKitExternalChanges() async {
        print("CalendarViewModel: Handling external EventKit changes...")
        // We need to use the service to process changes.
        // This usually triggers a refresh if things changed.
        await eventKitService.processExternalChanges(unitOfWork: unitOfWork)
        await MainActor.run {
            self.updateDisplayableItems()
        }
    }
    
    // --- Filtering Helpers ---
    
    private func updateAvailableFilters() {
        Task {
            // Update client filters based on FETCHED sessions
            // (Or we could filter based on all clients in repo, but filtering based on visible sessions is better context)
            // Actually, we want to allow filtering by ANY client, or just the ones in the view?
            // Similar to searching.
            // For now, let's just get unique client IDs from the cached sessions to populate the filter list dynamically.
            
            let clientIds = Set(filteredSessions.compactMap { $0.clientId })
            
            var clientOptions: [(label: String, value: UUID?, color: Color?)] = [("All Clients", nil, nil)]
            
            for id in clientIds {
                if let name = await fetchClientName(for: id) {
                    let color = ColorSystem.Client.color(for: id)
                    clientOptions.append((label: name, value: id, color: color))
                }
            }
            // Sort by name
            clientOptions.sort { $0.label < $1.label }
            
            await MainActor.run {
                self.availableFilterClients = clientOptions
                
                // Update statuses from sessions
                let statuses = Set(filteredSessions.compactMap { session in
                    SessionStatus(normalized: session.status ?? "")?.token
                })
                var statusOptions: [(label: String, value: String?)] = [("All Statuses", nil)]
                for status in statuses {
                    if let normalizedStatus = SessionStatus(normalized: status) {
                        statusOptions.append((label: normalizedStatus.displayName, value: status))
                    }
                }
                self.availableFilterStatuses = statusOptions
            }
        }
    }
    
    func fetchClientName(for clientId: UUID) async -> String? {
        if let name = clientNameCache[clientId] {
            return name
        }
        if let client = try? await clientsRepository.fetch(by: clientId) {
             let name = client.fullName
             clientNameCache[clientId] = name
             return name
        }
        return nil
    }
}
