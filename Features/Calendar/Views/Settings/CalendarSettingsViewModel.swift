import Foundation
import SwiftUI
import EventKit
import Combine // Added for Combine publishers
import SwiftData

/// ViewModel for CalendarSettingsView, mediating between CalendarPreferences, EventKitSyncService, and the UI.
@MainActor
class CalendarSettingsViewModel: ObservableObject {
    // MARK: - Dependencies
    @Published var preferences = CalendarPreferences()
    @Published var eventKitService: EventKitSyncService = .shared

    // MARK: - UI State
    @Published var showingInvalidCalendarAlert: Bool = false
    @Published var showCreateCalendarSheet: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var showingResetConfirmation: Bool = false
    @Published var showingClearSessionsConfirmation: Bool = false

    // MARK: - Computed Properties
    var accessGranted: Bool { eventKitService.accessGranted }
    var accessStatusText: String {
        if eventKitService.accessGranted { return "Calendar Access: Granted" }
        else { return "Calendar Access: Not Granted" }
    }
    var writableCalendars: [EKCalendar] {
        eventKitService.availableCalendars.filter { $0.allowsContentModifications }
    }
    var calendarLabels: [EKCalendar: String] {
        Dictionary(uniqueKeysWithValues: writableCalendars.map { ($0, $0.title) })
    }

    // MARK: - CalendarIdentifier Wrapper
    struct CalendarIdentifier: Identifiable, Hashable {
        let id: String // calendarIdentifier
        let title: String
    }

    /// Expose monitored calendar options as [CalendarIdentifier]
    var monitoredCalendarOptions: [CalendarIdentifier] {
        writableCalendars.map { CalendarIdentifier(id: $0.calendarIdentifier, title: $0.title) }
    }

    /// Convert monitoredCalendarIdentifiers (Set<String>) <-> Set<CalendarIdentifier>
    var selectedMonitoredCalendars: Set<CalendarIdentifier> {
        get {
            Set(preferences.monitoredCalendarIdentifiers.compactMap { id in
                monitoredCalendarOptions.first(where: { $0.id == id })
            })
        }
        set {
            preferences.monitoredCalendarIdentifiers = Set(newValue.map { $0.id })
        }
    }

    // MARK: - Validation & User Feedback
    @Published var calendarErrorText: String? = nil
    @Published var recurrenceErrorText: String? = nil
    @Published var recurrenceHelperText: String? = nil

    /// Validate the selected calendar and provide error feedback if invalid or unwritable.
    func validateCalendarSelection() {
        let selection = preferences.selectedCalendarIdentifier
        if selection.isEmpty {
            // No selection yet, don't show error
            showingInvalidCalendarAlert = false
            calendarErrorText = nil
            return
        }
        let valid = writableCalendars.contains { $0.calendarIdentifier == selection }
        if !valid {
            showingInvalidCalendarAlert = true
            calendarErrorText = "Selected calendar is not available or not writable."
            // Optionally: auto-select first available writable calendar if needed
            if let first = writableCalendars.first {
                preferences.selectedCalendarIdentifier = first.calendarIdentifier
            }
        } else {
            showingInvalidCalendarAlert = false
            calendarErrorText = nil
        }
    }

    /// Validate recurrence defaults and provide error/helper feedback.
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
        if preferences.defaultRecurrenceFrequency == .monthly && preferences.defaultMonthlyRecurrenceType == .onSpecificDays && preferences.defaultSelectedMonthDaysNumbers.isEmpty {
            recurrenceErrorText = "Select at least one day of the month."
        }
        // Yearly: if onSpecificDays, at least one day and month
        if preferences.defaultRecurrenceFrequency == .yearly && preferences.defaultYearlyRecurrenceType == .onSpecificDays {
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

    // Call validation on relevant changes
    private func setupValidationObservers() {
        $preferences
            .sink { [weak self] _ in
                self?.validateCalendarSelection()
                self?.validateRecurrenceDefaults()
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    @MainActor
    func requestAccess() async {
        print("[CalendarSettingsViewModel] User requested calendar access")
        isLoading = true
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
        var calendarSettings = currentPreferences[calendarIdentifier] ?? CalendarPreferences.PerCalendarSettings(colorHex: nil, isMonitored: false, customSyncDirection: nil)
        
        // Convert Color to hex string
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
        return Color(hex: hexString)
    }
    
    func resetCalendarColor(calendarIdentifier: String) {
        var currentPreferences = preferences.perCalendarPreferences
        if var calendarSettings = currentPreferences[calendarIdentifier] {
            calendarSettings.colorHex = nil
            currentPreferences[calendarIdentifier] = calendarSettings
            preferences.perCalendarPreferences = currentPreferences
        }
    }

    func clearAllSessions(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<SessionEntity>()
        do {
            let sessions: [SessionEntity] = try modelContext.fetch(descriptor)
            for session in sessions {
                modelContext.delete(session)
            }
            // No explicit save needed in SwiftData; changes are auto-tracked
            print("All sessions deleted successfully.")
        } catch {
            print("Failed to delete all sessions: \(error)")
        }
    }

    // MARK: - Initialization
    init() {
        setupValidationObservers()
    }

    // MARK: - Private
    private var cancellables = Set<AnyCancellable>()
} 
