import SwiftUI
import Data
import SharedUI

struct NativeSessionFormRecurrenceSection: View {
    @Bindable var viewModel: NewSessionViewModel
    @Binding var selectedRepeatOption: RepeatOption?

    private static let recurrenceEndDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    var body: some View {
        GroupBox("Recurrence") {
            VStack(spacing: FormSectionTokens.fieldStackSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Repeat:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    Picker("", selection: $selectedRepeatOption) {
                        ForEach(RepeatOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option as RepeatOption?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: selectedRepeatOption) { _, newValue in
                        guard let newValue else { return }
                        if newValue == .custom {
                            var updated = viewModel.formModel
                            if updated.recurrenceFrequency == .none {
                                updated.recurrenceFrequency = .daily
                                updated.recurrenceInterval = 1
                            }
                            viewModel.formModel = updated
                        } else {
                            applyRepeatOption(newValue)
                        }
                    }
                }

                if selectedRepeatOption == .custom {
                    customRecurrenceFields
                        .fluidListTransition()
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedRepeatOption)
                }

                if viewModel.formModel.hasRecurrence {
                    Text(getRecurrenceSummaryText())
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundColor(StyleGuide.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, StyleGuide.Dimensions.formLabelWidth + StyleGuide.Dimensions.paddingSmall)
                        .fluidListTransition()
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedRepeatOption)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }

    private var customRecurrenceFields: some View {
        VStack(spacing: FormSectionTokens.fieldStackSpacing) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Frequency:")
                    .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                    .foregroundColor(StyleGuide.Colors.text)

                Picker("Frequency", selection: viewModel.formBinding(\.recurrenceFrequency)) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .onChange(of: viewModel.formModel.recurrenceFrequency) { _, newValue in
                    if case .weekly = newValue, viewModel.formModel.selectedWeekdays.isEmpty {
                        let weekday = Calendar.current.component(.weekday, from: viewModel.formModel.startTime)
                        var updated = viewModel.formModel
                        updated.selectedWeekdays = [SelectableWeekday(rawValue: weekday) ?? .monday]
                        viewModel.formModel = updated
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Every:")
                    .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                    .foregroundColor(StyleGuide.Colors.text)

                HStack(spacing: FormSectionTokens.fieldStackSpacing) {
                    Stepper("", value: viewModel.formBinding(\.recurrenceInterval), in: 1...100)
                        .labelsHidden()

                    Text("\(viewModel.formModel.recurrenceInterval) \(pluralizeUnit(viewModel.formModel.recurrenceFrequency, interval: viewModel.formModel.recurrenceInterval))")
                        .foregroundColor(StyleGuide.Colors.text)

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.formModel.recurrenceFrequency == .weekly {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("On Days:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    HStack(spacing: FormSectionTokens.fieldStackSpacing) {
                        ForEach(SelectableWeekday.allCases, id: \.self) { weekday in
                            Toggle(weekday.shortName, isOn: Binding(
                                get: { viewModel.formModel.selectedWeekdays.contains(weekday) },
                                set: { isSelected in
                                    var updated = viewModel.formModel
                                    if isSelected {
                                        updated.selectedWeekdays.insert(weekday)
                                    } else {
                                        updated.selectedWeekdays.remove(weekday)
                                    }
                                    viewModel.formModel = updated
                                }
                            ))
                            .toggleStyle(.button)
                            .scaleEffect(0.8)
                        }

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceFrequency)
            }

            if viewModel.formModel.recurrenceFrequency == .monthly {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Pattern:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)
                    Picker("Type", selection: viewModel.formBinding(\.monthlyRecurrenceType)) {
                        Text("On specific day(s)").tag(PositionalRecurrenceType.onSpecificDays)
                        Text("On the ordinal weekday").tag(PositionalRecurrenceType.onTheOrdinalDayOfWeek)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceFrequency)

                if viewModel.formModel.monthlyRecurrenceType == .onSpecificDays {
                    HStack(alignment: .top, spacing: 6) {
                        Text("Days:")
                            .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)
                        MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedMonthDaysNumbers))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.monthlyRecurrenceType)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ordinal:")
                            .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)
                        Picker("Ordinal", selection: viewModel.formBinding(\.selectedOrdinal)) {
                            ForEach([1, 2, 3, 4, -1], id: \.self) { value in
                                Text(value == -1 ? "Last" : [1: "First", 2: "Second", 3: "Third", 4: "Fourth"][value]!).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("Weekday", selection: viewModel.formBinding(\.selectedDayOfWeekForOrdinal)) {
                            ForEach(
                                DayOfWeekOption.allCases.filter { $0.rawValue >= DayOfWeekOption.sunday.rawValue },
                                id: \.self
                            ) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.monthlyRecurrenceType)
                }
            }

            if viewModel.formModel.recurrenceFrequency == .yearly {
                HStack(alignment: .top, spacing: 6) {
                    Text("Months:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(SelectableMonth.allCases, id: \.self) { month in
                            Button(action: { toggleYearMonth(month) }) {
                                Text(month.shortName)
                                    .font(StyleGuide.Typography.itemSubtitle)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity, minHeight: 30)
                                    .background(viewModel.formModel.selectedYearMonths.contains(month) ? Color.accentColor : Color.white.opacity(0.1))
                                    .foregroundColor(viewModel.formModel.selectedYearMonths.contains(month) ? .white : .white.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceFrequency)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Pattern:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)
                    Picker("Type", selection: viewModel.formBinding(\.yearlyRecurrenceType)) {
                        Text("On specific day(s)").tag(PositionalRecurrenceType.onSpecificDays)
                        Text("On the ordinal weekday").tag(PositionalRecurrenceType.onTheOrdinalDayOfWeek)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceFrequency)

                if viewModel.formModel.yearlyRecurrenceType == .onSpecificDays {
                    HStack(alignment: .top, spacing: 6) {
                        Text("Days:")
                            .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)
                        MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedYearlyDaysNumbers))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.yearlyRecurrenceType)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ordinal:")
                            .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                            .foregroundColor(StyleGuide.Colors.text)
                        Picker("Ordinal", selection: viewModel.formBinding(\.selectedOrdinal)) {
                            ForEach([1, 2, 3, 4, -1], id: \.self) { value in
                                Text(value == -1 ? "Last" : [1: "First", 2: "Second", 3: "Third", 4: "Fourth"][value]!).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("Weekday", selection: viewModel.formBinding(\.selectedDayOfWeekForOrdinal)) {
                            ForEach(
                                DayOfWeekOption.allCases.filter { $0.rawValue >= DayOfWeekOption.sunday.rawValue },
                                id: \.self
                            ) { option in
                                Text(option.displayName).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.yearlyRecurrenceType)
                }
            }

            Divider()
                .background(Color.white.opacity(0.2))
                .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Ends:")
                    .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                    .foregroundColor(StyleGuide.Colors.text)

                Picker("End Type", selection: viewModel.formBinding(\.recurrenceEndType)) {
                    Text("Never").tag(RecurrenceEndType.never)
                    Text("After X occurrences").tag(RecurrenceEndType.afterCount)
                    Text("On date").tag(RecurrenceEndType.onDate)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.formModel.recurrenceEndType == .afterCount {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("After:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    HStack(spacing: FormSectionTokens.fieldStackSpacing) {
                        Stepper("", value: viewModel.formBinding(\.recurrenceCount), in: 1...999)
                            .labelsHidden()

                        Text("\(viewModel.formModel.recurrenceCount) occurrences")
                            .foregroundColor(StyleGuide.Colors.text)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceEndType)
            }

            if viewModel.formModel.recurrenceEndType == .onDate {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("End Date:")
                        .frame(width: StyleGuide.Dimensions.formLabelWidth, alignment: .trailing)
                        .foregroundColor(StyleGuide.Colors.text)

                    DatePicker("", selection: viewModel.formBinding(\.recurrenceEndDate), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceEndType)
            }
        }
    }

    private func applyRepeatOption(_ option: RepeatOption) {
        var updated = viewModel.formModel
        switch option {
        case .never:
            updated.clearRecurrence()
        case .everyDay:
            updated.recurrenceFrequency = .daily
            updated.recurrenceInterval = 1
        case .everyWeek:
            updated.recurrenceFrequency = .weekly
            updated.recurrenceInterval = 1
            if updated.selectedWeekdays.isEmpty {
                let weekday = Calendar.current.component(.weekday, from: updated.startTime)
                updated.selectedWeekdays = [SelectableWeekday(rawValue: weekday) ?? .monday]
            }
        case .every2Weeks:
            updated.recurrenceFrequency = .weekly
            updated.recurrenceInterval = 2
            if updated.selectedWeekdays.isEmpty {
                let weekday = Calendar.current.component(.weekday, from: updated.startTime)
                updated.selectedWeekdays = [SelectableWeekday(rawValue: weekday) ?? .monday]
            }
        case .everyMonth:
            updated.recurrenceFrequency = .monthly
            updated.recurrenceInterval = 1
            updated.monthlyRecurrenceType = .onSpecificDays
        case .everyYear:
            updated.recurrenceFrequency = .yearly
            updated.recurrenceInterval = 1
            updated.yearlyRecurrenceType = .onSpecificDays
        case .custom:
            break
        }
        viewModel.formModel = updated
    }

    private func getRecurrenceSummaryText() -> String {
        guard viewModel.formModel.hasRecurrence else { return "Does not repeat" }

        let frequency = viewModel.formModel.recurrenceFrequency
        let interval = viewModel.formModel.recurrenceInterval

        var summary = "Every \(interval) \(pluralizeUnit(frequency, interval: interval))"

        if frequency == .weekly && !viewModel.formModel.selectedWeekdays.isEmpty {
            let weekdays = viewModel.formModel.selectedWeekdays.sorted { $0.rawValue < $1.rawValue }.map { $0.shortName }.joined(separator: ", ")
            summary += " on \(weekdays)"
        }

        switch viewModel.formModel.recurrenceEndType {
        case .afterCount:
            summary += " for \(viewModel.formModel.recurrenceCount) occurrences"
        case .onDate:
            summary += " until \(Self.recurrenceEndDateFormatter.string(from: viewModel.formModel.recurrenceEndDate))"
        case .never:
            break
        }

        return summary
    }

    private func toggleYearMonth(_ month: SelectableMonth) {
        var updated = viewModel.formModel
        if updated.selectedYearMonths.contains(month) {
            updated.selectedYearMonths.remove(month)
        } else {
            updated.selectedYearMonths.insert(month)
        }
        viewModel.formModel = updated
    }

    private func pluralizeUnit(_ frequency: RecurrenceFrequency, interval: Int) -> String {
        let unit: String
        switch frequency {
        case .daily: unit = interval == 1 ? "day" : "days"
        case .weekly: unit = interval == 1 ? "week" : "weeks"
        case .monthly: unit = interval == 1 ? "month" : "months"
        case .yearly: unit = interval == 1 ? "year" : "years"
        case .none: unit = "day"
        }
        return unit
    }
}
