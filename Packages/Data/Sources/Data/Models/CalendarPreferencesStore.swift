import Core
import Foundation
import Observation

@MainActor
public protocol CalendarPreferencesStoreProtocol: AnyObject {
    var selectedCalendarIdentifier: String { get set }
    var monitoredCalendarIdentifiers: Set<String> { get set }
    var syncEnabled: Bool { get set }
    var syncDirection: CalendarPreferences.SyncDirection { get set }
    var syncGoogleColors: Bool { get set }
    var conflictResolutionPolicy: CalendarPreferences.ConflictResolutionPolicy { get set }
    var autoResolveRecurringConflicts: Bool { get set }
    var defaultRecurrenceFrequency: RecurrenceFrequency { get set }
    var defaultRecurrenceInterval: Int { get set }
    var defaultRecurrenceEndType: RecurrenceEndType { get set }
    var defaultRecurrenceCount: Int { get set }
    var defaultRecurrenceEndDate: Date { get set }
    var defaultSelectedWeekdays: Set<Int> { get set }
    var defaultMonthlyRecurrenceType: PositionalRecurrenceType { get set }
    var defaultSelectedMonthDaysNumbers: Set<Int> { get set }
    var defaultYearlyRecurrenceType: PositionalRecurrenceType { get set }
    var defaultSelectedYearlyDaysNumbers: Set<Int> { get set }
    var defaultSelectedYearMonths: Set<Int> { get set }
    var defaultSelectedOrdinal: Int { get set }
    var defaultSelectedDayOfWeekForOrdinal: Int { get set }
    var perCalendarPreferences: [String: CalendarPerCalendarSettings] { get set }
    var lastSyncStatus: String { get set }
    var lastSyncTimestamp: Date { get set }
    var defaultReminderMinutes: Int { get set }
    var defaultEventDurationMinutes: Int { get set }
    func resetToDefaults()
}

public struct CalendarPerCalendarSettings: Codable, Sendable, Equatable {
    public var colorHex: String?
    public var isMonitored: Bool
    public var customSyncDirection: CalendarPreferences.SyncDirection?

    public init(
        colorHex: String?,
        isMonitored: Bool,
        customSyncDirection: CalendarPreferences.SyncDirection?
    ) {
        self.colorHex = colorHex
        self.isMonitored = isMonitored
        self.customSyncDirection = customSyncDirection
    }
}

@Observable
@MainActor
public final class CalendarPreferencesStore: CalendarPreferencesStoreProtocol {
    private enum Key {
        static let selectedCalendarIdentifier = "selectedCalendarIdentifier"
        static let monitoredCalendarIdentifiers = "monitoredCalendarIdentifiers"
        static let syncEnabled = "syncEnabled"
        static let syncDirection = "syncDirection"
        static let syncGoogleColors = "syncGoogleColors"
        static let conflictResolutionPolicy = "conflictResolutionPolicy"
        static let autoResolveRecurringConflicts = "autoResolveRecurringConflicts"
        static let defaultRecurrenceFrequency = "defaultRecurrenceFrequency"
        static let defaultRecurrenceInterval = "defaultRecurrenceInterval"
        static let defaultRecurrenceEndType = "defaultRecurrenceEndType"
        static let defaultRecurrenceCount = "defaultRecurrenceCount"
        static let defaultRecurrenceEndDate = "defaultRecurrenceEndDate"
        static let defaultSelectedWeekdays = "defaultSelectedWeekdays"
        static let defaultMonthlyRecurrenceType = "defaultMonthlyRecurrenceType"
        static let defaultSelectedMonthDaysNumbers = "defaultSelectedMonthDaysNumbers"
        static let defaultYearlyRecurrenceType = "defaultYearlyRecurrenceType"
        static let defaultSelectedYearlyDaysNumbers = "defaultSelectedYearlyDaysNumbers"
        static let defaultSelectedYearMonths = "defaultSelectedYearMonths"
        static let defaultSelectedOrdinal = "defaultSelectedOrdinal"
        static let defaultSelectedDayOfWeekForOrdinal = "defaultSelectedDayOfWeekForOrdinal"
        static let perCalendarPreferences = "perCalendarPreferences"
        static let lastSyncStatus = "lastSyncStatus"
        static let lastSyncTimestamp = "lastSyncTimestamp"
        static let defaultReminderMinutes = "defaultReminderMinutes"
        static let defaultEventDurationMinutes = "defaultEventDurationMinutes"
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var isApplyingExternalDefaults = false

    public var selectedCalendarIdentifier: String = "" {
        didSet { write(selectedCalendarIdentifier, forKey: Key.selectedCalendarIdentifier, oldValue: oldValue) }
    }

    private var monitoredCalendarIdentifiersRaw: String = "" {
        didSet { write(monitoredCalendarIdentifiersRaw, forKey: Key.monitoredCalendarIdentifiers, oldValue: oldValue) }
    }
    public var monitoredCalendarIdentifiers: Set<String> {
        get { Set(monitoredCalendarIdentifiersRaw.split(separator: ",").map(String.init)) }
        set { monitoredCalendarIdentifiersRaw = newValue.sorted().joined(separator: ",") }
    }

    public var syncEnabled: Bool = true {
        didSet { write(syncEnabled, forKey: Key.syncEnabled, oldValue: oldValue) }
    }

    private var syncDirectionRaw: String = CalendarPreferences.SyncDirection.bidirectional.rawValue {
        didSet { write(syncDirectionRaw, forKey: Key.syncDirection, oldValue: oldValue) }
    }
    public var syncDirection: CalendarPreferences.SyncDirection {
        get { CalendarPreferences.SyncDirection(rawValue: syncDirectionRaw) ?? .bidirectional }
        set { syncDirectionRaw = newValue.rawValue }
    }

    public var syncGoogleColors: Bool = true {
        didSet { write(syncGoogleColors, forKey: Key.syncGoogleColors, oldValue: oldValue) }
    }

    private var conflictResolutionPolicyRaw: String = CalendarPreferences.ConflictResolutionPolicy.prompt.rawValue {
        didSet { write(conflictResolutionPolicyRaw, forKey: Key.conflictResolutionPolicy, oldValue: oldValue) }
    }
    public var conflictResolutionPolicy: CalendarPreferences.ConflictResolutionPolicy {
        get { CalendarPreferences.ConflictResolutionPolicy(rawValue: conflictResolutionPolicyRaw) ?? .prompt }
        set { conflictResolutionPolicyRaw = newValue.rawValue }
    }

    public var autoResolveRecurringConflicts: Bool = false {
        didSet { write(autoResolveRecurringConflicts, forKey: Key.autoResolveRecurringConflicts, oldValue: oldValue) }
    }

    private var defaultRecurrenceFrequencyRaw: String = RecurrenceFrequency.none.rawValue {
        didSet { write(defaultRecurrenceFrequencyRaw, forKey: Key.defaultRecurrenceFrequency, oldValue: oldValue) }
    }
    public var defaultRecurrenceFrequency: RecurrenceFrequency {
        get { RecurrenceFrequency(rawValue: defaultRecurrenceFrequencyRaw) ?? .none }
        set { defaultRecurrenceFrequencyRaw = newValue.rawValue }
    }

    public var defaultRecurrenceInterval: Int = 1 {
        didSet { write(defaultRecurrenceInterval, forKey: Key.defaultRecurrenceInterval, oldValue: oldValue) }
    }

    private var defaultRecurrenceEndTypeRaw: String = RecurrenceEndType.never.rawValue {
        didSet { write(defaultRecurrenceEndTypeRaw, forKey: Key.defaultRecurrenceEndType, oldValue: oldValue) }
    }
    public var defaultRecurrenceEndType: RecurrenceEndType {
        get { RecurrenceEndType(rawValue: defaultRecurrenceEndTypeRaw) ?? .never }
        set { defaultRecurrenceEndTypeRaw = newValue.rawValue }
    }

    public var defaultRecurrenceCount: Int = 10 {
        didSet { write(defaultRecurrenceCount, forKey: Key.defaultRecurrenceCount, oldValue: oldValue) }
    }

    public var defaultRecurrenceEndDate: Date = CalendarPreferencesStore.defaultRecurrenceEndDate {
        didSet { write(defaultRecurrenceEndDate, forKey: Key.defaultRecurrenceEndDate, oldValue: oldValue) }
    }

    private var defaultSelectedWeekdaysRaw: String = "" {
        didSet { write(defaultSelectedWeekdaysRaw, forKey: Key.defaultSelectedWeekdays, oldValue: oldValue) }
    }
    public var defaultSelectedWeekdays: Set<Int> {
        get { Set(defaultSelectedWeekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedWeekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    private var defaultMonthlyRecurrenceTypeRaw: String = PositionalRecurrenceType.onSpecificDays.rawValue {
        didSet { write(defaultMonthlyRecurrenceTypeRaw, forKey: Key.defaultMonthlyRecurrenceType, oldValue: oldValue) }
    }
    public var defaultMonthlyRecurrenceType: PositionalRecurrenceType {
        get { PositionalRecurrenceType(rawValue: defaultMonthlyRecurrenceTypeRaw) ?? .onSpecificDays }
        set { defaultMonthlyRecurrenceTypeRaw = newValue.rawValue }
    }

    private var defaultSelectedMonthDaysNumbersRaw: String = "" {
        didSet { write(defaultSelectedMonthDaysNumbersRaw, forKey: Key.defaultSelectedMonthDaysNumbers, oldValue: oldValue) }
    }
    public var defaultSelectedMonthDaysNumbers: Set<Int> {
        get { Set(defaultSelectedMonthDaysNumbersRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedMonthDaysNumbersRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    private var defaultYearlyRecurrenceTypeRaw: String = PositionalRecurrenceType.onSpecificDays.rawValue {
        didSet { write(defaultYearlyRecurrenceTypeRaw, forKey: Key.defaultYearlyRecurrenceType, oldValue: oldValue) }
    }
    public var defaultYearlyRecurrenceType: PositionalRecurrenceType {
        get { PositionalRecurrenceType(rawValue: defaultYearlyRecurrenceTypeRaw) ?? .onSpecificDays }
        set { defaultYearlyRecurrenceTypeRaw = newValue.rawValue }
    }

    private var defaultSelectedYearlyDaysNumbersRaw: String = "" {
        didSet { write(defaultSelectedYearlyDaysNumbersRaw, forKey: Key.defaultSelectedYearlyDaysNumbers, oldValue: oldValue) }
    }
    public var defaultSelectedYearlyDaysNumbers: Set<Int> {
        get { Set(defaultSelectedYearlyDaysNumbersRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedYearlyDaysNumbersRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    private var defaultSelectedYearMonthsRaw: String = "" {
        didSet { write(defaultSelectedYearMonthsRaw, forKey: Key.defaultSelectedYearMonths, oldValue: oldValue) }
    }
    public var defaultSelectedYearMonths: Set<Int> {
        get { Set(defaultSelectedYearMonthsRaw.split(separator: ",").compactMap { Int($0) }) }
        set { defaultSelectedYearMonthsRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    public var defaultSelectedOrdinal: Int = 1 {
        didSet { write(defaultSelectedOrdinal, forKey: Key.defaultSelectedOrdinal, oldValue: oldValue) }
    }

    public var defaultSelectedDayOfWeekForOrdinal: Int = 4 {
        didSet { write(defaultSelectedDayOfWeekForOrdinal, forKey: Key.defaultSelectedDayOfWeekForOrdinal, oldValue: oldValue) }
    }

    private var perCalendarPreferencesRaw: String = "{}" {
        didSet { write(perCalendarPreferencesRaw, forKey: Key.perCalendarPreferences, oldValue: oldValue) }
    }
    public var perCalendarPreferences: [String: CalendarPerCalendarSettings] {
        get {
            (try? JSONDecoder().decode([String: CalendarPerCalendarSettings].self, from: Foundation.Data(perCalendarPreferencesRaw.utf8))) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                perCalendarPreferencesRaw = String(data: data, encoding: .utf8) ?? "{}"
            }
        }
    }

    public var lastSyncStatus: String = "Never" {
        didSet { write(lastSyncStatus, forKey: Key.lastSyncStatus, oldValue: oldValue) }
    }

    public var lastSyncTimestamp: Date = .distantPast {
        didSet { write(lastSyncTimestamp, forKey: Key.lastSyncTimestamp, oldValue: oldValue) }
    }

    public var defaultReminderMinutes: Int = 30 {
        didSet { write(defaultReminderMinutes, forKey: Key.defaultReminderMinutes, oldValue: oldValue) }
    }

    public var defaultEventDurationMinutes: Int = 60 {
        didSet { write(defaultEventDurationMinutes, forKey: Key.defaultEventDurationMinutes, oldValue: oldValue) }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        loadFromDefaults()
        startObservation()
    }

    public func resetToDefaults() {
        selectedCalendarIdentifier = ""
        monitoredCalendarIdentifiersRaw = ""
        syncEnabled = true
        syncDirectionRaw = CalendarPreferences.SyncDirection.bidirectional.rawValue
        syncGoogleColors = true
        conflictResolutionPolicyRaw = CalendarPreferences.ConflictResolutionPolicy.prompt.rawValue
        autoResolveRecurringConflicts = false
        defaultRecurrenceFrequencyRaw = RecurrenceFrequency.none.rawValue
        defaultRecurrenceInterval = 1
        defaultRecurrenceEndTypeRaw = RecurrenceEndType.never.rawValue
        defaultRecurrenceCount = 10
        defaultRecurrenceEndDate = Self.defaultRecurrenceEndDate
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
        lastSyncTimestamp = .distantPast
        defaultReminderMinutes = 30
        defaultEventDurationMinutes = 60
    }

    private static var defaultRecurrenceEndDate: Date {
        Date().addingTimeInterval(3600 * 24 * 30)
    }

    private func loadFromDefaults() {
        applyExternalDefaults {
            selectedCalendarIdentifier = defaults.string(forKey: Key.selectedCalendarIdentifier) ?? ""
            monitoredCalendarIdentifiersRaw = defaults.string(forKey: Key.monitoredCalendarIdentifiers) ?? ""
            syncEnabled = defaults.bool(forKey: Key.syncEnabled, default: true)
            syncDirectionRaw = defaults.string(forKey: Key.syncDirection) ?? CalendarPreferences.SyncDirection.bidirectional.rawValue
            syncGoogleColors = defaults.bool(forKey: Key.syncGoogleColors, default: true)
            conflictResolutionPolicyRaw = defaults.string(forKey: Key.conflictResolutionPolicy) ?? CalendarPreferences.ConflictResolutionPolicy.prompt.rawValue
            autoResolveRecurringConflicts = defaults.bool(forKey: Key.autoResolveRecurringConflicts, default: false)
            defaultRecurrenceFrequencyRaw = defaults.string(forKey: Key.defaultRecurrenceFrequency) ?? RecurrenceFrequency.none.rawValue
            defaultRecurrenceInterval = defaults.int(forKey: Key.defaultRecurrenceInterval, default: 1)
            defaultRecurrenceEndTypeRaw = defaults.string(forKey: Key.defaultRecurrenceEndType) ?? RecurrenceEndType.never.rawValue
            defaultRecurrenceCount = defaults.int(forKey: Key.defaultRecurrenceCount, default: 10)
            defaultRecurrenceEndDate = defaults.date(forKey: Key.defaultRecurrenceEndDate, default: Self.defaultRecurrenceEndDate)
            defaultSelectedWeekdaysRaw = defaults.string(forKey: Key.defaultSelectedWeekdays) ?? ""
            defaultMonthlyRecurrenceTypeRaw = defaults.string(forKey: Key.defaultMonthlyRecurrenceType) ?? PositionalRecurrenceType.onSpecificDays.rawValue
            defaultSelectedMonthDaysNumbersRaw = defaults.string(forKey: Key.defaultSelectedMonthDaysNumbers) ?? ""
            defaultYearlyRecurrenceTypeRaw = defaults.string(forKey: Key.defaultYearlyRecurrenceType) ?? PositionalRecurrenceType.onSpecificDays.rawValue
            defaultSelectedYearlyDaysNumbersRaw = defaults.string(forKey: Key.defaultSelectedYearlyDaysNumbers) ?? ""
            defaultSelectedYearMonthsRaw = defaults.string(forKey: Key.defaultSelectedYearMonths) ?? ""
            defaultSelectedOrdinal = defaults.int(forKey: Key.defaultSelectedOrdinal, default: 1)
            defaultSelectedDayOfWeekForOrdinal = defaults.int(forKey: Key.defaultSelectedDayOfWeekForOrdinal, default: 4)
            perCalendarPreferencesRaw = defaults.string(forKey: Key.perCalendarPreferences) ?? "{}"
            lastSyncStatus = defaults.string(forKey: Key.lastSyncStatus) ?? "Never"
            lastSyncTimestamp = defaults.date(forKey: Key.lastSyncTimestamp, default: .distantPast)
            defaultReminderMinutes = defaults.int(forKey: Key.defaultReminderMinutes, default: 30)
            defaultEventDurationMinutes = defaults.int(forKey: Key.defaultEventDurationMinutes, default: 60)
        }
    }

    private func startObservation() {
        observeString(Key.selectedCalendarIdentifier, defaultValue: "") { [weak self] in self?.selectedCalendarIdentifier = $0 }
        observeString(Key.monitoredCalendarIdentifiers, defaultValue: "") { [weak self] in self?.monitoredCalendarIdentifiersRaw = $0 }
        observeBool(Key.syncEnabled, defaultValue: true) { [weak self] in self?.syncEnabled = $0 }
        observeString(Key.syncDirection, defaultValue: CalendarPreferences.SyncDirection.bidirectional.rawValue) { [weak self] in self?.syncDirectionRaw = $0 }
        observeBool(Key.syncGoogleColors, defaultValue: true) { [weak self] in self?.syncGoogleColors = $0 }
        observeString(Key.conflictResolutionPolicy, defaultValue: CalendarPreferences.ConflictResolutionPolicy.prompt.rawValue) { [weak self] in self?.conflictResolutionPolicyRaw = $0 }
        observeBool(Key.autoResolveRecurringConflicts, defaultValue: false) { [weak self] in self?.autoResolveRecurringConflicts = $0 }
        observeString(Key.defaultRecurrenceFrequency, defaultValue: RecurrenceFrequency.none.rawValue) { [weak self] in self?.defaultRecurrenceFrequencyRaw = $0 }
        observeInt(Key.defaultRecurrenceInterval, defaultValue: 1) { [weak self] in self?.defaultRecurrenceInterval = $0 }
        observeString(Key.defaultRecurrenceEndType, defaultValue: RecurrenceEndType.never.rawValue) { [weak self] in self?.defaultRecurrenceEndTypeRaw = $0 }
        observeInt(Key.defaultRecurrenceCount, defaultValue: 10) { [weak self] in self?.defaultRecurrenceCount = $0 }
        observeDate(Key.defaultRecurrenceEndDate, defaultValue: Self.defaultRecurrenceEndDate) { [weak self] in self?.defaultRecurrenceEndDate = $0 }
        observeString(Key.defaultSelectedWeekdays, defaultValue: "") { [weak self] in self?.defaultSelectedWeekdaysRaw = $0 }
        observeString(Key.defaultMonthlyRecurrenceType, defaultValue: PositionalRecurrenceType.onSpecificDays.rawValue) { [weak self] in self?.defaultMonthlyRecurrenceTypeRaw = $0 }
        observeString(Key.defaultSelectedMonthDaysNumbers, defaultValue: "") { [weak self] in self?.defaultSelectedMonthDaysNumbersRaw = $0 }
        observeString(Key.defaultYearlyRecurrenceType, defaultValue: PositionalRecurrenceType.onSpecificDays.rawValue) { [weak self] in self?.defaultYearlyRecurrenceTypeRaw = $0 }
        observeString(Key.defaultSelectedYearlyDaysNumbers, defaultValue: "") { [weak self] in self?.defaultSelectedYearlyDaysNumbersRaw = $0 }
        observeString(Key.defaultSelectedYearMonths, defaultValue: "") { [weak self] in self?.defaultSelectedYearMonthsRaw = $0 }
        observeInt(Key.defaultSelectedOrdinal, defaultValue: 1) { [weak self] in self?.defaultSelectedOrdinal = $0 }
        observeInt(Key.defaultSelectedDayOfWeekForOrdinal, defaultValue: 4) { [weak self] in self?.defaultSelectedDayOfWeekForOrdinal = $0 }
        observeString(Key.perCalendarPreferences, defaultValue: "{}") { [weak self] in self?.perCalendarPreferencesRaw = $0 }
        observeString(Key.lastSyncStatus, defaultValue: "Never") { [weak self] in self?.lastSyncStatus = $0 }
        observeDate(Key.lastSyncTimestamp, defaultValue: .distantPast) { [weak self] in self?.lastSyncTimestamp = $0 }
        observeInt(Key.defaultReminderMinutes, defaultValue: 30) { [weak self] in self?.defaultReminderMinutes = $0 }
        observeInt(Key.defaultEventDurationMinutes, defaultValue: 60) { [weak self] in self?.defaultEventDurationMinutes = $0 }
    }

    private func observeString(_ key: String, defaultValue: String, apply: @escaping @MainActor @Sendable (String) -> Void) {
        observe(key, as: String.self, defaultValue: { defaultValue }, apply: apply)
    }

    private func observeBool(_ key: String, defaultValue: Bool, apply: @escaping @MainActor @Sendable (Bool) -> Void) {
        observe(key, as: Bool.self, defaultValue: { defaultValue }, apply: apply)
    }

    private func observeInt(_ key: String, defaultValue: Int, apply: @escaping @MainActor @Sendable (Int) -> Void) {
        observe(key, as: Int.self, defaultValue: { defaultValue }, apply: apply)
    }

    private func observeDate(_ key: String, defaultValue: Date, apply: @escaping @MainActor @Sendable (Date) -> Void) {
        observe(key, as: Date.self, defaultValue: { defaultValue }, apply: apply)
    }

    private func observe<Value: Sendable>(
        _ key: String,
        as type: Value.Type,
        defaultValue: @escaping @Sendable () -> Value,
        apply: @escaping @MainActor @Sendable (Value) -> Void
    ) {
        observationTasks.append(Task { [weak self, defaults] in
            for await newValue in defaults.observedValue(forKey: key, as: type) {
                self?.applyObservedValue(newValue ?? defaultValue(), apply: apply)
            }
        })
    }

    private func applyObservedValue<Value>(
        _ value: Value,
        apply: @escaping @MainActor @Sendable (Value) -> Void
    ) {
        applyExternalDefaults {
            apply(value)
        }
    }

    private func write<Value: Equatable>(_ value: Value, forKey key: String, oldValue: Value) {
        guard !isApplyingExternalDefaults, value != oldValue else { return }
        defaults.set(value, forKey: key)
    }

    private func applyExternalDefaults(_ apply: () -> Void) {
        isApplyingExternalDefaults = true
        apply()
        isApplyingExternalDefaults = false
    }

    deinit {
        observationTasks.forEach { $0.cancel() }
    }
}

private extension UserDefaults {
    func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        guard let object = object(forKey: key) else { return defaultValue }
        if let value = object as? Bool { return value }
        if let number = object as? NSNumber { return number.boolValue }
        return defaultValue
    }

    func int(forKey key: String, default defaultValue: Int) -> Int {
        guard let object = object(forKey: key) else { return defaultValue }
        if let value = object as? Int { return value }
        if let number = object as? NSNumber { return number.intValue }
        return defaultValue
    }

    func date(forKey key: String, default defaultValue: Date) -> Date {
        object(forKey: key) as? Date ?? defaultValue
    }
}
