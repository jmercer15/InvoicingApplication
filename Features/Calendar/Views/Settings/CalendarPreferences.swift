import Foundation
import SwiftUI

/// Centralized model for all calendar-related user preferences, persisted via @AppStorage.
final class CalendarPreferences: ObservableObject {
    // MARK: - Calendar Selection
    @AppStorage("selectedCalendarIdentifier") var selectedCalendarIdentifier: String = ""
    @AppStorage("monitoredCalendarIdentifiers") private var monitoredCalendarIdentifiersRaw: String = ""
    var monitoredCalendarIdentifiers: Set<String> {
        get { Set(monitoredCalendarIdentifiersRaw.split(separator: ",").map(String.init)) }
        set { monitoredCalendarIdentifiersRaw = newValue.joined(separator: ",") }
    }

    // MARK: - Synchronization
    @AppStorage("syncEnabled") var syncEnabled: Bool = true
    @AppStorage("syncDirection") private var syncDirectionRaw: String = SyncDirection.bidirectional.rawValue
    var syncDirection: SyncDirection {
        get { SyncDirection(rawValue: syncDirectionRaw) ?? .bidirectional }
        set { syncDirectionRaw = newValue.rawValue }
    }
    @AppStorage("syncGoogleColors") var syncGoogleColors: Bool = true

    // MARK: - Conflict Resolution
    @AppStorage("conflictResolutionPolicy") private var conflictResolutionPolicyRaw: String = ConflictResolutionPolicy.prompt.rawValue
    var conflictResolutionPolicy: ConflictResolutionPolicy {
        get { ConflictResolutionPolicy(rawValue: conflictResolutionPolicyRaw) ?? .prompt }
        set { conflictResolutionPolicyRaw = newValue.rawValue }
    }
    @AppStorage("autoResolveRecurringConflicts") var autoResolveRecurringConflicts: Bool = false

    // MARK: - Recurrence Defaults
    @AppStorage("defaultRecurrenceFrequency") private var defaultRecurrenceFrequencyRaw: String = RecurrenceFrequency.none.rawValue
    var defaultRecurrenceFrequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: defaultRecurrenceFrequencyRaw) ?? .none }
        set { defaultRecurrenceFrequencyRaw = newValue.rawValue }
    }
    @AppStorage("defaultRecurrenceInterval") var defaultRecurrenceInterval: Int = 1
    @AppStorage("defaultRecurrenceEndType") private var defaultRecurrenceEndTypeRaw: String = RecurrenceEndType.never.rawValue
    var defaultRecurrenceEndType: RecurrenceEndType {
        get { RecurrenceEndType(rawValue: defaultRecurrenceEndTypeRaw) ?? .never }
        set { defaultRecurrenceEndTypeRaw = newValue.rawValue }
    }
    @AppStorage("defaultRecurrenceCount") var defaultRecurrenceCount: Int = 10
    @AppStorage("defaultRecurrenceEndDate") var defaultRecurrenceEndDate: Date = Date().addingTimeInterval(3600 * 24 * 30)
    @AppStorage("defaultSelectedWeekdays") private var defaultSelectedWeekdaysRaw: String = ""
    var defaultSelectedWeekdays: Set<Int> {
        get { Set(defaultSelectedWeekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedWeekdaysRaw = newValue.map(String.init).joined(separator: ",") }
    }
    @AppStorage("defaultMonthlyRecurrenceType") private var defaultMonthlyRecurrenceTypeRaw: String = PositionalRecurrenceType.onSpecificDays.rawValue
    var defaultMonthlyRecurrenceType: PositionalRecurrenceType {
        get { PositionalRecurrenceType(rawValue: defaultMonthlyRecurrenceTypeRaw) ?? .onSpecificDays }
        set { defaultMonthlyRecurrenceTypeRaw = newValue.rawValue }
    }
    @AppStorage("defaultSelectedMonthDaysNumbers") private var defaultSelectedMonthDaysNumbersRaw: String = ""
    var defaultSelectedMonthDaysNumbers: Set<Int> {
        get { Set(defaultSelectedMonthDaysNumbersRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedMonthDaysNumbersRaw = newValue.map(String.init).joined(separator: ",") }
    }
    @AppStorage("defaultYearlyRecurrenceType") private var defaultYearlyRecurrenceTypeRaw: String = PositionalRecurrenceType.onSpecificDays.rawValue
    var defaultYearlyRecurrenceType: PositionalRecurrenceType {
        get { PositionalRecurrenceType(rawValue: defaultYearlyRecurrenceTypeRaw) ?? .onSpecificDays }
        set { defaultYearlyRecurrenceTypeRaw = newValue.rawValue }
    }
    @AppStorage("defaultSelectedYearlyDaysNumbers") private var defaultSelectedYearlyDaysNumbersRaw: String = ""
    var defaultSelectedYearlyDaysNumbers: Set<Int> {
        get { Set(defaultSelectedYearlyDaysNumbersRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedYearlyDaysNumbersRaw = newValue.map(String.init).joined(separator: ",") }
    }
    @AppStorage("defaultSelectedYearMonths") private var defaultSelectedYearMonthsRaw: String = ""
    var defaultSelectedYearMonths: Set<Int> {
        get { Set(defaultSelectedYearMonthsRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedYearMonthsRaw = newValue.map(String.init).joined(separator: ",") }
    }
    @AppStorage("defaultSelectedOrdinal") var defaultSelectedOrdinal: Int = 1
    @AppStorage("defaultSelectedDayOfWeekForOrdinal") var defaultSelectedDayOfWeekForOrdinal: Int = 4 // Monday

    // MARK: - Enums
    enum SyncDirection: String, CaseIterable, Identifiable, Codable {
        case appToCalendar = "App to Calendar Only"
        case calendarToApp = "Calendar to App Only"
        case bidirectional = "Bidirectional"
        var id: String { rawValue }
    }

    enum ConflictResolutionPolicy: String, CaseIterable, Identifiable {
        case preferApp = "Prefer App Data"
        case preferCalendar = "Prefer Calendar Data"
        case prompt = "Prompt User"
        var id: String { rawValue }
    }

    // MARK: - Per-Calendar Preferences
    @AppStorage("perCalendarPreferences") private var perCalendarPreferencesRaw: String = "{}"
    var perCalendarPreferences: [String: CalendarPreferences.PerCalendarSettings] {
        get {
            (try? JSONDecoder().decode([String: CalendarPreferences.PerCalendarSettings].self, from: Data(perCalendarPreferencesRaw.utf8))) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                perCalendarPreferencesRaw = String(data: data, encoding: .utf8) ?? "{}"
            }
        }
    }
    struct PerCalendarSettings: Codable {
        var colorHex: String?
        var isMonitored: Bool
        var customSyncDirection: SyncDirection?
    }

    // MARK: - Last Sync Status
    @AppStorage("lastSyncStatus") var lastSyncStatus: String = "Never"
    @AppStorage("lastSyncTimestamp") var lastSyncTimestamp: Date = Date.distantPast

    // MARK: - Defaults for New Events
    @AppStorage("defaultReminderMinutes") var defaultReminderMinutes: Int = 30
    @AppStorage("defaultEventDurationMinutes") var defaultEventDurationMinutes: Int = 60

    // MARK: - Reset
    func resetToDefaults() {
        selectedCalendarIdentifier = ""
        monitoredCalendarIdentifiersRaw = ""
        syncEnabled = true
        syncDirectionRaw = SyncDirection.bidirectional.rawValue
        syncGoogleColors = true
        conflictResolutionPolicyRaw = ConflictResolutionPolicy.prompt.rawValue
        autoResolveRecurringConflicts = false
        defaultRecurrenceFrequencyRaw = RecurrenceFrequency.none.rawValue
        defaultRecurrenceInterval = 1
        defaultRecurrenceEndTypeRaw = RecurrenceEndType.never.rawValue
        defaultRecurrenceCount = 10
        defaultRecurrenceEndDate = Date().addingTimeInterval(3600 * 24 * 30)
        defaultSelectedWeekdaysRaw = ""
        defaultMonthlyRecurrenceTypeRaw = PositionalRecurrenceType.onSpecificDays.rawValue
        defaultSelectedMonthDaysNumbersRaw = ""
        defaultYearlyRecurrenceTypeRaw = PositionalRecurrenceType.onSpecificDays.rawValue
        defaultSelectedYearlyDaysNumbersRaw = ""
        defaultSelectedYearMonthsRaw = ""
        defaultSelectedOrdinal = 1
        defaultSelectedDayOfWeekForOrdinal = 4
        perCalendarPreferencesRaw = "{}"
        lastSyncStatus = "Never"
        lastSyncTimestamp = Date.distantPast
        defaultReminderMinutes = 30
        defaultEventDurationMinutes = 60
    }
} 