import Foundation
import EventKit
import SwiftUI
import Combine
import SwiftData
import CoreLocation
import Core
import PersistenceModels
import Observation
import os

// MARK: - EventKitSyncService
/// EventKitSyncService manages all EventKit operations and state.
@Observable
@MainActor
public final class EventKitSyncService {
    public let eventStore = EKEventStore()
    var isSyncing = false
    var reverseGeocodeCache: [String: EventKitLocationParser.ParsedLocation] = [:]
    var externalChangeSnapshot: [String: Date] = [:]
    let maxEventFetchWindowYears = 4
    let preferencesStore: any CalendarPreferencesStoreProtocol
    let recurrenceRuleManager: Core.RecurrenceRuleManager

    var sessionWriter: EventKitSessionWriter {
        EventKitSessionWriter(
            recurrenceRuleManager: recurrenceRuleManager,
            parsedLocation: { event in await self.parsedLocation(for: event) },
            encodeSyncTag: { self.encodeSyncTag($0) },
            serializeAlarms: { self.serializeAlarms($0) },
            normalizeLocationText: { self.normalizeLocationText($0) },
            firstNonEmptyString: { a, b, c in self.firstNonEmptyString(a, b, c) },
            applyParsedAddressToSession: { loc, session in self.applyParsedAddressToSession(loc, session: session) },
            resolvedCoordinate: { self.resolvedCoordinate(forSnapshot: $0) }
        )
    }
    @ObservationIgnored let accessGrantedSubject = CurrentValueSubject<Bool, Never>(false)
    @ObservationIgnored let availableCalendarsSubject = CurrentValueSubject<[EKCalendar], Never>([])

    static let syncTagWriteFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let syncTagReadFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let internetDateTime = ISO8601DateFormatter()
        internetDateTime.formatOptions = [.withInternetDateTime]

        return [withFractional, internetDateTime]
    }()

    static let legacySyncTagFormatter: DateFormatter = {
        // Parses legacy EventKit sync tags written as `ExportMachineFormatting.eventKitLegacySyncTag`.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()

    // MARK: - Published Properties for Settings
    public var accessGranted: Bool = false {
        didSet { accessGrantedSubject.send(accessGranted) }
    }
    public var availableCalendars: [EKCalendar] = [] {
        didSet { availableCalendarsSubject.send(availableCalendars) }
    }
    public var selectedCalendarIdentifier: String {
        get { preferencesStore.selectedCalendarIdentifier }
        set { preferencesStore.selectedCalendarIdentifier = newValue }
    }
    public var monitoredCalendarIdentifiers: Set<String> {
        get { preferencesStore.monitoredCalendarIdentifiers }
        set { preferencesStore.monitoredCalendarIdentifiers = newValue }
    }
    public var syncEnabled: Bool {
        get { preferencesStore.syncEnabled }
        set {
            let wasEnabled = preferencesStore.syncEnabled
            preferencesStore.syncEnabled = newValue
            if wasEnabled && !newValue {
                cancelActiveSyncTasks()
            }
        }
    }
    public var syncDirection: CalendarPreferences.SyncDirection {
        get { preferencesStore.syncDirection }
        set { preferencesStore.syncDirection = newValue }
    }
    public var conflictResolutionPolicy: CalendarPreferences.ConflictResolutionPolicy {
        get { preferencesStore.conflictResolutionPolicy }
        set { preferencesStore.conflictResolutionPolicy = newValue }
    }
    public var syncGoogleColors: Bool {
        get { preferencesStore.syncGoogleColors }
        set { preferencesStore.syncGoogleColors = newValue }
    }
    public var autoResolveRecurringConflicts: Bool {
        get { preferencesStore.autoResolveRecurringConflicts }
        set { preferencesStore.autoResolveRecurringConflicts = newValue }
    }

    var error: Error?
    var isLoadingCalendars: Bool = false
    
    // MARK: - Sync Status
    public var syncStatus: SyncStatus = .idle
    public var lastSyncDate: Date?
    public var syncProgress: Double = 0.0
    

    // --- Conflict Prompt System ---
    var pendingConflict: ConflictPrompt? = nil
    struct ConflictPrompt {
        /// Master (series) session id — refetch via `EntityResolutionService` before mutations.
        let sessionID: UUID
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
                let sessionID = prompt.sessionID
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let resolver = EntityResolutionService(context: modelContext)
                    guard let session = try? resolver.resolveSession(id: sessionID) else { return }
                    _ = await self.updateSessionFromRemote(
                        snapshot: session.snapshot(),
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

    var cancellables = Set<AnyCancellable>()

    @ObservationIgnored var activeOutboundSyncTask: Task<Void, Never>?
    @ObservationIgnored var activeRecurringMergeTask: Task<Void, Never>?
    @ObservationIgnored var activeDeleteTask: Task<Void, Never>?

    func cancelActiveSyncTasks() {
        activeOutboundSyncTask?.cancel()
        activeOutboundSyncTask = nil
        activeRecurringMergeTask?.cancel()
        activeRecurringMergeTask = nil
        activeDeleteTask?.cancel()
        activeDeleteTask = nil
    }

    deinit {
        activeOutboundSyncTask?.cancel()
        activeRecurringMergeTask?.cancel()
        activeDeleteTask?.cancel()
    }

    public var accessGrantedPublisher: AnyPublisher<Bool, Never> {
        accessGrantedSubject.eraseToAnyPublisher()
    }

    public var availableCalendarsPublisher: AnyPublisher<[EKCalendar], Never> {
        availableCalendarsSubject.eraseToAnyPublisher()
    }

    public init(
        preferencesStore: any CalendarPreferencesStoreProtocol,
        recurrenceRuleManager: Core.RecurrenceRuleManager,
        startsLiveObservation: Bool = true
    ) {
        self.preferencesStore = preferencesStore
        self.recurrenceRuleManager = recurrenceRuleManager
        guard startsLiveObservation else {
            syncStatus = .idle
            return
        }
        Logger.data.debug("EventKitSyncService initializing")
        NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: eventStore)
            .debounce(for: .seconds(2), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    Logger.data.debug("Event store changed; refreshing calendar list")
                    self.checkInitialAccessAndFetchCalendars()
                }
            }
            .store(in: &cancellables)
        checkInitialAccessAndFetchCalendars()
        Logger.data.debug("EventKitSyncService initialization complete")

        syncStatus = accessGranted ? .idle : .error
        observeSyncEnabledPreference()
    }

    private func observeSyncEnabledPreference() {
        withObservationTracking { [preferencesStore] in
            _ = preferencesStore.syncEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if !self.preferencesStore.syncEnabled {
                    self.cancelActiveSyncTasks()
                }
                self.observeSyncEnabledPreference()
            }
        }
    }

    func encodeSyncTag(_ date: Date?) -> String? {
        guard let date else { return nil }
        return Self.syncTagWriteFormatter.string(from: date)
    }

    func decodeSyncTag(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        for formatter in Self.syncTagReadFormatters {
            if let parsed = formatter.date(from: rawValue) {
                return parsed
            }
        }

        return Self.legacySyncTagFormatter.date(from: rawValue)
    }

    func identityKeys(for event: EKEvent) -> [String] {
        EventKitSyncIdentityKeys.identityKeys(for: event)
    }

    func identityKeys(for snapshot: EventKitEventSnapshot) -> [String] {
        EventKitSyncIdentityKeys.identityKeys(for: snapshot)
    }

    func identityKeys(for snapshot: SessionSnapshot) -> [String] {
        EventKitSyncIdentityKeys.identityKeys(for: snapshot)
    }

    // MARK: - Session ← Remote Event

    /// Update a local Session model from a remote EKEvent.
    /// Used by conflict resolution (preferCalendar) and external-change pull.
    public func updateSessionFromRemote(snapshot: SessionSnapshot, remoteEvent: EKEvent, modelContext: ModelContext) async -> SessionSnapshot {
        let resolver = EntityResolutionService(context: modelContext)
        guard let sessionModel = try? resolver.resolveSession(id: snapshot.id) else { return snapshot }
        let includeCoreFields = EventKitSyncPolicy.shouldIncludeCoreFieldsOnPull(for: sessionModel)
        await applyRemoteEventToSession(
            remoteEvent: remoteEvent,
            session: sessionModel,
            includeCoreFields: includeCoreFields
        )
        return SessionSnapshot(sessionModel)
    }

    // --- Per-Instance Conflict Queue ---
    /// SwiftData context for the sync that produced `pendingInstanceConflicts` (main-thread UI context only).
    var instanceConflictResolutionContext: ModelContext?
    var pendingInstanceConflicts: [(date: Date, masterSessionID: String, remoteEvent: EKEvent?, localDetachedID: String?, remote: EKEvent?)] = []
}
