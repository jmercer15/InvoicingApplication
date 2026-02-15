import Foundation
import EventKit
import SwiftUI
import Combine
import SwiftData
import CoreLocation
import Core

// MARK: - Notification Names
extension Notification.Name {
    public static let eventKitExternalChangesDetected = Notification.Name("eventKitExternalChangesDetected")
}

// MARK: - EventKitSyncService
/// EventKitSyncService is a singleton responsible for all EventKit operations and state.
@MainActor
public final class EventKitSyncService: ObservableObject {
    public static let shared = EventKitSyncService()
    public let eventStore = EKEventStore()
    private var isSyncing = false
    private var reverseGeocodeCache: [String: EventKitLocationParser.ParsedLocation] = [:]
    private var externalChangeSnapshot: [String: Date] = [:]
    private let maxEventFetchWindowYears = 4

    private static let syncTagWriteFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let syncTagReadFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let internetDateTime = ISO8601DateFormatter()
        internetDateTime.formatOptions = [.withInternetDateTime]

        return [withFractional, internetDateTime]
    }()

    private static let legacySyncTagFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()

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
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    await self.updateSessionFromRemote(
                        session: prompt.session,
                        remoteEvent: remote,
                        modelContext: modelContext
                    )
                }
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

    private func encodeSyncTag(_ date: Date?) -> String? {
        guard let date else { return nil }
        return Self.syncTagWriteFormatter.string(from: date)
    }

    private func decodeSyncTag(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        for formatter in Self.syncTagReadFormatters {
            if let parsed = formatter.date(from: rawValue) {
                return parsed
            }
        }

        return Self.legacySyncTagFormatter.date(from: rawValue)
    }

    private func monitoredCalendarsForFetch() -> [EKCalendar]? {
        let identifiers = monitoredCalendarIdentifiers
        guard !identifiers.isEmpty else { return nil }

        let calendars = identifiers.compactMap { eventStore.calendar(withIdentifier: $0) }
        return calendars.isEmpty ? nil : calendars
    }

    private func normalizedDateRange(start: Date, end: Date) -> (Date, Date)? {
        if start == end { return nil }
        return start < end ? (start, end) : (end, start)
    }

    private func fetchSegments(start: Date, end: Date) -> [DateInterval] {
        guard let (normalizedStart, normalizedEnd) = normalizedDateRange(start: start, end: end) else {
            return []
        }

        let calendar = Calendar.current
        var segments: [DateInterval] = []
        var cursor = normalizedStart

        while cursor < normalizedEnd {
            let nextBoundary = calendar.date(
                byAdding: .year,
                value: maxEventFetchWindowYears,
                to: cursor
            ) ?? normalizedEnd
            let segmentEnd = min(nextBoundary, normalizedEnd)
            segments.append(DateInterval(start: cursor, end: segmentEnd))
            cursor = segmentEnd
        }

        return segments
    }

    private func sortedUniqueEvents(_ events: [EKEvent]) -> [EKEvent] {
        var uniqueEvents: [String: EKEvent] = [:]
        uniqueEvents.reserveCapacity(events.count)

        for event in events {
            // Recurring occurrences can share identifiers. Include temporal anchor
            // so separate instances are preserved while still deduping window overlap.
            let baseKey = event.eventIdentifier
                ?? event.calendarItemExternalIdentifier
                ?? event.calendarItemIdentifier
            let startAnchor = event.startDate.timeIntervalSinceReferenceDate
            let endAnchor = event.endDate.timeIntervalSinceReferenceDate
            let occurrenceAnchor = (event.occurrenceDate ?? event.startDate).timeIntervalSinceReferenceDate
            let dedupeKey = "\(baseKey)|\(occurrenceAnchor)|\(startAnchor)|\(endAnchor)"
            uniqueEvents[dedupeKey] = event
        }

        return uniqueEvents.values.sorted { lhs, rhs in
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            if lhs.endDate != rhs.endDate { return lhs.endDate < rhs.endDate }
            return (lhs.title ?? "") < (rhs.title ?? "")
        }
    }

    private func identityKeys(for event: EKEvent) -> [String] {
        var keys: [String] = []
        if let identifier = event.eventIdentifier, !identifier.isEmpty {
            keys.append("event:\(identifier)")
        }
        if let externalIdentifier = event.calendarItemExternalIdentifier, !externalIdentifier.isEmpty {
            keys.append("external:\(externalIdentifier)")
        }
        return keys
    }

    private func identityKeys(for session: SessionEntity) -> [String] {
        var keys: [String] = []
        if !session.eventIdentifier.isEmpty {
            keys.append("event:\(session.eventIdentifier)")
        }
        if let externalIdentifier = session.eventExternalIdentifier, !externalIdentifier.isEmpty {
            keys.append("external:\(externalIdentifier)")
        }
        return keys
    }

    private func fetchEvents(start: Date, end: Date, calendars: [EKCalendar]?) -> [EKEvent] {
        let segments = fetchSegments(start: start, end: end)
        guard !segments.isEmpty else { return [] }

        var allEvents: [EKEvent] = []
        allEvents.reserveCapacity(segments.count * 64)

        for segment in segments {
            let predicate = eventStore.predicateForEvents(
                withStart: segment.start,
                end: segment.end,
                calendars: calendars
            )
            allEvents.append(contentsOf: eventStore.events(matching: predicate))
        }

        return sortedUniqueEvents(allEvents)
    }

    private func findRemoteEvent(for session: SessionEntity) -> EKEvent? {
        guard canPerformReadWriteEventOperations() else { return nil }

        // Detached rows represent a specific recurring occurrence and must be
        // resolved by temporal anchor, not just by series identifier.
        if session.isDetached, let occurrenceAnchor = session.occurrenceDate {
            let calendar = Calendar.current
            let searchStart = calendar.date(byAdding: .day, value: -30, to: occurrenceAnchor) ?? occurrenceAnchor
            let searchEnd = calendar.date(byAdding: .day, value: 30, to: occurrenceAnchor) ?? occurrenceAnchor
            let candidateEvents = fetchEvents(
                start: searchStart,
                end: searchEnd,
                calendars: monitoredCalendarsForFetch()
            )

            let normalizedTarget: Date = {
                if session.isAllDay {
                    return calendar.startOfDay(for: occurrenceAnchor)
                }
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: occurrenceAnchor)
                return calendar.date(from: comps) ?? occurrenceAnchor
            }()

            let preferred = candidateEvents.first { candidate in
                guard let candidateAnchor = candidate.occurrenceDate ?? candidate.startDate else {
                    return false
                }
                let normalizedCandidate: Date = {
                    if session.isAllDay {
                        return calendar.startOfDay(for: candidateAnchor)
                    }
                    let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: candidateAnchor)
                    return calendar.date(from: comps) ?? candidateAnchor
                }()

                guard normalizedCandidate == normalizedTarget else { return false }

                if let external = session.eventExternalIdentifier, !external.isEmpty {
                    return candidate.calendarItemExternalIdentifier == external
                }
                if !session.eventIdentifier.isEmpty {
                    return candidate.eventIdentifier == session.eventIdentifier
                }
                return true
            }

            if let preferred { return preferred }
        }

        if !session.eventIdentifier.isEmpty,
           let event = eventStore.event(withIdentifier: session.eventIdentifier) {
            return event
        }

        guard let externalIdentifier = session.eventExternalIdentifier,
              !externalIdentifier.isEmpty else {
            return nil
        }

        let baseStart = session.startTime ?? Date()
        let baseEnd = session.endTime ?? baseStart.addingTimeInterval(3600)
        let calendar = Calendar.current
        let searchStart = calendar.date(byAdding: .year, value: -2, to: baseStart) ?? baseStart
        let searchEnd = calendar.date(byAdding: .year, value: 2, to: baseEnd) ?? baseEnd
        let calendars = monitoredCalendarsForFetch()

        let matchingEvents = fetchEvents(start: searchStart, end: searchEnd, calendars: calendars)
        return matchingEvents.first { $0.calendarItemExternalIdentifier == externalIdentifier }
    }

    private func resolvePersistedEventIdentity(
        savedEvent: EKEvent,
        session: SessionEntity,
        span: EKSpan,
        previousIdentifier: String
    ) -> EKEvent {
        if let identifier = savedEvent.eventIdentifier,
           !identifier.isEmpty,
           let reloaded = eventStore.event(withIdentifier: identifier) {
            if span != .futureEvents || identifier != previousIdentifier {
                return reloaded
            }
        }

        guard span == .futureEvents else {
            return savedEvent
        }

        if let splitMaster = refetchFutureSeriesMaster(
            for: session,
            preferredCalendar: savedEvent.calendar,
            previousIdentifier: previousIdentifier
        ) {
            return splitMaster
        }

        if let identifier = savedEvent.eventIdentifier,
           !identifier.isEmpty,
           let reloaded = eventStore.event(withIdentifier: identifier) {
            return reloaded
        }

        return savedEvent
    }

    private func refetchFutureSeriesMaster(
        for session: SessionEntity,
        preferredCalendar: EKCalendar?,
        previousIdentifier: String
    ) -> EKEvent? {
        guard let anchor = session.startTime else { return nil }

        let calendar = Calendar.current
        let windowStart = calendar.date(byAdding: .day, value: -14, to: anchor) ?? anchor
        let windowEnd = calendar.date(byAdding: .day, value: 365, to: anchor) ?? anchor.addingTimeInterval(365 * 24 * 60 * 60)
        let calendars: [EKCalendar]? = preferredCalendar.map { [$0] } ?? monitoredCalendarsForFetch()
        let expectedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedExternalIdentifier = session.eventExternalIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        let expectedHasRecurrence = session.recurrenceRuleData != nil

        let candidates = fetchEvents(start: windowStart, end: windowEnd, calendars: calendars)
            .filter { candidate in
                guard let candidateStart = candidate.startDate else { return false }
                guard abs(candidateStart.timeIntervalSince(anchor)) <= 60 else { return false }

                if !expectedTitle.isEmpty {
                    let candidateTitle = candidate.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    guard candidateTitle == expectedTitle else { return false }
                }

                if expectedHasRecurrence {
                    guard candidate.recurrenceRules?.isEmpty == false else { return false }
                }

                return true
            }

        if let expectedExternalIdentifier, !expectedExternalIdentifier.isEmpty {
            if let externalMatch = candidates.first(where: {
                ($0.calendarItemExternalIdentifier ?? "") == expectedExternalIdentifier &&
                    ($0.eventIdentifier ?? "") != previousIdentifier
            }) {
                return externalMatch
            }
        }

        if let rebasedIdentifierMatch = candidates.first(where: {
            let identifier = $0.eventIdentifier ?? ""
            return !identifier.isEmpty && identifier != previousIdentifier
        }) {
            return rebasedIdentifierMatch
        }

        return candidates.first
    }

    private func canPerformReadWriteEventOperations() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, macOS 14.0, *) {
            return status == .fullAccess
        }
        return status == .authorized
    }

    private init() {
        print("[EventKitSyncService] Initializing EventKitSyncService...")
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: eventStore)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { _ in
                print("[SyncService] Event store changed, triggering refresh.")
                // Post a notification that external changes occurred
                // The actual ModelContext operations will be handled by views that have access to the context
                NotificationCenter.default.post(name: .eventKitExternalChangesDetected, object: nil)
            }
            .store(in: &cancellables)
        checkInitialAccessAndFetchCalendars()
        print("[EventKitSyncService] EventKitSyncService initialization complete")
        
        // Set initial sync status based on access
        if self.accessGranted {
            self.syncStatus = .idle
        } else {
            self.syncStatus = .error
        }
    }

    func checkInitialAccessAndFetchCalendars() {
        let status = EKEventStore.authorizationStatus(for: .event)
        print("[EventKitSyncService] Initial authorization status: \(status)")
        if #available(iOS 17.0, macOS 14.0, *), status == .writeOnly {
            print("[EventKitSyncService] Write-only Calendar access detected. Full access is required for sync and recurrence management.")
        }
        let isAuthorized = canPerformReadWriteEventOperations()
        print("[EventKitSyncService] Is authorized: \(isAuthorized)")
        self.accessGranted = isAuthorized
        if isAuthorized && self.syncEnabled {
            Task { await self.fetchAvailableCalendars() }
            self.syncStatus = .idle
        } else {
            self.availableCalendars = []
            self.syncStatus = isAuthorized ? .idle : .error
        }
    }

    /// Request access to the user's calendars. Calls completion on main thread.
    public func requestAccess() async -> Bool {
        print("[EventKitSyncService] Requesting calendar access...")
        return await withCheckedContinuation { continuation in
            if #available(iOS 17.0, macOS 14.0, *) {
                print("[EventKitSyncService] Using requestFullAccessToEvents (iOS 17+/macOS 14+)")
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
                print("[EventKitSyncService] Using requestAccess(to: .event) (legacy OS)")
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
    public func fetchAvailableCalendars() async {
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
    public func createCalendar(title: String, color: CGColor?) async throws {
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

    /// Synchronize a Session domain model with EventKit (domain model version)
    public func sync(session: Session, modelContext: ModelContext, span: EKSpan = .thisEvent) {
        // Fetch entity for sync operation
        let resolver = EntityResolutionService(context: modelContext)
        guard let sessionEntity = try? resolver.resolveSession(id: session.id) else {
            print("[EventKitSyncService] Failed to find SessionEntity for session \(session.id)")
            return
        }
        sync(session: sessionEntity, modelContext: modelContext, span: span)
    }
    
    /// Synchronize a Session using the UnitOfWork pattern (Bridge to legacy entity implementation)
    public func sync(session: Session, unitOfWork: UnitOfWorkService, span: EKSpan = .thisEvent) {
        if let swiftDataUoW = unitOfWork as? SwiftDataUnitOfWork {
            sync(session: session, modelContext: swiftDataUoW.eventKitModelContext, span: span)
        } else {
            print("[EventKitSyncService] Error: Sync requires SwiftDataUnitOfWork for legacy entity resolution.")
        }
    }
    
    /// Synchronize a SessionEntity with EventKit, respecting sync direction and conflict resolution policy.
    public func sync(session: SessionEntity, modelContext: ModelContext, span: EKSpan = .thisEvent) {
        // Update sync status to syncing
        self.syncStatus = .syncing
        self.syncProgress = 0.0
        
        // Respect sync direction: only push if .appToCalendar or .bidirectional
        guard syncEnabled else {
            self.error = NSError(domain: "EventKitSyncService", code: 101, userInfo: [NSLocalizedDescriptionKey: "Sync is disabled or session context is missing."])
            self.syncStatus = .error
            return
        }
        if syncDirection == .calendarToApp {
            self.error = NSError(domain: "EventKitSyncService", code: 102, userInfo: [NSLocalizedDescriptionKey: "Sync direction is set to 'Calendar to App'. Local changes will not be pushed."])
            self.syncStatus = .error
            return // Do not push if only pulling
        }
        guard canPerformReadWriteEventOperations() else {
            self.error = NSError(
                domain: "EventKitSyncService",
                code: 110,
                userInfo: [NSLocalizedDescriptionKey: "Full Calendar access is required for two-way calendar sync."]
            )
            self.syncStatus = .error
            return
        }
        guard let calendar = selectedCalendar else {
            self.error = NSError(domain: "EventKitSyncService", code: 103, userInfo: [NSLocalizedDescriptionKey: "No calendar selected. Please choose a writable calendar in Settings."])
            self.syncStatus = .error
            return
        }
        guard calendar.allowsContentModifications else {
            self.error = NSError(domain: "EventKitSyncService", code: 104, userInfo: [NSLocalizedDescriptionKey: "The selected calendar is read-only. Please choose a different calendar."])
            self.syncStatus = .error
            return
        }
        
        // Run the remainder on MainActor as an async task
        Task { @MainActor in
            // Fetch the remote event if it exists
            let remoteEvent = self.findRemoteEvent(for: session)
            let localLastModified = session.lastModifiedDate ?? Date.distantPast
            let remoteLastModified = remoteEvent?.lastModifiedDate ?? Date.distantPast
            let lastSyncTag = self.decodeSyncTag(session.lastSyncTag) ?? Date.distantPast
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
                    case .preferApp, .localWins:
                        break // push local
                    case .preferCalendar, .remoteWins:
                        if let remote = remoteEvent {
                            await self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
                        }
                        return
                    case .prompt:
                        // Default to preferApp for series-level, but per-instance prompts handled above
                        break
                    }
                } else if isRecurring && self.autoResolveRecurringConflicts {
                    // Auto-resolve according to policy
                    switch self.conflictResolutionPolicy {
                    case .preferApp, .localWins:
                        // Overwrite remote with local (continue with push)
                        break
                    case .preferCalendar, .remoteWins:
                        // Overwrite local with remote
                        if let remote = remoteEvent {
                            await self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
                        }
                        return
                    case .prompt:
                        // Auto-resolve as preferApp (default)
                        break
                    }
                } else {
                    switch self.conflictResolutionPolicy {
                    case .preferApp, .localWins:
                        break
                    case .preferCalendar, .remoteWins:
                        if let remote = remoteEvent {
                            await self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
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
                    await self.updateSessionFromRemote(session: session, remoteEvent: remote, modelContext: modelContext)
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
                // Recurring instance merge is handled above via extractLocalExceptions, 
                // extractRemoteExceptions, mergeExceptions, and applyMergedExceptions.
                // Per-instance conflicts are queued in pendingInstanceConflicts for user resolution.
            }
            var ekEvent: EKEvent
            let isExistingEvent: Bool
            if let event = remoteEvent {
                // Event exists, update it
                ekEvent = event
                isExistingEvent = true

                // Refresh to reduce "last writer wins" overwrite races.
                _ = ekEvent.refresh()

                // Conflict resolution: check if calendar event is newer
                if let remoteModDate = ekEvent.lastModifiedDate,
                   remoteModDate > lastSyncTag,
                   !localChanged {
                    let msg = "Conflict detected for '\(session.title)'. Remote event is newer. Aborting push."
                    print("[SyncService] \(msg)")
                    self.error = NSError(domain: "EventKitSyncService", code: 105, userInfo: [NSLocalizedDescriptionKey: msg])
                    self.syncStatus = .error
                    return
                }
            } else {
                // New event, create it
                ekEvent = EKEvent(eventStore: self.eventStore)
                ekEvent.calendar = calendar
                isExistingEvent = false
            }
            let previousIdentifier = session.eventIdentifier
            self.mapSessionToEvent(session, event: ekEvent, preserveExistingMetadata: isExistingEvent)
            
            do {
                try self.eventStore.save(ekEvent, span: span, commit: true)
                let resolvedEvent = self.resolvePersistedEventIdentity(
                    savedEvent: ekEvent,
                    session: session,
                    span: span,
                    previousIdentifier: previousIdentifier
                )
                await self.applyRemoteEventToSession(
                    remoteEvent: resolvedEvent,
                    session: session,
                    includeCoreFields: false
                )
                if previousIdentifier != session.eventIdentifier {
                    print("[SyncService] Event identifier rebased after save span \(span): \(previousIdentifier) -> \(session.eventIdentifier)")
                }
                // No explicit save needed for session, changes are tracked by ModelContext automatically
                print("[SyncService] Successfully synced session: \(session.title)")
                
                // Update sync status to completed
                self.syncStatus = .idle
                self.lastSyncDate = Date()
                self.syncProgress = 1.0
                
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if self.syncStatus == .idle {
                        self.syncStatus = .idle
                    }
                }
            } catch {
                let msg = "Failed to save event to calendar: \(error.localizedDescription)"
                print("[SyncService] \(msg)")
                self.error = NSError(domain: "EventKitSyncService", code: 106, userInfo: [NSLocalizedDescriptionKey: msg])
                self.syncStatus = .error
            }
        }
    }

    public func delete(syncIdentifier: String, span: EKSpan = .thisEvent) {
        guard syncEnabled else {
            self.error = NSError(domain: "EventKitSyncService", code: 107, userInfo: [NSLocalizedDescriptionKey: "Sync is disabled. Cannot delete event from calendar."])
            return
        }
        guard canPerformReadWriteEventOperations() else {
            self.error = NSError(domain: "EventKitSyncService", code: 110, userInfo: [NSLocalizedDescriptionKey: "Full Calendar access is required for two-way calendar sync."])
            return
        }
        guard let event = eventStore.event(withIdentifier: syncIdentifier) else {
            self.error = NSError(domain: "EventKitSyncService", code: 108, userInfo: [NSLocalizedDescriptionKey: "Event not found in calendar. It may have already been deleted."])
            return
        }
        do {
            try eventStore.remove(event, span: span, commit: true)
            print("[SyncService] Successfully deleted event from calendar.")
            self.error = nil
        } catch {
            let msg = "Error deleting event: \(error.localizedDescription)"
            print("[SyncService] \(msg)")
            self.error = NSError(domain: "EventKitSyncService", code: 109, userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    /// Fetch events from EventKit for a given date range
    public func fetchEvents(start: Date, end: Date) -> [EKEvent] {
        guard canPerformReadWriteEventOperations() else { return [] }
        return fetchEvents(start: start, end: end, calendars: monitoredCalendarsForFetch())
    }

    private func handleExternalChanges() async {
        // This method is now deprecated - external changes are handled via notifications
        // and processed by views that have access to the ModelContext
        print("[SyncService] External change detected. Processing via notification system.")
        guard accessGranted, syncEnabled else { 
            print("[SyncService] Skipping external changes - access not granted or sync disabled")
            return 
        }
        
        // Post notification for views to handle
        NotificationCenter.default.post(name: .eventKitExternalChangesDetected, object: nil)
        
        // Optionally, refetch calendars
        Task { await fetchAvailableCalendars() }
    }
    


    // MARK: - Legacy / Helper Methods (Aliases)
    
    /// Get available calendars (alias for property access)
    public func getCalendars() -> [EKCalendar] {
        return self.availableCalendars
    }
    
    /// Process external changes (alias for handleExternalChangesWithContext)
    public func processExternalChanges(context: ModelContext) async {
        await self.handleExternalChangesWithContext(context)
    }
    
    /// Process external changes using UnitOfWork (Bridge to legacy ModelContext)
    public func processExternalChanges(unitOfWork: UnitOfWorkService) async {
        if let swiftDataUoW = unitOfWork as? SwiftDataUnitOfWork {
            await self.handleExternalChangesWithContext(swiftDataUoW.eventKitModelContext)
        } else {
            print("[EventKitSyncService] Error: processExternalChanges requires SwiftDataUnitOfWork for legacy operations.")
        }
    }
    
    public func handleExternalChangesWithContext(_ modelContext: ModelContext) async {
        print("[SyncService] Processing external changes with provided ModelContext")
        guard accessGranted, syncEnabled else { 
            print("[SyncService] Skipping external changes - access not granted or sync disabled")
            return 
        }
        
        let calendar = Calendar.current
        let start = calendar.date(byAdding: .year, value: -1, to: Date())!
        let end = calendar.date(byAdding: .year, value: 1, to: Date())!
        
        // Fetch all events from monitored calendars
        let remoteEvents = self.fetchEvents(start: start, end: end)
        print("[SyncService] Fetched \(remoteEvents.count) remote events")
        var remoteEventsById = [String: EKEvent]()
        var remoteEventsByExternalId = [String: EKEvent]()
        var newSnapshot: [String: Date] = [:]
        for event in remoteEvents {
            if let id = event.eventIdentifier, remoteEventsById[id] == nil {
                remoteEventsById[id] = event
            }
            if let externalId = event.calendarItemExternalIdentifier,
               !externalId.isEmpty,
               remoteEventsByExternalId[externalId] == nil {
                remoteEventsByExternalId[externalId] = event
            }

            let lastModified = event.lastModifiedDate ?? event.startDate ?? Date.distantPast
            for key in identityKeys(for: event) {
                let existing = newSnapshot[key]
                if existing == nil || (existing ?? .distantPast) < lastModified {
                    newSnapshot[key] = lastModified
                }
            }
        }

        let changedKeys = Set(newSnapshot.keys.filter { externalChangeSnapshot[$0] != newSnapshot[$0] })
        let deletedKeys = Set(externalChangeSnapshot.keys).subtracting(newSnapshot.keys)
        externalChangeSnapshot = newSnapshot
        
        // Fetch all local sessions with eventIdentifier in this range using EntityResolutionService
        let resolver = EntityResolutionService(context: modelContext)
        let localSessions = resolver.resolveSessionsWithEventIdentifier(start: start, end: end)
        
        print("[SyncService] Fetched \(localSessions.count) local sessions")
        
        // 1. Update local sessions from remote events (do not create new sessions)
        var updatedCount = 0
        for localSession in localSessions {
            let remoteEvent: EKEvent? = {
                if !localSession.eventIdentifier.isEmpty,
                   let matchedByIdentifier = remoteEventsById[localSession.eventIdentifier] {
                    return matchedByIdentifier
                }

                if let externalIdentifier = localSession.eventExternalIdentifier,
                   !externalIdentifier.isEmpty,
                   let matchedByExternalIdentifier = remoteEventsByExternalId[externalIdentifier] {
                    return matchedByExternalIdentifier
                }

                return nil
            }()

            guard let remoteEvent else {
                continue
            }

            let localIdentityKeys = Set(identityKeys(for: localSession))
            let shouldProcess = !changedKeys.isDisjoint(with: localIdentityKeys) ||
                !deletedKeys.isDisjoint(with: localIdentityKeys)
            if !shouldProcess {
                continue
            }

            let localLastModified = localSession.lastModifiedDate ?? Date.distantPast
            let remoteLastModified = remoteEvent.lastModifiedDate ?? Date.distantPast
            let lastSyncTag = decodeSyncTag(localSession.lastSyncTag) ?? Date.distantPast
            let localChanged = localLastModified > lastSyncTag
            let remoteChanged = remoteLastModified > lastSyncTag

            if remoteChanged && (!localChanged || remoteLastModified > localLastModified) {
                // Remote is newer, update local
                await self.updateSessionFromRemote(
                    session: localSession,
                    remoteEvent: remoteEvent,
                    modelContext: modelContext
                )
                updatedCount += 1
            }
        }
        print("[SyncService] Updated \(updatedCount) local sessions from remote events")
        
        // 2. Handle local sessions whose eventIdentifier is not found in remote events
        // NOTE: We should NOT delete local sessions just because the remote event is missing.
        // Sessions are enhanced EKEvents with additional application functionality.
        // The remote event might not exist yet, be outside the fetch range, or the sync hasn't happened.
        var missingRemoteCount = 0
        for localSession in localSessions {
            let hasRemoteMatch = (!localSession.eventIdentifier.isEmpty && remoteEventsById[localSession.eventIdentifier] != nil) ||
                ((localSession.eventExternalIdentifier?.isEmpty == false) &&
                 remoteEventsByExternalId[localSession.eventExternalIdentifier ?? ""] != nil)

            if !hasRemoteMatch {
                // Remote event not found - this could mean:
                // 1. Event was deleted remotely (but we should preserve local session)
                // 2. Event exists outside current fetch range
                // 3. Event hasn't been synced yet
                // 4. Event is in a different calendar
                // 
                // For now, we'll preserve the local session and log the situation
                missingRemoteCount += 1
                print("[SyncService] Local session '\(localSession.title)' has no matching remote event (eventIdentifier: \(localSession.eventIdentifier), external: \(localSession.eventExternalIdentifier ?? "nil")). Preserving local session.")
            }
        }
        if missingRemoteCount > 0 {
            print("[SyncService] Found \(missingRemoteCount) local sessions without matching remote events. All preserved.")
        }
        
        // Save context if there are changes
        do {
            try modelContext.save()
            print("[SyncService] Successfully saved context after external changes")
        } catch {
            print("[SyncService] Error saving after pull: \(error.localizedDescription)")
        }
    }
    
    private func handleSyncEnabledChange(isEnabled: Bool) {
        if isEnabled && accessGranted {
            Task { await fetchAvailableCalendars() }
        } else {
            self.availableCalendars = []
        }
    }

    private struct SerializedAlarm: Codable {
        let relativeOffset: TimeInterval?
        let absoluteDate: Date?
        let proximityRaw: Int?
        let structuredTitle: String?
        let latitude: Double?
        let longitude: Double?
    }
    
    private func normalizeLocationText(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let normalized = rawValue
            .replacingOccurrences(of: "\n", with: ", ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
    
    private func preferredLocation(from event: EKEvent) -> String? {
        EventKitLocationParser.preferredLocation(from: event)
    }
    
    private func serializeAlarms(_ alarms: [EKAlarm]?) -> Data? {
        guard let alarms, !alarms.isEmpty else { return nil }
        
        let payload = alarms.map { alarm in
            let coordinate = alarm.structuredLocation?.geoLocation?.coordinate
            return SerializedAlarm(
                relativeOffset: alarm.absoluteDate == nil ? alarm.relativeOffset : nil,
                absoluteDate: alarm.absoluteDate,
                proximityRaw: alarm.proximity.rawValue,
                structuredTitle: alarm.structuredLocation?.title,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude
            )
        }
        
        return try? JSONEncoder().encode(payload)
    }
    
    private func deserializeAlarms(_ data: Data?) -> [EKAlarm]? {
        guard let data else { return nil }
        
        if let payload = try? JSONDecoder().decode([SerializedAlarm].self, from: data) {
            return payload.compactMap { item in
                let alarm: EKAlarm
                if let absoluteDate = item.absoluteDate {
                    alarm = EKAlarm(absoluteDate: absoluteDate)
                } else if let relativeOffset = item.relativeOffset {
                    alarm = EKAlarm(relativeOffset: relativeOffset)
                } else {
                    return nil
                }
                
                if let proximityRaw = item.proximityRaw,
                   let proximity = EKAlarmProximity(rawValue: proximityRaw) {
                    alarm.proximity = proximity
                }
                
                if item.structuredTitle != nil || (item.latitude != nil && item.longitude != nil) {
                    let structuredLocation = EKStructuredLocation(title: item.structuredTitle ?? "Reminder")
                    if let latitude = item.latitude, let longitude = item.longitude {
                        structuredLocation.geoLocation = CLLocation(latitude: latitude, longitude: longitude)
                    }
                    alarm.structuredLocation = structuredLocation
                }
                
                return alarm
            }
        }
        
        // Backward compatibility: support previously archived EKAlarm arrays if present.
        if let legacyAlarms = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [EKAlarm] {
            return legacyAlarms
        }
        
        return nil
    }

    private func hasCoordinates(latitude: Double, longitude: Double) -> Bool {
        latitude != 0 || longitude != 0
    }

    private func resolvedCoordinate(for session: SessionEntity) -> CLLocationCoordinate2D? {
        if hasCoordinates(latitude: session.sessionLatitude, longitude: session.sessionLongitude) {
            return CLLocationCoordinate2D(latitude: session.sessionLatitude, longitude: session.sessionLongitude)
        }

        if let address = session.address,
           hasCoordinates(latitude: address.latitude, longitude: address.longitude) {
            return CLLocationCoordinate2D(latitude: address.latitude, longitude: address.longitude)
        }

        return nil
    }

    private func resolvedLocationText(for session: SessionEntity) -> String? {
        let explicitLocation = normalizeLocationText(session.location)
        if explicitLocation != nil {
            return explicitLocation
        }

        if let addressText = normalizeLocationText(session.address?.fullAddressText) {
            return addressText
        }

        return normalizeLocationText(session.address?.fullFormattedAddress)
    }

    private func applyParsedAddressToSession(
        _ parsedLocation: EventKitLocationParser.ParsedLocation,
        session: SessionEntity
    ) {
        guard parsedLocation.hasAnyAddressData else {
            session.address = nil
            return
        }

        let addressEntity: AddressEntity
        if let existingAddress = session.address {
            addressEntity = existingAddress
        } else {
            let createdAddress = AddressEntity()
            createdAddress.id = session.id
            if createdAddress.modelContext == nil {
                session.modelContext?.insert(createdAddress)
            }
            session.address = createdAddress
            addressEntity = createdAddress
        }

        addressEntity.id = session.id
        addressEntity.unitNumber = parsedLocation.unitNumber
        addressEntity.streetNumber = parsedLocation.streetNumber
        addressEntity.streetName = parsedLocation.streetName
        addressEntity.suburb = parsedLocation.suburb
        addressEntity.city = parsedLocation.city
        addressEntity.state = parsedLocation.state
        addressEntity.postcode = parsedLocation.postcode
        addressEntity.country = parsedLocation.country
        addressEntity.poBox = parsedLocation.poBox
        addressEntity.fullAddressText = parsedLocation.fullAddressText

        if parsedLocation.hasCoordinates {
            addressEntity.latitude = parsedLocation.latitude
            addressEntity.longitude = parsedLocation.longitude
        } else {
            addressEntity.latitude = 0
            addressEntity.longitude = 0
        }
    }
    
    private func firstNonEmptyString(_ values: String?...) -> String? {
        values.first(where: {
            guard let value = $0 else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) ?? nil
    }

    private func mergedParsedLocation(
        primary: EventKitLocationParser.ParsedLocation,
        fallback: EventKitLocationParser.ParsedLocation,
        preferredLocationOverride: String?
    ) -> EventKitLocationParser.ParsedLocation {
        let shouldPreferFallbackAddress = !primary.hasGranularAddressData && !fallback.fullAddressText.isEmpty
        let resolvedPreferredLocation = firstNonEmptyString(
            preferredLocationOverride,
            primary.preferredLocation,
            fallback.preferredLocation
        )
        let resolvedFullAddress = shouldPreferFallbackAddress
            ? fallback.fullAddressText
            : (firstNonEmptyString(
                primary.fullAddressText,
                fallback.fullAddressText,
                resolvedPreferredLocation
            ) ?? "")

        let resolvedSuburb = firstNonEmptyString(primary.suburb, fallback.suburb, primary.city, fallback.city) ?? ""
        let resolvedCity = firstNonEmptyString(primary.city, fallback.city, resolvedSuburb) ?? ""
        let resolvedLatitude = primary.hasCoordinates ? primary.latitude : fallback.latitude
        let resolvedLongitude = primary.hasCoordinates ? primary.longitude : fallback.longitude

        return EventKitLocationParser.ParsedLocation(
            preferredLocation: resolvedPreferredLocation,
            fullAddressText: resolvedFullAddress,
            unitNumber: firstNonEmptyString(primary.unitNumber, fallback.unitNumber) ?? "",
            streetNumber: firstNonEmptyString(primary.streetNumber, fallback.streetNumber) ?? "",
            streetName: firstNonEmptyString(primary.streetName, fallback.streetName) ?? "",
            suburb: resolvedSuburb,
            city: resolvedCity,
            state: firstNonEmptyString(primary.state, fallback.state) ?? "",
            postcode: firstNonEmptyString(primary.postcode, fallback.postcode) ?? "",
            country: firstNonEmptyString(primary.country, fallback.country) ?? "",
            poBox: firstNonEmptyString(primary.poBox, fallback.poBox) ?? "",
            latitude: resolvedLatitude,
            longitude: resolvedLongitude
        )
    }

    private func reverseGeocodeCacheKey(for coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.6f,%.6f", coordinate.latitude, coordinate.longitude)
    }

    private func parsedLocation(for remoteEvent: EKEvent) async -> EventKitLocationParser.ParsedLocation {
        let baseParsedLocation = EventKitLocationParser.parse(event: remoteEvent)
        guard baseParsedLocation.hasCoordinates else {
            return baseParsedLocation
        }

        let shouldReverseGeocode = !baseParsedLocation.hasGranularAddressData || baseParsedLocation.fullAddressText.isEmpty
        guard shouldReverseGeocode else {
            return baseParsedLocation
        }

        let coordinate = CLLocationCoordinate2D(
            latitude: baseParsedLocation.latitude,
            longitude: baseParsedLocation.longitude
        )
        let preferredLocationOverride = firstNonEmptyString(
            normalizeLocationText(remoteEvent.location),
            normalizeLocationText(remoteEvent.structuredLocation?.title)
        )
        let cacheKey = reverseGeocodeCacheKey(for: coordinate)
        if let cached = reverseGeocodeCache[cacheKey] {
            return mergedParsedLocation(
                primary: baseParsedLocation,
                fallback: cached,
                preferredLocationOverride: preferredLocationOverride
            )
        }

        do {
            guard let reverseGeocoded = try await MapKitAddressResolver.parseAddress(from: coordinate) else {
                return baseParsedLocation
            }
            reverseGeocodeCache[cacheKey] = reverseGeocoded
            return mergedParsedLocation(
                primary: baseParsedLocation,
                fallback: reverseGeocoded,
                preferredLocationOverride: preferredLocationOverride
            )
        } catch {
            print("[EventKitSyncService] Reverse geocode failed for EKEvent \(remoteEvent.eventIdentifier ?? "<unknown>"): \(error.localizedDescription)")
            return baseParsedLocation
        }
    }

    private func applyRemoteEventToSession(
        remoteEvent: EKEvent,
        session: SessionEntity,
        includeCoreFields: Bool
    ) async {
        let parsedLocation = await parsedLocation(for: remoteEvent)

        if includeCoreFields {
            let trimmedTitle = remoteEvent.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            session.title = (trimmedTitle?.isEmpty == false) ? (trimmedTitle ?? "Untitled") : "Untitled"
            session.startTime = remoteEvent.startDate
            session.endTime = remoteEvent.endDate
            session.isAllDay = remoteEvent.isAllDay
            session.location = firstNonEmptyString(
                normalizeLocationText(remoteEvent.location),
                normalizeLocationText(remoteEvent.structuredLocation?.title),
                parsedLocation.preferredLocation
            )
            session.notes = remoteEvent.notes
            session.occurrenceDate = remoteEvent.occurrenceDate
        }

        // Preserve temporal anchor identity for recurring instances/exceptions.
        if let occurrenceDate = remoteEvent.occurrenceDate {
            session.occurrenceDate = occurrenceDate
        } else if includeCoreFields {
            session.occurrenceDate = nil
        }
        
        session.eventIdentifier = remoteEvent.eventIdentifier ?? ""
        session.eventExternalIdentifier = remoteEvent.calendarItemExternalIdentifier
        session.calendarIdentifier = remoteEvent.calendar.calendarIdentifier
        session.calendarSourceIdentifier = remoteEvent.calendar.source?.sourceIdentifier
        session.lastModifiedDate = remoteEvent.lastModifiedDate
        session.lastSyncTag = encodeSyncTag(remoteEvent.lastModifiedDate ?? Date())
        session.ekCreationDate = remoteEvent.creationDate
        session.ekEventAvailabilityRaw = Int16(remoteEvent.availability.rawValue)
        session.ekEventStatusRaw = Int16(remoteEvent.status.rawValue)
        session.organizerName = remoteEvent.organizer?.name
        session.organizerURL = remoteEvent.organizer?.url.absoluteString
        session.timeZone = remoteEvent.timeZone?.identifier
        session.url = remoteEvent.url?.absoluteString
        session.attendeesCount = Int32(remoteEvent.attendees?.count ?? 0)
        session.googleColorId = GoogleCalendarColors.getGoogleEventColorId(remoteEvent)
        
        session.hasEKAlarms = !(remoteEvent.alarms?.isEmpty ?? true)
        session.alarmsData = serializeAlarms(remoteEvent.alarms)
        
        if let rules = remoteEvent.recurrenceRules, let firstRule = rules.first {
            session.recurrenceRuleData = RecurrenceRuleManager.shared.serialize(firstRule)
            session.ekRecurrenceRuleDescription = rules.map(\.description).joined(separator: "\n")
        } else {
            session.recurrenceRuleData = nil
            session.ekRecurrenceRuleDescription = nil
        }
        
        if parsedLocation.hasCoordinates {
            session.sessionLatitude = parsedLocation.latitude
            session.sessionLongitude = parsedLocation.longitude
        } else if includeCoreFields {
            session.sessionLatitude = 0
            session.sessionLongitude = 0
        }

        if includeCoreFields {
            applyParsedAddressToSession(parsedLocation, session: session)
        }
    }
    
    private func mapSessionToEvent(
        _ session: SessionEntity,
        event: EKEvent,
        preserveExistingMetadata: Bool = false
    ) {
        event.title = session.title
        event.startDate = session.startTime
        event.endDate = session.endTime
        event.isAllDay = session.isAllDay
        event.location = resolvedLocationText(for: session)
        
        // Only store the session's notes, not any app-specific or internal data
        event.notes = session.notes
        
        if let timeZoneIdentifier = session.timeZone,
           !timeZoneIdentifier.isEmpty,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            event.timeZone = timeZone
        } else if !preserveExistingMetadata {
            event.timeZone = nil
        }
        
        if let rawURL = session.url?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawURL.isEmpty,
           let parsedURL = URL(string: rawURL) {
            event.url = parsedURL
        } else if !preserveExistingMetadata {
            event.url = nil
        }
        
        // Map recurrence
        if let ruleData = session.recurrenceRuleData,
           let rule = RecurrenceRuleManager.shared.deserialize(ruleData) {
            event.recurrenceRules = [rule]
        } else {
            event.recurrenceRules = nil
        }
        
        if session.hasEKAlarms || session.alarmsData != nil {
            event.alarms = deserializeAlarms(session.alarmsData)
        } else if !preserveExistingMetadata {
            event.alarms = nil
        }
        
        if let coordinate = resolvedCoordinate(for: session) {
            let structuredTitle = resolvedLocationText(for: session) ?? session.title
            let structuredLocation = EKStructuredLocation(title: structuredTitle)
            structuredLocation.geoLocation = CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            event.structuredLocation = structuredLocation
            if event.location == nil {
                event.location = structuredTitle
            }
        } else if !preserveExistingMetadata {
            event.structuredLocation = nil
        }
    }

    /// Update a SessionEntity from a remote EKEvent (used for preferCalendar and auto-resolve)
    public func updateSessionFromRemote(session: SessionEntity, remoteEvent: EKEvent, modelContext _: ModelContext) async {
        await applyRemoteEventToSession(remoteEvent: remoteEvent, session: session, includeCoreFields: true)
        // No explicit save needed in SwiftData; changes are auto-tracked
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
            let events = fetchEvents(start: start, end: end, calendars: [event.calendar])
            for occ in events {
                let belongsToSeries = (
                    (occ.calendarItemExternalIdentifier ?? "") == (event.calendarItemExternalIdentifier ?? "")
                ) || (
                    (occ.eventIdentifier ?? "") == (event.eventIdentifier ?? "")
                )
                guard belongsToSeries else { continue }

                // `occurrenceDate` is the stable temporal anchor for modified instances.
                if let occurrenceDate = occ.occurrenceDate {
                    result[occurrenceDate] = occ
                    continue
                }

                // Fallback for providers that surface detached instances without occurrenceDate.
                if (occ.eventIdentifier ?? "") != (event.eventIdentifier ?? "") {
                    result[occ.startDate] = occ
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
        let resolver = EntityResolutionService(context: modelContext)
        guard let uuid = UUID(uuidString: sessionID),
              let session = try? resolver.resolveSession(id: uuid) else { return }
        
        // Re-fetch local instance if needed
        var local: SessionEntity? = nil
        if let localIDStr = localID, let localUUID = UUID(uuidString: localIDStr) {
            local = try? resolver.resolveSession(id: localUUID)
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
                case .preferApp, .localWins:
                    merged[date] = (l, nil)
                case .preferCalendar, .remoteWins:
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
                // If both exist and policy is .prompt, defer to the conflict queue.
                if localInstance != nil && remoteInstance != nil && conflictResolutionPolicy == .prompt {
                    continue
                }
                if let local = localInstance, remoteInstance == nil {
                    // Local only: ensure this instance is saved locally and pushed to remote if needed
                    // --- PUSH LOGIC ---
                    let ekEvent: EKEvent
                    let isExistingEvent: Bool
                    if let existing = self.findRemoteEvent(for: local) {
                        ekEvent = existing
                        isExistingEvent = true
                    } else {
                        ekEvent = EKEvent(eventStore: self.eventStore)
                        ekEvent.calendar = self.selectedCalendar
                        isExistingEvent = false
                    }
                    self.mapSessionToEvent(
                        local,
                        event: ekEvent,
                        preserveExistingMetadata: isExistingEvent
                    )
                    ekEvent.recurrenceRules = nil
                    do {
                        try self.eventStore.save(ekEvent, span: .thisEvent, commit: true)
                        await self.applyRemoteEventToSession(
                            remoteEvent: ekEvent,
                            session: local,
                            includeCoreFields: false
                        )
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
                    
                    await self.applyRemoteEventToSession(
                        remoteEvent: remote,
                        session: detached,
                        includeCoreFields: true
                    )
                    detached.status = session.status
                    detached.recurrenceRuleData = nil
                    detached.ekRecurrenceRuleDescription = nil
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
                    let isExistingEvent: Bool
                    if let existing = self.findRemoteEvent(for: local) {
                        ekEvent = existing
                        isExistingEvent = true
                    } else {
                        ekEvent = EKEvent(eventStore: self.eventStore)
                        ekEvent.calendar = self.selectedCalendar
                        isExistingEvent = false
                    }
                    self.mapSessionToEvent(
                        local,
                        event: ekEvent,
                        preserveExistingMetadata: isExistingEvent
                    )
                    ekEvent.recurrenceRules = nil
                    do {
                        try self.eventStore.save(ekEvent, span: .thisEvent, commit: true)
                        await self.applyRemoteEventToSession(
                            remoteEvent: ekEvent,
                            session: local,
                            includeCoreFields: false
                        )
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
                    
                    await self.applyRemoteEventToSession(
                        remoteEvent: remote,
                        session: detached,
                        includeCoreFields: true
                    )
                    detached.status = session.status
                    detached.client = session.client
                    detached.clientService = session.clientService
                    detached.recurrenceRuleData = nil
                    detached.ekRecurrenceRuleDescription = nil
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
