
// LOCAL VERSION - COMMENTED OUT TO USE PACKAGE VERSION
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
            return event.eventIdentifier // A real, saved event.
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
            let statusString = session.status ?? ""
            let isCompleted = statusString == SessionStatus.completed.rawValue
            let isCancelled = statusString == SessionStatus.cancelled.rawValue
            let currentEndDate = self.endDate ?? Date()
            let isPast = currentEndDate < Date()
            let isConfirmed = statusString == SessionStatus.scheduled.rawValue
            let isPending = statusString == SessionStatus.scheduled.rawValue

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
    @Published var isShowingNewSessionSheet: Bool
    @Published var selectedSessionInfo: (session: Session?, instanceStart: Date?, instanceEnd: Date?)?
    @Published var selectedClientFilterIDs: Set<UUID> = []
    @Published var showCancelledSessions: Bool = false
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

    // MARK: - Dependencies
    public let sessionsRepository: SessionsRepository
    public let clientsRepository: ClientsRepository
    public let clientServicesRepository: ClientServicesRepository
    private var cancellables = Set<AnyCancellable>()

    // --- New: Inject EventKitSyncService ---
    let eventKitService: EventKitSyncService
    let dataManager: CalendarDataManager // Add CalendarDataManager dependency
    
    // ModelContext is needed for EventKit external changes handling
    // EventKitSyncService.handleExternalChangesWithContext requires ModelContext to fetch and update entities
    // This is a limitation of the current EventKitSyncService implementation
    public let modelContext: ModelContext
    let addressRepository: AddressRepository
    
    // MARK: - Session Modification Service
    private let sessionModificationService: SessionModificationService
    
    // MARK: - Client/Service Name Caching
    private var clientNameCache: [UUID: String] = [:]
    private var clientServiceCache: [UUID: ClientService] = [:]

    public init(sessionsRepository: SessionsRepository,
         clientsRepository: ClientsRepository,
         clientServicesRepository: ClientServicesRepository,
         eventKitService: EventKitSyncService,
         dataManager: CalendarDataManager,
         modelContext: ModelContext, // Needed for EventKit external changes handling
         addressRepository: AddressRepository,
         selectedDate: Date = Date(),
         calendarViewType: CalendarViewType = .week,
         searchText: String = "",
         isShowingNewSessionSheet: Bool = false) {
        self.sessionsRepository = sessionsRepository
        self.clientsRepository = clientsRepository
        self.clientServicesRepository = clientServicesRepository
        self.eventKitService = eventKitService
        self.dataManager = dataManager
        self.modelContext = modelContext // Needed for EventKit external changes handling
        self.addressRepository = addressRepository
        self.selectedDate = selectedDate
        self.calendarViewType = calendarViewType
        self.searchText = searchText
        self.isShowingNewSessionSheet = isShowingNewSessionSheet
        self.hourHeight = CGFloat(UserDefaults.standard.double(forKey: "hourHeightDouble"))
        self.miniCalendarDisplayMonth = selectedDate.startOfMonth
        self.interactionHandler = CalendarInteractionHandler()
        self.filterState = CalendarFilterState()
        
        // Create SessionModificationService for use in calendar operations
        self.sessionModificationService = SessionModificationService(
            context: modelContext,
            sessionsRepository: sessionsRepository,
            addressRepository: addressRepository,
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
        // Calculate income synchronously from cached data
        // For accurate calculation, use calculateTotalGrossIncome() async method
        return 0.0 // Placeholder - use async method for actual calculation
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
            let (viewStartDate, viewEndDate) = currentViewDateRange
            // Fetch both sessions and events in a single call from dataManager (now async)
            let (fetchedSessions, fetchedEvents) = await dataManager.fetchCalendarData(from: viewStartDate, to: viewEndDate)
        
        var localAllDayItems: [DisplayableCalendarItem] = []
        var localTimedItems: [DisplayableCalendarItem] = []

        // Expand recurring sessions using RecurrenceService
        let expandedSessionData = RecurrenceService().expandRecurringSessions(
            fetchedSessions.filter { $0.recurrenceRuleData != nil },
                    rangeStart: viewStartDate,
                    rangeEnd: viewEndDate
                )
        
        // Process expanded recurring sessions
        for sessionData in expandedSessionData {
            // Use domain model from SessionRecurrenceData
            guard let masterSession = sessionData.masterSession else { continue }
            for instance in sessionData.instances {
                    let item = DisplayableCalendarItem.recurringSessionInstance(
                    template: masterSession,
                        instanceStartDate: instance.instanceStart,
                        instanceEndDate: instance.instanceEnd,
                    instanceIsAllDay: masterSession.isAllDay
                    )
                if item.isAllDay {
                        localAllDayItems.append(item)
                        } else {
                        localTimedItems.append(item)
                        }
                    }
        }
        
        // Process non-recurring sessions AND master sessions that fall within the view range
        for session in fetchedSessions.filter({ $0.recurrenceRuleData == nil }) {
                let item = DisplayableCalendarItem.session(session)
                if item.isAllDay {
                    localAllDayItems.append(item)
                } else {
                    localTimedItems.append(item)
            }
        }
        


        // Add the filtered EKEvents to display items
        for event in fetchedEvents {
            // Filter events based on visible calendars
            let shouldShowEvent = visibleCalendarIdentifiers.contains(event.calendar.calendarIdentifier)
            
            if shouldShowEvent {
                let item = DisplayableCalendarItem.event(event)
                if item.isAllDay {
                    localAllDayItems.append(item)
                } else {
                    localTimedItems.append(item)
                }
            }
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
                if let existingSession = try await sessionsRepository.fetch(byId: session.id) {
                    // Update existing session
                    savedSession = try await sessionsRepository.update(session)
                } else {
                    // Create new session
                    savedSession = try await sessionsRepository.create(session)
                }
                
                // Sync with EventKit using domain model
                Task { @MainActor in
                    eventKitService.sync(session: savedSession, modelContext: modelContext)
                }
                
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("Error saving session: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteSession(_ session: Session) {
        Task {
            // Delete from EventKit if it has an event identifier
            if !session.eventIdentifier.isEmpty {
                Task { @MainActor in
                    eventKitService.delete(syncIdentifier: session.eventIdentifier)
                }
            }
            
            do {
                try await sessionsRepository.delete(id: session.id)
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("Error deleting session: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Session Duplication
    
    func duplicateSession(_ session: Session) {
        Task {
            do {
                // Create a duplicate session with new ID
                var duplicateSession = session
                // Create new session via repository
                // Note: This creates a shallow copy - deep duplication logic would go here
                duplicateSession = Session(
                    id: UUID(),
                    title: session.title,
                    startTime: session.startTime,
                    endTime: session.endTime,
                    isAllDay: session.isAllDay,
                    location: session.location,
                    notes: session.notes,
                    status: session.status,
                    isTravel: session.isTravel,
                    clientId: session.clientId,
                    clientServiceId: session.clientServiceId,
                    addressId: session.addressId,
                    groupID: session.groupID,
                    groupedPosition: session.groupedPosition,
                    eventIdentifier: "", // New session doesn't have EventKit identifier yet
                    calendarIdentifier: session.calendarIdentifier,
                    lastModifiedDate: Date(),
                    lastSyncTag: nil,
                    recurrenceRuleData: session.recurrenceRuleData,
                    attendeesCount: session.attendeesCount,
                    derivedFromEKEventID: session.derivedFromEKEventID,
                    googleColorId: session.googleColorId,
                    sessionLatitude: session.sessionLatitude,
                    sessionLongitude: session.sessionLongitude
                )
                
                let _ = try await sessionsRepository.create(duplicateSession)
                
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                print("Error duplicating session: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Fetch client name with caching
    func fetchClientName(for clientId: UUID) async -> String? {
        // Check cache first
        if let cachedName = clientNameCache[clientId] {
            return cachedName
        }
        
        // Fetch from repository
        do {
            if let client = try await clientsRepository.fetch(by: clientId) {
                let name = client.fullName
                clientNameCache[clientId] = name
                return name
            }
        } catch {
            print("[CalendarViewModel] Failed to fetch client: \(error)")
        }
        return nil
    }
    
    /// Fetch client service with caching
    func fetchClientService(for serviceId: UUID) async -> ClientService? {
        // Check cache first
        if let cached = clientServiceCache[serviceId] {
            return cached
        }
        
        // Fetch directly from repository using the new fetch(by:) method
        do {
            if let service = try await clientServicesRepository.fetch(by: serviceId) {
                clientServiceCache[serviceId] = service
                return service
            }
        } catch {
            print("[CalendarViewModel] Failed to fetch client service: \(error)")
        }
        return nil
    }
    
    /// Fetch client service by client ID and service ID
    private func fetchClientService(clientId: UUID, serviceId: UUID) async -> ClientService? {
        do {
            let services = try await clientServicesRepository.fetch(for: clientId)
            return services.first(where: { $0.id == serviceId })
        } catch {
            print("[CalendarViewModel] Failed to fetch client services: \(error)")
            return nil
        }
    }
    
    /// Helper to fetch SessionEntity for EventKit sync operations
    /// Note: EventKitSyncService.sync(session:modelContext:) already accepts domain models
    /// This method is kept for direct entity operations that still require SessionEntity
    func fetchSessionEntity(by id: UUID) async throws -> SessionEntity {
        let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id == id })
        return try await MainActor.run {
            guard let entity = try modelContext.fetch(descriptor).first else {
                throw RepositoryError.entityNotFound
            }
            return entity
        }
    }

    func updateAvailableFilters() {
        // Update available statuses from filtered sessions
        let statuses: Set<String> = Set(filteredSessions.compactMap { $0.status }.filter { !$0.isEmpty })
        var newAvailableStatuses: [(label: String, value: String?)] = [("All", nil)]
        newAvailableStatuses.append(contentsOf: statuses.sorted().map { (label: $0.capitalized, value: $0) })
        self.availableFilterStatuses = newAvailableStatuses

        // Update available clients from visible session instances (async)
        Task {
            // Collect unique client IDs from sessions
            let clientIds = Set(visibleSessionInstances.compactMap { $0.underlyingSession?.clientId })
            
            // Fetch client names using ClientsRepository
            var uniqueClients: [(label: String, value: UUID?, color: Color?)] = [("All", nil, nil)]
            for clientId in clientIds {
                let clientName = await fetchClientName(for: clientId) ?? "Client \(clientId.uuidString.prefix(8))"
                uniqueClients.append((
                    label: clientName,
                    value: clientId,
                    color: ColorSystem.Client.color(for: clientId)
                ))
            }
            await MainActor.run {
                self.availableFilterClients = uniqueClients
            }
        }
    }

    func prepareSession(from event: EKEvent) {
        self.eventToConvert = event
        // self.isShowingNewSessionSheet = true // This is handled by .sheet watching eventToConvert
    }

    func updateSessionStatus(for session: Session, to status: String) {
        Task {
            do {
                try await sessionsRepository.updateStatus(id: session.id, status: status)
                await MainActor.run {
                    updateDisplayableItems() // Refresh items after status change
                }
            } catch {
                print("Error updating session status: \(error)")
            }
        }
    }

    // MARK: - Event Conversion and Session Management (Added for error fixes)
    
    func convertEventToSession(_ event: EKEvent) {
        prepareSession(from: event)
    }
    
    func rescheduleSession(with sessionID: String, originalInstanceDate: Date?, to newStartDate: Date, isAllDay: Bool) {
        // Find the session by ID using repository
        Task {
            guard let sessionUUID = UUID(uuidString: sessionID),
                  let session = try? await sessionsRepository.fetch(byId: sessionUUID) else {
                print("[CalendarViewModel] Could not find session with ID: \(sessionID)")
                return
            }
            
            var formModel = SessionFormModel(from: session)
            formModel.updateStartTime(newStartDate)
            formModel.isAllDay = isAllDay
            
            // Update session via repository
            var updatedSession = session
            updatedSession = Session(
                id: session.id,
                title: session.title,
                startTime: newStartDate,
                endTime: session.endTime,
                isAllDay: isAllDay,
                location: session.location,
                notes: session.notes,
                status: session.status,
                isTravel: session.isTravel,
                clientId: session.clientId,
                clientServiceId: session.clientServiceId,
                addressId: session.addressId,
                groupID: session.groupID,
                groupedPosition: session.groupedPosition,
                eventIdentifier: session.eventIdentifier,
                calendarIdentifier: session.calendarIdentifier,
                lastModifiedDate: Date(),
                lastSyncTag: session.lastSyncTag,
                recurrenceRuleData: session.recurrenceRuleData,
                attendeesCount: session.attendeesCount,
                derivedFromEKEventID: session.derivedFromEKEventID,
                googleColorId: session.googleColorId,
                sessionLatitude: session.sessionLatitude,
                sessionLongitude: session.sessionLongitude
            )
            
            do {
                let _ = try await sessionsRepository.update(updatedSession)
                
                // Sync with EventKit using domain model
                Task { @MainActor in
                    eventKitService.sync(session: updatedSession, modelContext: modelContext)
                }
                
                await MainActor.run {
                    print("[CalendarViewModel] Successfully rescheduled session \(sessionID)")
                    updateDisplayableItems()
                }
            } catch {
                print("[CalendarViewModel] Failed to reschedule session: \(error.localizedDescription)")
            }
        }
    }
    
    func handleDeleteFromEditor(with mode: RecurringEditMode, viewModel: NewSessionViewModel) {
        guard let session = viewModel.sessionToEdit else {
            print("[CalendarViewModel] No session to delete in viewModel")
            return
        }
        Task {
            do {
                try await sessionModificationService.deleteSession(session, mode: mode, originalInstanceDate: viewModel.formModel.startTime)
                await MainActor.run {
                    print("[CalendarViewModel] Successfully deleted session \(session.id)")
                    updateDisplayableItems()
                }
            } catch {
                print("[CalendarViewModel] Failed to delete session: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Month-Specific Summary Properties
    
    private func filteredSessionsForCurrentMonth() -> [Session] {
        let calendar = Calendar.current
        let startOfMonth = calendar.startOfDay(for: selectedDate.startOfMonth)
        guard let endOfMonthBase = calendar.date(byAdding: .month, value: 1, to: startOfMonth),
              let endOfMonth = calendar.date(byAdding: .day, value: -1, to: endOfMonthBase) else {
            return []
        }
        let endOfMonthDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endOfMonth)) ?? endOfMonth.addingTimeInterval(24*60*60)

        // Note: This computed property is synchronous, so it uses already-loaded session data
        // from filteredSessions, allDayItems, and timedItems rather than making async repository calls
        // For accurate date-range filtering, consider using an async method that queries the repository directly
        let allSessions = (allDayItems + timedItems).compactMap { $0.underlyingSession }

        return allSessions.filter { session in
            let isInMonth =
                (session.recurrenceRuleData == nil && (
                    (session.isAllDay == true && (session.startTime ?? Date.distantPast) >= startOfMonth && (session.startTime ?? Date.distantFuture) < endOfMonthDay)
                    ||
                    (session.isAllDay == false && (session.endTime ?? Date.distantPast) > startOfMonth && (session.startTime ?? Date.distantFuture) < endOfMonthDay)
                ))
                ||
                (session.recurrenceRuleData != nil && (session.startTime ?? Date.distantFuture) < endOfMonthDay)

            if !isInMonth { return false }
            if !selectedClientFilterIDs.isEmpty && !(selectedClientFilterIDs.contains(session.clientId ?? UUID())) { return false }
            if !filterStatuses.isEmpty && !(filterStatuses.contains(session.status ?? "")) { return false }
            if !showCancelledSessions && session.status == SessionStatus.cancelled.rawValue { return false }
            if !searchText.isEmpty && !(session.title.localizedCaseInsensitiveContains(searchText)) { return false }
            return true
        }
    }

    var monthVisibleSessionsCount: Int {
        return filteredSessionsForCurrentMonth().count
    }
    
    var monthTotalBillableHours: Double {
        return filteredSessionsForCurrentMonth().reduce(0.0) { total, session in
            guard let startTime = session.startTime, let endTime = session.endTime, endTime > startTime else {
                return total
            }
            let durationInSeconds = endTime.timeIntervalSince(startTime)
            return total + (durationInSeconds / 3600.0)
        }
    }
    
    var monthTotalGrossIncome: Double {
        // Calculate income synchronously from cached data
        // For accurate calculation, use calculateMonthTotalGrossIncome() async method
        return 0.0 // Placeholder - use async method for actual calculation
    }
    
    /// Calculate month total gross income asynchronously
    func calculateMonthTotalGrossIncome() async -> Double {
        var total: Double = 0.0
        
        for session in filteredSessionsForCurrentMonth() {
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
                // For non-hourly units, add the rate directly
                total += serviceRate
            }
        }
        
        return total
    }

    // --- Computed: All visible session instances (timed + all-day) ---
    var visibleSessionInstances: [DisplayableCalendarItem] {
        timedItems.filter { $0.isSession } + allDayItems.filter { $0.isSession }
    }

    // --- Computed: Billable hours for visible session instances ---
    var visibleBillableHours: Double {
        visibleSessionInstances.reduce(0.0) { total, item in
            guard let start = item.startDate, let end = item.endDate, end > start else { return total }
            let duration = end.timeIntervalSince(start) / 3600.0
            return total + duration
        }
    }

    // --- Computed: Gross income for visible session instances ---
    var visibleGrossIncome: Double {
        // Note: This computed property returns 0 as it's synchronous
        // For accurate calculation, use calculateVisibleGrossIncome() async method
        return 0.0
    }
    
    /// Calculate visible gross income asynchronously
    func calculateVisibleGrossIncome() async -> Double {
        var total: Double = 0.0
        
        for item in visibleSessionInstances {
            guard let session = item.underlyingSession,
                  let serviceId = session.clientServiceId else { continue }
            
            // Fetch service data
            let service = await fetchClientService(for: serviceId)
            guard let service = service, service.rate > 0 else { continue }
            
            let serviceUnit = service.unit.lowercased()
            let serviceRate = service.rate
            
            // Calculate session duration in hours for hourly rates
            if serviceUnit == "hour" {
                if let startTime = item.startDate, let endTime = item.endDate, endTime > startTime {
                    let durationInSeconds = endTime.timeIntervalSince(startTime)
                    let durationInHours = durationInSeconds / 3600.0
                    total += serviceRate * durationInHours
                }
            } else if !serviceUnit.isEmpty {
                // For non-hourly units, add the rate directly
                total += serviceRate
            }
        }
        
        return total
    }

    // Add this computed property for CalendarView selection tracking
    var selectedSessionEquatableID: String? {
        selectedSessionInfo?.session?.id.uuidString
    }

    // Add stubs for missing methods used in CalendarView
    
    private func convertRecurrenceFrequency(from rule: EKRecurrenceRule?) -> RecurrenceFrequency {
        guard let rule = rule else { return .none }
        switch rule.frequency {
        case .daily: return .daily
        case .weekly: return .weekly
        case .monthly: return .monthly
        case .yearly: return .yearly
        @unknown default: return .none
        }
    }
    
    func handleSaveFromEditor(with mode: RecurringEditMode, viewModel: NewSessionViewModel) {
        Task {
            if let session = viewModel.sessionToEdit {
                // Editing existing session
                // Use instance date from selectedSessionInfo for recurring session edits
                let instanceDate = session.recurrenceRuleData != nil ? selectedSessionInfo?.instanceStart : nil
                do {
                    let modifiedSession = try await viewModel.sessionModificationService.modifySession(
                        session,
                        with: viewModel.formModel,
                        mode: mode,
                        originalInstanceDate: instanceDate
                    )
                    print("[CalendarViewModel] Successfully saved session \(modifiedSession.id)")
                    await MainActor.run {
                        updateDisplayableItems()
                    }
                } catch {
                    print("[CalendarViewModel] Failed to save session: \(error.localizedDescription)")
                }
            } else {
                // Creating new session
                do {
                    let newSession = try await viewModel.sessionModificationService.createSession(from: viewModel.formModel)
                    print("[CalendarViewModel] Successfully created session \(newSession.id)")
                    await MainActor.run {
                        updateDisplayableItems()
                    }
                } catch {
                    print("[CalendarViewModel] Failed to create session: \(error.localizedDescription)")
                }
            }
        }
    }

    func executeRecurringModification(with mode: RecurringEditMode) {
        guard let pending = pendingRecurringModification else { return }
        
        Task {
            var formModel = SessionFormModel(from: pending.session)
            // Update the start time if it's a move, or both if it's a resize
            switch pending.modification {
            case .move(let newStartTime):
                formModel.updateStartTime(newStartTime)
            case .resize(let newStartTime, let newEndTime):
                formModel.updateStartTime(newStartTime)
                formModel.updateEndTime(newEndTime)
            }
            
            do {
                let modifiedSession = try await sessionModificationService.modifySession(
                    pending.session,
                    with: formModel,
                    mode: mode,
                    originalInstanceDate: pending.originalInstanceDate
                )
                await MainActor.run {
                    print("[CalendarViewModel] Successfully modified recurring session \(modifiedSession.id)")
                    updateDisplayableItems()
                    pendingRecurringModification = nil
                    showingRecurringModificationDialog = false
                }
            } catch {
                print("[CalendarViewModel] Failed to modify recurring session: \(error.localizedDescription)")
            }
        }
    }

    // Stub for resizeSession used in CalendarItemBlockView
    func resizeSession(with masterSessionID: String, originalInstanceDate: Date, edge: CalendarInteractionHandler.ResizeEdge, timeDelta: TimeInterval) {
        // Find the session by ID using repository
        Task {
            guard let sessionUUID = UUID(uuidString: masterSessionID),
                  let session = try? await sessionsRepository.fetch(byId: sessionUUID) else {
                print("[CalendarViewModel] Could not find session with ID: \(masterSessionID)")
                return
            }
            
            // Create form model from existing session for proper data handling
            var formModel = SessionFormModel(from: session)
            
            // Apply the specific time change based on which edge was resized
            if edge == .top {
                // Only adjust start time when resizing the top edge
                let newStart = formModel.startTime.addingTimeInterval(timeDelta)
                formModel.updateStartTime(newStart)
            } else {
                // Only adjust end time when resizing the bottom edge
                let newEnd = formModel.endTime.addingTimeInterval(timeDelta)
                formModel.updateEndTime(newEnd)
            }
            
            // Check if this is a recurring session
            let isRecurring = session.recurrenceRuleData != nil
            
            if isRecurring {
                // For recurring sessions, show the modification dialog
                await MainActor.run {
                    pendingRecurringModification = (
                        session: session,
                        modification: RecurringModificationType.resize(newStartTime: formModel.startTime, newEndTime: formModel.endTime),
                        originalInstanceDate: originalInstanceDate
                    )
                    showingRecurringModificationDialog = true
                }
            } else {
                // For non-recurring sessions, update via repository
                var updatedSession = session
                updatedSession = Session(
                    id: session.id,
                    title: session.title,
                    startTime: formModel.startTime,
                    endTime: formModel.endTime,
                    isAllDay: session.isAllDay,
                    location: session.location,
                    notes: session.notes,
                    status: session.status,
                    isTravel: session.isTravel,
                    clientId: session.clientId,
                    clientServiceId: session.clientServiceId,
                    addressId: session.addressId,
                    groupID: session.groupID,
                    groupedPosition: session.groupedPosition,
                    eventIdentifier: session.eventIdentifier,
                    calendarIdentifier: session.calendarIdentifier,
                    lastModifiedDate: Date(),
                    lastSyncTag: session.lastSyncTag,
                    recurrenceRuleData: session.recurrenceRuleData,
                    attendeesCount: session.attendeesCount,
                    derivedFromEKEventID: session.derivedFromEKEventID,
                    googleColorId: session.googleColorId,
                    sessionLatitude: session.sessionLatitude,
                    sessionLongitude: session.sessionLongitude
                )
                
                do {
                    let _ = try await sessionsRepository.update(updatedSession)
                    
                    // Sync with EventKit using domain model
                    Task { @MainActor in
                        eventKitService.sync(session: updatedSession, modelContext: modelContext)
                    }
                    
                    await MainActor.run {
                        print("[CalendarViewModel] Successfully resized session \(masterSessionID)")
                        updateDisplayableItems()
                    }
                } catch {
                    print("[CalendarViewModel] Failed to resize session: \(error.localizedDescription)")
                }
            }
        }
    }

    // Stub for formatTime used in CalendarItemBlockView
    func formatTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Calendar Visibility Management
    
    // MARK: - Bulk Operations
    @Published var isBulkSelectionMode: Bool = false
    @Published var selectedItemIDs: Set<String> = []
    
    /// Toggle bulk selection mode
    func toggleBulkSelectionMode() {
        isBulkSelectionMode.toggle()
        if !isBulkSelectionMode {
            selectedItemIDs.removeAll()
        }
    }
    
    /// Toggle selection of a specific item
    func toggleItemSelection(_ itemID: String) {
        if selectedItemIDs.contains(itemID) {
            selectedItemIDs.remove(itemID)
        } else {
            selectedItemIDs.insert(itemID)
        }
    }
    
    /// Select all items
    func selectAllItems() {
        selectedItemIDs = Set(displayableItems.map { $0.id })
    }
    
    /// Deselect all items
    func deselectAllItems() {
        selectedItemIDs.removeAll()
    }
    
    /// Get selected sessions (filter out events since we can't modify them)
    var selectedSessions: [Session] {
        return displayableItems.compactMap { item in
            guard selectedItemIDs.contains(item.id) else { return nil }
            switch item {
            case .session(let session):
                return session
            case .recurringSessionInstance(let template, _, _, _):
                return template
            case .event, .eventSegment:
                return nil // Can't modify external events
            }
        }
    }
    
    /// Bulk status change
    func bulkChangeStatus(to newStatus: String) {
        let sessions = selectedSessions
        Task {
            do {
                // Update all sessions in parallel
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for session in sessions {
                        group.addTask {
                            try await self.sessionsRepository.updateStatus(id: session.id, status: newStatus)
                        }
                    }
                    try await group.waitForAll()
                }
                
                await MainActor.run {
                    updateDisplayableItems()
                    // Exit bulk selection mode
                    isBulkSelectionMode = false
                    selectedItemIDs.removeAll()
                }
            } catch {
                print("[CalendarViewModel] Failed to bulk change status: \(error.localizedDescription)")
            }
        }
    }
    
    /// Bulk delete sessions
    func bulkDeleteSessions() {
        let sessions = selectedSessions
        Task {
            do {
                // Delete all sessions in parallel
                try await withThrowingTaskGroup(of: Void.self) { group in
                    for session in sessions {
                        group.addTask {
                            try await self.sessionsRepository.delete(id: session.id)
                        }
                    }
                    try await group.waitForAll()
                }
                
                await MainActor.run {
                    updateDisplayableItems()
                    // Exit bulk selection mode
                    isBulkSelectionMode = false
                    selectedItemIDs.removeAll()
                }
            } catch {
                print("[CalendarViewModel] Failed to bulk delete sessions: \(error.localizedDescription)")
            }
        }
    }
    
    /// Toggle the visibility of a specific calendar
    func toggleCalendarVisibility(calendarIdentifier: String) {
        if visibleCalendarIdentifiers.contains(calendarIdentifier) {
            visibleCalendarIdentifiers.remove(calendarIdentifier)
        } else {
            visibleCalendarIdentifiers.insert(calendarIdentifier)
        }
        
        // Trigger UI update
        objectWillChange.send()
        updateDisplayableItems()
    }
    
    /// Get monitored calendars for visibility toggling
    var availableCalendars: [EKCalendar] {
        // Only show calendars that are being monitored/synced
        return eventKitService.availableCalendars.filter { calendar in
            eventKitService.monitoredCalendarIdentifiers.contains(calendar.calendarIdentifier)
        }
    }
    
    /// Check if a calendar is currently visible
    func isCalendarVisible(calendarIdentifier: String) -> Bool {
        return visibleCalendarIdentifiers.contains(calendarIdentifier)
    }
    
    /// Initialize calendar visibility from EventKitSyncService
    func initializeCalendarVisibility() {
        // Only work with monitored calendars
        let monitoredCalendars = eventKitService.availableCalendars.filter { calendar in
            eventKitService.monitoredCalendarIdentifiers.contains(calendar.calendarIdentifier)
        }
        
        // Start with all monitored calendars visible
        visibleCalendarIdentifiers = Set(monitoredCalendars.map { $0.calendarIdentifier })
        
        // Initialization complete
    }

    // MARK: - EventKit External Changes Handling
    private func handleEventKitExternalChanges() async {
        print("[CalendarViewModel] Handling EventKit external changes")
        guard eventKitService.accessGranted, eventKitService.syncEnabled else { 
            print("[CalendarViewModel] Skipping external changes - access not granted or sync disabled")
            return 
        }
        
        await MainActor.run {
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .year, value: -1, to: Date())!
            let end = calendar.date(byAdding: .year, value: 1, to: Date())!
            
            // Fetch all events from monitored calendars
            let remoteEvents = eventKitService.fetchEvents(start: start, end: end)
            print("[CalendarViewModel] Fetched \(remoteEvents.count) remote events")
            var remoteEventsById = [String: EKEvent]()
            for event in remoteEvents {
                if let id = event.eventIdentifier, remoteEventsById[id] == nil {
                    remoteEventsById[id] = event
                }
            }
            
            // Fetch all local sessions with eventIdentifier in this range using FetchDescriptor
            let fetchDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate {
                $0.eventIdentifier != ""
            })
            
            // Filter by date range in Swift
            let localSessions = ((try? modelContext.fetch(fetchDescriptor)) ?? []).filter {
                ($0.startTime ?? Date.distantPast) >= start &&
                ($0.endTime ?? Date.distantFuture) <= end
            }
            print("[CalendarViewModel] Fetched \(localSessions.count) local sessions")
            var localSessionsById: [String: SessionEntity] = [:]
            for session in localSessions {
                if !session.eventIdentifier.isEmpty {
                    localSessionsById[session.eventIdentifier] = session
                }
            }
            
            // 1. Update local sessions from remote events (do not create new sessions)
            var updatedCount = 0
            for (eventId, remoteEvent) in remoteEventsById {
                if let localSession = localSessionsById[eventId] {
                    let localLastModified = localSession.lastModifiedDate ?? Date.distantPast
                    let remoteLastModified = remoteEvent.lastModifiedDate ?? Date.distantPast
                    let lastSyncTag = localSession.lastSyncTag.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date.distantPast
                    let localChanged = localLastModified > lastSyncTag
                    let remoteChanged = remoteLastModified > lastSyncTag
                    if remoteChanged && (!localChanged || remoteLastModified > localLastModified) {
                        // Remote is newer, update local
                        eventKitService.updateSessionFromRemote(session: localSession, remoteEvent: remoteEvent, modelContext: modelContext)
                        updatedCount += 1
                    }
                }
            }
            print("[CalendarViewModel] Updated \(updatedCount) local sessions from remote events")
            
            // 2. Handle local sessions whose eventIdentifier is not found in remote events
            // NOTE: We should NOT delete local sessions just because the remote event is missing.
            // Sessions are enhanced EKEvents with additional application functionality.
            // The remote event might not exist yet, be outside the fetch range, or the sync hasn't happened.
            let remoteEventIds = Set(remoteEventsById.keys)
            var missingRemoteCount = 0
            for (localId, localSession) in localSessionsById {
                if !remoteEventIds.contains(localId) {
                    // Remote event not found - this could mean:
                    // 1. Event was deleted remotely (but we should preserve local session)
                    // 2. Event exists outside current fetch range
                    // 3. Event hasn't been synced yet
                    // 4. Event is in a different calendar
                    // 
                    // For now, we'll preserve the local session and log the situation
                    missingRemoteCount += 1
                    print("[CalendarViewModel] Local session '\(localSession.title)' has no matching remote event (eventIdentifier: \(localId)). Preserving local session.")
                }
            }
            if missingRemoteCount > 0 {
                print("[CalendarViewModel] Found \(missingRemoteCount) local sessions without matching remote events. All preserved.")
            }
            
            // Save context if there are changes
            do {
                try modelContext.save()
                print("[CalendarViewModel] Successfully saved context after external changes")
                
                // Update the displayable items to reflect the changes
                updateDisplayableItems()
            } catch {
                print("[CalendarViewModel] Error saving after pull: \(error.localizedDescription)")
            }
        }
    }
    
}

// Ensure Date extension for chunked exists (add if needed, e.g., in Utilities)

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}


// Helper extension for end of day/month for fetching
extension Date {
    var endOfWeekPlusOneDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: self.endOfWeek) ?? self.endOfWeek
    }
    var endOfMonthPlusOneDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: self.endOfMonth) ?? self.endOfMonth
    }
}

private extension Calendar {
    func endOfDay(for date: Date) -> Date {
        let startOfDay = self.startOfDay(for: date)
        // Add one day and subtract one second to get 23:59:59
        return self.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
    }
}
