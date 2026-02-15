import SwiftUI
import Data
import Core
import SharedUI

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
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
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
                        .frame(width: 24, height: 24)
                        .background(selectedDays.contains(day) ? Color.blue : Color.clear)
                        .foregroundColor(selectedDays.contains(day) ? .white : .primary)
                        .cornerRadius(4)
                        .contentShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Recurrence Settings Views

struct RecurrenceDefaultsView: View {
    @ObservedObject var viewModel: CalendarSettingsViewModel
    let maxLabelWidth: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(
                icon: "repeat",
                title: "Default Recurrence Rule",
                description: "Set up how new recurring events repeat by default. You can customize frequency, days, and end conditions."
            )
            VStack(spacing: 12) {
                RecurrenceBasicSettingsCard(viewModel: viewModel, maxLabelWidth: maxLabelWidth)
                
                if viewModel.preferences.defaultRecurrenceFrequency == .weekly {
                    RecurrenceWeeklyOptionsCard(viewModel: viewModel)
                }
                
                if viewModel.preferences.defaultRecurrenceFrequency == .monthly {
                    RecurrenceMonthlyOptionsCard(viewModel: viewModel, maxLabelWidth: maxLabelWidth)
                }
                
                if viewModel.preferences.defaultRecurrenceFrequency == .yearly {
                    RecurrenceYearlyOptionsCard(viewModel: viewModel, maxLabelWidth: maxLabelWidth)
                }
                
                RecurrenceEndOptionsCard(viewModel: viewModel, maxLabelWidth: maxLabelWidth)
                
                if let error = viewModel.recurrenceErrorText {
                    Text(error).formErrorStyle()
                }
                if let helper = viewModel.recurrenceHelperText {
                    Text(helper).formDescriptionStyle()
                }
            }
        }
        .sectionStyle()
    }
}

struct RecurrenceBasicSettingsCard: View {
    @ObservedObject var viewModel: CalendarSettingsViewModel
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Recurrence Frequency:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<RecurrenceFrequency?>(
                    get: { viewModel.preferences.defaultRecurrenceFrequency },
                    set: { viewModel.preferences.defaultRecurrenceFrequency = $0 ?? .none }
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
                    get: { Double(viewModel.preferences.defaultRecurrenceInterval) },
                    set: { viewModel.preferences.defaultRecurrenceInterval = Int($0) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                Stepper("", value: Binding<Double>(
                    get: { Double(viewModel.preferences.defaultRecurrenceInterval) },
                    set: { viewModel.preferences.defaultRecurrenceInterval = Int($0) }
                ), in: 1...100, step: 1)
                    .accessibilityLabel("Adjust recurrence interval")
                InfoIcon(tooltip: "Every X frequency units (e.g., every 2 weeks)")
            }
        }
    }
}

struct RecurrenceWeeklyOptionsCard: View {
    @ObservedObject var viewModel: CalendarSettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("On Days")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(SelectableWeekday.allCases, id: \.self) { weekday in
                        HStack {
                            Button(action: {
                                if viewModel.preferences.defaultSelectedWeekdays.contains(weekday.rawValue) {
                                    viewModel.preferences.defaultSelectedWeekdays.remove(weekday.rawValue)
                                } else {
                                    viewModel.preferences.defaultSelectedWeekdays.insert(weekday.rawValue)
                                }
                            }) {
                                Image(systemName: viewModel.preferences.defaultSelectedWeekdays.contains(weekday.rawValue) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(viewModel.preferences.defaultSelectedWeekdays.contains(weekday.rawValue) ? .blue : .gray)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Text(weekday.shortName)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(8)
        
        HStack {
            Spacer()
            InfoIcon(tooltip: "Choose which days of the week the event should repeat on.")
        }
    }
}

struct RecurrenceMonthlyOptionsCard: View {
    @ObservedObject var viewModel: CalendarSettingsViewModel
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Monthly Rule Type:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<PositionalRecurrenceType?>(
                    get: { viewModel.preferences.defaultMonthlyRecurrenceType },
                    set: { viewModel.preferences.defaultMonthlyRecurrenceType = $0 ?? .onSpecificDays }
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
        
        if viewModel.preferences.defaultMonthlyRecurrenceType == .onSpecificDays {
            VStack(alignment: .leading, spacing: 6) {
                Text("Select Days")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                MonthDayGridView(selectedDays: Binding(get: {
                    viewModel.preferences.defaultSelectedMonthDaysNumbers
                }, set: { newSet in
                    viewModel.preferences.defaultSelectedMonthDaysNumbers = newSet
                }))
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(8)
            HStack {
                Spacer()
                InfoIcon(tooltip: "Select the days of the month for the event to repeat.")
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Positional Rule")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(8)
            HStack {
                Spacer()
                InfoIcon(tooltip: "Set a positional rule, like 'second Tuesday' of the month.")
            }
        }
    }
}

struct RecurrenceYearlyOptionsCard: View {
    @ObservedObject var viewModel: CalendarSettingsViewModel
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Yearly Rule Type:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<PositionalRecurrenceType?>(
                    get: { viewModel.preferences.defaultYearlyRecurrenceType },
                    set: { viewModel.preferences.defaultYearlyRecurrenceType = $0 ?? .onSpecificDays }
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
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(SelectableMonth.allCases, id: \.self) { month in
                        HStack {
                            Button(action: {
                                if viewModel.preferences.defaultSelectedYearMonths.contains(month.rawValue) {
                                    viewModel.preferences.defaultSelectedYearMonths.remove(month.rawValue)
                                } else {
                                    viewModel.preferences.defaultSelectedYearMonths.insert(month.rawValue)
                                }
                            }) {
                                Image(systemName: viewModel.preferences.defaultSelectedYearMonths.contains(month.rawValue) ? "checkmark.square.fill" : "square")
                                    .foregroundColor(viewModel.preferences.defaultSelectedYearMonths.contains(month.rawValue) ? .blue : .gray)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            Text(month.shortName)
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(maxHeight: 100)
        }
        .padding(10)
        .background(Color.accentColor.opacity(0.05))
        .cornerRadius(8)
        
        if viewModel.preferences.defaultYearlyRecurrenceType == .onSpecificDays {
            VStack(alignment: .leading, spacing: 6) {
                Text("Select Days")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                MonthDayGridView(selectedDays: Binding(get: {
                    viewModel.preferences.defaultSelectedYearlyDaysNumbers
                }, set: { newSet in
                    viewModel.preferences.defaultSelectedYearlyDaysNumbers = newSet
                }))
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(8)
            HStack {
                Spacer()
                InfoIcon(tooltip: "Select the days of the year for the event to repeat.")
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Positional Rule")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(8)
            HStack {
                Spacer()
                InfoIcon(tooltip: "Set a positional rule for yearly recurrence, like 'third Friday' in June.")
            }
        }
    }
}

struct RecurrenceEndOptionsCard: View {
    @ObservedObject var viewModel: CalendarSettingsViewModel
    let maxLabelWidth: CGFloat
    
    var body: some View {
        SettingsRow(label: "Recurrence End Type:", labelWidth: maxLabelWidth) {
            HStack {
                Picker("", selection: Binding<RecurrenceEndType?>(
                    get: { viewModel.preferences.defaultRecurrenceEndType },
                    set: { viewModel.preferences.defaultRecurrenceEndType = $0 ?? .never }
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
        
        if viewModel.preferences.defaultRecurrenceEndType == .afterCount {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(label: "Recurrence Count:", labelWidth: maxLabelWidth) {
                    HStack {
                        TextField("Enter count", value: Binding<Double>(
                            get: { Double(viewModel.preferences.defaultRecurrenceCount) },
                            set: { viewModel.preferences.defaultRecurrenceCount = Int($0) }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Recurrence count")
                        .accessibilityHint("Enter the number of times the event should repeat")
                        Stepper("", value: Binding<Double>(
                            get: { Double(viewModel.preferences.defaultRecurrenceCount) },
                            set: { viewModel.preferences.defaultRecurrenceCount = Int($0) }
                        ), in: 1...999, step: 1)
                        .accessibilityLabel("Adjust recurrence count")
                        InfoIcon(tooltip: "Set how many times the event should repeat before ending.")
                    }
                }
            }
        } else if viewModel.preferences.defaultRecurrenceEndType == .onDate {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRow(label: "Recurrence End Date:", labelWidth: maxLabelWidth) {
                    HStack {
                        DatePicker("", selection: $viewModel.preferences.defaultRecurrenceEndDate, in: Date()...Date.distantFuture, displayedComponents: .date)
                            .accessibilityLabel("Recurrence end date")
                            .accessibilityHint("Select the date when the recurrence should stop")
                        InfoIcon(tooltip: "Pick the date when the recurrence should stop.")
                    }
                }
            }
        }
    }
}
