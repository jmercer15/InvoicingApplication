import SwiftUI
import EventKit

// Typography refinements: custom modifiers
extension View {
    func formDescriptionStyle() -> some View {
        self
            .font(.footnote)
            .foregroundColor(.secondary)
            .padding(.leading, 20)
            .lineSpacing(1.5)
    }
    func formErrorStyle() -> some View {
        self
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundColor(.red)
            .padding(.leading, 20)
    }
    func formSectionTitleStyle() -> some View {
        self
            .font(.title3)
            .fontWeight(.bold)
            .padding(.bottom, 2)
    }
    func sectionCardStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    #if os(macOS)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.7))
                    #else
                    .fill(Color(.systemBackground).opacity(0.7))
                    #endif
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
            )
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
    }
}

// Add SectionHeader for section titles with icons
struct SectionHeader: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.title2)
            Text(title)
                .formSectionTitleStyle()
        }
        .padding(.bottom, 4)
    }
}

struct CalendarSettingsView: View {
    @StateObject private var viewModel = CalendarSettingsViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        FormComponentContainer {
            ScrollView {
                VStack(spacing: 32) {
                    permissionsSection
                    defaultCalendarSection
                    defaultsForNewEventsSection
                    syncPreferencesSection
                    monitoredCalendarsSection
                    recurrenceDefaultsSection
                    conflictResolutionSection
                    resetButtonSection
                    clearSessionsSection
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.black.opacity(0.15))
                    .shadow(radius: 8)
            )
#if os(macOS)
            .scrollIndicators(.visible)
#endif
        }
        .disabled(viewModel.isLoading)
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
                if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.headline)
                        Text("To enable calendar access, go to System Settings > Privacy & Security > Calendars and enable access for this app.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        #if os(macOS)
                        Button("Open System Settings") {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.glassProminent)
                        #endif
                    }
                    .padding()
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(10)
                    .padding()
                }
            }
        )
        .alert(isPresented: $viewModel.showingInvalidCalendarAlert) {
            Alert(title: Text("Invalid Calendar"), message: Text("Please select a valid, writable calendar."), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $viewModel.showCreateCalendarSheet) {
            CreateCalendarSheet(
                onCreate: { title, color in
                    // Use async creation for new calendar
                    Task {
                        viewModel.createNewCalendar(title: title, color: color)
                        viewModel.showCreateCalendarSheet = false
                    }
                },
                onCancel: {
                    viewModel.showCreateCalendarSheet = false
                }
            )
        }
        .onAppear {
            print("[CalendarSettingsView] Settings view appeared")
            print("[CalendarSettingsView] Initial access granted: \(viewModel.accessGranted)")
            print("[CalendarSettingsView] Available calendars count: \(viewModel.writableCalendars.count)")
            viewModel.validateCalendarSelection()
        }
    }
    
    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "lock.shield", title: "Calendar Access")
            Text("Grant access to your calendars so the app can sync events and create new sessions. This is required before you can select which calendars to sync.")
                .formDescriptionStyle()
            HStack(alignment: .center, spacing: 12) {
                Text(viewModel.accessStatusText)
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
            }
        }
        .padding(20)
        .sectionCardStyle()
        .onAppear {
            print("[CalendarSettingsView] Permissions section appeared, access granted: \(viewModel.accessGranted)")
        }
    }
    
    private var defaultCalendarSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "calendar", title: "Default Calendar")
            Text("Choose which calendar new sessions will be created in by default. This should be one of your synced calendars.")
                .formDescriptionStyle()
            VStack(alignment: .leading, spacing: 8) {
                FormDropdown(
                    label: "Default Calendar",
                    options: viewModel.writableCalendars,
                    optionLabels: viewModel.calendarLabels,
                    selection: Binding<EKCalendar?>(
                        get: { viewModel.writableCalendars.first(where: { $0.calendarIdentifier == viewModel.preferences.selectedCalendarIdentifier }) },
                        set: { viewModel.preferences.selectedCalendarIdentifier = $0?.calendarIdentifier ?? "" }
                    )
                )
                if let error = viewModel.calendarErrorText {
                    Text(error).formErrorStyle()
                }
            }
            HStack {
                Spacer()
                Button("Create New Calendar") { viewModel.showCreateCalendarSheet = true }
                    .font(.callout).fontWeight(.semibold)
                    .buttonStyle(.glass)
            }
        }
        .padding(20)
        .sectionCardStyle()
    }
    
    private var defaultsForNewEventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "clock", title: "Defaults for New Events")
            Text("Set the default reminder and duration for new events you create in the app.")
                .formDescriptionStyle()
            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 6) {
                    FormStepper(
                        label: "Default Reminder (minutes before)",
                        value: Binding<Double>(
                            get: { Double(viewModel.preferences.defaultReminderMinutes) },
                            set: { viewModel.preferences.defaultReminderMinutes = Int($0) }
                        ),
                        range: 0...120,
                        step: 5
                    )
                    Text("How many minutes before the event should the default reminder be set?")
                        .formDescriptionStyle()
                }
                VStack(alignment: .leading, spacing: 6) {
                    FormStepper(
                        label: "Default Event Duration (minutes)",
                        value: Binding<Double>(
                            get: { Double(viewModel.preferences.defaultEventDurationMinutes) },
                            set: { viewModel.preferences.defaultEventDurationMinutes = Int($0) }
                        ),
                        range: 15...240,
                        step: 15
                    )
                    Text("How long should new events last by default?")
                        .formDescriptionStyle()
                }
            }
        }
        .padding(20)
        .sectionCardStyle()
    }
    
    private var syncPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "arrow.triangle.2.circlepath", title: "Sync Settings")
            Text("Control how events sync between this app and your synced calendars. Choose the sync direction, enable Google color support, and trigger manual syncs.")
                .formDescriptionStyle()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 24) {
                    FormToggle(label: "Enable Sync", isOn: $viewModel.preferences.syncEnabled)
                    FormToggle(label: "Sync Google Calendar Colors", isOn: $viewModel.preferences.syncGoogleColors)
                }
                FormDropdown(
                    label: "Sync Direction",
                    options: CalendarPreferences.SyncDirection.allCases,
                    optionLabels: Dictionary(uniqueKeysWithValues: CalendarPreferences.SyncDirection.allCases.map { ($0, $0.rawValue) }),
                    selection: Binding<CalendarPreferences.SyncDirection?>(
                        get: { viewModel.preferences.syncDirection },
                        set: { viewModel.preferences.syncDirection = $0 ?? .bidirectional }
                    )
                )
            }
            HStack {
                Spacer()
                Button("Manual Sync Now") {
                    Task { await viewModel.performManualSync() }
                }
                .accessibilityHint("Immediately synchronize all events between the app and your calendars.")
                .font(.callout).fontWeight(.semibold)
                .buttonStyle(.glassProminent)
            }
            if viewModel.preferences.lastSyncTimestamp > Date.distantPast {
                Text("Last Sync: \(viewModel.preferences.lastSyncTimestamp.formatted(.dateTime)) (\(viewModel.preferences.lastSyncStatus))")
                    .formDescriptionStyle()
            }
        }
        .padding(20)
        .sectionCardStyle()
    }
    
    private var monitoredCalendarsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "arrow.triangle.2.circlepath", title: "Synced Calendars")
            Text("Select which calendars the app should sync and monitor for events. Only events from these calendars will be available in the app.")
                .formDescriptionStyle()
            
            // Custom calendar list with color pickers
            VStack(spacing: 8) {
                ForEach(viewModel.writableCalendars, id: \.calendarIdentifier) { calendar in
                    CalendarRowView(
                        calendar: calendar,
                        isSelected: viewModel.selectedMonitoredCalendars.contains(CalendarSettingsViewModel.CalendarIdentifier(id: calendar.calendarIdentifier, title: calendar.title)),
                        onToggle: { isSelected in
                            if isSelected {
                                viewModel.selectedMonitoredCalendars.insert(CalendarSettingsViewModel.CalendarIdentifier(id: calendar.calendarIdentifier, title: calendar.title))
                            } else {
                                viewModel.selectedMonitoredCalendars.remove(CalendarSettingsViewModel.CalendarIdentifier(id: calendar.calendarIdentifier, title: calendar.title))
                            }
                        },
                        onColorChange: { newColor in
                            viewModel.updateCalendarColor(calendarIdentifier: calendar.calendarIdentifier, color: newColor)
                        },
                        currentColor: viewModel.getCalendarColor(calendarIdentifier: calendar.calendarIdentifier) ?? Color(calendar.cgColor)
                    )
                }
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.07))
            .cornerRadius(8)
            
            Text("Events from synced calendars will be available in the app. You can then use the calendar visibility toggle in the main view to show/hide specific calendars.")
                .formDescriptionStyle()
            
            // Helpful note about the relationship
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                Text("Tip: Use the calendar visibility toggle (📅) in the main calendar view to control which synced calendars are visible.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .sectionCardStyle()
    }
    
    private var recurrenceDefaultsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "repeat", title: "Default Recurrence Rule")
            Text("Set up how new recurring events repeat by default. You can customize frequency, days, and end conditions.")
                .formDescriptionStyle()
            HStack(spacing: 24) {
                FormDropdown(
                    label: "Frequency",
                    options: RecurrenceFrequency.allCases,
                    optionLabels: Dictionary(uniqueKeysWithValues: RecurrenceFrequency.allCases.map { ($0, $0.rawValue) }),
                    selection: Binding<RecurrenceFrequency?>(
                        get: { viewModel.preferences.defaultRecurrenceFrequency },
                        set: { viewModel.preferences.defaultRecurrenceFrequency = $0 ?? .none }
                    )
                )
                FormStepper(
                    label: "Repeat Every",
                    value: Binding<Double>(
                        get: { Double(viewModel.preferences.defaultRecurrenceInterval) },
                        set: { viewModel.preferences.defaultRecurrenceInterval = Int($0) }
                    ),
                    range: 1...100,
                    step: 1
                )
            }
            if viewModel.preferences.defaultRecurrenceFrequency == .weekly {
                FormMultiSelectRow(
                    label: "On Days",
                    optionLabels: Dictionary(uniqueKeysWithValues: SelectableWeekday.allCases.map { ($0, $0.shortName) }),
                    selectedOptions: Binding(get: {
                        Set(viewModel.preferences.defaultSelectedWeekdays.compactMap { SelectableWeekday(rawValue: $0) })
                    }, set: { newSet in
                        viewModel.preferences.defaultSelectedWeekdays = Set(newSet.map { $0.rawValue })
                    })
                )
                Text("Choose which days of the week the event should repeat on.")
                    .formDescriptionStyle()
            }
            if viewModel.preferences.defaultRecurrenceFrequency == .monthly {
                VStack(alignment: .leading, spacing: 8) {
                    FormDropdown(
                        label: "Rule Type",
                        options: PositionalRecurrenceType.allCases,
                        optionLabels: Dictionary(uniqueKeysWithValues: PositionalRecurrenceType.allCases.map { ($0, $0.rawValue) }),
                        selection: Binding<PositionalRecurrenceType?>(
                            get: { viewModel.preferences.defaultMonthlyRecurrenceType },
                            set: { viewModel.preferences.defaultMonthlyRecurrenceType = $0 ?? .onSpecificDays }
                        )
                    )
                    if viewModel.preferences.defaultMonthlyRecurrenceType == .onSpecificDays {
                        MonthDayGridView(selectedDays: Binding(get: {
                            viewModel.preferences.defaultSelectedMonthDaysNumbers
                        }, set: { newSet in
                            viewModel.preferences.defaultSelectedMonthDaysNumbers = newSet
                        }))
                        Text("Select the days of the month for the event to repeat.")
                            .formDescriptionStyle()
                    } else {
                        OrdinalPickerView(
                            ordinalSelection: Binding<OrdinalSelection?>(
                                get: { OrdinalSelection(intValue: viewModel.preferences.defaultSelectedOrdinal) },
                                set: { if let newValue = $0 { viewModel.preferences.defaultSelectedOrdinal = newValue.rawValue } }
                            ),
                            dayOfWeekSelection: Binding<DayOfWeekOption?>(
                                get: { DayOfWeekOption(rawValue: viewModel.preferences.defaultSelectedDayOfWeekForOrdinal) },
                                set: { if let newV = $0 { viewModel.preferences.defaultSelectedDayOfWeekForOrdinal = newV.rawValue } }
                            )
                        )
                        Text("Set a positional rule, like 'second Tuesday' of the month.")
                            .formDescriptionStyle()
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.07))
                .cornerRadius(10)
            }
            if viewModel.preferences.defaultRecurrenceFrequency == .yearly {
                VStack(alignment: .leading, spacing: 8) {
                    FormDropdown(
                        label: "Rule Type",
                        options: PositionalRecurrenceType.allCases,
                        optionLabels: Dictionary(uniqueKeysWithValues: PositionalRecurrenceType.allCases.map { ($0, $0.rawValue) }),
                        selection: Binding<PositionalRecurrenceType?>(
                            get: { viewModel.preferences.defaultYearlyRecurrenceType },
                            set: { viewModel.preferences.defaultYearlyRecurrenceType = $0 ?? .onSpecificDays }
                        )
                    )
                    FormMultiSelectRow(
                        label: "In Months",
                        optionLabels: Dictionary(uniqueKeysWithValues: SelectableMonth.allCases.map { ($0, $0.shortName) }),
                        selectedOptions: Binding(get: {
                            Set(viewModel.preferences.defaultSelectedYearMonths.compactMap { SelectableMonth(rawValue: $0) })
                        }, set: { newSet in
                            viewModel.preferences.defaultSelectedYearMonths = Set(newSet.map { $0.rawValue })
                        })
                    )
                    if viewModel.preferences.defaultYearlyRecurrenceType == .onSpecificDays {
                        MonthDayGridView(selectedDays: Binding(get: {
                            viewModel.preferences.defaultSelectedYearlyDaysNumbers
                        }, set: { newSet in
                            viewModel.preferences.defaultSelectedYearlyDaysNumbers = newSet
                        }))
                        Text("Select the days of the year for the event to repeat.")
                            .formDescriptionStyle()
                    } else {
                        OrdinalPickerView(
                            ordinalSelection: Binding<OrdinalSelection?>(
                                get: { OrdinalSelection(intValue: viewModel.preferences.defaultSelectedOrdinal) },
                                set: { if let newValue = $0 { viewModel.preferences.defaultSelectedOrdinal = newValue.rawValue } }
                            ),
                            dayOfWeekSelection: Binding<DayOfWeekOption?>(
                                get: { DayOfWeekOption(rawValue: viewModel.preferences.defaultSelectedDayOfWeekForOrdinal) },
                                set: { if let newV = $0 { viewModel.preferences.defaultSelectedDayOfWeekForOrdinal = newV.rawValue } }
                            )
                        )
                        Text("Set a positional rule for yearly recurrence, like 'third Friday' in June.")
                            .formDescriptionStyle()
                    }
                }
                .padding(12)
                .background(Color.accentColor.opacity(0.07))
                .cornerRadius(10)
            }
            FormDropdown(
                label: "Ends",
                options: RecurrenceEndType.allCases,
                optionLabels: Dictionary(uniqueKeysWithValues: RecurrenceEndType.allCases.map { ($0, $0.rawValue) }),
                selection: Binding<RecurrenceEndType?>(
                    get: { viewModel.preferences.defaultRecurrenceEndType },
                    set: { viewModel.preferences.defaultRecurrenceEndType = $0 ?? .never }
                )
            )
            if viewModel.preferences.defaultRecurrenceEndType == .afterCount {
                FormStepper(
                    label: "After",
                    value: Binding<Double>(
                        get: { Double(viewModel.preferences.defaultRecurrenceCount) },
                        set: { viewModel.preferences.defaultRecurrenceCount = Int($0) }
                    ),
                    range: 1...999,
                    step: 1
                )
                Text("Set how many times the event should repeat before ending.")
                    .formDescriptionStyle()
            } else if viewModel.preferences.defaultRecurrenceEndType == .onDate {
                FormDatePicker(
                    label: "End Date",
                    date: $viewModel.preferences.defaultRecurrenceEndDate,
                    range: Date()...Date.distantFuture
                )
                Text("Pick the date when the recurrence should stop.")
                    .formDescriptionStyle()
            }
            if let error = viewModel.recurrenceErrorText {
                Text(error).formErrorStyle()
            }
            if let helper = viewModel.recurrenceHelperText {
                Text(helper).formDescriptionStyle()
            }
        }
        .padding(20)
        .sectionCardStyle()
    }
    
    private var conflictResolutionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(icon: "exclamationmark.arrow.triangle.2.circlepath", title: "Conflict Resolution")
            Text("Choose how to handle conflicts when both the app and your calendar have changed the same event.")
                .formDescriptionStyle()
            HStack(spacing: 24) {
                FormDropdown(
                    label: "Policy",
                    options: CalendarPreferences.ConflictResolutionPolicy.allCases,
                    optionLabels: Dictionary(uniqueKeysWithValues: CalendarPreferences.ConflictResolutionPolicy.allCases.map { ($0, $0.rawValue) }),
                    selection: Binding<CalendarPreferences.ConflictResolutionPolicy?>(
                        get: { viewModel.preferences.conflictResolutionPolicy },
                        set: { viewModel.preferences.conflictResolutionPolicy = $0 ?? .prompt }
                    )
                )
                FormToggle(label: "Auto-Resolve Recurring Conflicts", isOn: $viewModel.preferences.autoResolveRecurringConflicts)
            }
            Text("'Prefer App Data' always keeps your changes, 'Prefer Calendar Data' always pulls from the calendar, and 'Prompt User' asks you each time.")
                .formDescriptionStyle()
            Text("If enabled, recurring event conflicts will be resolved automatically using the selected policy.")
                .formDescriptionStyle()
        }
        .padding(20)
        .sectionCardStyle()
    }
    
    private var resetButtonSection: some View {
        VStack {
            HStack {
                Spacer()
                Button("Reset All Calendar Settings") {
                    viewModel.showingResetConfirmation = true
                }
                .accessibilityLabel("Reset All Calendar Settings")
                .accessibilityHint("Resets all calendar preferences to their default values.")
                .padding(.top, 16)
                .font(.callout)
                .fontWeight(.semibold)
                .buttonStyle(.glass)
            }
            Text("This will restore all calendar settings to their original defaults. Use with caution.")
                .formDescriptionStyle()
            .confirmationDialog(
                "Reset all calendar settings to defaults?",
                isPresented: Binding<Bool>(
                    get: { viewModel.showingResetConfirmation },
                    set: { viewModel.showingResetConfirmation = $0 }
                )
            ) {
                Button("Reset", role: .destructive) { viewModel.preferences.resetToDefaults() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    private var clearSessionsSection: some View {
        VStack {
            HStack {
                Spacer()
                Button("Clear All Sessions (App Only)") {
                    viewModel.showingClearSessionsConfirmation = true
                }
                .accessibilityLabel("Clear All Sessions")
                .accessibilityHint("Deletes all session data in the app, but does not affect your calendar events.")
                .padding(.top, 16)
                .font(.callout)
                .fontWeight(.semibold)
                .buttonStyle(.glass)
                .foregroundColor(.red)
            }
            Text("This will permanently delete all session data from the app, but will NOT remove any events from your calendars.")
                .formDescriptionStyle()
            .confirmationDialog(
                "Delete all session data from the app? This cannot be undone.",
                isPresented: Binding<Bool>(
                    get: { viewModel.showingClearSessionsConfirmation },
                    set: { viewModel.showingClearSessionsConfirmation = $0 }
                )
            ) {
                Button("Delete All Sessions", role: .destructive) { viewModel.clearAllSessions(modelContext: modelContext) }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - Calendar Row View with Color Picker

struct CalendarRowView: View {
    let calendar: EKCalendar
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    let onColorChange: (Color) -> Void
    let currentColor: Color
    
    @State private var showingColorPicker = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                onToggle(!isSelected)
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .accentColor : .white.opacity(0.6))
            }
            .buttonStyle(.plain)
            
            // Calendar name
            Text(calendar.title)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Color picker button
            Button(action: {
                showingColorPicker.toggle()
            }) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingColorPicker) {
                VStack(spacing: 16) {
                    Text("Calendar Color")
                        .font(.headline)
                        .padding(.top)
                    
                    ColorPicker("", selection: Binding(
                        get: { currentColor },
                        set: { onColorChange($0) }
                    ))
                    .labelsHidden()
                    .frame(width: 200, height: 200)
                    
                    Button("Reset to Default") {
                        onColorChange(Color(calendar.cgColor))
                        showingColorPicker = false
                    }
                    .buttonStyle(.glass)
                    
                    Spacer()
                }
                .frame(width: 250, height: 300)
                .padding()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
    }
}

 
