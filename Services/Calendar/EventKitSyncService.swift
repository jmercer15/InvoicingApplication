import Foundation
import EventKit
import Combine
import SwiftUI
import SwiftData // Import SwiftData

// MARK: - EventKitSyncService
/// EventKitSyncService is a singleton responsible for all EventKit operations and state.
@MainActor
final class EventKitSyncService: ObservableObject {
    static let shared = EventKitSyncService()
    private let eventStore = EKEventStore()
    private var isSyncing = false

    // MARK: - Published Properties for Settings
    @Published public private(set) var accessGranted: Bool = false
    @Published public private(set) var availableCalendars: [EKCalendar] = []
    @AppStorage("selectedCalendarIdentifier") public var selectedCalendarIdentifier: String = ""
    @AppStorage("monitoredCalendarIdentifiers") private var monitoredCalendarIdentifiersRaw: String = ""
    public var monitoredCalendarIdentifiers: Set<String> {
        get { Set(monitoredCalendarIdentifiersRaw.split(separator: ",").map(String.init)) }
        set { monitoredCalendarIdentifiersRaw = newValue.joined(separator: ",") }
    }
    @AppStorage("syncEnabled") public var syncEnabled: Bool = true
    @AppStorage("syncDirection") private var syncDirectionRaw: String = CalendarPreferences.SyncDirection.bidirectional.rawValue
    public var syncDirection: CalendarPreferences.SyncDirection {
        get { CalendarPreferences.SyncDirection(rawValue: syncDirectionRaw) ?? .bidirectional }
        set { syncDirectionRaw = newValue.rawValue }
    }
    @AppStorage("conflictResolutionPolicy") private var conflictResolutionPolicyRaw: String = CalendarPreferences.ConflictResolutionPolicy.prompt.rawValue
    public var conflictResolutionPolicy: CalendarPreferences.ConflictResolutionPolicy {
        get { CalendarPreferences.ConflictResolutionPolicy(rawValue: conflictResolutionPolicyRaw) ?? .prompt }
        set { conflictResolutionPolicyRaw = newValue.rawValue }
    }
    @AppStorage("syncGoogleColors") public var syncGoogleColors: Bool = true
    @AppStorage("autoResolveRecurringConflicts") public var autoResolveRecurringConflicts: Bool = false

    @Published var error: Error?
    @Published var isLoadingCalendars: Bool = false
    
    // MARK: - Sync Status
    @Published public private(set) var syncStatus: SyncStatus = .idle
    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var syncProgress: Double = 0.0
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case completed
        case failed(Error)
        case noAccess
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.completed, .completed), (.noAccess, .noAccess):
                return true
            case (.failed, .failed):
                return true // We'll consider all failures equal for UI purposes
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .idle: return "Idle"
            case .syncing: return "Syncing..."
            case .completed: return "Synced"
            case .failed(let error): return "Failed: \(error.localizedDescription)"
            case .noAccess: return "No Access"
            }
        }
        
        var icon: String {
            switch self {
            case .idle: return "circle"
            case .syncing: return "arrow.triangle.2.circlepath"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "exclamationmark.circle.fill"
            case .noAccess: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .idle: return .gray
            case .syncing: return .blue
            case .completed: return .green
            case .failed: return .red
            case .noAccess: return .orange
            }
        }
    }

    // --- Conflict Prompt System ---
    @Published var pendingConflict: ConflictPrompt? = nil
    struct ConflictPrompt {
        let session: SessionEntity
        let remoteEvent: EKEvent?
        let isRecurring: Bool
        let completion: (ConflictResolutionChoice, ModelContext) -> Void
    }
    enum ConflictResolutionChoice {
        case preferApp
        case preferCalendar
        case skip
    }
    func resolveConflict(_ choice: ConflictResolutionChoice, modelContext: ModelContext) {
        // This method should be called by the UI after user makes a choice
        guard let prompt = pendingConflict else { return }
        pendingConflict = nil
        switch choice {
        case .preferApp:
            // Continue with push (do nothing, let sync continue)
            break
        case .preferCalendar:
            if let remote = prompt.remoteEvent {
                self.updateSessionFromRemote(session: prompt.session, remoteEvent: remote, modelContext: modelContext)
            }
            return
        case .skip:
            return
        }
        // After resolving, continue sync if needed (could be extended)
    }
    // --- End Conflict Prompt System ---

    var selectedCalendar: EKCalendar? {
        guard !selectedCalendarIdentifier.isEmpty else { return nil }
        return availableCalendars.first { $0.calendarIdentifier == selectedCalendarIdentifier }
            ?? eventStore.calendar(withIdentifier: selectedCalendarIdentifier)
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("[EventKitSyncService] Initializing EventKitSyncService...")
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: eventStore)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                print("[SyncService] Event store changed, triggering refresh.")
                Task { await self?.handleExternalChanges() }
            }
            .store(in: &cancellables)
        checkInitialAccessAndFetchCalendars()
        print("[EventKitSyncService] EventKitSyncService initialization complete")
        
        // Set initial sync status based on access
        if self.accessGranted {
            self.syncStatus = .idle
        } else {
            self.syncStatus = .noAccess
        }
    }

    func checkInitialAccessAndFetchCalendars() {
        let status = EKEventStore.authorizationStatus(for: .event)
        print("[EventKitSyncService] Initial authorization status: \(status)")
        let isAuthorized: Bool
        if #available(macOS 14.0, *) {
            isAuthorized = (status == .fullAccess || status == .writeOnly)
        } else {
            isAuthorized = (status == .authorized)
        }
        print("[EventKitSyncService] Is authorized: \(isAuthorized)")
        self.accessGranted = isAuthorized
        if isAuthorized && self.syncEnabled {
            Task { await self.fetchAvailableCalendars() }
            self.syncStatus = .idle
        } else {
            self.availableCalendars = []
            self.syncStatus = isAuthorized ? .idle : .noAccess
        }
    }

    /// Request access to the user's calendars. Calls completion on main thread.
    func requestAccess() async -> Bool {
        print("[EventKitSyncService] Requesting calendar access...")
        return await withCheckedContinuation { continuation in
            if #available(macOS 14.0, *) {
                print("[EventKitSyncService] Using requestFullAccessToEvents (macOS 14.0+)")
                eventStore.requestFullAccessToEvents { [weak self] granted, error in
                    print("[EventKitSyncService] Full access request result: granted=\(granted), error=\(error?.localizedDescription ?? "none")")
                    Task { @MainActor in
                        if granted {
                            self?.accessGranted = true
                            if self?.syncEnabled == true {
                                await self?.fetchAvailableCalendars()
                            }
                        } else {
                            self?.accessGranted = false
                            self?.availableCalendars = []
                        }
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                print("[EventKitSyncService] Using requestAccess(to: .event) (pre-macOS 14.0)")
                eventStore.requestAccess(to: .event) { [weak self] granted, error in
                    print("[EventKitSyncService] Basic access request result: granted=\(granted), error=\(error?.localizedDescription ?? "none")")
                    Task { @MainActor in
                        if granted {
                            self?.accessGranted = true
                            if self?.syncEnabled == true {
                                await self?.fetchAvailableCalendars()
                            }
                        } else {
                            self?.accessGranted = false
                            self?.availableCalendars = []
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    /// Fetch available writable calendars. Updates availableCalendars on main thread.
    func fetchAvailableCalendars() async {
        print("[EventKitSyncService] Fetching available calendars...")
        let allCalendars = eventStore.calendars(for: .event)
        print("[EventKitSyncService] Total calendars found: \(allCalendars.count)")
        let calendars = allCalendars.filter { $0.allowsContentModifications }
        print("[EventKitSyncService] Writable calendars found: \(calendars.count)")
        
        await MainActor.run {
            self.availableCalendars = calendars
            if calendars.isEmpty {
                print("[EventKitSyncService] No writable calendars found")
                self.error = NSError(domain: "EventKitSyncService", code: 100, userInfo: [NSLocalizedDescriptionKey: "No writable calendars found. Please check your calendar accounts and permissions."])
            } else {
                print("[EventKitSyncService] Successfully loaded \(calendars.count) writable calendars")
                self.error = nil
            }
        }
    }

    /// Create a new calendar with the given title and color. Calls completion on main thread.
    func createCalendar(title: String, color: CGColor?) async throws {
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = title
        if let color = color {
            newCalendar.cgColor = color
        }
        newCalendar.source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first { [.local, .calDAV, .exchange, .subscribed, .mobileMe].contains($0.sourceType) }
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            await fetchAvailableCalendars()
        } catch {
            throw error
        }
    }

    /// Synchronize a SessionEntity with EventKit, respecting sync direction and conflict resolution policy.
    func sync(session: SessionEntity, modelContext: ModelContext) {
        // Update sync status to syncing
        self.syncStatus = .syncing
        self.syncProgress = 0.0
        
        // Respect sync direction: only push if .appToCalendar or .bidirectional
        guard syncEnabled else {
            self.error = NSError(domain: "EventKitSyncService", code: 101, userInfo: [NSLocalizedDescriptionKey: "Sync is disabled or session context is missing."])
            self.syncStatus = .failed(self.error!)
            return
        }
        if syncDirection == .calendarToApp {
            self.error = NSError(domain: "EventKitSyncService", code: 102, userInfo: [NSLocalizedDescriptionKey: "Sync direction is set to 'Calendar to App'. Local changes will not be pushed."])
            self.syncStatus = .failed(self.error!)
            return // Do not push if only pulling
        }
        guard let calendar = selectedCalendar else {
            self.error = NSError(domain: "EventKitSyncService", code: 103, userInfo: [NSLocalizedDescriptionKey: "No calendar selected. Please choose a writable calendar in Settings."])
            self.syncStatus = .failed(self.error!)
            return
        }
        guard calendar.allowsContentModifications else {
            self.error = NSError(domain: "EventKitSyncService", code: 104, userInfo: [NSLocalizedDescriptionKey: "The selected calendar is read-only. Please choose a different calendar."])
            self.syncStatus = .failed(self.error!)
            return
        }
        
        // Run the remainder on MainActor as an async task
        Task { @MainActor in
            // Fetch the remote event if it exists
            var remoteEvent: EKEvent? = nil
            if !session.eventIdentifier.isEmpty {
                remoteEvent = self.eventStore.event(withIdentifier: session.eventIdentifier)
            }
            let localLastModified = session.lastModifiedDate ?? Date.distantPast
            let remoteLastModified = remoteEvent?.lastModifiedDate ?? Date.distantPast
            let lastSyncTag = session.lastSyncTag.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date.distantPast
            let localChanged = localLastModified > lastSyncTag
            let remoteChanged = remoteLastModified > lastSyncTag
            let isRecurring = session.recurrenceRuleData != nil || (remoteEvent?.recurrenceRules?.isEmpty == false)

            if self.syncDirection == .bidirectional && localChanged && remoteChanged {
                if isRecurring {
                    // --- FULL RECURRING INSTANCE MERGE LOGIC ---
                    let localExceptions = await self.extractLocalExceptions(session: session, modelContext: modelContext)
                    let remoteExceptions = self.extractRemoteExceptions(remoteEvent: remoteEvent)
                    let mergedExceptions = self.mergeExceptions(local: localExceptions, remote: remoteExceptions, policy: self.conflictResolutionPolicy, prompt: { date, local, remote in
                        // If policy is prompt, queue a conflict prompt for this instance
                        self.pendingConflict = ConflictPrompt(
                            session: session,
                            remoteEvent: remoteEvent,
                            isRecurring: true,
                            completion: { [weak self] choice, modelContext in
                                // For per-instance, apply the user's choice
                                self?.applyInstanceMergeChoice(session: session, remoteEvent: remoteEvent, date: date, choice: choice, local: local, remote: remote, modelContext: modelContext)
                            }
                        )
                    }, modelContext: modelContext)
                    // Apply merged exceptions to local and/or remote as needed
                    self.applyMergedExceptions(session: session, remoteEvent: remoteEvent, merged: mergedExceptions, modelContext: modelContext)
                    // Continue with series-level conflict resolution as before
                    switch self.conflictResolutionPolicy {
                    case .preferApp:
                        break // push local
                    case .preferCalendar:
                        if let remote = remoteEvent {
                            self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
                        }
                        return
                    case .prompt:
                        // Default to preferApp for series-level, but per-instance prompts handled above
                        break
                    }
                } else if isRecurring && self.autoResolveRecurringConflicts {
                    // Auto-resolve according to policy
                    switch self.conflictResolutionPolicy {
                    case .preferApp:
                        // Overwrite remote with local (continue with push)
                        break
                    case .preferCalendar:
                        // Overwrite local with remote
                        if let remote = remoteEvent {
                            self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
                        }
                        return
                    case .prompt:
                        // Auto-resolve as preferApp (default)
                        break
                    }
                } else {
                    switch self.conflictResolutionPolicy {
                    case .preferApp:
                        break
                    case .preferCalendar:
                        if let remote = remoteEvent {
                            self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
                        }
                        return
                    case .prompt:
                        // User prompt for conflict resolution
                        self.pendingConflict = ConflictPrompt(
                            session: session,
                            remoteEvent: remoteEvent,
                            isRecurring: isRecurring,
                            completion: { [weak self] choice, modelContext in
                                self?.resolveConflict(choice, modelContext: modelContext)
                            }
                        )
                        return
                    }
                }
            } else if self.syncDirection == .bidirectional && remoteChanged && !localChanged {
                // Remote changed, local did not: update local
                if let remote = remoteEvent {
                    self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
                }
                return
            } else if self.syncDirection == .bidirectional && localChanged && !remoteChanged {
                // Local changed, remote did not: push local
                // continue
            } else if self.syncDirection == .bidirectional && !localChanged && !remoteChanged {
                // No changes: do nothing
                return
            }
            // Robust handling for detached/series recurring event conflicts
            if isRecurring {
                // Merging of detached/exception instances between local and remote
                // would involve comparing the recurrence rules and exceptions,
                // and merging changes at the instance level. If both sides have changes
                // to different instances, merge them. If both sides have changes to the
                // same instance, resolve according to policy or prompt the user.
                // For now, this is a stub.
            }
            let ekEvent: EKEvent
            if !session.eventIdentifier.isEmpty, let event = self.eventStore.event(withIdentifier: session.eventIdentifier) {
                // Event exists, update it
                ekEvent = event
                // Conflict resolution: check if calendar event is newer
                if let remoteModDate = ekEvent.lastModifiedDate, let localSyncTag = session.lastSyncTag, remoteModDate.description > localSyncTag {
                    let msg = "Conflict detected for '\(session.title)'. Remote event is newer. Aborting push."
                    print("[SyncService] \(msg)")
                    self.error = NSError(domain: "EventKitSyncService", code: 105, userInfo: [NSLocalizedDescriptionKey: msg])
                    self.syncStatus = .failed(self.error!)
                    return
                }
            } else {
                // New event, create it
                ekEvent = EKEvent(eventStore: self.eventStore)
                ekEvent.calendar = calendar
            }
            self.mapSessionToEvent(session, event: ekEvent)
            
            do {
                try self.eventStore.save(ekEvent, span: .thisEvent, commit: true)
                session.eventIdentifier = ekEvent.eventIdentifier
                session.lastSyncTag = ekEvent.lastModifiedDate?.description
                session.calendarIdentifier = ekEvent.calendar.calendarIdentifier
                // No explicit save needed for session, changes are tracked by ModelContext automatically
                print("[SyncService] Successfully synced session: \(session.title)")
                
                // Update sync status to completed
                self.syncStatus = .completed
                self.lastSyncDate = Date()
                self.syncProgress = 1.0
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if self.syncStatus == .completed {
                        self.syncStatus = .idle
                    }
                }
            } catch {
                let msg = "Failed to save event to calendar: \(error.localizedDescription)"
                print("[SyncService] \(msg)")
                self.error = NSError(domain: "EventKitSyncService", code: 106, userInfo: [NSLocalizedDescriptionKey: msg])
                self.syncStatus = .failed(self.error!)
            }
        }
    }

    func delete(syncIdentifier: String) {
        guard syncEnabled else {
            self.error = NSError(domain: "EventKitSyncService", code: 107, userInfo: [NSLocalizedDescriptionKey: "Sync is disabled. Cannot delete event from calendar."])
            return
        }
        guard let event = eventStore.event(withIdentifier: syncIdentifier) else {
            self.error = NSError(domain: "EventKitSyncService", code: 108, userInfo: [NSLocalizedDescriptionKey: "Event not found in calendar. It may have already been deleted."])
            return
        }
        do {
            try eventStore.remove(event, span: .thisEvent, commit: true)
            print("[SyncService] Successfully deleted event from calendar.")
            self.error = nil
        } catch {
            let msg = "Error deleting event: \(error.localizedDescription)"
            print("[SyncService] \(msg)")
            self.error = NSError(domain: "EventKitSyncService", code: 109, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    /// Fetch events in a date range from the selected calendar(s), respecting sync direction.
    func fetchEvents(start: Date, end: Date) -> [EKEvent] {
        guard accessGranted, syncEnabled else { return [] }
        if syncDirection == .appToCalendar { return [] } // Do not pull if only pushing
        let calendars: [EKCalendar]
        if monitoredCalendarIdentifiers.isEmpty {
            calendars = selectedCalendar != nil ? [selectedCalendar!] : []
        } else {
            calendars = eventStore.calendars(for: .event).filter { monitoredCalendarIdentifiers.contains($0.calendarIdentifier) }
        }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return eventStore.events(matching: predicate)
    }

    private func handleExternalChanges() async {
        // Robust event pull and reconciliation logic
        print("[SyncService] External change detected. Pulling and reconciling events.")
        guard accessGranted, syncEnabled else { 
            print("[SyncService] Skipping external changes - access not granted or sync disabled")
            return 
        }
        
        // Create a new ModelContainer and context on the main actor
        let container: ModelContainer
        do {
            container = try await MainActor.run { try ModelContainer(for: SessionEntity.self) }
            print("[SyncService] Successfully created ModelContainer for external changes")
        } catch {
            print("Error creating ModelContainer for external changes: \(error)")
            return
        }
        
        // Perform all ModelContext operations on the main actor
        await MainActor.run {
            print("[SyncService] Starting ModelContext operations on main actor")
            let newContext = container.mainContext
            
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .year, value: -1, to: Date())!
            let end = calendar.date(byAdding: .year, value: 1, to: Date())!
            
            // Fetch all events from monitored calendars
            let remoteEvents = self.fetchEvents(start: start, end: end)
            print("[SyncService] Fetched \(remoteEvents.count) remote events")
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
            let localSessions = ((try? newContext.fetch(fetchDescriptor)) ?? []).filter {
                ($0.startTime ?? Date.distantPast) >= start &&
                ($0.endTime ?? Date.distantFuture) <= end
            }
            print("[SyncService] Fetched \(localSessions.count) local sessions")
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
                        self.updateSessionFromRemote(session: localSession, remoteEvent: remoteEvent, modelContext: newContext)
                        updatedCount += 1
                    }
                }
            }
            print("[SyncService] Updated \(updatedCount) local sessions from remote events")
            
            // 2. Handle local sessions whose eventIdentifier is not found in remote events (deleted remotely)
            let remoteEventIds = Set(remoteEventsById.keys)
            var deletedCount = 0
            for (localId, localSession) in localSessionsById {
                if !remoteEventIds.contains(localId) {
                    // Event was deleted remotely; delete local session
                    newContext.delete(localSession)
                    deletedCount += 1
                    print("[SyncService] Local session deleted because remote event was removed: \(localSession.title)")
                }
            }
            print("[SyncService] Deleted \(deletedCount) local sessions")
            
            // Save context if there are changes (SwiftData needs explicit save if auto-save isn't configured for this context)
            do {
                try newContext.save()
                print("[SyncService] Successfully saved context after external changes")
            } catch {
                print("[SyncService] Error saving after pull: \(error.localizedDescription)")
            }
        }
        
        // Optionally, refetch calendars
        Task { await fetchAvailableCalendars() }
    }
    
    private func handleSyncEnabledChange(isEnabled: Bool) {
        if isEnabled && accessGranted {
            Task { await fetchAvailableCalendars() }
        } else {
            self.availableCalendars = []
        }
    }

    private func mapSessionToEvent(_ session: SessionEntity, event: EKEvent) {
        event.title = session.title
        event.startDate = session.startTime
        event.endDate = session.endTime
        event.isAllDay = session.isAllDay
        event.location = session.location
        
        // Only store the session's notes, not any app-specific or internal data
        event.notes = session.notes

        // Map recurrence
        if let ruleData = session.recurrenceRuleData {
            // Suppress deprecation: EKRecurrenceRule does NOT support NSSecureCoding, so this is required
            // swiftlint:disable:next deprecated_api_usage
            if let rule = RecurrenceRuleManager.shared.deserialize(ruleData) {
                event.recurrenceRules = [rule]
            }
        }
    }

    /// Update a SessionEntity from a remote EKEvent (used for preferCalendar and auto-resolve)
    private func updateSessionFromRemote(session: SessionEntity, remoteEvent: EKEvent, modelContext: ModelContext) {
        Task { @MainActor in
            session.title = remoteEvent.title ?? "Untitled"
            session.startTime = remoteEvent.startDate
            session.endTime = remoteEvent.endDate
            session.isAllDay = remoteEvent.isAllDay
            session.location = remoteEvent.location
            session.notes = remoteEvent.notes
            session.eventIdentifier = remoteEvent.eventIdentifier
            session.lastSyncTag = remoteEvent.lastModifiedDate?.description
            session.calendarIdentifier = remoteEvent.calendar.calendarIdentifier
            // No explicit save needed in SwiftData; changes are auto-tracked
        }
    }

    // --- Recurring Instance Merge Utilities ---
    private func extractLocalExceptions(session: SessionEntity, modelContext: ModelContext) async -> [Date: String] {
        return await MainActor.run {
            let masterID = session.id.uuidString
            let descriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { 
                $0.isDetached == true && $0.derivedFromEKEventID == masterID 
            })
            let detached = (try? modelContext.fetch(descriptor)) ?? []
            var result: [Date: String] = [:]
            for instance in detached {
                if let date = instance.occurrenceDate {
                    result[date] = instance.id.uuidString
                }
            }
            return result
        }
    }
    private func extractRemoteExceptions(remoteEvent: EKEvent?) -> [Date: EKEvent] {
        guard let event = remoteEvent else { return [:] }
        var result: [Date: EKEvent] = [:]
        // EventKit does not expose exceptions directly, but you can get all occurrences in a range
        if let recurrenceRules = event.recurrenceRules, !recurrenceRules.isEmpty {
            let calendar = Calendar.current
            let start = calendar.date(byAdding: .year, value: -1, to: Date())!
            let end = calendar.date(byAdding: .year, value: 1, to: Date())!
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [event.calendar])
            let events = eventStore.events(matching: predicate)
            for occ in events where occ.eventIdentifier != event.eventIdentifier && occ.recurrenceRules != nil {
                if let date = occ.startDate {
                    result[date] = occ
                }
            }
        }
        return result
    }
    // --- Per-Instance Conflict Queue ---
    private var pendingInstanceConflicts: [(date: Date, sessionID: String, remoteEvent: EKEvent?, localID: String?, remote: EKEvent?, modelContext: ModelContext)] = []
    private func processNextInstanceConflict() {
        guard pendingConflict == nil, !pendingInstanceConflicts.isEmpty else { return }
        let (date, sessionID, remoteEvent, localID, remote, modelContext) = pendingInstanceConflicts.removeFirst()
        
        // Re-fetch the session using the ID
        let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id.uuidString == sessionID })
        guard let session = try? modelContext.fetch(sessionDescriptor).first else { return }
        
        // Re-fetch local instance if needed
        var local: SessionEntity? = nil
        if let localID = localID {
            let localDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id.uuidString == localID })
            local = try? modelContext.fetch(localDescriptor).first
        }
        
        pendingConflict = ConflictPrompt(
            session: session,
            remoteEvent: remoteEvent,
            isRecurring: true,
            completion: { [weak self] choice, _ in
                self?.applyInstanceMergeChoice(session: session, remoteEvent: remoteEvent, date: date, choice: choice, local: local, remote: remote, modelContext: modelContext)
                self?.processNextInstanceConflict()
            }
        )
    }

    private func mergeExceptions(
        local: [Date: String], // Store session IDs instead of SessionEntity objects
        remote: [Date: EKEvent],
        policy: CalendarPreferences.ConflictResolutionPolicy,
        prompt: (Date, SessionEntity?, EKEvent?) -> Void,
        modelContext: ModelContext
    ) -> [Date: (SessionEntity?, EKEvent?)] {
        var merged: [Date: (SessionEntity?, EKEvent?)] = [:]
        let allDates = Set(local.keys).union(remote.keys)
        for date in allDates {
            let localSessionID = local[date]
            let remoteInstance = remote[date]
            
            // Re-fetch local session if needed
            var localSession: SessionEntity? = nil
            if let sessionID = localSessionID {
                let sessionDescriptor = FetchDescriptor<SessionEntity>(predicate: #Predicate { $0.id.uuidString == sessionID })
                localSession = try? modelContext.fetch(sessionDescriptor).first
            }
            
            if localSession != nil && remoteInstance == nil {
                merged[date] = (localSession, nil)
            } else if localSession == nil && remoteInstance != nil {
                merged[date] = (nil, remoteInstance)
            } else if let l = localSession, let r = remoteInstance {
                switch policy {
                case .preferApp:
                    merged[date] = (l, nil)
                case .preferCalendar:
                    merged[date] = (nil, r)
                case .prompt:
                    // Queue this conflict for user resolution
                    pendingInstanceConflicts.append((date, l.id.uuidString, r, l.id.uuidString, r, modelContext))
                    // Do not resolve yet; will be handled after user input
                }
            }
        }
        return merged
    }

    private func applyMergedExceptions(
        session: SessionEntity,
        remoteEvent: EKEvent?,
        merged: [Date: (SessionEntity?, EKEvent?)],
        modelContext: ModelContext
    ) {
        Task { @MainActor in
            for (date, (localInstance, remoteInstance)) in merged {
                // If both exist and policy is .prompt, skip for now (will be handled by conflict queue)
                if localInstance != nil && remoteInstance != nil && conflictResolutionPolicy == .prompt {
                    continue
                }
                if let local = localInstance, remoteInstance == nil {
                    // Local only: ensure this instance is saved locally and pushed to remote if needed
                    // --- PUSH LOGIC ---
                    let ekEvent: EKEvent
                    if !local.eventIdentifier.isEmpty, let existing = self.eventStore.event(withIdentifier: local.eventIdentifier) {
                        ekEvent = existing
                    } else {
                        ekEvent = EKEvent(eventStore: self.eventStore)
                        ekEvent.calendar = self.selectedCalendar
                    }
                    self.mapSessionToEvent(local, event: ekEvent)
                    ekEvent.recurrenceRules = nil
                    do {
                        try self.eventStore.save(ekEvent, span: .thisEvent, commit: true)
                        local.eventIdentifier = ekEvent.eventIdentifier
                        local.lastSyncTag = ekEvent.lastModifiedDate?.description
                        local.calendarIdentifier = ekEvent.calendar.calendarIdentifier
                        // No explicit save needed for local, changes are tracked by ModelContext
                        print("[SyncService] Pushed detached instance to calendar: \(local.title) @ \(date)")
                    } catch {
                        print("[SyncService] Error pushing detached instance: \(error.localizedDescription)")
                    }
                } else if let remote = remoteInstance, localInstance == nil {
                    // Remote only: create or update local instance from remote
                    let descriptor = FetchDescriptor<SessionEntity>(
                        predicate: #Predicate { 
                            $0.isDetached == true && $0.occurrenceDate == date
                        }
                    )
                    // Filter for derivedFromEKEventID in Swift
                    let existing = (try? modelContext.fetch(descriptor))?.first { ($0.derivedFromEKEventID ?? "") == session.id.uuidString }
                    
                    let detached: SessionEntity
                    if let existing = existing {
                        detached = existing
                    } else {
                        // Use SessionFactory for consistent detached instance creation
                        let sessionFactory = SessionFactory(context: modelContext)
                        detached = sessionFactory.createDetachedInstance(from: session, at: date) { _ in }
                    }
                    
                    detached.title = remote.title
                    detached.startTime = remote.startDate
                    detached.endTime = remote.endDate
                    detached.isAllDay = remote.isAllDay
                    detached.location = remote.location
                    detached.notes = remote.notes
                    detached.status = session.status
                    detached.eventIdentifier = remote.eventIdentifier
                    detached.lastSyncTag = remote.lastModifiedDate?.description
                    detached.calendarIdentifier = remote.calendar.calendarIdentifier
                    // No explicit save needed for detached, changes are tracked by ModelContext
                    print("[SyncService] Created detached instance from remote: \(detached.title) @ \(date)")
                }
            }
        }
    }
    private func applyInstanceMergeChoice(
        session: SessionEntity,
        remoteEvent: EKEvent?,
        date: Date,
        choice: ConflictResolutionChoice,
        local: SessionEntity?,
        remote: EKEvent?,
        modelContext: ModelContext
    ) {
        Task { @MainActor in
            switch choice {
            case .preferApp:
                // Keep local, optionally push to remote
                if let local = local {
                    let ekEvent: EKEvent
                    if !local.eventIdentifier.isEmpty, let existing = self.eventStore.event(withIdentifier: local.eventIdentifier) {
                        ekEvent = existing
                    } else {
                        ekEvent = EKEvent(eventStore: self.eventStore)
                        ekEvent.calendar = self.selectedCalendar
                    }
                    self.mapSessionToEvent(local, event: ekEvent)
                    ekEvent.recurrenceRules = nil
                    do {
                        try self.eventStore.save(ekEvent, span: .thisEvent, commit: true)
                        local.eventIdentifier = ekEvent.eventIdentifier
                        local.lastSyncTag = ekEvent.lastModifiedDate?.description
                        local.calendarIdentifier = ekEvent.calendar.calendarIdentifier
                        // No explicit save needed for local, changes are tracked by ModelContext
                        print("[SyncService] Pushed detached instance to calendar (user preferApp): \(local.title) @ \(date)")
                    } catch {
                        print("[SyncService] Error pushing detached instance (user preferApp): \(error.localizedDescription)")
                    }
                }
            case .preferCalendar:
                // Overwrite local with remote
                if let remote = remote {
                    // Check if a detached SessionEntity already exists for this occurrence
                    let descriptor = FetchDescriptor<SessionEntity>(
                        predicate: #Predicate { 
                            $0.isDetached == true && $0.occurrenceDate == date
                        }
                    )
                    // Filter for derivedFromEKEventID in Swift
                    let existing = (try? modelContext.fetch(descriptor))?.first { ($0.derivedFromEKEventID ?? "") == session.id.uuidString }
                    
                    let detached: SessionEntity
                    if let existing = existing {
                        detached = existing
                    } else {
                        // Use SessionFactory for consistent detached instance creation
                        let sessionFactory = SessionFactory(context: modelContext)
                        detached = sessionFactory.createDetachedInstance(from: session, at: date) { _ in }
                    }
                    
                    detached.title = remote.title
                    detached.startTime = remote.startDate
                    detached.endTime = remote.endDate
                    detached.isAllDay = remote.isAllDay
                    detached.location = remote.location
                    detached.notes = remote.notes
                    detached.status = session.status
                    detached.client = session.client
                    detached.clientService = session.clientService
                    detached.recurrenceRuleData = nil
                    detached.ekRecurrenceRuleDescription = nil
                    detached.eventIdentifier = remote.eventIdentifier
                    detached.lastSyncTag = remote.lastModifiedDate?.description
                    detached.calendarIdentifier = remote.calendar.calendarIdentifier
                    // No explicit save needed for detached, changes are tracked by ModelContext
                    print("[SyncService] Pulled detached instance from calendar (user preferCalendar): \(detached.title) @ \(date)")
                }
            case .skip:
                // Do nothing
                break
            }
        }
    }
    // --- End Recurring Instance Merge Utilities ---
} 
