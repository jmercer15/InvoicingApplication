import SwiftUI
import Core
import EventKit
import Foundation
import SwiftData
import SharedUI
import Data
import Observation

// DisplayableCalendarItem extracted to Models/DisplayableCalendarItem.swift

// MARK: - CalendarViewModel Class
@Observable
@MainActor
public class CalendarViewModel {
    // MARK: - Published State
    var selectedDate: Date
    var calendarViewType: CalendarViewType
    var searchText: String
    var workspaceShowDatePicker = false
    var selectedSessionInfo: (session: Session?, instanceStart: Date?, instanceEnd: Date?)?
    var selectedClientFilterIDs: Set<UUID> = []
    var showCancelledSessions: Bool = false
    var isLoading: Bool = false
    var operationErrorMessage: String?
    /// Shared-store revision. Changes from Billing Hub, imports, CloudKit, and other windows
    /// invalidate calendar projections without reaching into SwiftData's Core Data internals.
    var dataRevision: Int = 0
    /// Latest display refresh wins; cancels in-flight range/EventKit work when the view range or query updates rapidly.
    var displayItemsUpdateTask: Task<Void, Never>?
    var displayItemsUpdateGeneration: UInt64 = 0
    var lastDisplayItemsRefreshFingerprint: DisplayItemsRefreshFingerprint?
    /// Bumped on EventKit store changes so display refresh is not skipped when only external events changed.
    var eventStoreChangeGeneration: UInt64 = 0
    var hourHeight: CGFloat
    var filteredSessions: [Session] = []
    /// Sessions seen from the last `@Query`-driven calendar pipeline plus any single-row resolves (Billing Hub deep link, off-window ops). Prefer this over ad-hoc fetches when an id should already be materialized.
    var sessionRegistry: [UUID: Session] = [:]
    var clientNamesCache: [UUID: String] = [:]
    var serviceNamesCache: [UUID: String] = [:]

    // --- Travel Charge Sheet State ---
    var isShowingTravelChargeSheet: Bool = false
    var selectedSessionForTravel: Session?
    var selectedInstanceStartDateForTravel: Date?
    var selectedInstanceEndDateForTravel: Date?

    // --- ADD State for Event Conversion ---
    var eventToConvert: EKEvent? = nil

    // --- Bulk Selection Mode ---
    var isBulkSelectionMode: Bool = false
    var bulkSelectedSessionIDs: Set<UUID> = []
    
    // --- Available Calendars from EventKit ---
    var availableCalendars: [EKCalendar] = []
    
    // --- ADD Unified Item State ---
    var allDayItems: [DisplayableCalendarItem] = []
    var timedItems: [DisplayableCalendarItem] = []
    
    // --- ADD Pre-grouped Item Caches ---
    var timedItemsByDay: [DateComponents: [DisplayableCalendarItem]] = [:]
    var allDayItemsByDay: [DateComponents: [DisplayableCalendarItem]] = [:]
    /// Pre-merged timed + all-day items per day (sorted once per refresh).
    var combinedItemsByDay: [DateComponents: [DisplayableCalendarItem]] = [:]
    
    // --- ADD Pre-calculated Relative Placements ---
    var relativePlacementsByDay: [DateComponents: [String: CalendarItemOverlapGeometry.RelativePlacement]] = [:]
    
    // --- ADD All-Day Layout Caches ---
    var allDayPositionedItems: [AllDayPositionedItem] = []
    var allDayStripHeight: CGFloat = 0
    
    // --- Dynamic Filter Options ---
    var availableFilterStatuses: [(label: String, value: String?)] = [("All", nil)]
    var availableFilterClients: [(label: String, value: UUID?, color: Color?)] = [("All", nil, nil)]

    // --- Selected Filters (Remain as Sets) ---
    var filterStatuses: Set<String> = []
    
    // --- Calendar Visibility State ---
    var visibleCalendarIdentifiers: Set<String> = []
    @ObservationIgnored nonisolated(unsafe) private var eventStoreObserver: NSObjectProtocol?

    // --- State for Recurring Modification Dialog ---
    var showingRecurringModificationDialog = false
    var pendingRecurringModification: (session: Session, modification: RecurringModificationType, originalInstanceDate: Date)?
    var mode: RecurringEditMode = .thisOnly

    var recurringModificationModes: [RecurringEditMode] {
        pendingRecurringModification == nil ? [] : [.thisOnly, .thisAndFuture, .all]
    }

    var recommendedRecurringModificationMode: RecurringEditMode? {
        recurringModificationModes.contains(.thisAndFuture) ? .thisAndFuture : recurringModificationModes.first
    }

    // MARK: - Dependencies
    let modelContext: ModelContext
    let syncService: SyncService
    let eventKitService: any CalendarEventService
    let recurrenceRuleManager: Core.RecurrenceRuleManager
    let sessionResolver: any CalendarSessionResolving

    // MARK: - Data Manager
    let dataManager: CalendarDataManager
    let workflow: CalendarWorkflowActor
    
    // MARK: - Session Modification Service
    let sessionModificationService: SessionModificationService
    
    public init(
        modelContext: ModelContext,
        modelContainer: ModelContainer,
        syncService: SyncService,
        eventKitService: any CalendarEventService,
        recurrenceRuleManager: Core.RecurrenceRuleManager,
        selectedDate: Date = Date(),
        calendarViewType: CalendarViewType = .week,
        searchText: String = "",
        sessionResolver: (any CalendarSessionResolving)? = nil,
        storeChangeMonitor: SwiftDataStoreChangeMonitor? = nil
    ) {
        self.modelContext = modelContext
        self.syncService = syncService
        self.eventKitService = eventKitService
        self.recurrenceRuleManager = recurrenceRuleManager
        self.sessionResolver = sessionResolver ?? SwiftDataCalendarSessionResolver(modelContext: modelContext)
        self.selectedDate = selectedDate
        self.calendarViewType = calendarViewType
        self.searchText = searchText
        self.hourHeight = CGFloat(UserDefaults.standard.double(forKey: "hourHeightDouble"))

        self.dataManager = CalendarDataManager(eventKitService: eventKitService)
        self.workflow = CalendarWorkflowActor(modelContainer: modelContainer)

        self.sessionModificationService = SessionModificationService(
            modelContext: modelContext,
            syncService: syncService,
            eventKitService: eventKitService,
            recurrenceRuleManager: recurrenceRuleManager,
            recurrenceRuleBuilder: RecurrenceRuleBuilder()
        )

        initializeCalendarVisibility()
        self.availableCalendars = eventKitService.getCalendars()

        SwiftDataStoreChangeMonitor.subscribeToStoreChanges(monitor: storeChangeMonitor) { [weak self] revision in
            self?.dataRevision = revision
        }

        self.eventStoreObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.eventStoreChangeGeneration &+= 1
                self.availableCalendars = self.eventKitService.getCalendars()
                self.updateDisplayableItems()
            }
        }
    }

    deinit {
        if let observer = eventStoreObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func makeNewSessionViewModel(session: Session?, instanceDate: Date?, instanceEndDate: Date?) -> NewSessionViewModel {
        NewSessionViewModel(
            modelContext: modelContext,
            sessionModificationService: sessionModificationService,
            recurrenceRuleManager: recurrenceRuleManager,
            session: session,
            instanceDate: instanceDate,
            instanceEndDate: instanceEndDate
        )
    }

    func makeNewSessionViewModel(from event: EKEvent) -> NewSessionViewModel {
        NewSessionViewModel(
            modelContext: modelContext,
            sessionModificationService: sessionModificationService,
            recurrenceRuleManager: recurrenceRuleManager,
            from: event
        )
    }

    func makeTravelChargeViewModel(
        mainSession: Session,
        daySessions: [DisplayableCalendarItem],
        geocodingService: any Core.GeocodingServiceProtocol,
        onSave: @escaping () -> Void
    ) -> TravelChargeViewModel {
        TravelChargeViewModel(
            modelContext: modelContext,
            geocodingService: geocodingService,
            mainSession: mainSession,
            daySessions: daySessions,
            onSave: onSave
        )
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

    // --- ADDED: Computed property for all displayable items ---
    var displayableItems: [DisplayableCalendarItem] {
        return allDayItems + timedItems
    }

    // --- ADDED: Helper functions to get items for a specific day ---
    func getTimedItems(for day: Date) -> [DisplayableCalendarItem] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return timedItemsByDay[components] ?? []
    }

    func getAllDayItems(for day: Date) -> [DisplayableCalendarItem] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return allDayItemsByDay[components] ?? []
    }

    func combinedItems(for day: Date) -> [DisplayableCalendarItem] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: day)
        return combinedItemsByDay[components] ?? []
    }

    func isSelectedDay(_ day: Date) -> Bool {
        Calendar.current.isDate(day, inSameDayAs: selectedDate)
    }

    // Event Fetching and Processing moved to CalendarViewModel+Fetching.swift

    // MARK: - Recurring Editing Support
    
    func handleDeleteFromEditor(with _: RecurringEditMode, viewModel _: NewSessionViewModel) {
        Task {
            // Deletion is handled in the editor flow; this callback only dismisses and refreshes.
            self.selectedSessionInfo = nil
            self.eventToConvert = nil
            self.updateDisplayableItems()
        }
    }
    
    func handleSaveFromEditor(with _: RecurringEditMode, viewModel _: NewSessionViewModel) {
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
                reportOperationFailure("Apply recurring change", error: error)
            }
        }
    }

    // MARK: - Helpers
    
    // Session Manipulation actions extracted to CalendarViewModel+Actions.swift
    
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Format a date as time string
    func formatTime(_ date: Date) -> String {
        return Self.timeFormatter.string(from: date)
    }
    
    /// Check if a calendar is visible
    func isCalendarVisible(id: String) -> Bool {
        visibleCalendarIdentifiers.contains(id)
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
            var failureCount = 0
            for sessionId in bulkSelectedSessionIDs {
                do {
                    try await deleteSession(sessionId: sessionId)
                } catch {
                    failureCount += 1
                }
            }
            await MainActor.run {
                bulkSelectedSessionIDs.removeAll()
                isBulkSelectionMode = false
                if failureCount > 0 {
                    operationErrorMessage = "Bulk delete failed for \(failureCount) session(s)."
                }
                updateDisplayableItems()
            }
        }
    }

    func serviceName(for serviceId: UUID) -> String? {
        serviceNamesCache[serviceId]
    }
    
    // Visibility implementation moved to CalendarViewModel+Visibility.swift
    
    // --- Filtering Helpers ---
    
    func updateAvailableFilters() {
        var latestClientNames: [UUID: String] = [:]

        for session in filteredSessions {
            if let clientID = session.clientId,
               let clientName = session.client?.fullName,
               !clientName.isEmpty {
                latestClientNames[clientID] = clientName
            }
        }

        var clientOptions: [(label: String, value: UUID?, color: Color?)] = [("All Clients", nil, nil)]
        for (id, name) in latestClientNames {
            guard !name.isEmpty else { continue }
            let color = ColorSystem.Client.color(for: id)
            clientOptions.append((label: name, value: id, color: color))
        }
        clientOptions.sort { $0.label < $1.label }
        self.availableFilterClients = clientOptions

        let statuses = Set(filteredSessions.compactMap { session in
            Core.SessionStatus(normalized: session.status?.rawValue ?? "")?.token
        })
        var statusOptions: [(label: String, value: String?)] = [("All Statuses", nil)]
        for status in statuses {
            if let normalizedStatus = Core.SessionStatus(normalized: status) {
                statusOptions.append((label: normalizedStatus.displayName, value: status))
            }
        }
        self.availableFilterStatuses = statusOptions
    }

    func clientName(for clientId: UUID) -> String? {
        clientNamesCache[clientId]
    }

    // Additional actions extracted to CalendarViewModel+Actions.swift

}

@MainActor
public protocol CalendarSessionResolving {
    func fetchSession(id: UUID) throws -> Session?
}

@MainActor
public struct SwiftDataCalendarSessionResolver: CalendarSessionResolving {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchSession(id: UUID) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
