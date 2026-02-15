import SwiftUI
import SwiftData
import Data
import Core
import SharedUI

// ─────────────────────────────────────────────────────────────
// MARK: - Session Form View (Used in Sheet)
// ─────────────────────────────────────────────────────────────

struct NewSessionView: View {

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
    
    private func applyRepeatOption(_ option: RepeatOption) {
        var updated = viewModel.formModel
        switch option {
        case .never:
            updated.recurrenceFrequency = .none
        case .everyDay:
            updated.recurrenceFrequency = .daily
            updated.recurrenceInterval = 1
        case .everyWeek:
            updated.recurrenceFrequency = .weekly
            updated.recurrenceInterval = 1
        case .every2Weeks:
            updated.recurrenceFrequency = .weekly
            updated.recurrenceInterval = 2
        case .everyMonth:
            updated.recurrenceFrequency = .monthly
            updated.recurrenceInterval = 1
        case .everyYear:
            updated.recurrenceFrequency = .yearly
            updated.recurrenceInterval = 1
        case .custom:
            break
        }
        viewModel.formModel = updated
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

    // Clients are fetched via ViewModel

    // Binding helpers (read-modify-write so struct updates persist)
    private var recurrenceIntervalProxy: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.formModel.recurrenceInterval) },
            set: { newValue in
                var updated = viewModel.formModel
                updated.recurrenceInterval = Int(newValue)
                viewModel.formModel = updated
            }
        )
    }

    private var recurrenceCountProxy: Binding<Double> {
        Binding<Double>(
            get: { Double(viewModel.formModel.recurrenceCount) },
            set: { newValue in
                var updated = viewModel.formModel
                updated.recurrenceCount = Int(newValue)
                viewModel.formModel = updated
            }
        )
    }

    private func ordinalDropdownBinding() -> Binding<DayOfWeekOption?> {
        Binding<DayOfWeekOption?>(
            get: { viewModel.formModel.selectedDayOfWeekForOrdinal },
            set: { newV in
                guard let newV = newV else { return }
                var updated = viewModel.formModel
                updated.selectedDayOfWeekForOrdinal = newV
                viewModel.formModel = updated
            }
        )
    }

    private var ordinalSelectionProxy: Binding<OrdinalSelection?> {
        Binding<OrdinalSelection?>(
            get: { OrdinalSelection(intValue: viewModel.formModel.selectedOrdinal) },
            set: { newValue in
                guard let newValue = newValue else { return }
                var updated = viewModel.formModel
                updated.selectedOrdinal = newValue.rawValue
                viewModel.formModel = updated
            }
        )
    }

    private var clientPickerOptions: [Client] {
        var options = viewModel.availableClients
        if let selectedClient = viewModel.selectedClient,
           !options.contains(where: { $0.id == selectedClient.id }) {
            options.insert(selectedClient, at: 0)
        }
        return options
    }

    private var servicePickerOptions: [ClientService] {
        var options = viewModel.availableServices
        if let selectedService = viewModel.selectedClientService,
           !options.contains(where: { $0.id == selectedService.id }) {
            options.insert(selectedService, at: 0)
        }
        return options
    }

    private var clientPickerSelection: Binding<UUID?> {
        Binding<UUID?>(
            get: { viewModel.formModel.selectedClientID },
            set: { newID in viewModel.updateSelectedClientID(newID) }
        )
    }

    private var servicePickerSelection: Binding<UUID?> {
        Binding<UUID?>(
            get: { viewModel.formModel.selectedClientServiceID },
            set: { newID in viewModel.updateSelectedClientServiceID(newID) }
        )
    }

    private var missingSelectedClientID: UUID? {
        guard let selectedClientID = viewModel.formModel.selectedClientID else { return nil }
        return clientPickerOptions.contains(where: { $0.id == selectedClientID }) ? nil : selectedClientID
    }

    private var missingSelectedServiceID: UUID? {
        guard let selectedServiceID = viewModel.formModel.selectedClientServiceID else { return nil }
        return servicePickerOptions.contains(where: { $0.id == selectedServiceID }) ? nil : selectedServiceID
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
        .glassEffect(.regular, in: .rect())
        .foregroundColor(Color("Text", bundle: .sharedUI))
        .frame(idealWidth: 500, maxWidth: 600, minHeight: 500, idealHeight: 600) // Reduced dimensions
        .onAppear {
            selectedRepeatOption = repeatOptionForCurrentRecurrence()
            viewModel.onSaveCompleted = { dismiss() }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.glass)

            }
            ToolbarItem(placement: .automatic) {
                Button(viewModel.saveButtonTitle) { viewModel.handleSaveButtonTapped() }
                    .buttonStyle(.glassProminent)

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
                TextField("Session Title", text: viewModel.formBinding(\.title))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: viewModel.formModel.title) { _, newValue in
                        if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            // Handle empty title
                        }
                    }
                    .font(.title.weight(.bold)) // Reduced from .largeTitle to .title
                    .foregroundColor(titleError != nil ? .red : .white)
                
                Spacer()

                Picker("Status", selection: Binding<SessionStatus>(
                    get: { SessionStatus(normalized: viewModel.formModel.status) ?? .scheduled },
                    set: { newValue in
                        var updated = viewModel.formModel
                        updated.status = newValue.rawValue
                        viewModel.formModel = updated
                    }
                )) {
                    ForEach(SessionStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .pickerStyle(.menu)
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
                gradient: Gradient(colors: [Color("Blue", bundle: .sharedUI), Color("DarkBlue", bundle: .sharedUI)]),
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
                        Text("Google Calendar Color: \(colorName)").font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        Spacer()
                        Toggle("Use", isOn: viewModel.formBinding(\.useGoogleColor)).toggleStyle(.switch)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                
                FormField("Title") {
                    TextField("Enter session title", text: viewModel.formBinding(\.title))
                }
                
                // Date and Time Layout - More responsive
                VStack(spacing: 8) {
                    // Date row
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Date")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        DatePicker("Date", selection: viewModel.formBinding(\.startTime), displayedComponents: .date)
                    }
                    
                    // Time row - Only show when not all day
                    if !viewModel.formModel.isAllDay {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Start")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                DatePicker("Start", selection: viewModel.formBinding(\.startTime), displayedComponents: .hourAndMinute)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("End")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                DatePicker("End", selection: viewModel.formBinding(\.endTime), displayedComponents: .hourAndMinute)
                            }
                        }
                    }
                }
                
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        Picker("Status", selection: Binding<SessionStatus>(
                            get: { SessionStatus(normalized: viewModel.formModel.status) ?? .scheduled },
                            set: { newValue in
                                var updated = viewModel.formModel
                                updated.status = newValue.rawValue
                                viewModel.formModel = updated
                            }
                        )) {
                            ForEach(SessionStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All Day")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        Toggle("All Day", isOn: viewModel.formBinding(\.isAllDay))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var locationSection: some View {
        CompactDetailSection(title: "Location", systemImage: "mappin.and.ellipse") {
                FormField("Address") {
                    TextField("Enter address", text: viewModel.formBinding(\.addressSearchText))
                }
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
                VStack(alignment: .leading, spacing: 4) {
                    Text("Client")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("Client", selection: clientPickerSelection) {
                        Text("Select a client").tag(nil as UUID?)
                        if let missingSelectedClientID {
                            Text("Loading selected client...").tag(missingSelectedClientID as UUID?)
                        }
                        ForEach(clientPickerOptions, id: \.id) { client in
                            Text(client.fullName).tag(client.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                if viewModel.formModel.selectedClientID != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Service")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        Picker("Service", selection: servicePickerSelection) {
                            Text("Select a service").tag(nil as UUID?)
                            if let missingSelectedServiceID {
                                Text("Loading selected service...").tag(missingSelectedServiceID as UUID?)
                            }
                            ForEach(servicePickerOptions, id: \.id) { service in
                                Text(service.serviceName).tag(service.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Service")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        Picker("Service", selection: .constant(nil as UUID?)) {
                            Text("Select a client first").tag(nil as UUID?)
                        }
                        .pickerStyle(.menu)
                        .disabled(true)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var recurrenceSection: some View {
        CompactDetailSection(title: "Recurrence", systemImage: "repeat.circle") {
            VStack(alignment: .leading, spacing: 4) { // Very compact spacing
                VStack(alignment: .leading, spacing: 4) {
                    Text("Repeat")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("Repeat", selection: $selectedRepeatOption) {
                        ForEach(RepeatOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option as RepeatOption?)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .onChange(of: selectedRepeatOption) { _, newValue in
                    guard let newValue = newValue else { return }
                    if newValue == .custom {
                        // Show custom recurrence fields inline instead of opening sheet
                        var updated = viewModel.formModel
                        updated.recurrenceFrequency = .daily
                        viewModel.formModel = updated
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
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .padding(.top, 2) // Reduced from 4 to 2
            }
        }
    }
    
    // MARK: - Recurrence Details (Helper View)
    @ViewBuilder
    private func recurrenceDetailsView() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Frequency selector for custom recurrence
            VStack(alignment: .leading, spacing: 4) {
                Text("Frequency")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Picker("Frequency", selection: viewModel.formBinding(\.recurrenceFrequency)) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Text(String(describing: frequency)).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Every")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    HStack {
                        Button("-") {
                            if viewModel.formModel.recurrenceInterval > 1 {
                                var updated = viewModel.formModel
                                updated.recurrenceInterval -= 1
                                viewModel.formModel = updated
                            }
                        }
                        TextField("", value: viewModel.formBinding(\.recurrenceInterval), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Button("+") {
                            if viewModel.formModel.recurrenceInterval < 100 {
                                var updated = viewModel.formModel
                                updated.recurrenceInterval += 1
                                viewModel.formModel = updated
                            }
                        }
                    }
                }
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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Ends")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Picker("Ends", selection: viewModel.formBinding(\.recurrenceEndType)) {
                    ForEach(RecurrenceEndType.allCases, id: \.self) { endType in
                        Text(String(describing: endType)).tag(endType)
                    }
                }
                .pickerStyle(.menu)
            }
            
            if viewModel.formModel.recurrenceEndType == .afterCount {
                VStack(alignment: .leading, spacing: 4) {
                    Text("After")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    HStack {
                        Button("-") {
                            if viewModel.formModel.recurrenceCount > 1 {
                                var updated = viewModel.formModel
                                updated.recurrenceCount -= 1
                                viewModel.formModel = updated
                            }
                        }
                        TextField("", value: viewModel.formBinding(\.recurrenceCount), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Button("+") {
                            if viewModel.formModel.recurrenceCount < 999 {
                                var updated = viewModel.formModel
                                updated.recurrenceCount += 1
                                viewModel.formModel = updated
                            }
                        }
                    }
                }
            } else if viewModel.formModel.recurrenceEndType == .onDate {
                VStack(alignment: .leading, spacing: 4) {
                    Text("End Date")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    DatePicker("End Date", selection: viewModel.formBinding(\.recurrenceEndDate), in: viewModel.formModel.startTime...Date.distantFuture, displayedComponents: .date)
                }
            }
        }
    }
    
    // MARK: - Recurrence Detail Sub-Views
    @ViewBuilder
    private func dayOfWeekSelector() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("On Days")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SelectableWeekday.allCases, id: \.self) { weekday in
                        Button(weekday.shortName) {
                            var updated = viewModel.formModel
                            if updated.selectedWeekdays.contains(weekday) {
                                updated.selectedWeekdays.remove(weekday)
                            } else {
                                updated.selectedWeekdays.insert(weekday)
                            }
                            viewModel.formModel = updated
                        }
                        .buttonStyle(.bordered)
                        .background(viewModel.formModel.selectedWeekdays.contains(weekday) ? Color.accentColor : Color.clear)
                        .foregroundColor(viewModel.formModel.selectedWeekdays.contains(weekday) ? .white : .primary)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func monthlyRecurrenceTypeSelector() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rule Type")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Picker("Rule Type", selection: viewModel.formBinding(\.monthlyRecurrenceType)) {
                    ForEach(PositionalRecurrenceType.allCases, id: \.self) { type in
                        Text(String(describing: type)).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.formModel.monthlyRecurrenceType == .onSpecificDays {
                MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedMonthDaysNumbers))
                
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
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                
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
                                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider().padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("Rule Type")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                Picker("Rule Type", selection: viewModel.formBinding(\.yearlyRecurrenceType)) {
                    ForEach(PositionalRecurrenceType.allCases, id: \.self) { type in
                        Text(String(describing: type)).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }

            if viewModel.formModel.yearlyRecurrenceType == .onSpecificDays {
                MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedYearlyDaysNumbers))
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
            TextField("Add any relevant notes for this session...", text: viewModel.formBinding(\.notes), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(minHeight: 60)
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
    var updated = viewModel.formModel
    if updated.selectedYearMonths.contains(month) {
        updated.selectedYearMonths.remove(month)
    } else {
        updated.selectedYearMonths.insert(month)
    }
    viewModel.formModel = updated
}
// MARK: - Custom Recurrence Sheet
private struct CustomRecurrenceSheet: View {
    @ObservedObject var viewModel: NewSessionViewModel
    var onDone: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    frequencySection
                    intervalSection
                    descriptionText
                    weeklySection
                    monthlySection
                    yearlySection
                    endTypeSection
                }
            }
            .navigationTitle("Custom Recurrence")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .automatic) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
    
    @ViewBuilder
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Frequency")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            Picker("Frequency", selection: viewModel.formBinding(\.recurrenceFrequency)) {
                ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                    Text(frequency.rawValue).tag(frequency)
                }
            }
            .pickerStyle(.menu)
        }
    }
    
    @ViewBuilder
    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Every")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            HStack {
                Button("-") {
                    if viewModel.formModel.recurrenceInterval > 1 {
                        viewModel.formModel.recurrenceInterval -= 1
                    }
                }
                TextField("", value: viewModel.formBinding(\.recurrenceInterval), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 60)
                Button("+") {
                    viewModel.formModel.recurrenceInterval += 1
                }
            }
        }
    }
    
    @ViewBuilder
    private var descriptionText: some View {
        Text(viewModel.formModel.recurrenceFrequency != .none ? pluralizeUnit(viewModel.formModel.recurrenceFrequency, interval: viewModel.formModel.recurrenceInterval) : "")
    }
    
    @ViewBuilder
    private var weeklySection: some View {
        if viewModel.formModel.recurrenceFrequency == .weekly {
            VStack(alignment: .leading, spacing: 4) {
                Text("On Days")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(SelectableWeekday.allCases, id: \.self) { weekday in
                            Button(weekday.shortName) {
                                if viewModel.formModel.selectedWeekdays.contains(weekday) {
                                    viewModel.formModel.selectedWeekdays.remove(weekday)
                                } else {
                                    viewModel.formModel.selectedWeekdays.insert(weekday)
                                }
                            }
                            .buttonStyle(.bordered)
                            .background(viewModel.formModel.selectedWeekdays.contains(weekday) ? Color.blue : Color.clear)
                            .foregroundColor(viewModel.formModel.selectedWeekdays.contains(weekday) ? .white : .primary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
    
    @ViewBuilder
    private var monthlySection: some View {
        if viewModel.formModel.recurrenceFrequency == .monthly {
            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rule Type")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("Rule Type", selection: viewModel.formBinding(\.monthlyRecurrenceType)) {
                        ForEach(PositionalRecurrenceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                if viewModel.formModel.monthlyRecurrenceType == .onSpecificDays {
                    MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedMonthDaysNumbers))
                } else {
                    let ordinalBinding = Binding<OrdinalSelection?>(
                        get: { OrdinalSelection(intValue: viewModel.formModel.selectedOrdinal) },
                        set: { newValue in
                            guard let newValue = newValue else { return }
                            var updated = viewModel.formModel
                            updated.selectedOrdinal = newValue.rawValue
                            viewModel.formModel = updated
                        }
                    )
                    let dayOfWeekBinding = Binding<DayOfWeekOption?>(
                        get: { viewModel.formModel.selectedDayOfWeekForOrdinal },
                        set: { newV in
                            guard let newV = newV else { return }
                            var updated = viewModel.formModel
                            updated.selectedDayOfWeekForOrdinal = newV
                            viewModel.formModel = updated
                        }
                    )
                    OrdinalPickerView(
                        ordinalSelection: ordinalBinding,
                        dayOfWeekSelection: dayOfWeekBinding
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var yearlySection: some View {
        if viewModel.formModel.recurrenceFrequency == .yearly {
            VStack(alignment: .leading, spacing: 6) {
                // Custom month selection for Set<Int>
                VStack(alignment: .leading, spacing: 4) {
                    Text("In Months")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    
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
                                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Divider().padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rule Type")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("Rule Type", selection: viewModel.formBinding(\.yearlyRecurrenceType)) {
                        ForEach(PositionalRecurrenceType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if viewModel.formModel.yearlyRecurrenceType == .onSpecificDays {
                    MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedYearlyDaysNumbers))
                } else {
                    let ordinalBinding = Binding<OrdinalSelection?>(
                        get: { OrdinalSelection(intValue: viewModel.formModel.selectedOrdinal) },
                        set: { newValue in
                            guard let newValue = newValue else { return }
                            var updated = viewModel.formModel
                            updated.selectedOrdinal = newValue.rawValue
                            viewModel.formModel = updated
                        }
                    )
                    let dayOfWeekBinding = Binding<DayOfWeekOption?>(
                        get: { viewModel.formModel.selectedDayOfWeekForOrdinal },
                        set: { newV in
                            guard let newV = newV else { return }
                            var updated = viewModel.formModel
                            updated.selectedDayOfWeekForOrdinal = newV
                            viewModel.formModel = updated
                        }
                    )
                    OrdinalPickerView(
                        ordinalSelection: ordinalBinding,
                        dayOfWeekSelection: dayOfWeekBinding
                    )
                }
            }
        }
    }
    
    @ViewBuilder
    private var endTypeSection: some View {
        Divider().padding(.vertical, 2)
        VStack(alignment: .leading, spacing: 4) {
            Text("Ends")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            Picker("Ends", selection: viewModel.formBinding(\.recurrenceEndType)) {
                ForEach(RecurrenceEndType.allCases, id: \.self) { endType in
                    Text(endType.displayName).tag(endType)
                }
            }
            .pickerStyle(.menu)
        }
        if viewModel.formModel.recurrenceEndType == .afterCount {
            VStack(alignment: .leading, spacing: 4) {
                Text("After")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                HStack {
                    Button("-") {
                        if viewModel.formModel.recurrenceCount > 1 {
                            viewModel.formModel.recurrenceCount -= 1
                        }
                    }
                    TextField("", value: viewModel.formBinding(\.recurrenceCount), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    Button("+") {
                        viewModel.formModel.recurrenceCount += 1
                    }
                }
            }
        } else if viewModel.formModel.recurrenceEndType == .onDate {
            VStack(alignment: .leading, spacing: 4) {
                Text("End Date")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                DatePicker("", selection: viewModel.formBinding(\.recurrenceEndDate), in: viewModel.formModel.startTime..., displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
        }
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
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .font(.system(size: 12)) // Smaller icon
                }
                Text(title)
                    .font(.subheadline) // Smaller font
                    .fontWeight(.semibold) // Reduced weight
                    .textCase(.uppercase)
                    .tracking(0.5) // Reduced tracking
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
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
