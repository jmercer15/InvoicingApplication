import SwiftUI
import SwiftData

// ─────────────────────────────────────────────────────────────
// MARK: - Session Form View (Used in Sheet)
// ─────────────────────────────────────────────────────────────

struct NewSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: NewSessionViewModel // Use the extracted ViewModel
    var onSave: (() -> Void)? // Callback for after saving

    @State private var titleError: String? = nil // State for inline error message
    @State private var showCustomRecurrenceSheet: Bool = false
    @State private var selectedRepeatOption: RepeatOption? = .never
    
    // Repeat options for Apple-style recurrence UI
    enum RepeatOption: String, CaseIterable, Identifiable {
        case never = "Never"
        case everyDay = "Every Day"
        case everyWeek = "Every Week"
        case every2Weeks = "Every 2 Weeks"
        case everyMonth = "Every Month"
        case everyYear = "Every Year"
        case custom = "Custom..."
        
        var id: String { rawValue }
    }
    
    // Helper to update recurrence settings based on selected option
    private func applyRepeatOption(_ option: RepeatOption) {
        switch option {
        case .never:
            viewModel.formModel.recurrenceFrequency = .none
        case .everyDay:
            viewModel.formModel.recurrenceFrequency = .daily
            viewModel.formModel.recurrenceInterval = 1
        case .everyWeek:
            viewModel.formModel.recurrenceFrequency = .weekly
            viewModel.formModel.recurrenceInterval = 1
        case .every2Weeks:
            viewModel.formModel.recurrenceFrequency = .weekly
            viewModel.formModel.recurrenceInterval = 2
        case .everyMonth:
            viewModel.formModel.recurrenceFrequency = .monthly
            viewModel.formModel.recurrenceInterval = 1
        case .everyYear:
            viewModel.formModel.recurrenceFrequency = .yearly
            viewModel.formModel.recurrenceInterval = 1
        case .custom:
            // Do not change settings, just show custom sheet
            break
        }
    }
    
    // Computed summary text for recurrence
    private var recurrenceSummary: String {
        guard let selected = selectedRepeatOption else { return "Does not repeat" }
        if selected == .never || viewModel.formModel.recurrenceFrequency == .none {
            return "Does not repeat"
        }
        switch selected {
        case .everyDay: return "Repeats every day"
        case .everyWeek: return "Repeats every week"
        case .every2Weeks: return "Repeats every 2 weeks"
        case .everyMonth: return "Repeats every month"
        case .everyYear: return "Repeats every year"
        case .custom:
            return viewModel.recurrenceSummaryText
        default: return "Does not repeat"
        }
    }

    // Fetch clients directly here for the Picker
    @Query(sort: \ClientEntity.fullName) private var clients: [ClientEntity]

    // Binding helpers for Int -> Double conversion for FormStepper
    private var recurrenceIntervalProxy: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.formModel.recurrenceInterval) },
            set: { viewModel.formModel.recurrenceInterval = Int($0) }
        )
    }

    private var recurrenceCountProxy: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.formModel.recurrenceCount) },
            set: { viewModel.formModel.recurrenceCount = Int($0) }
        )
    }
    
    // Binding helper for Int-based Enum -> Enum? for FormDropdown
    private func ordinalDropdownBinding() -> Binding<DayOfWeekOption?> {
        Binding<DayOfWeekOption?>(
            get: { viewModel.formModel.selectedDayOfWeekForOrdinal },
            set: {
                if let newV = $0 {
                    viewModel.formModel.selectedDayOfWeekForOrdinal = newV
                }
            }
        )
    }

    // Binding helper for Int -> OrdinalSelection for FormDropdown
    private var ordinalSelectionProxy: Binding<OrdinalSelection?> {
        Binding<OrdinalSelection?>(
            get: { OrdinalSelection(intValue: viewModel.formModel.selectedOrdinal) },
            set: {
                if let newValue = $0 {
                    viewModel.formModel.selectedOrdinal = newValue.rawValue
                }
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) { // Reduced spacing from 24 to 12
                sessionHeaderView
                    .padding(.bottom, 4) // Reduced from 8 to 4

                VStack(alignment: .leading, spacing: 12) { // Reduced spacing from 24 to 12
                    detailsSection
                    locationSection
                    clientServiceSection
                    recurrenceSection
                    notesSection
                }
            }
            .padding(.horizontal, 20) // Standard 20-point margins
            .padding(.top, 14) // 14 points from top
            .padding(.bottom, 20) // 20 points from bottom
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundColor(.white)
        .frame(idealWidth: 500, maxWidth: 600, minHeight: 500, idealHeight: 600) // Reduced dimensions
        .onAppear {
            // Set the Repeat dropdown to match the loaded recurrence values
            selectedRepeatOption = repeatOptionForCurrentRecurrence()
            print("[NewSessionView] Setting onSaveCompleted callback")
            viewModel.onSaveCompleted = {
                print("[NewSessionView] onSaveCompleted callback triggered, dismissing sheet")
                dismiss()
            }
            print("[NewSessionView] onSaveCompleted callback set successfully")
        }
        .sheet(isPresented: $viewModel.showingEditModeDialog) {
            RecurringEditModeDialog(
                selectedMode: $viewModel.selectedEditMode,
                onConfirm: {
                    viewModel.showingEditModeDialog = false
                    viewModel.completeSaveWithSelectedMode()
                },
                onCancel: {
                    viewModel.showingEditModeDialog = false
                }
            )
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.glass)
                    .appInteractiveCursor()
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { viewModel.handleSaveButtonTapped() }
                    .buttonStyle(.glassProminent)
                    .appInteractiveCursor()
            }
        }
        
    }

    // Helper to map recurrence values to RepeatOption
    private func repeatOptionForCurrentRecurrence() -> RepeatOption? {
        switch viewModel.formModel.recurrenceFrequency {
        case .none:
            return .never
        case .daily:
            return viewModel.formModel.recurrenceInterval == 1 ? .everyDay : .custom
        case .weekly:
            if viewModel.formModel.recurrenceInterval == 1 {
                return .everyWeek
            } else if viewModel.formModel.recurrenceInterval == 2 {
                return .every2Weeks
            } else {
                return .custom
            }
        case .monthly:
            return viewModel.formModel.recurrenceInterval == 1 ? .everyMonth : .custom
        case .yearly:
            return viewModel.formModel.recurrenceInterval == 1 ? .everyYear : .custom
        }
    }
    
    // MARK: - Header
    private var sessionHeaderView: some View {
        VStack(alignment: .leading, spacing: 6) { // Reduced spacing from 8 to 6
            HStack {
                TextField("Session Title", text: $viewModel.formModel.title)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.formModel.title) { _, newValue in
                        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Handle empty title
                        }
                    }
                    .font(.title.weight(.bold)) // Reduced from .largeTitle to .title
                    .foregroundColor(titleError != nil ? .red : .white)
                
                Spacer()

                EnumDropdown(label: "Status", selection: Binding(
                    get: { SessionStatus(rawValue: viewModel.formModel.status) ?? .planned },
                    set: { newValue in
                        viewModel.formModel.status = newValue.rawValue
                    }
                ), displayStyle: .menu)
                    .frame(width: 120) // Reduced from 150 to 120
            }

            if let error = titleError {
                Text(error).font(.caption).foregroundColor(.red)
            }
        }
        .padding(.horizontal, 20) // Reduced from 24 to 20
        .padding(.vertical, 8) // Reduced from 12 to 8
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(hex: "#3F51B5"), Color(hex: "#283593")]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(8) // Reduced from 12 to 8
    }
    
    // MARK: - Form Sections
    @ViewBuilder
    private var detailsSection: some View {
        CompactDetailSection(title: "Session Details", systemImage: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 6) { // Reduced spacing from default to 6
                if viewModel.hasGoogleColor(), let colorName = viewModel.googleColorName {
                    HStack {
                        if let color = viewModel.getGoogleColor() {
                            Circle().fill(color).frame(width: 12, height: 12) // Smaller indicator
                        }
                        Text("Google Calendar Color: \(colorName)").font(.caption).foregroundColor(.secondary)
                        Spacer()
                        Toggle("Use", isOn: $viewModel.formModel.useGoogleColor).toggleStyle(.switch)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                
                FormField(
                    label: "Title",
                    text: $viewModel.formModel.title,
                    placeholder: "Enter session title",
                    isRequired: true,
                    errorText: titleError,
                    leadingIcon: "text.alignleft",
                    layoutStyle: .compact
                )
                
                // Date and Time Layout - More responsive
                VStack(spacing: 8) {
                    // Date row
                    FormDatePicker(
                        label: "Date",
                        date: $viewModel.formModel.startTime,
                        leadingIcon: "calendar",
                        layoutStyle: .compact
                    )
                    
                    // Time row - Only show when not all day
                    if !viewModel.formModel.isAllDay {
                        HStack(spacing: 12) {
                            FormTimePicker(
                                label: "Start",
                                time: $viewModel.formModel.startTime,
                                leadingIcon: "clock",
                                layoutStyle: .compact
                            )
                            
                            FormTimePicker(
                                label: "End",
                                time: $viewModel.formModel.endTime,
                                leadingIcon: "clock.fill",
                                layoutStyle: .compact
                            )
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    FormDropdown(
                        label: "Status",
                        options: SessionStatus.allCases,
                        optionLabels: Dictionary(uniqueKeysWithValues: SessionStatus.allCases.map { ($0, $0.rawValue) }),
                        selection: Binding<SessionStatus?>(
                            get: { SessionStatus(rawValue: viewModel.formModel.status) ?? .planned },
                            set: { newValue in
                                if let newValue = newValue {
                                    viewModel.formModel.status = newValue.rawValue
                                }
                            }
                        ),
                        leadingIcon: "flag",
                        layoutStyle: .compact
                    )
                    
                    FormToggle(
                        label: "All Day",
                        isOn: $viewModel.formModel.isAllDay,
                        leadingIcon: "calendar.badge.clock",
                        layoutStyle: .compact
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var locationSection: some View {
        CompactDetailSection(title: "Location", systemImage: "mappin.and.ellipse") {
                AddressSearchField(
                    searchText: $viewModel.formModel.addressSearchText,
                    selectedAddress: $viewModel.formModel.selectedAddress,
                    unitNumber: $viewModel.formModel.unitNumber,
                    streetNumber: $viewModel.formModel.streetNumber,
                    streetName: $viewModel.formModel.streetName,
                    suburb: $viewModel.formModel.suburb,
                    postcode: $viewModel.formModel.postcode,
                    state: $viewModel.formModel.state,
                    country: $viewModel.formModel.country,
                    poBox: $viewModel.formModel.poBox
                )
                .onChange(of: viewModel.formModel.selectedAddress) { _, newValue in
                    if newValue != nil {
                        // Address data is already updated through bindings
                    }
                }
        }
    }

    @ViewBuilder
    private var clientServiceSection: some View {
        CompactDetailSection(title: "Client & Service", systemImage: "person.2.fill") {
            VStack(alignment: .leading, spacing: 6) { // Compact spacing
                EntityDropdown(
                    label: "Client",
                    entities: clients.map { $0 },
                    selection: $viewModel.selectedClient,
                    placeholder: "Select a client",
                    isRequired: true,
                    layoutStyle: .compact
                )
                
                if let selectedClient = viewModel.selectedClient {
                    EntityDropdown(
                        label: "Service",
                        entities: Array(selectedClient.clientServices ?? []),
                        selection: $viewModel.selectedClientService,
                        placeholder: "Select a service",
                        isRequired: true,
                        layoutStyle: .compact
                    )
                } else {
                    FormDropdown<ClientServiceEntity>(
                        label: "Service",
                        options: [],
                        optionLabels: [:],
                        selection: .constant(nil),
                        placeholder: "Select a client first",
                        layoutStyle: .compact
                    )
                    .disabled(true)
                }
            }
        }
    }
    
    @ViewBuilder
    private var recurrenceSection: some View {
        CompactDetailSection(title: "Recurrence", systemImage: "repeat.circle") {
            VStack(alignment: .leading, spacing: 4) { // Very compact spacing
                FormDropdown(
                    label: "Repeat",
                    options: RepeatOption.allCases,
                    optionLabels: Dictionary(uniqueKeysWithValues: RepeatOption.allCases.map { ($0, $0.rawValue) }),
                    selection: $selectedRepeatOption,
                    layoutStyle: .compact
                )
                .onChange(of: selectedRepeatOption) { _, newValue in
                    guard let newValue = newValue else { return }
                    if newValue == .custom {
                        // Show custom recurrence fields inline instead of opening sheet
                        viewModel.formModel.recurrenceFrequency = .daily // Default to daily for custom
                    } else {
                        applyRepeatOption(newValue)
                    }
                }
                
                // Show custom recurrence fields inline when custom is selected
                if selectedRepeatOption == .custom {
                    recurrenceDetailsView()
                        .padding(.top, 8)
                }
                
                Text(recurrenceSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 2) // Reduced from 4 to 2
            }
        }
    }
    
    // MARK: - Recurrence Details (Helper View)
    @ViewBuilder
    private func recurrenceDetailsView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Frequency selector for custom recurrence
            EnumDropdown(
                label: "Frequency",
                selection: $viewModel.formModel.recurrenceFrequency,
                displayStyle: .menu,
                layoutStyle: .compact
            )
            
            HStack {
                FormStepper(
                    label: "Every",
                    value: recurrenceIntervalProxy,
                    range: 1...100,
                    step: 1
                )
                Text(pluralizeUnit(viewModel.formModel.recurrenceFrequency, interval: viewModel.formModel.recurrenceInterval))
                Spacer()
            }
            
            if viewModel.formModel.recurrenceFrequency == .weekly {
                dayOfWeekSelector()
            }
            
            if viewModel.formModel.recurrenceFrequency == .monthly {
                monthlyRecurrenceTypeSelector()
            }
            
            if viewModel.formModel.recurrenceFrequency == .yearly {
                yearlyRecurrenceTypeSelector()
            }

            Divider().padding(.vertical, 4)
            
            EnumDropdown(
                label: "Ends", 
                selection: $viewModel.formModel.recurrenceEndType, 
                displayStyle: .menu,
                layoutStyle: .compact
            )
            
            if viewModel.formModel.recurrenceEndType == .afterCount {
                FormStepper(
                    label: "After",
                    value: recurrenceCountProxy,
                    range: 1...999,
                    step: 1
                )
            } else if viewModel.formModel.recurrenceEndType == .onDate {
                FormDatePicker(
                    label: "End Date",
                    date: $viewModel.formModel.recurrenceEndDate,
                    range: viewModel.formModel.startTime...Date.distantFuture,
                    layoutStyle: .compact
                )
            }
        }
    }
    
    // MARK: - Recurrence Detail Sub-Views
    @ViewBuilder
    private func dayOfWeekSelector() -> some View {
        FormMultiSelectRow(
            label: "On Days",
            optionLabels: Dictionary(uniqueKeysWithValues: SelectableWeekday.allCases.map { ($0, $0.shortName) }),
            selectedOptions: $viewModel.formModel.selectedWeekdays
        )
    }
    
    @ViewBuilder
    private func monthlyRecurrenceTypeSelector() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            EnumDropdown(label: "Rule Type", selection: $viewModel.formModel.monthlyRecurrenceType, displayStyle: .segmented)

            if viewModel.formModel.monthlyRecurrenceType == .onSpecificDays {
                MonthDayGridView(selectedDays: $viewModel.formModel.selectedMonthDaysNumbers)
                
            } else {
                OrdinalPickerView(
                    ordinalSelection: ordinalSelectionProxy,
                    dayOfWeekSelection: ordinalDropdownBinding()
                    )
            }
        }
    }
    
    @ViewBuilder
    private func yearlyRecurrenceTypeSelector() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Custom month selection for Set<Int>
            VStack(alignment: .leading, spacing: 4) {
                Text("In Months")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(SelectableMonth.allCases, id: \.self) { month in
                        Button(action: {
                            toggleMonthSelection(month, in: viewModel)
                        }) {
                            Text(month.shortName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .background(viewModel.formModel.selectedYearMonths.contains(month) ? Color.accentColor : Color.white.opacity(0.1))
                                .foregroundColor(viewModel.formModel.selectedYearMonths.contains(month) ? .white : .white.opacity(0.8))
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().padding(.vertical, 4)

            EnumDropdown(label: "Rule Type", selection: $viewModel.formModel.yearlyRecurrenceType, displayStyle: .segmented)

            if viewModel.formModel.yearlyRecurrenceType == .onSpecificDays {
                MonthDayGridView(selectedDays: $viewModel.formModel.selectedYearlyDaysNumbers)
            } else {
                OrdinalPickerView(
                    ordinalSelection: ordinalSelectionProxy,
                    dayOfWeekSelection: ordinalDropdownBinding()
                    )
            }
        }
    }
    
    @ViewBuilder
    private var notesSection: some View {
        CompactDetailSection(title: "Notes", systemImage: "note.text") {
            FormTextArea(label: "", text: $viewModel.formModel.notes, placeholder: "Add any relevant notes for this session...", minHeight: 60) // Reduced from 100 to 60
        }
    }
}

fileprivate func pluralizeUnit(_ frequency: RecurrenceFrequency, interval: Int) -> String {
    let unit: String
    switch frequency {
    case .daily: unit = "day"
    case .weekly: unit = "week"
    case .monthly: unit = "month"
    case .yearly: unit = "year"
    case .none: return ""
    }
    return interval == 1 ? unit : unit + "s"
}

// MARK: - Helper Functions

@MainActor
private func toggleMonthSelection(_ month: SelectableMonth, in viewModel: NewSessionViewModel) {
    if viewModel.formModel.selectedYearMonths.contains(month) {
        viewModel.formModel.selectedYearMonths.remove(month)
    } else {
        viewModel.formModel.selectedYearMonths.insert(month)
    }
}

// MARK: - Recurrence UI Components

struct MonthDayGridView: View {
    @Binding var selectedDays: Set<Int>
    private let columns = [GridItem](repeating: .init(.flexible()), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...31, id: \.self) { day in
                Button(action: {
                    toggleSelection(for: day)
                }) {
                    Text("\(day)")
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(background(for: day))
                        .clipShape(Circle())
                        .foregroundColor(foreground(for: day))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }

    private func toggleSelection(for day: Int) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    @ViewBuilder
    private func background(for day: Int) -> some View {
        if selectedDays.contains(day) {
            Circle().fill(Color.accentColor)
        } else {
            Circle().fill(Color.white.opacity(0.1))
        }
    }
    
    private func foreground(for day: Int) -> Color {
        if selectedDays.contains(day) {
            return .white
        } else {
            return .white.opacity(0.8)
        }
    }
}

struct OrdinalPickerView: View {
    var ordinalSelection: Binding<OrdinalSelection?>
    var dayOfWeekSelection: Binding<DayOfWeekOption?>

    var body: some View {
        HStack {
            Text("On the")
                .foregroundColor(.secondary)
            
            FormDropdown(
                label: "",
                options: OrdinalSelection.allCases,
                optionLabels: Dictionary(uniqueKeysWithValues: OrdinalSelection.allCases.map { ($0, $0.displayName) }),
                selection: ordinalSelection
            )
            .frame(minWidth: 120)

            FormDropdown(
                label: "",
                options: DayOfWeekOption.allCases,
                optionLabels: Dictionary(uniqueKeysWithValues: DayOfWeekOption.allCases.map { ($0, $0.displayName) }),
                selection: dayOfWeekSelection
            )
            .frame(minWidth: 150)
        }
    }
}

struct RecurringEditModeDialog: View {
    @Binding var selectedMode: RecurringEditMode
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("Edit Recurring Session")
                .font(.title2).fontWeight(.bold)
            Text("Do you want to apply your changes to:")
                .font(.body)
            Picker("Edit Mode", selection: $selectedMode) {
                Text("This Instance Only").tag(RecurringEditMode.thisOnly)
                Text("This and Future Instances").tag(RecurringEditMode.thisAndFuture)
                Text("All Instances").tag(RecurringEditMode.all)
            }
            .pickerStyle(.segmented)
            HStack {
                Button("Cancel", action: onCancel)
                Spacer()
                Button("Confirm", action: onConfirm)
                    .fontWeight(.bold)
            }
        }
        .padding(32)
        .frame(width: 400)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(16)
        .shadow(radius: 20)
    }
}

// MARK: - Custom Recurrence Sheet
private struct CustomRecurrenceSheet: View {
    @ObservedObject var viewModel: NewSessionViewModel
    var onDone: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) { // Reduced from 24 to 16
                    // Frequency
                    EnumDropdown(
                        label: "Frequency",
                        selection: $viewModel.formModel.recurrenceFrequency,
                        displayStyle: .menu
                    )
                    // Interval
                    FormStepper(
                        label: "Every",
                        value: Binding<Double>(
                            get: { Double(viewModel.formModel.recurrenceInterval) },
                            set: { viewModel.formModel.recurrenceInterval = Int($0) }
                        ),
                        range: 1...100,
                        step: 1
                    )
                    Text(viewModel.formModel.recurrenceFrequency != .none ? pluralizeUnit(viewModel.formModel.recurrenceFrequency, interval: viewModel.formModel.recurrenceInterval) : "")
                    // Weekly
                    if viewModel.formModel.recurrenceFrequency == .weekly {
                        FormMultiSelectRow(
                            label: "On Days",
                            optionLabels: Dictionary(uniqueKeysWithValues: SelectableWeekday.allCases.map { ($0, $0.shortName) }),
                            selectedOptions: $viewModel.formModel.selectedWeekdays
                        )
                    }
                    // Monthly
                    if viewModel.formModel.recurrenceFrequency == .monthly {
                        VStack(alignment: .leading, spacing: 6) { // Reduced from 8 to 6
                            EnumDropdown(label: "Rule Type", selection: $viewModel.formModel.monthlyRecurrenceType, displayStyle: .segmented)
                            if viewModel.formModel.monthlyRecurrenceType == .onSpecificDays {
                                MonthDayGridView(selectedDays: $viewModel.formModel.selectedMonthDaysNumbers)
                            } else {
                                OrdinalPickerView(
                                    ordinalSelection: Binding<OrdinalSelection?>(
                                        get: { OrdinalSelection(intValue: viewModel.formModel.selectedOrdinal) },
                                        set: { if let newValue = $0 { viewModel.formModel.selectedOrdinal = newValue.rawValue } }
                                    ),
                                    dayOfWeekSelection: Binding<DayOfWeekOption?>(
                                        get: { viewModel.formModel.selectedDayOfWeekForOrdinal },
                                        set: { if let newV = $0 { viewModel.formModel.selectedDayOfWeekForOrdinal = newV } }
                                    )
                                )
                            }
                        }
                    }
                    // Yearly
                    if viewModel.formModel.recurrenceFrequency == .yearly {
                        VStack(alignment: .leading, spacing: 6) { // Reduced from 8 to 6
                            // Custom month selection for Set<Int>
                            VStack(alignment: .leading, spacing: 4) {
                                Text("In Months")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white.opacity(0.8))
                                
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    ForEach(SelectableMonth.allCases, id: \.self) { month in
                                        Button(action: {
                                            toggleMonthSelection(month, in: viewModel)
                                        }) {
                                            Text(month.shortName)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .frame(maxWidth: .infinity, minHeight: 30)
                                                .background(viewModel.formModel.selectedYearMonths.contains(month) ? Color.accentColor : Color.white.opacity(0.1))
                                                .foregroundColor(viewModel.formModel.selectedYearMonths.contains(month) ? .white : .white.opacity(0.8))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            Divider().padding(.vertical, 2) // Reduced from 4 to 2
                            EnumDropdown(label: "Rule Type", selection: $viewModel.formModel.yearlyRecurrenceType, displayStyle: .segmented)
                            if viewModel.formModel.yearlyRecurrenceType == .onSpecificDays {
                                MonthDayGridView(selectedDays: $viewModel.formModel.selectedYearlyDaysNumbers)
                            } else {
                                OrdinalPickerView(
                                    ordinalSelection: Binding<OrdinalSelection?>(
                                        get: { OrdinalSelection(intValue: viewModel.formModel.selectedOrdinal) },
                                        set: { if let newValue = $0 { viewModel.formModel.selectedOrdinal = newValue.rawValue } }
                                    ),
                                    dayOfWeekSelection: Binding<DayOfWeekOption?>(
                                        get: { viewModel.formModel.selectedDayOfWeekForOrdinal },
                                        set: { if let newV = $0 { viewModel.formModel.selectedDayOfWeekForOrdinal = newV } }
                                    )
                                )
                            }
                        }
                    }
                    Divider().padding(.vertical, 2) // Reduced from 4 to 2
                    EnumDropdown(label: "Ends", selection: $viewModel.formModel.recurrenceEndType, displayStyle: .menu)
                    if viewModel.formModel.recurrenceEndType == .afterCount {
                        FormStepper(
                            label: "After",
                            value: Binding<Double>(
                                get: { Double(viewModel.formModel.recurrenceCount) },
                                set: { viewModel.formModel.recurrenceCount = Int($0) }
                            ),
                            range: 1...999,
                            step: 1
                        )
                    } else if viewModel.formModel.recurrenceEndType == .onDate {
                        FormDatePicker(
                            label: "End Date",
                            date: $viewModel.formModel.recurrenceEndDate,
                            range: viewModel.formModel.startTime...Date.distantFuture,
                            layoutStyle: .compact
                        )
                    }
                }
                .padding(16) // Reduced from 24 to 16
            }
            .navigationTitle("Custom Recurrence")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .appInteractiveCursor()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                        .fontWeight(.bold)
                        .appInteractiveCursor()
                }
            }
        }
        .frame(minWidth: 350, minHeight: 450) // Reduced from 400x600 to 350x450
    }
}

// MARK: - Compact Detail Section for Session Form
struct CompactDetailSection<Content: View>: View {
    let title: String
    let systemImage: String?
    @ViewBuilder let content: Content

    init(title: String, systemImage: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) { // Reduced spacing from 8 to 6
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12)) // Smaller icon
                }
                Text(title)
                    .font(.subheadline) // Smaller font
                    .fontWeight(.semibold) // Reduced weight
                    .textCase(.uppercase)
                    .tracking(0.5) // Reduced tracking
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 12) // Reduced from 16 to 12
            .padding(.vertical, 6) // Reduced from 10 to 6
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.gray.opacity(0.2))
            
            VStack(alignment: .leading, spacing: 4) { // Reduced spacing from 8 to 4
                content
            }
            .padding(.horizontal, 12) // Reduced from 16 to 12
            .padding(.vertical, 8) // Reduced from 16 to 8
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(8) // Reduced from 12 to 8
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
