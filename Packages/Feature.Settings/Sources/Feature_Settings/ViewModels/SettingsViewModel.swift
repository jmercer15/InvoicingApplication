import Foundation
import SwiftUI
import Core
import Data
import Core

/// ViewModel for the Settings feature using clean architecture
@MainActor
public class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published public var isLoading: Bool = false
    @Published public var error: Error?
    @Published public private(set) var lastUpdated: Date = Date()
    
    // Calendar Sync Settings
    @Published public var syncEnabled: Bool = true
    @Published public var selectedCalendarIdentifier: String = ""
    @Published public var monitoredCalendarIdentifiers: Set<String> = []
    @Published public var syncDirection: SyncDirection = .bidirectional
    @Published public var conflictResolutionPolicy: ConflictResolutionPolicy = .prompt
    @Published public var syncGoogleColors: Bool = true
    @Published public var autoResolveRecurringConflicts: Bool = false
    
    // Import/Export Settings
    @Published public var isImporting: Bool = false
    @Published public var isExporting: Bool = false
    @Published public var importProgress: Double = 0.0
    @Published public var exportProgress: Double = 0.0
    @Published public var lastImportDate: Date?
    @Published public var lastExportDate: Date?
    
    // Application Settings
    @Published public var hourHeight: CGFloat = 60.0
    @Published public var defaultSessionDuration: TimeInterval = 3600 // 1 hour
    @Published public var autoSaveEnabled: Bool = true
    @Published public var notificationsEnabled: Bool = true
    
    // MARK: - Dependencies
    private let syncService: SyncService
    private let importAllData: ImportAllData
    private let exportAllData: ExportAllData
    
    // MARK: - Initialization
    public init(
        syncService: SyncService,
        importAllData: ImportAllData,
        exportAllData: ExportAllData
    ) {
        self.syncService = syncService
        self.importAllData = importAllData
        self.exportAllData = exportAllData
        
        loadSettings()
        setupBindings()
    }
    
    // MARK: - Computed Properties
    
    public var availableCalendars: [CalendarInfo] {
        syncService.availableCalendars
    }
    
    public var accessGranted: Bool {
        syncService.accessGranted
    }
    
    public var syncStatus: Core.SyncStatus {
        syncService.syncStatus
    }
    
    public var lastSyncDate: Date? {
        syncService.lastSyncDate
    }
    
    public var selectedCalendar: CalendarInfo? {
        availableCalendars.first { $0.id == selectedCalendarIdentifier }
    }
    
    // MARK: - Public Methods
    
    public func loadSettings() {
        // Load settings from UserDefaults
        syncEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")
        selectedCalendarIdentifier = UserDefaults.standard.string(forKey: "selectedCalendarIdentifier") ?? ""
        syncDirection = SyncDirection(rawValue: UserDefaults.standard.string(forKey: "syncDirection") ?? "bidirectional") ?? .bidirectional
        conflictResolutionPolicy = ConflictResolutionPolicy(rawValue: UserDefaults.standard.string(forKey: "conflictResolutionPolicy") ?? "prompt") ?? .prompt
        syncGoogleColors = UserDefaults.standard.bool(forKey: "syncGoogleColors")
        autoResolveRecurringConflicts = UserDefaults.standard.bool(forKey: "autoResolveRecurringConflicts")
        hourHeight = CGFloat(UserDefaults.standard.double(forKey: "hourHeightDouble"))
        defaultSessionDuration = UserDefaults.standard.double(forKey: "defaultSessionDuration")
        autoSaveEnabled = UserDefaults.standard.bool(forKey: "autoSaveEnabled")
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        
        // Load monitored calendars
        if let data = UserDefaults.standard.data(forKey: "monitoredCalendarIdentifiers"),
           let identifiers = try? JSONDecoder().decode(Set<String>.self, from: data) {
            monitoredCalendarIdentifiers = identifiers
        }
        
        // Load last import/export dates
        if let importDate = UserDefaults.standard.object(forKey: "lastImportDate") as? Date {
            lastImportDate = importDate
        }
        if let exportDate = UserDefaults.standard.object(forKey: "lastExportDate") as? Date {
            lastExportDate = exportDate
        }
    }
    
    public func saveSettings() {
        UserDefaults.standard.set(syncEnabled, forKey: "syncEnabled")
        UserDefaults.standard.set(selectedCalendarIdentifier, forKey: "selectedCalendarIdentifier")
        UserDefaults.standard.set(syncDirection.rawValue, forKey: "syncDirection")
        UserDefaults.standard.set(conflictResolutionPolicy.rawValue, forKey: "conflictResolutionPolicy")
        UserDefaults.standard.set(syncGoogleColors, forKey: "syncGoogleColors")
        UserDefaults.standard.set(autoResolveRecurringConflicts, forKey: "autoResolveRecurringConflicts")
        UserDefaults.standard.set(Double(hourHeight), forKey: "hourHeightDouble")
        UserDefaults.standard.set(defaultSessionDuration, forKey: "defaultSessionDuration")
        UserDefaults.standard.set(autoSaveEnabled, forKey: "autoSaveEnabled")
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        
        // Save monitored calendars
        if let data = try? JSONEncoder().encode(monitoredCalendarIdentifiers) {
            UserDefaults.standard.set(data, forKey: "monitoredCalendarIdentifiers")
        }
        
        lastUpdated = Date()
    }
    
    // MARK: - Calendar Sync Methods
    
    public func requestCalendarAccess() async -> Bool {
        do {
            return try await syncService.requestAccess()
        } catch {
            self.error = error
            return false
        }
    }
    
    public func toggleSyncEnabled() async {
        syncEnabled.toggle()
        await syncService.setSyncEnabled(syncEnabled)
        saveSettings()
    }
    
    public func selectCalendar(_ calendar: CalendarInfo) {
        selectedCalendarIdentifier = calendar.id
        saveSettings()
    }
    
    public func toggleCalendarMonitoring(_ calendar: CalendarInfo) {
        if monitoredCalendarIdentifiers.contains(calendar.id) {
            monitoredCalendarIdentifiers.remove(calendar.id)
        } else {
            monitoredCalendarIdentifiers.insert(calendar.id)
        }
        saveSettings()
    }
    
    public func setSyncDirection(_ direction: SyncDirection) {
        syncDirection = direction
        saveSettings()
    }
    
    public func setConflictResolutionPolicy(_ policy: ConflictResolutionPolicy) {
        conflictResolutionPolicy = policy
        saveSettings()
    }
    
    public func toggleSyncGoogleColors() {
        syncGoogleColors.toggle()
        saveSettings()
    }
    
    public func toggleAutoResolveRecurringConflicts() {
        autoResolveRecurringConflicts.toggle()
        saveSettings()
    }
    
    // MARK: - Import/Export Methods
    
    public func importAllData() async {
        isImporting = true
        importProgress = 0.0
        error = nil
        
        do {
            let result = try await importAllData.callAsFunction()
            if result.success {
                lastImportDate = Date()
                UserDefaults.standard.set(lastImportDate, forKey: "lastImportDate")
                importProgress = 1.0
            } else {
                self.error = NSError(domain: "ImportError", code: 1001, userInfo: [NSLocalizedDescriptionKey: result.errors.joined(separator: ", ")])
            }
        } catch {
            self.error = error
        }
        
        isImporting = false
    }
    
    public func exportAllData() async {
        isExporting = true
        exportProgress = 0.0
        error = nil
        
        do {
            let result = try await exportAllData.callAsFunction()
            if result.success {
                lastExportDate = Date()
                UserDefaults.standard.set(lastExportDate, forKey: "lastExportDate")
                exportProgress = 1.0
            } else {
                self.error = ExportError.exportFailed(result.errors.joined(separator: ", "))
            }
        } catch {
            self.error = error
        }
        
        isExporting = false
    }
    
    // MARK: - Application Settings Methods
    
    public func setHourHeight(_ height: CGFloat) {
        hourHeight = height
        saveSettings()
    }
    
    public func setDefaultSessionDuration(_ duration: TimeInterval) {
        defaultSessionDuration = duration
        saveSettings()
    }
    
    public func toggleAutoSave() {
        autoSaveEnabled.toggle()
        saveSettings()
    }
    
    public func toggleNotifications() {
        notificationsEnabled.toggle()
        saveSettings()
    }
    
    // MARK: - Reset Methods
    
    public func resetToDefaults() {
        syncEnabled = true
        selectedCalendarIdentifier = ""
        monitoredCalendarIdentifiers = []
        syncDirection = .bidirectional
        conflictResolutionPolicy = .prompt
        syncGoogleColors = true
        autoResolveRecurringConflicts = false
        hourHeight = 60.0
        defaultSessionDuration = 3600
        autoSaveEnabled = true
        notificationsEnabled = true
        
        saveSettings()
    }
    
    public func clearAllData() async {
        // This would typically involve clearing all data from repositories
        // For now, we'll just reset the last import/export dates
        lastImportDate = nil
        lastExportDate = nil
        UserDefaults.standard.removeObject(forKey: "lastImportDate")
        UserDefaults.standard.removeObject(forKey: "lastExportDate")
        
        lastUpdated = Date()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Set up any necessary bindings or observers
        // This could include monitoring sync service changes, etc.
    }
}

// MARK: - Supporting Types

public enum SyncDirection: String, CaseIterable {
    case appToCalendar = "appToCalendar"
    case calendarToApp = "calendarToApp"
    case bidirectional = "bidirectional"
    
    public var displayName: String {
        switch self {
        case .appToCalendar:
            return "App to Calendar"
        case .calendarToApp:
            return "Calendar to App"
        case .bidirectional:
            return "Bidirectional"
        }
    }
}

public enum ConflictResolutionPolicy: String, CaseIterable {
    case preferApp = "preferApp"
    case preferCalendar = "preferCalendar"
    case prompt = "prompt"
    
    public var displayName: String {
        switch self {
        case .preferApp:
            return "Prefer App"
        case .preferCalendar:
            return "Prefer Calendar"
        case .prompt:
            return "Ask Me"
        }
    }
}


public enum ExportError: Error, LocalizedError {
    case exportFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Export failed: \(message)"
        }
    }
}
