import SwiftUI
import Core
import SharedUI
import Observation

// Simple replacement for OrdinalPickerView
struct OrdinalPickerView: View {
    @Binding var ordinalSelection: OrdinalSelection?
    @Binding var dayOfWeekSelection: DayOfWeekOption?
    
    var body: some View {
        VStack {
            Picker("Ordinal", selection: $ordinalSelection) {
                Text("First").tag(OrdinalSelection.first as OrdinalSelection?)
                Text("Second").tag(OrdinalSelection.second as OrdinalSelection?)
                Text("Third").tag(OrdinalSelection.third as OrdinalSelection?)
                Text("Fourth").tag(OrdinalSelection.fourth as OrdinalSelection?)
                Text("Last").tag(OrdinalSelection.last as OrdinalSelection?)
            }
            .pickerStyle(.segmented)
            
            Picker("Day of Week", selection: $dayOfWeekSelection) {
                Text("Monday").tag(DayOfWeekOption.monday as DayOfWeekOption?)
                Text("Tuesday").tag(DayOfWeekOption.tuesday as DayOfWeekOption?)
                Text("Wednesday").tag(DayOfWeekOption.wednesday as DayOfWeekOption?)
                Text("Thursday").tag(DayOfWeekOption.thursday as DayOfWeekOption?)
                Text("Friday").tag(DayOfWeekOption.friday as DayOfWeekOption?)
                Text("Saturday").tag(DayOfWeekOption.saturday as DayOfWeekOption?)
                Text("Sunday").tag(DayOfWeekOption.sunday as DayOfWeekOption?)
            }
            .pickerStyle(.menu)
        }
    }
}

// Simple replacement for MonthDayGridView
struct MonthDayGridView: View {
    @Binding var selectedDays: Set<Int>
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: FormSectionTokens.labelFieldSpacing) {
            ForEach(1...31, id: \.self) { day in
                Button(action: {
                    if selectedDays.contains(day) {
                        selectedDays.remove(day)
                    } else {
                        selectedDays.insert(day)
                    }
                }) {
                    Text("\(day)")
                        .font(.caption)
                        .frame(width: StyleGuide.Dimensions.entityListIconWidth, height: StyleGuide.Dimensions.entityListIconWidth)
                        .background(selectedDays.contains(day) ? Color.blue : Color.clear)
                        .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall, style: .continuous))
                        .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusXSmall, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Recurrence Settings Views

struct RecurrenceDefaultsView: View {
    @Bindable var viewModel: CalendarSettingsViewModel
    @Bindable var preferences: CalendarPreferencesStore
    let maxLabelWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
            SectionHeader(
                icon: "repeat",
                title: "Default Recurrence Rule",
                description: "Set up how new recurring events repeat by default. You can customize frequency, days, and end conditions."
            )
            VStack(spacing: FormSectionTokens.sectionStackSpacing) {
                RecurrenceBasicSettingsCard(preferences: preferences, maxLabelWidth: maxLabelWidth)
                
                if preferences.defaultRecurrenceFrequency == .weekly {
                    RecurrenceWeeklyOptionsCard(preferences: preferences)
                }
                
                if preferences.defaultRecurrenceFrequency == .monthly {
                    RecurrenceMonthlyOptionsCard(preferences: preferences, maxLabelWidth: maxLabelWidth)
                }
                
                if preferences.defaultRecurrenceFrequency == .yearly {
                    RecurrenceYearlyOptionsCard(preferences: preferences, maxLabelWidth: maxLabelWidth)
                }
                
                RecurrenceEndOptionsCard(preferences: preferences, maxLabelWidth: maxLabelWidth)
                
                if let error = viewModel.recurrenceErrorText {
                    Text(error).formErrorStyle()
                }
                if let helper = viewModel.recurrenceHelperText {
                    Text(helper).formDescriptionStyle()
                }
            }
        }
        .standardSectionStyle()
    }
}

struct RecurrenceBasicSettingsCard: View {
    @Bindable var preferences: CalendarPreferencesStore
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Recurrence Frequency:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<RecurrenceFrequency?>(
                    get: { preferences.defaultRecurrenceFrequency },
                    set: { preferences.defaultRecurrenceFrequency = $0 ?? .none }
                )) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency as RecurrenceFrequency?)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Recurrence frequency")
                .accessibilityHint("Select the default frequency for recurring events")
                InfoIcon(tooltip: "How often the event should repeat")
            }
        }
        
        SettingsRow(label: "Recurrence Interval:", labelWidth: maxLabelWidth) {
            HStack {
                TextField("Enter interval", value: Binding<Double>(
                    get: { Double(preferences.defaultRecurrenceInterval) },
                    set: { preferences.defaultRecurrenceInterval = Int($0) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                Stepper("", value: Binding<Double>(
                    get: { Double(preferences.defaultRecurrenceInterval) },
                    set: { preferences.defaultRecurrenceInterval = Int($0) }
                ), in: 1...100, step: 1)
                    .accessibilityLabel("Adjust recurrence interval")
                InfoIcon(tooltip: "Every X frequency units (e.g., every 2 weeks)")
            }
        }
    }
}

struct RecurrenceWeeklyOptionsCard: View {
    @Bindable var preferences: CalendarPreferencesStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("On Days")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                    ForEach(SelectableWeekday.allCases, id: \.self) { weekday in
                        HStack {
                            Button(action: {
                                if preferences.defaultSelectedWeekdays.contains(weekday.rawValue) {
                                    preferences.defaultSelectedWeekdays.remove(weekday.rawValue)
                                } else {
                                    preferences.defaultSelectedWeekdays.insert(weekday.rawValue)
                                }
                            }) {
                                Image(systemName: preferences.defaultSelectedWeekdays.contains(weekday.rawValue) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(preferences.defaultSelectedWeekdays.contains(weekday.rawValue) ? .blue : .gray)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Text(weekday.shortName)
                            Spacer()
                        }
                        .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .padding(StyleGuide.Dimensions.paddingXMedium)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
        
        HStack {
            Spacer()
            InfoIcon(tooltip: "Choose which days of the week the event should repeat on.")
        }
    }
}

struct RecurrenceMonthlyOptionsCard: View {
    @Bindable var preferences: CalendarPreferencesStore
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Monthly Rule Type:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<PositionalRecurrenceType?>(
                    get: { preferences.defaultMonthlyRecurrenceType },
                    set: { preferences.defaultMonthlyRecurrenceType = $0 ?? .onSpecificDays }
                )) {
                    ForEach(PositionalRecurrenceType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type as PositionalRecurrenceType?)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Monthly rule type")
                .accessibilityHint("Select the type of monthly recurrence rule")
                InfoIcon(tooltip: "Choose between specific days of the month or positional rules like 'second Tuesday'.")
            }
        }
        
        if preferences.defaultMonthlyRecurrenceType == .onSpecificDays {
            VStack(alignment: .leading, spacing: 6) {
                Text("Select Days")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                MonthDayGridView(selectedDays: Binding(get: {
                    preferences.defaultSelectedMonthDaysNumbers
                }, set: { newSet in
                    preferences.defaultSelectedMonthDaysNumbers = newSet
                }))
            }
            .padding(StyleGuide.Dimensions.paddingXMedium)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
            HStack {
                Spacer()
                InfoIcon(tooltip: "Select the days of the month for the event to repeat.")
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Positional Rule")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                OrdinalPickerView(
                    ordinalSelection: Binding<OrdinalSelection?>(
                        get: { OrdinalSelection(intValue: preferences.defaultSelectedOrdinal) },
                        set: { if let newValue = $0 { preferences.defaultSelectedOrdinal = newValue.rawValue } }
                    ),
                    dayOfWeekSelection: Binding<DayOfWeekOption?>(
                        get: { DayOfWeekOption(rawValue: preferences.defaultSelectedDayOfWeekForOrdinal) },
                        set: { if let newV = $0 { preferences.defaultSelectedDayOfWeekForOrdinal = newV.rawValue } }
                    )
                )
            }
            .padding(StyleGuide.Dimensions.paddingXMedium)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
            HStack {
                Spacer()
                InfoIcon(tooltip: "Set a positional rule, like 'second Tuesday' of the month.")
            }
        }
    }
}

struct RecurrenceYearlyOptionsCard: View {
    @Bindable var preferences: CalendarPreferencesStore
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Yearly Rule Type:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<PositionalRecurrenceType?>(
                    get: { preferences.defaultYearlyRecurrenceType },
                    set: { preferences.defaultYearlyRecurrenceType = $0 ?? .onSpecificDays }
                )) {
                    ForEach(PositionalRecurrenceType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type as PositionalRecurrenceType?)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Yearly rule type")
                .accessibilityHint("Select the type of yearly recurrence rule")
                InfoIcon(tooltip: "Choose between specific days of the year or positional rules like 'third Friday in June'.")
            }
        }
        
        VStack(alignment: .leading, spacing: 6) {
            Text("In Months")
                .font(.caption)
                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                    ForEach(SelectableMonth.allCases, id: \.self) { month in
                        HStack {
                            Button(action: {
                                if preferences.defaultSelectedYearMonths.contains(month.rawValue) {
                                    preferences.defaultSelectedYearMonths.remove(month.rawValue)
                                } else {
                                    preferences.defaultSelectedYearMonths.insert(month.rawValue)
                                }
                            }) {
                                Image(systemName: preferences.defaultSelectedYearMonths.contains(month.rawValue) ? "checkmark.square.fill" : "square")
                                    .foregroundStyle(preferences.defaultSelectedYearMonths.contains(month.rawValue) ? .blue : .gray)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Text(month.shortName)
                            Spacer()
                        }
                        .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .padding(StyleGuide.Dimensions.paddingXMedium)
        .background(Color.accentColor.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
        
        if preferences.defaultYearlyRecurrenceType == .onSpecificDays {
            VStack(alignment: .leading, spacing: 6) {
                Text("Select Days")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                MonthDayGridView(selectedDays: Binding(get: {
                    preferences.defaultSelectedYearlyDaysNumbers
                }, set: { newSet in
                    preferences.defaultSelectedYearlyDaysNumbers = newSet
                }))
            }
            .padding(StyleGuide.Dimensions.paddingXMedium)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
            HStack {
                Spacer()
                InfoIcon(tooltip: "Select the days of the year for the event to repeat.")
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Positional Rule")
                    .font(.caption)
                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                OrdinalPickerView(
                    ordinalSelection: Binding<OrdinalSelection?>(
                        get: { OrdinalSelection(intValue: preferences.defaultSelectedOrdinal) },
                        set: { if let newValue = $0 { preferences.defaultSelectedOrdinal = newValue.rawValue } }
                    ),
                    dayOfWeekSelection: Binding<DayOfWeekOption?>(
                        get: { DayOfWeekOption(rawValue: preferences.defaultSelectedDayOfWeekForOrdinal) },
                        set: { if let newV = $0 { preferences.defaultSelectedDayOfWeekForOrdinal = newV.rawValue } }
                    )
                )
            }
            .padding(StyleGuide.Dimensions.paddingXMedium)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall, style: .continuous))
            HStack {
                Spacer()
                InfoIcon(tooltip: "Set a positional rule for yearly recurrence, like 'third Friday' in June.")
            }
        }
    }
}

struct RecurrenceEndOptionsCard: View {
    @Bindable var preferences: CalendarPreferencesStore
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Recurrence End Type:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<RecurrenceEndType?>(
                    get: { preferences.defaultRecurrenceEndType },
                    set: { preferences.defaultRecurrenceEndType = $0 ?? .never }
                )) {
                    ForEach(RecurrenceEndType.allCases, id: \.self) { endType in
                        Text(endType.rawValue).tag(endType as RecurrenceEndType?)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityLabel("Recurrence end type")
                .accessibilityHint("Select how the recurrence should end")
                InfoIcon(tooltip: "Choose how the recurrence should end: never, after a specific count, or on a specific date.")
            }
        }
        
        if preferences.defaultRecurrenceEndType == .afterCount {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                SettingsRow(label: "Recurrence Count:", labelWidth: maxLabelWidth) {
                    HStack {
                        TextField("Enter count", value: Binding<Double>(
                            get: { Double(preferences.defaultRecurrenceCount) },
                            set: { preferences.defaultRecurrenceCount = Int($0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Recurrence count")
                        .accessibilityHint("Enter the number of times the event should repeat")
                        Stepper("", value: Binding<Double>(
                            get: { Double(preferences.defaultRecurrenceCount) },
                            set: { preferences.defaultRecurrenceCount = Int($0) }
                        ), in: 1...999, step: 1)
                        .accessibilityLabel("Adjust recurrence count")
                        InfoIcon(tooltip: "Set how many times the event should repeat before ending.")
                    }
                }
            }
        } else if preferences.defaultRecurrenceEndType == .onDate {
            VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                SettingsRow(label: "Recurrence End Date:", labelWidth: maxLabelWidth) {
                    HStack {
                        DatePicker("", selection: $preferences.defaultRecurrenceEndDate, in: Date()...Date.distantFuture, displayedComponents: .date)
                            .accessibilityLabel("Recurrence end date")
                            .accessibilityHint("Select the date when the recurrence should stop")
                        InfoIcon(tooltip: "Pick the date when the recurrence should stop.")
                    }
                }
            }
        }
    }
}
