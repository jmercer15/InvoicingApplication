import SwiftUI
import Core
import PersistenceModels
import EventKit
import Foundation
import SwiftData
import SharedUI
import Data
import DataInterfaces
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
    var isLoading: Bool {
        get { display.isLoading }
        set { display.isLoading = newValue }
    }
    var operationErrorMessage: String?
    /// Non-blocking nudge shown after a session is marked Completed, pointing the user at Billing
    /// Hub instead of leaving them to discover the next step on their own.
    var sessionReadyForBillingHubMessage: String?
    /// Session ids carried with the Billing Hub nudge so Open Billing Hub can focus Completed cards.
    var sessionReadyForBillingHubSessionIDs: [UUID] = []
    /// Shared-store revision. Changes from Billing Hub, imports, CloudKit, and other windows
    /// invalidate calendar projections without reaching into SwiftData's Core Data internals.
    var dataRevision: Int = 0
    /// Latest display refresh wins; cancels in-flight range/EventKit work when the view range or query updates rapidly.
    var displayItemsUpdateTask: Task<Void, Never>?
    var recurringModificationTask: Task<Void, Never>?
    var displayItemsUpdateGeneration: UInt64 = 0
    var lastDisplayItemsRefreshFingerprint: DisplayItemsRefreshFingerprint?
    /// Bumped on EventKit store changes so display refresh is not skipped when only external events changed.
    var eventStoreChangeGeneration: UInt64 = 0
    var hourHeight: CGFloat

    /// Display cache isolated from interaction/filter state to reduce observation fan-out.
    let display = CalendarDisplayState()

    // --- Travel Charge Sheet State ---
    let travelPresentation = CalendarTravelPresentation()

    var isShowingTravelChargeSheet: Bool {
        get { travelPresentation.isShowingSheet }
        set { travelPresentation.isShowingSheet = newValue }
    }
    var selectedSessionForTravel: Session? {
        get { travelPresentation.selectedSession }
        set { travelPresentation.selectedSession = newValue }
    }
    var selectedInstanceStartDateForTravel: Date? {
        get { travelPresentation.selectedInstanceStartDate }
        set { travelPresentation.selectedInstanceStartDate = newValue }
    }
    var selectedInstanceEndDateForTravel: Date? {
        get { travelPresentation.selectedInstanceEndDate }
        set { travelPresentation.selectedInstanceEndDate = newValue }
    }
    var travelChargeDaySessions: [DisplayableCalendarItem] {
        get { travelPresentation.daySessions }
        set { travelPresentation.daySessions = newValue }
    }

    func presentTravelCharge(
        for session: Session,
        instanceStart: Date,
        instanceEnd: Date
    ) {
        travelPresentation.present(
            for: session,
            instanceStart: instanceStart,
            instanceEnd: instanceEnd,
            daySessionsProvider: daySessionsForTravel(mainSession:on:)
        )
    }

    func dismissTravelChargePresentation() {
        travelPresentation.dismiss()
    }

    /// Store revision (including CloudKit HistoryExpired) — drop live Session refs before reload.
    func handleStoreRevision(_ revision: Int) {
        guard revision != dataRevision else { return }
        dataRevision = revision
        invalidateLiveSessionModelsForStoreChange()
        updateDisplayableItems()
    }

    private func invalidateLiveSessionModelsForStoreChange() {
        selectedSessionInfo = nil
        pendingRecurringModification = nil
        dismissTravelChargePresentation()
        displayItemsUpdateTask?.cancel()
        displayItemsUpdateGeneration &+= 1
        lastDisplayItemsRefreshFingerprint = nil
        display.clearLiveSessionModels()
    }

    func daySessionsForTravel(mainSession: Session, on sessionDate: Date) -> [DisplayableCalendarItem] {
        let allItems = display.allDayItems + display.timedItems
        return allItems.filter { item in
            guard let itemSession = item.underlyingSession,
                  !itemSession.isTravel,
                  itemSession.clientId == mainSession.clientId else {
                return false
            }
            guard let startDate = item.startDate else { return false }
            return Calendar.current.isDate(startDate, inSameDayAs: sessionDate)
        }
    }

    // --- ADD State for Event Conversion ---
    var eventToConvert: EKEvent? = nil

    // --- Bulk Selection Mode ---
    var isBulkSelectionMode: Bool = false
    var bulkSelectedSessionIDs: Set<UUID> = []
    var bulkOperationProgress: CalendarBulkOperationProgress?
    var bulkOperationFeedback: CalendarBulkOperationFeedback?

    var isBulkOperationInFlight: Bool {
        bulkOperationProgress != nil
    }
    
    // --- Available Calendars from EventKit ---
    var availableCalendars: [EKCalendar] = []
    
    // --- ADD Unified Item State (display cache) ---
    var filteredSessions: [Session] {
        get { display.filteredSessions }
        set { display.filteredSessions = newValue }
    }
    var sessionRegistry: [UUID: Session] {
        get { display.sessionRegistry }
        set { display.sessionRegistry = newValue }
    }
    var clientNamesCache: [UUID: String] {
        get { display.clientNamesCache }
        set { display.clientNamesCache = newValue }
    }
    var serviceNamesCache: [UUID: String] {
        get { display.serviceNamesCache }
        set { display.serviceNamesCache = newValue }
    }
    var allDayItems: [DisplayableCalendarItem] {
        get { display.allDayItems }
        set { display.allDayItems = newValue }
    }
    var timedItems: [DisplayableCalendarItem] {
        get { display.timedItems }
        set { display.timedItems = newValue }
    }
    var timedItemsByDay: [DateComponents: [DisplayableCalendarItem]] {
        get { display.timedItemsByDay }
        set { display.timedItemsByDay = newValue }
    }
    var allDayItemsByDay: [DateComponents: [DisplayableCalendarItem]] {
        get { display.allDayItemsByDay }
        set { display.allDayItemsByDay = newValue }
    }
    var combinedItemsByDay: [DateComponents: [DisplayableCalendarItem]] {
        get { display.combinedItemsByDay }
        set { display.combinedItemsByDay = newValue }
    }
    var relativePlacementsByDay: [DateComponents: [String: CalendarItemOverlapGeometry.RelativePlacement]] {
        get { display.relativePlacementsByDay }
        set { display.relativePlacementsByDay = newValue }
    }
    var allDayPositionedItems: [AllDayPositionedItem] {
        get { display.allDayPositionedItems }
        set { display.allDayPositionedItems = newValue }
    }
    var allDayStripHeight: CGFloat {
        get { display.allDayStripHeight }
        set { display.allDayStripHeight = newValue }
    }
    
    // --- Dynamic Filter Options ---
    var availableFilterStatuses: [(label: String, value: String?)] = [("All", nil)]
    var availableFilterClients: [(label: String, value: UUID?, color: Color?)] = [("All", nil, nil)]

    // --- Selected Filters (Remain as Sets) ---
    var filterStatuses: Set<String> = []
    
    // --- Calendar Visibility State ---
    var visibleCalendarIdentifiers: Set<String> = []
    @ObservationIgnored private var eventStoreObserver: NSObjectProtocol?

    // --- State for Recurring Modification Dialog ---
    var showingRecurringModificationDialog = false
    var pendingRecurringModification: (session: Session, modification: RecurringModificationType, originalInstanceDate: Date)?
    var mode: RecurringEditMode = .thisOnly

    // --- Soft-lock confirmation for edits to sessions already linked to an invoice ---
    var pendingInvoicedSessionAction: InvoicedSessionAction?

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
    private(set) var sessionActionCoordinator: CalendarSessionActionCoordinator!
    
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
        storeChangeMonitor: (any StoreChangeMonitoring)? = nil
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
            modelContainer: modelContainer,
            syncService: syncService,
            eventKitService: eventKitService,
            recurrenceRuleManager: recurrenceRuleManager,
            recurrenceRuleBuilder: RecurrenceRuleBuilder()
        )
        self.sessionActionCoordinator = CalendarSessionActionCoordinator(host: self)

        initializeCalendarVisibility()
        self.availableCalendars = eventKitService.getCalendars()

        StoreChangeMonitoringSubscription.subscribe(monitor: storeChangeMonitor) { [weak self] revision in
            self?.handleStoreRevision(revision)
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

    isolated deinit {
        displayItemsUpdateTask?.cancel()
        recurringModificationTask?.cancel()
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
            onSave: onSave,
            onError: { [weak self] error in
                self?.operationErrorMessage =
                    "Save travel charge failed: \(error.localizedDescription)"
            }
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
        display.displayableItems
    }

    func getTimedItems(for day: Date) -> [DisplayableCalendarItem] {
        display.timedItems(for: day)
    }

    func getAllDayItems(for day: Date) -> [DisplayableCalendarItem] {
        display.allDayItems(for: day)
    }

    func combinedItems(for day: Date) -> [DisplayableCalendarItem] {
        display.combinedItems(for: day)
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
    
    func handleSaveFromEditor(with _: RecurringEditMode, viewModel: NewSessionViewModel) {
        // Editor Complete→Save: nudge only on a true transition into Completed.
        if viewModel.didTransitionIntoCompletedStatus {
            setBillingHubNudge(
                message: CalendarSessionCompletionFeedback.billingHubNudgeMessage,
                sessionIDs: CalendarSessionCompletionFeedback.focusSessionIDs(
                    persistedID: viewModel.lastPersistedSessionID,
                    editingID: viewModel.sessionToEdit?.id
                )
            )
        }
        self.selectedSessionInfo = nil
        self.eventToConvert = nil
        self.updateDisplayableItems()
    }

    func setBillingHubNudge(message: String, sessionIDs: [UUID]) {
        let mergedIDs = CalendarSessionCompletionFeedback.mergedFocusSessionIDs(
            existing: sessionReadyForBillingHubSessionIDs,
            new: sessionIDs
        )
        sessionReadyForBillingHubSessionIDs = mergedIDs
        sessionReadyForBillingHubMessage = mergedIDs.count > 1
            ? CalendarSessionCompletionFeedback.billingHubNudgeMessage(
                completedCount: mergedIDs.count
            )
            : message
    }

    /// Clears banner copy only. Focus ids stay until Open Billing Hub consumes them
    /// or an explicit full clear runs.
    func clearBillingHubNudgeMessage() {
        sessionReadyForBillingHubMessage = nil
    }

    func clearBillingHubNudge() {
        sessionReadyForBillingHubMessage = nil
        sessionReadyForBillingHubSessionIDs = []
    }
    
    // MARK: - Recurring Modification Execution (for drag/drop or resize)
    
    func executeRecurringModification(with mode: RecurringEditMode) {
        guard let (session, modification, originalDate) = pendingRecurringModification else { return }
        
        recurringModificationTask?.cancel()
        recurringModificationTask = Task {
            do {
                _ = try await sessionModificationService.processRecurringModification(
                    sessionID: session.id,
                    modification: modification,
                    mode: mode,
                    originalInstanceDate: originalDate
                )

                pendingRecurringModification = nil
                showingRecurringModificationDialog = false
                updateDisplayableItems()
            } catch {
                reportOperationFailure("Apply recurring change", error: error)
            }
        }
    }

    // MARK: - Helpers
    
    // Session Manipulation actions extracted to CalendarViewModel+Actions.swift
    
    /// Format a date as time string
    func formatTime(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
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
    
    /// Bulk delete selected sessions. Sessions already linked to an invoice are skipped
    /// (soft-locked) rather than silently deleted, and reported separately.
    func bulkDeleteSessions() {
        guard !isBulkOperationInFlight else { return }
        let sessionIDs = Array(bulkSelectedSessionIDs)
        guard !sessionIDs.isEmpty else { return }
        bulkOperationFeedback = nil
        bulkOperationProgress = CalendarBulkOperationProgress(
            action: "Deleting",
            completedCount: 0,
            totalCount: sessionIDs.count
        )

        Task {
            var failureCount = 0
            var lockedCount = 0
            var skippedInvoiceIDs: [UUID] = []
            for (index, sessionId) in sessionIDs.enumerated() {
                let invoiceID = resolveSession(for: sessionId)?.invoice?.id
                do {
                    try await deleteSession(sessionId: sessionId)
                } catch is CalendarActionError {
                    lockedCount += 1
                    if let invoiceID, !skippedInvoiceIDs.contains(invoiceID) {
                        skippedInvoiceIDs.append(invoiceID)
                    }
                } catch {
                    failureCount += 1
                }
                bulkOperationProgress = CalendarBulkOperationProgress(
                    action: "Deleting",
                    completedCount: index + 1,
                    totalCount: sessionIDs.count
                )
            }
            let succeededCount = sessionIDs.count - lockedCount - failureCount
            bulkOperationProgress = nil
            bulkOperationFeedback = CalendarBulkOperationFeedback.result(
                action: "Deleted",
                succeeded: succeededCount,
                skipped: lockedCount,
                failed: failureCount,
                invoicedInvoiceIDs: skippedInvoiceIDs
            )
            bulkSelectedSessionIDs.removeAll()
            isBulkSelectionMode = false
            updateDisplayableItems()
        }
    }

    func clearBulkOperationFeedback() {
        bulkOperationFeedback = nil
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
