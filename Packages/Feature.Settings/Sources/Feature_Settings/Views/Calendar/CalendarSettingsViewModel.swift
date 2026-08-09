import Foundation
import SwiftUI
import EventKit
import Combine
import SwiftData
import Core
import DataInterfaces
import SharedUI
import Observation

/// ViewModel for CalendarSettingsView, mediating between CalendarPreferences, EventKitSyncService, and the UI.
@Observable
@MainActor
public class CalendarSettingsViewModel {
    // MARK: - Dependencies
    let preferences: CalendarPreferencesStore
    private let eventKitService: any CalendarIntegrationService
    private let sessionWiper: any CalendarSessionWiping

    // MARK: - UI State
    var showingInvalidCalendarAlert: Bool = false
    var showCreateCalendarSheet: Bool = false
    var isLoading: Bool = false
    var errorMessage: String? = nil
    
    
    var showingResetConfirmation: Bool = false
    var showingClearSessionsConfirmation: Bool = false

    // MARK: - Reactive State Properties
    private(set) var accessGranted: Bool = false
    private(set) var availableCalendars: [EKCalendar] = []
    private(set) var writableCalendars: [EKCalendar] = []
    private(set) var calendarLabels: [EKCalendar: String] = [:]
    private(set) var monitoredCalendarOptions: [CalendarIdentifier] = []
    private(set) var selectedMonitoredCalendars: Set<CalendarIdentifier> = []
    
    // MARK: - Validation State
    var calendarErrorText: String? = nil
    var recurrenceErrorText: String? = nil
    var recurrenceHelperText: String? = nil

    // MARK: - CalendarIdentifier Wrapper
    struct CalendarIdentifier: Identifiable, Hashable {
        let id: String // calendarIdentifier
        let title: String
    }

    // MARK: - Initialization
    public init(
        preferencesStore: CalendarPreferencesStore,
        eventKitService: any CalendarIntegrationService,
        sessionWiper: any CalendarSessionWiping
    ) {
        self.preferences = preferencesStore
        self.eventKitService = eventKitService
        self.sessionWiper = sessionWiper
        setupStateObservers()
        initializeState()
    }

    // MARK: - Private State Management
    private var cancellables = Set<AnyCancellable>()

    private func setupStateObservers() {
        // Observe EventKitSyncService state changes
        eventKitService.accessGrantedPublisher
            .sink { [weak self] granted in
                self?.accessGranted = granted
                self?.validateCalendarSelection()
            }
            .store(in: &cancellables)

        eventKitService.availableCalendarsPublisher
            .sink { [weak self] calendars in
                self?.availableCalendars = calendars
                self?.updateWritableCalendars()
                self?.updateCalendarLabels()
                self?.updateMonitoredCalendarOptions()
                self?.updateSelectedMonitoredCalendars()
                self?.validateCalendarSelection()
            }
            .store(in: &cancellables)

    }

    private func initializeState() {
        // Initialize state from current EventKitSyncService state
        accessGranted = eventKitService.accessGranted
        availableCalendars = eventKitService.availableCalendars
        updateWritableCalendars()
        updateCalendarLabels()
        updateMonitoredCalendarOptions()
        updateSelectedMonitoredCalendars()
        
        // Perform initial validation
        validateCalendarSelection()
        validateRecurrenceDefaults()
        
        // Fetch calendars if access is granted but no calendars are available
        if accessGranted && availableCalendars.isEmpty {
            Task {
                await performManualSync()
            }
        }
    }

    private func updateWritableCalendars() {
        writableCalendars = availableCalendars.filter { $0.allowsContentModifications }
    }

    private func updateCalendarLabels() {
        calendarLabels = Dictionary(uniqueKeysWithValues: writableCalendars.map { ($0, $0.title) })
    }

    private func updateMonitoredCalendarOptions() {
        monitoredCalendarOptions = writableCalendars.map { CalendarIdentifier(id: $0.calendarIdentifier, title: $0.title) }
    }

    private func updateSelectedMonitoredCalendars() {
        let selectedIds = preferences.monitoredCalendarIdentifiers
        selectedMonitoredCalendars = Set(monitoredCalendarOptions.filter { selectedIds.contains($0.id) })
    }

    // MARK: - Public Interface for Calendar Selection
    func updateSelectedMonitoredCalendars(_ newSelection: Set<CalendarIdentifier>) {
        let newIds = Set(newSelection.map { $0.id })
        preferences.monitoredCalendarIdentifiers = newIds
        selectedMonitoredCalendars = newSelection
    }

    // MARK: - Validation Methods
    func validateCalendarSelection() {
        let selection = preferences.selectedCalendarIdentifier
        if selection.isEmpty {
            showingInvalidCalendarAlert = false
            calendarErrorText = nil
            return
        }
        
        let valid = writableCalendars.contains { $0.calendarIdentifier == selection }
        if !valid {
            showingInvalidCalendarAlert = true
            calendarErrorText = "Selected calendar is not available or not writable."
            // Auto-select first available writable calendar if needed
            if let first = writableCalendars.first {
                preferences.selectedCalendarIdentifier = first.calendarIdentifier
            }
        } else {
            showingInvalidCalendarAlert = false
            calendarErrorText = nil
        }
    }

    func validateRecurrenceDefaults() {
        recurrenceErrorText = nil
        recurrenceHelperText = nil
        
        // Interval must be > 0
        if preferences.defaultRecurrenceInterval < 1 {
            recurrenceErrorText = "Repeat interval must be at least 1."
        }
        
        // Weekly: at least one weekday
        if preferences.defaultRecurrenceFrequency == .weekly && preferences.defaultSelectedWeekdays.isEmpty {
            recurrenceErrorText = "Select at least one day of the week."
        }
        
        // Monthly: if onSpecificDays, at least one day
        if preferences.defaultRecurrenceFrequency == .monthly &&
           preferences.defaultMonthlyRecurrenceType == .onSpecificDays &&
           preferences.defaultSelectedMonthDaysNumbers.isEmpty {
            recurrenceErrorText = "Select at least one day of the month."
        }
        
        // Yearly: if onSpecificDays, at least one day and month
        if preferences.defaultRecurrenceFrequency == .yearly &&
           preferences.defaultYearlyRecurrenceType == .onSpecificDays {
            if preferences.defaultSelectedYearlyDaysNumbers.isEmpty {
                recurrenceErrorText = "Select at least one day of the year."
            }
            if preferences.defaultSelectedYearMonths.isEmpty {
                recurrenceErrorText = "Select at least one month."
            }
        }
        
        // End date must be in the future
        if preferences.defaultRecurrenceEndType == .onDate && preferences.defaultRecurrenceEndDate < Date() {
            recurrenceErrorText = "End date must be in the future."
        }
        
        // Helper text for recurrence
        if preferences.defaultRecurrenceFrequency != .none {
            recurrenceHelperText = "These defaults will be used for all new sessions."
        }
    }

    // MARK: - Actions
    @MainActor
    func requestAccess() async {
        print("[CalendarSettingsViewModel] User requested calendar access")
        isLoading = true
        errorMessage = nil
        
        let granted = await eventKitService.requestAccess()
        print("[CalendarSettingsViewModel] Access request completed: granted=\(granted)")
        
        isLoading = false
        if !granted {
            errorMessage = "Calendar access was not granted."
            print("[CalendarSettingsViewModel] Access denied, showing error message")
        } else {
            print("[CalendarSettingsViewModel] Access granted successfully")
            errorMessage = nil
        }
    }

    @MainActor
    func performManualSync() async {
        isLoading = true
        errorMessage = nil
        
        await eventKitService.fetchAvailableCalendars()
        
        isLoading = false
    }

    @MainActor
    func checkCurrentAccessStatus() {
        print("[CalendarSettingsViewModel] Current access status check:")
        print("  - Access granted: \(accessGranted)")
        print("  - Available calendars: \(writableCalendars.count)")
        print("  - Selected calendar: \(preferences.selectedCalendarIdentifier)")
        print("  - Sync enabled: \(preferences.syncEnabled)")
        print("  - Sync direction: \(preferences.syncDirection.rawValue)")
    }

    @MainActor
    func createNewCalendar(title: String, color: CGColor?) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await eventKitService.createCalendar(title: title, color: color)
                isLoading = false
            } catch {
                isLoading = false
                errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Calendar Color Management
    func updateCalendarColor(calendarIdentifier: String, color: Color) {
        var currentPreferences = preferences.perCalendarPreferences
        var calendarSettings = currentPreferences[calendarIdentifier] ?? CalendarPerCalendarSettings(colorHex: nil, isMonitored: false, customSyncDirection: nil)
        
        // Store color as hex for backward compatibility
        // Note: Calendar colors support arbitrary user selections, so we store hex values
        // The color system is used primarily for client/domain entity colors, not user-customizable calendar colors
        let hexString = color.toHex()
        calendarSettings.colorHex = hexString
        
        currentPreferences[calendarIdentifier] = calendarSettings
        preferences.perCalendarPreferences = currentPreferences
        
    }
    
    func getCalendarColor(calendarIdentifier: String) -> Color? {
        guard let calendarSettings = preferences.perCalendarPreferences[calendarIdentifier],
              let hexString = calendarSettings.colorHex else {
            return nil
        }
        // Use the new color system to migrate from hex
        return ColorSystem.migrateFromHex(hexString)
    }

    func clearAllSessions() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await sessionWiper.wipeAllSessions()
        } catch {
            errorMessage = "Failed to delete sessions: \(error.localizedDescription)"
        }
    }
}
