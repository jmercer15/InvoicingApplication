import SwiftUI
import EventKit
import Data
import SharedUI

// MARK: - Main View

public struct CalendarSettingsView: View {
// Placeholder to ensure line removal
    @State private var viewModel: CalendarSettingsViewModel
    
    public init(viewModel: @autoclosure @escaping () -> CalendarSettingsViewModel) {
        _viewModel = State(initialValue: viewModel())
    }

    private var preferences: CalendarPreferencesStore {
        _viewModel.wrappedValue.preferences
    }
    
    @ScaledMetric(relativeTo: .body) private var paddingXLarge = StyleGuide.Dimensions.paddingXLarge
    @ScaledMetric(relativeTo: .body) private var paddingLarge = StyleGuide.Dimensions.paddingLarge
    @ScaledMetric(relativeTo: .body) private var cornerRadiusLarge = StyleGuide.Dimensions.cornerRadiusLarge
    
    private var maxLabelWidth: CGFloat {
        let labels = [
            "Enable Sync:", "Sync Google Colors:", "Auto-resolve Conflicts:",
            "Default Reminder Minutes:", "Default Event Duration:", "Sync Direction:",
            "Recurrence Frequency:", "Recurrence Interval:", "Monthly Rule Type:",
            "Yearly Rule Type:", "Recurrence End Type:", "Recurrence Count:",
            "Recurrence End Date:", "Conflict Resolution Policy:", "Default Calendar:"
        ]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: FormSectionTokens.pageStackSpacing) {
                permissionsSection
                defaultCalendarSection
                defaultsForNewEventsSection
                syncPreferencesSection
                monitoredCalendarsSection
                recurrenceDefaultsSection
                conflictResolutionSection
                
                // Action buttons at bottom
                HStack(spacing: FormSectionTokens.formGroupSpacing) {
                    Button("Reset All Calendar Settings") {
                        viewModel.showingResetConfirmation = true
                    }
                    .accessibilityLabel("Reset All Calendar Settings")
                    .accessibilityHint("Resets all calendar preferences to their default values.")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity)
                    
                    Button("Clear All Sessions (App Only)") {
                        viewModel.showingClearSessionsConfirmation = true
                    }
                    .accessibilityLabel("Clear All Sessions")
                    .accessibilityHint("Deletes all session data in the app, but does not affect your calendar events.")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .buttonStyle(.glass)
                    .foregroundColor(ColorSystem.Status.error)
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, StyleGuide.Dimensions.paddingLarge)
            }
            .padding(.vertical, paddingXLarge)
            .padding(.horizontal, paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
#if os(macOS)
        .scrollIndicators(.visible)
#endif
        .disabled(viewModel.isLoading)
        .overlay(loadingOverlay)
        .alert(isPresented: $viewModel.showingInvalidCalendarAlert) {
            Alert(title: Text("Invalid Calendar"), message: Text("Please select a valid, writable calendar."), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $viewModel.showCreateCalendarSheet) {
            CreateCalendarSheet(
                onCreate: { title, color in
                    Task {
                        viewModel.createNewCalendar(title: title, color: color)
                        viewModel.showCreateCalendarSheet = false
                    }
                },
                onCancel: {
                    viewModel.showCreateCalendarSheet = false
                }
            )
            .fluidSheetTransition()
            .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: viewModel.showCreateCalendarSheet)
        }
        .confirmationDialog(
            "Reset all calendar settings to defaults?",
            isPresented: Binding<Bool>(
                get: { viewModel.showingResetConfirmation },
                set: { viewModel.showingResetConfirmation = $0 }
            )
        ) {
            Button("Reset", role: .destructive) { preferences.resetToDefaults() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete all session data from the app? This cannot be undone.",
            isPresented: Binding<Bool>(
                get: { viewModel.showingClearSessionsConfirmation },
                set: { viewModel.showingClearSessionsConfirmation = $0 }
            )
        ) {
            Button("Delete All Sessions", role: .destructive) {
                Task {
                    await viewModel.clearAllSessions()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            print("[CalendarSettingsView] Settings view appeared")
            print("[CalendarSettingsView] Initial access granted: \(viewModel.accessGranted)")
            print("[CalendarSettingsView] Available calendars count: \(viewModel.writableCalendars.count)")
            viewModel.validateCalendarSelection()
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassEffect(.regular, in: .rect())
            }
            if let error = viewModel.errorMessage {
                VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                    Text(error)
                        .foregroundColor(ColorSystem.Status.error)
                        .font(.headline)
                    Text("To enable calendar access, go to System Settings > Privacy & Security > Calendars and enable access for this app.")
                        .font(.footnote)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    #if os(macOS)
                    Button("Open System Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.glassProminent)
                    #endif
                }
                .padding(paddingLarge)
                .background(Color.red.opacity(0.08))
                .cornerRadius(cornerRadiusLarge)
                .padding(paddingLarge)
            }
        }
    }
    
    // MARK: - Section Views
    
    private var permissionsSection: some View {
        SettingsSection(
            icon: "lock.shield",
            title: "Calendar Access",
            description: "Grant access to your calendars so the app can sync events and create new sessions. This is required before you can select which calendars to sync."
        ) {
            HStack(alignment: .center, spacing: FormSectionTokens.sectionStackSpacing) {
                Text(viewModel.accessGranted ? "Calendar Access: Granted" : "Calendar Access: Not Granted")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(viewModel.accessGranted ? .green : .red)
                Spacer()
                if !viewModel.accessGranted {
                    Button("Request Access") {
                        print("[CalendarSettingsView] User clicked Request Access button")
                        Task { await viewModel.requestAccess() }
                    }
                    .accessibilityHint("Request permission to access your calendars.")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                }
                #if DEBUG
                Button("Debug Status") {
                    viewModel.checkCurrentAccessStatus()
                }
                .font(.caption)
                .buttonStyle(.glass)
                #endif
                InfoIcon(tooltip: "Calendar access is required to sync events and create new sessions.")
            }
            .standardCardStyle()
        }
    }
    
    private var defaultCalendarSection: some View {
        SettingsSection(
            icon: "calendar",
            title: "Default Calendar",
            description: "Choose which calendar new sessions will be created in by default. This should be one of your synced calendars."
        ) {
            SettingsRow(label: "Default Calendar:", labelWidth: maxLabelWidth) {
                HStack {
                    Picker("", selection: Binding<EKCalendar?>(
                        get: { viewModel.writableCalendars.first(where: { $0.calendarIdentifier == preferences.selectedCalendarIdentifier }) },
                        set: { preferences.selectedCalendarIdentifier = $0?.calendarIdentifier ?? "" }
                    )) {
                        Text("Select Calendar").tag(nil as EKCalendar?)
                        ForEach(viewModel.writableCalendars, id: \.calendarIdentifier) { calendar in
                            Text(viewModel.calendarLabels[calendar] ?? calendar.title).tag(calendar as EKCalendar?)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Default calendar")
                    .accessibilityHint("Select the default calendar for new events")
                    Button("Create New Calendar") { viewModel.showCreateCalendarSheet = true }
                        .font(.caption)
                        .buttonStyle(.glass)
                    InfoIcon(tooltip: "Select which calendar new sessions will be created in by default.")
                }
            }
            if let error = viewModel.calendarErrorText {
                Text(error).formErrorStyle()
            }
        }
    }
    
    private var defaultsForNewEventsSection: some View {
        SettingsSection(
            icon: "clock",
            title: "Defaults for New Events",
            description: "Set the default reminder and duration for new events you create in the app."
        ) {
            SettingsRow(label: "Default Reminder Minutes:", labelWidth: maxLabelWidth) {
                HStack {
                    TextField("Enter reminder minutes", value: Binding<Double>(
                        get: { Double(preferences.defaultReminderMinutes) },
                        set: { preferences.defaultReminderMinutes = Int($0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Default reminder minutes")
                    .accessibilityHint("Enter the number of minutes before an event for the default reminder")
                    Stepper("", value: Binding<Double>(
                        get: { Double(preferences.defaultReminderMinutes) },
                        set: { preferences.defaultReminderMinutes = Int($0) }
                    ), in: 0...120, step: 5)
                    .accessibilityLabel("Adjust default reminder minutes")
                    InfoIcon(tooltip: "How many minutes before the event should the default reminder be set?")
                }
            }
            
            SettingsRow(label: "Default Event Duration:", labelWidth: maxLabelWidth) {
                HStack {
                    TextField("Enter duration minutes", value: Binding<Double>(
                        get: { Double(preferences.defaultEventDurationMinutes) },
                        set: { preferences.defaultEventDurationMinutes = Int($0) }
                    ), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Default event duration minutes")
                    .accessibilityHint("Enter the default duration in minutes for new events")
                    Stepper("", value: Binding<Double>(
                        get: { Double(preferences.defaultEventDurationMinutes) },
                        set: { preferences.defaultEventDurationMinutes = Int($0) }
                    ), in: 15...240, step: 15)
                    .accessibilityLabel("Adjust default event duration minutes")
                    InfoIcon(tooltip: "How long should new events last by default?")
                }
            }
        }
    }
    
    private var syncPreferencesSection: some View {
        SettingsSection(
            icon: "arrow.triangle.2.circlepath",
            title: "Sync Settings",
            description: "Control how events sync between this app and your synced calendars. Choose the sync direction, enable Google color support, and trigger manual syncs.",
            trailingButton: {
                AnyView(
                    Button("Manual Sync Now") {
                        Task { await viewModel.performManualSync() }
                    }
                    .accessibilityHint("Immediately synchronize all events between the app and your calendars.")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .buttonStyle(.glassProminent)
                )
            }
        ) {
            SettingsRow(label: "Enable Sync:", labelWidth: maxLabelWidth) {
                HStack {
                    Toggle("", isOn: Binding(
                        get: { preferences.syncEnabled },
                        set: { preferences.syncEnabled = $0 }
                    ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Enable sync")
                        .accessibilityHint("Toggle to enable or disable calendar synchronization")
                    InfoIcon(tooltip: "Enable synchronization between the app and your calendars")
                }
            }
            
            SettingsRow(label: "Sync Google Colors:", labelWidth: maxLabelWidth) {
                HStack {
                    Toggle("", isOn: Binding(
                        get: { preferences.syncGoogleColors },
                        set: { preferences.syncGoogleColors = $0 }
                    ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Sync Google calendar colors")
                        .accessibilityHint("Toggle to sync colors from Google Calendar")
                    InfoIcon(tooltip: "Import calendar colors from Google Calendar")
                }
            }
            
            SettingsRow(label: "Sync Direction:", labelWidth: maxLabelWidth) {
                HStack {
                    Picker("", selection: Binding<CalendarPreferences.SyncDirection?>(
                        get: { preferences.syncDirection },
                        set: { preferences.syncDirection = $0 ?? .bidirectional }
                    )) {
                        ForEach(CalendarPreferences.SyncDirection.allCases, id: \.self) { direction in
                            Text(direction.displayName).tag(direction as CalendarPreferences.SyncDirection?)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Sync direction")
                    .accessibilityHint("Select the direction for calendar synchronization")
                    InfoIcon(tooltip: "Choose how data flows between the app and your calendars")
                }
            }
            
            if preferences.lastSyncTimestamp > Date.distantPast {
                Text("Last Sync: \(preferences.lastSyncTimestamp.formatted(.dateTime)) (\(preferences.lastSyncStatus))")
                    .formDescriptionStyle()
            }
        }
    }
    
    private var monitoredCalendarsSection: some View {
        SettingsSection(
            icon: "arrow.triangle.2.circlepath",
            title: "Synced Calendars",
            description: "Select which calendars the app should sync and monitor for events. Only events from these calendars will be available in the app."
        ) {
            VStack(spacing: 6) {
                ForEach(viewModel.writableCalendars, id: \.calendarIdentifier) { calendar in
                    CalendarRowView(
                        calendar: calendar,
                        isSelected: viewModel.selectedMonitoredCalendars.contains(CalendarSettingsViewModel.CalendarIdentifier(id: calendar.calendarIdentifier, title: calendar.title)),
                        onToggle: { isSelected in
                            var newSelection = viewModel.selectedMonitoredCalendars
                            let calendarId = CalendarSettingsViewModel.CalendarIdentifier(id: calendar.calendarIdentifier, title: calendar.title)
                            if isSelected {
                                newSelection.insert(calendarId)
                            } else {
                                newSelection.remove(calendarId)
                            }
                            viewModel.updateSelectedMonitoredCalendars(newSelection)
                        },
                        onColorChange: { newColor in
                            viewModel.updateCalendarColor(calendarIdentifier: calendar.calendarIdentifier, color: newColor)
                        },
                        currentColor: viewModel.getCalendarColor(calendarIdentifier: calendar.calendarIdentifier) ?? Color(calendar.cgColor)
                    )
                }
            }
            .standardCardStyle()
            
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(ColorSystem.Status.info)
                Text("Tip: Use the calendar visibility toggle (📅) in the main calendar view to control which synced calendars are visible.")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            .padding(.top, StyleGuide.Dimensions.paddingXSmall)
        }
    }
    
    private var recurrenceDefaultsSection: some View {
        RecurrenceDefaultsView(viewModel: viewModel, preferences: preferences, maxLabelWidth: maxLabelWidth)
    }
    
    private var conflictResolutionSection: some View {
        SettingsSection(
            icon: "exclamationmark.arrow.triangle.2.circlepath",
            title: "Conflict Resolution",
            description: "Choose how to handle conflicts when both the app and your calendar have changed the same event."
        ) {
            SettingsRow(label: "Conflict Resolution Policy:", labelWidth: maxLabelWidth) {
                HStack {
                    Picker("", selection: Binding<CalendarPreferences.ConflictResolutionPolicy?>(
                        get: { preferences.conflictResolutionPolicy },
                        set: { preferences.conflictResolutionPolicy = $0 ?? .prompt }
                    )) {
                        ForEach(CalendarPreferences.ConflictResolutionPolicy.allCases, id: \.self) { policy in
                            Text(policy.displayName).tag(policy as CalendarPreferences.ConflictResolutionPolicy?)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Conflict resolution policy")
                    .accessibilityHint("Select how to handle calendar conflicts")
                    InfoIcon(tooltip: "'Prefer App Data' always keeps your changes, 'Prefer Calendar Data' always pulls from the calendar, and 'Prompt User' asks you each time.")
                }
            }
            
            SettingsRow(label: "Auto-resolve Conflicts:", labelWidth: maxLabelWidth) {
                HStack {
                    Toggle("", isOn: Binding(
                        get: { preferences.autoResolveRecurringConflicts },
                        set: { preferences.autoResolveRecurringConflicts = $0 }
                    ))
                        .toggleStyle(.switch)
                        .accessibilityLabel("Auto-resolve recurring conflicts")
                        .accessibilityHint("Toggle to automatically resolve recurring event conflicts")
                    InfoIcon(tooltip: "If enabled, recurring event conflicts will be resolved automatically using the selected policy.")
                }
            }
        }
    }
}

// MARK: - Supporting Views
// Note: Recurrence-related views have been moved to Views/Calendar/Components/RecurrenceSettingsViews.swift
// Note: CalendarRowView has been moved to Views/Calendar/Components/CalendarRowView.swift

 
