//
//  NativeSessionFormView.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Native Form Implementation
//
import SwiftUI
import SwiftData
import Data
import Core
import EventKit
import MapKit
import SharedUI

// MARK: - RepeatOption Enum
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

/// Native session form following Mario Guzman's layout guidelines
/// Uses native SwiftUI controls with calendar-style glass morphism effects
struct NativeSessionFormView: View {
    @ObservedObject var viewModel: NewSessionViewModel
    
    // Helper view to fetch and display address
    private struct AddressDisplayView: View {
        let addressId: UUID
        let addressRepository: AddressRepository
        @State private var address: Address?
        @State private var isLoading = true
        
        var body: some View {
            Group {
                if isLoading {
                    Text("Loading address...")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .font(.caption)
                } else if let address = address {
                    Text(address.fullFormattedAddress)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .font(.caption)
                } else {
                    Text("Address not found")
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .font(.caption)
                }
            }
            .task {
                isLoading = true
                address = try? await addressRepository.fetch(by: addressId)
                isLoading = false
            }
        }
    }
    
    // Form state
    @State private var selectedRepeatOption: RepeatOption? = .never
    @State private var showAddressEditingSheet = false
    @State private var validationErrors: [String: String] = [:]
    
    // Clients are fetched via ViewModel
    
    // Computed bindings for dropdown compatibility (read-modify-write so struct updates persist)
    private var statusBinding: Binding<SessionStatus> {
        Binding(
            get: {
                SessionStatus(normalized: viewModel.formModel.status) ?? .scheduled
            },
            set: { newValue in
                var updated = viewModel.formModel
                updated.status = newValue.rawValue
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
        Binding(
            get: { viewModel.formModel.selectedClientID },
            set: { newID in viewModel.updateSelectedClientID(newID) }
        )
    }

    private var servicePickerSelection: Binding<UUID?> {
        Binding(
            get: { viewModel.formModel.selectedClientServiceID },
            set: { newID in viewModel.updateSelectedClientServiceID(newID) }
        )
    }

    private func supportLogBinding<T>(_ keyPath: WritableKeyPath<SessionSupportLogDraft, T>) -> Binding<T> {
        Binding(
            get: { viewModel.formModel.supportLogDraft[keyPath: keyPath] },
            set: { newValue in
                var updated = viewModel.formModel
                updated.supportLogDraft[keyPath: keyPath] = newValue
                viewModel.formModel = updated
            }
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
            VStack(alignment: .leading, spacing: 0) {
                // Header
                sessionHeaderView
                    .padding(.bottom, 20)
                
                // Form Content
                VStack(spacing: 12) {
                    basicInformationSection
                    clientServiceSection
                    recurrenceSection
                    locationSection
                    notesSection
                    supportLogSection
                    statusSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color("Background", bundle: .sharedUI),
                    Color("Background", bundle: .sharedUI).opacity(0.95),
                    Color("Background", bundle: .sharedUI).opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: 450, minHeight: 500)
        .onAppear {
            // Set the Repeat dropdown to match the loaded recurrence values
            selectedRepeatOption = repeatOptionForCurrentRecurrence()
        }
    }
    
    // MARK: - Header
    
    private var sessionHeaderView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isEditing ? "Edit Session" : "New Session")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Text(viewModel.isEditing ? "Modify the session details" : "Create a new session for your calendar")
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Basic Information Section
    
    private var basicInformationSection: some View {
        GroupBox("Basic Information") {
            VStack(spacing: 8) {
                // Title
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Title:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Session title", text: viewModel.formBinding(\.title))
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .onChange(of: viewModel.formModel.title) { _, newValue in
                                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    validationErrors["title"] = "Title is required."
                                } else {
                                    validationErrors["title"] = nil
                                }
                            }
                            .onSubmit {
                                var updated = viewModel.formModel
                                updated.title = updated.title.trimmingCharacters(in: .whitespacesAndNewlines)
                                viewModel.formModel = updated
                            }
                        
                        if let error = validationErrors["title"] {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .fluidListTransition()
                                .animation(.easeInOut(duration: 0.3), value: validationErrors["title"])
                        }
                    }
                }
                
                // Date and Time
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Date:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    HStack(spacing: 12) {
                        DatePicker("", selection: viewModel.formBinding(\.startTime), displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .onChange(of: viewModel.formModel.startTime) { _, newValue in
                                var updated = viewModel.formModel
                                if updated.isAllDay {
                                    if updated.endTime < newValue {
                                        updated.endTime = newValue
                                    }
                                } else if updated.endTime <= newValue {
                                    updated.endTime = newValue.addingTimeInterval(3600)
                                }
                                viewModel.formModel = updated
                            }
                        
                        Toggle("All Day", isOn: viewModel.formBinding(\.isAllDay))
                            .toggleStyle(.switch)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .onChange(of: viewModel.formModel.isAllDay) { _, isAllDay in
                                if isAllDay {
                                    let cal = Calendar.current
                                    var updated = viewModel.formModel
                                    let dayStart = cal.startOfDay(for: updated.startTime)
                                    updated.startTime = dayStart
                                    if updated.endTime < updated.startTime {
                                        updated.endTime = updated.startTime
                                    }
                                    viewModel.formModel = updated
                                } else {
                                    var updated = viewModel.formModel
                                    if updated.endTime <= updated.startTime {
                                        updated.endTime = updated.startTime.addingTimeInterval(3600)
                                    }
                                    viewModel.formModel = updated
                                }
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Time Range (only show if not all day)
                if !viewModel.formModel.isAllDay {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Time:")
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        HStack(spacing: 12) {
                            DatePicker("Start", selection: viewModel.formBinding(\.startTime), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                                .accentColor(.blue)
                                .onChange(of: viewModel.formModel.startTime) { _, newValue in
                                    var updated = viewModel.formModel
                                    if !updated.isAllDay && updated.endTime <= newValue {
                                        updated.endTime = newValue.addingTimeInterval(3600)
                                    }
                                    viewModel.formModel = updated
                                }
                            
                            Text("to")
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            
                            DatePicker("End", selection: viewModel.formBinding(\.endTime), displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                                .accentColor(.blue)
                                .onChange(of: viewModel.formModel.endTime) { _, newValue in
                                    var updated = viewModel.formModel
                                    if !updated.isAllDay && newValue <= updated.startTime {
                                        updated.endTime = updated.startTime.addingTimeInterval(3600)
                                    }
                                    viewModel.formModel = updated
                                }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.easeInOut(duration: 0.3), value: viewModel.formModel.isAllDay)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
    
    // MARK: - Client & Service Section
    
    private var clientServiceSection: some View {
        GroupBox("Client & Service") {
            VStack(spacing: 8) {
                // Client Selection
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Client:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Picker("", selection: clientPickerSelection) {
                        Text("Select a client").tag(nil as UUID?)
                        if let missingSelectedClientID {
                            Text("Loading selected client...").tag(missingSelectedClientID as UUID?)
                        }
                        ForEach(clientPickerOptions, id: \.id) { client in
                            Text(client.fullName).tag(client.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // Service Selection
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Service:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    if viewModel.formModel.selectedClientID != nil {
                        Picker("", selection: servicePickerSelection) {
                            Text("Select a service").tag(nil as UUID?)
                            if let missingSelectedServiceID {
                                Text("Loading selected service...").tag(missingSelectedServiceID as UUID?)
                            }
                            ForEach(servicePickerOptions, id: \.id) { service in
                                Text(service.serviceName).tag(service.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                        HStack {
                            Text("Select a client first")
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(6)
                        .disabled(true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
    
    // MARK: - Recurrence Section
    
    private var recurrenceSection: some View {
        GroupBox("Recurrence") {
            VStack(spacing: 8) {
                // Repeat Option
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Repeat:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
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
                
                // Custom Recurrence Fields (inline)
                if selectedRepeatOption == .custom {
                    customRecurrenceFields
                        .fluidListTransition()
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedRepeatOption)
                }
                
                // Recurrence Summary
                if viewModel.formModel.hasRecurrence {
                    Text(getRecurrenceSummaryText())
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 86) // Align with controls
                        .fluidListTransition()
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: selectedRepeatOption)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
    
    private var customRecurrenceFields: some View {
        VStack(spacing: 8) {
            // Frequency
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Frequency:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
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
            
            // Interval
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Every:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                HStack(spacing: 8) {
                    Stepper("", value: viewModel.formBinding(\.recurrenceInterval), in: 1...100)
                        .labelsHidden()
                    
                    Text("\(viewModel.formModel.recurrenceInterval) \(pluralizeUnit(viewModel.formModel.recurrenceFrequency, interval: viewModel.formModel.recurrenceInterval))")
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Weekdays (for weekly)
            if viewModel.formModel.recurrenceFrequency == .weekly {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("On Days:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    HStack(spacing: 8) {
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
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
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
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedMonthDaysNumbers))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.monthlyRecurrenceType)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ordinal:")
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
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
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(SelectableMonth.allCases, id: \.self) { month in
                            Button(action: { toggleYearMonth(month) }) {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceFrequency)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Pattern:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
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
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        MonthDayGridView(selectedDays: viewModel.formBinding(\.selectedYearlyDaysNumbers))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.yearlyRecurrenceType)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ordinal:")
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
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
                .padding(.vertical, 2)
            
            // End Conditions
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Ends:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Picker("End Type", selection: viewModel.formBinding(\.recurrenceEndType)) {
                    Text("Never").tag(RecurrenceEndType.never)
                    Text("After X occurrences").tag(RecurrenceEndType.afterCount)
                    Text("On date").tag(RecurrenceEndType.onDate)
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // End Count
            if viewModel.formModel.recurrenceEndType == .afterCount {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("After:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    HStack(spacing: 8) {
                        Stepper("", value: viewModel.formBinding(\.recurrenceCount), in: 1...999)
                            .labelsHidden()
                        
                        Text("\(viewModel.formModel.recurrenceCount) occurrences")
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceEndType)
            }
            
            // End Date
            if viewModel.formModel.recurrenceEndType == .onDate {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("End Date:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
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
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        GroupBox("Location") {
            VStack(spacing: 8) {
                // Prioritize displaying the address currently being edited in the view model
                if hasAddressData {
                    compactAddressView
                        .fluidListTransition()
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hasAddressData)
                    
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.vertical, 8)
                        .fluidListTransition()
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: hasAddressData)
                } else if let addressId = viewModel.sessionToEdit?.addressId {
                    // Fetch and display address using AddressRepository
                    AddressDisplayView(addressId: addressId, addressRepository: viewModel.unitOfWork.addresses)
                        .fluidListTransition()
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.sessionToEdit?.addressId != nil)
                }
                
                // Add/Edit Address button
                HStack {
                    Spacer()
                    Button(hasAddressData ? "Edit Address" : "Add Address") {
                        showAddressEditingSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
        .sheet(isPresented: $showAddressEditingSheet) {
            AddressEditingSheet(
                viewModel: viewModel,
                isPresented: $showAddressEditingSheet
            )
            .fluidSheetTransition()
            .animation(.spring(response: 0.6, dampingFraction: 0.7), value: showAddressEditingSheet)
        }
    }
    
    private var compactAddressView: some View {
        HStack {
            Text(formatAddressForDisplay())
                .font(.system(size: 14))
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func formatAddressForDisplay() -> String {
        var parts: [String] = []
        
        if !viewModel.formModel.poBox.isEmpty {
            parts.append("PO Box \(viewModel.formModel.poBox)")
        } else {
            // Handle street address components
            var streetComponents: [String] = []
            
            if !viewModel.formModel.unitNumber.isEmpty {
                streetComponents.append("Unit \(viewModel.formModel.unitNumber)")
            }
            
            // Combine street number and name without comma
            var streetAddress = ""
            if !viewModel.formModel.streetNumber.isEmpty {
                streetAddress += viewModel.formModel.streetNumber
            }
            if !viewModel.formModel.streetName.isEmpty {
                if !streetAddress.isEmpty {
                    streetAddress += " "
                }
                streetAddress += viewModel.formModel.streetName
            }
            
            if !streetAddress.isEmpty {
                streetComponents.append(streetAddress)
            }
            
            // Ensure street components are joined by a space, then add to main parts list
            if !streetComponents.isEmpty {
                parts.append(streetComponents.joined(separator: " "))
            }
        }
        
        // Add locality components
        let locality = viewModel.formModel.suburb.isEmpty ? viewModel.formModel.city : viewModel.formModel.suburb
        if !locality.isEmpty { parts.append(locality) }
        if !viewModel.formModel.state.isEmpty { parts.append(viewModel.formModel.state) }
        if !viewModel.formModel.postcode.isEmpty { parts.append(viewModel.formModel.postcode) }
        if !viewModel.formModel.country.isEmpty { parts.append(viewModel.formModel.country) }
        
        return parts.joined(separator: ", ")
    }
    
    private var hasAddressData: Bool {
        !viewModel.formModel.unitNumber.isEmpty || !viewModel.formModel.streetNumber.isEmpty || 
        !viewModel.formModel.streetName.isEmpty || !viewModel.formModel.suburb.isEmpty || !viewModel.formModel.city.isEmpty ||
        !viewModel.formModel.state.isEmpty || !viewModel.formModel.postcode.isEmpty || 
        !viewModel.formModel.country.isEmpty || !viewModel.formModel.poBox.isEmpty
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        GroupBox("Notes") {
            VStack(spacing: 8) {
                TextEditor(text: viewModel.formBinding(\.notes))
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                        .frame(minHeight: 80)
                        .scrollContentBackground(.hidden)
                        .background(Color("Background", bundle: .sharedUI).opacity(0.3))
                        .cornerRadius(8)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }

    // MARK: - Support Log Section

    private var supportLogSection: some View {
        GroupBox("Support Log") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Capture support log for this session", isOn: supportLogBinding(\.isEnabled))
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if viewModel.formModel.supportLogDraft.isEnabled {
                    let requiredFieldCount = 7
                    let completedRequiredFieldCount = [
                        viewModel.formModel.supportLogDraft.participantName,
                        viewModel.formModel.supportLogDraft.participantNdisNumber,
                        viewModel.formModel.supportLogDraft.supportItemNumber,
                        viewModel.formModel.supportLogDraft.serviceDescription,
                        viewModel.formModel.supportLogDraft.location,
                        viewModel.formModel.supportLogDraft.deliveredBy,
                        viewModel.formModel.supportLogDraft.attestedBy
                    ]
                    .map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .filter { $0 }
                    .count

                    HStack(spacing: 8) {
                        Image(systemName: "checklist")
                            .foregroundStyle(Color.accentColor)
                        Text("Required fields completed: \(completedRequiredFieldCount)/\(requiredFieldCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.accentColor.opacity(0.10))
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Participant & Support")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Participant:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField("Participant name", text: supportLogBinding(\.participantName))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("NDIS #:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField("Participant NDIS number", text: supportLogBinding(\.participantNdisNumber))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Item #:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField("Support item number", text: supportLogBinding(\.supportItemNumber))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Description:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField("Service description", text: supportLogBinding(\.serviceDescription))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Delivery Evidence")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Delivered:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            DatePicker(
                                "",
                                selection: supportLogBinding(\.deliveredFrom),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            DatePicker(
                                "",
                                selection: supportLogBinding(\.deliveredTo),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Delivered by:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField("Staff name", text: supportLogBinding(\.deliveredBy))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Attested by:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField("Attested by", text: supportLogBinding(\.attestedBy))
                                .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Attested at:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            DatePicker(
                                "",
                                selection: supportLogBinding(\.attestedAt),
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Location:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField("Location", text: supportLogBinding(\.location))
                                .textFieldStyle(.roundedBorder)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Optional Compliance Details")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Method:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            Picker("", selection: Binding(
                                get: { viewModel.formModel.supportLogDraft.signatureMethod ?? SignatureMethod.attestation.rawValue },
                                set: { newValue in
                                    var updated = viewModel.formModel
                                    updated.supportLogDraft.signatureMethod = newValue
                                    viewModel.formModel = updated
                                }
                            )) {
                                ForEach(SignatureMethod.allCases, id: \.rawValue) { method in
                                    Text(method.rawValue.capitalized).tag(method.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Signed by:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField(
                                "Participant/nominee signature",
                                text: Binding(
                                    get: { viewModel.formModel.supportLogDraft.signedBy ?? "" },
                                    set: { newValue in
                                        var updated = viewModel.formModel
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        updated.supportLogDraft.signedBy = trimmed.isEmpty ? nil : trimmed
                                        viewModel.formModel = updated
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Cancel code:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField(
                                "NSDH / NSDF / NSDT / NSDO",
                                text: Binding(
                                    get: { viewModel.formModel.supportLogDraft.cancellationReasonCode ?? "" },
                                    set: { newValue in
                                        var updated = viewModel.formModel
                                        let trimmed = String(newValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased().prefix(4))
                                        updated.supportLogDraft.cancellationReasonCode = trimmed.isEmpty ? nil : trimmed
                                        viewModel.formModel = updated
                                    }
                                )
                            )
                            .textFieldStyle(.roundedBorder)
                        }

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Notes:")
                                .frame(width: 90, alignment: .trailing)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                            TextField(
                                "Optional notes",
                                text: Binding(
                                    get: { viewModel.formModel.supportLogDraft.notes ?? "" },
                                    set: { newValue in
                                        var updated = viewModel.formModel
                                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                        updated.supportLogDraft.notes = trimmed.isEmpty ? nil : trimmed
                                        viewModel.formModel = updated
                                    }
                                ),
                                axis: .vertical
                            )
                            .lineLimit(2...5)
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        GroupBox("Status") {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Status:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Picker("", selection: statusBinding) {
                        Text("Scheduled").tag(SessionStatus.scheduled)
                        Text("Completed").tag(SessionStatus.completed)
                        Text("Cancelled").tag(SessionStatus.cancelled)
                        Text("No Show").tag(SessionStatus.noShow)
                        Text("Rescheduled").tag(SessionStatus.rescheduled)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .background(Color.clear)
    }
    
    // MARK: - Helper Methods
    
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
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            summary += " until \(formatter.string(from: viewModel.formModel.recurrenceEndDate))"
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

// MARK: - Native SwiftUI Styling

// Using native SwiftUI styling options for optimal form appearance
// TextField: .roundedBorder for form fields
// Button: .bordered for secondary actions, .borderedProminent for primary actions
// Toggle: .switch for standard toggle appearance
// DatePicker: .compact for inline form appearance
// Picker: .menu for dropdown selection
// GroupBox: Default styling with proper spacing

// MARK: - Custom Modifiers





// MARK: - NativeAddressSearchField Component

struct NativeAddressSearchField: View {
    @Binding var searchText: String
    @Binding var selectedAddress: AddressData?
    
    // Address field bindings
    @Binding var unitNumber: String
    @Binding var streetNumber: String
    @Binding var streetName: String
    @Binding var suburb: String
    @Binding var postcode: String
    @Binding var state: String
    @Binding var country: String
    @Binding var poBox: String
    
    // Search state
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var showResults = false
    @State private var isSearching = false
    @State private var searchTimer: Timer?
    @State private var isProgrammaticallyUpdatingSearchText = false
    @State private var searchError: String?
    
    private static let searchCompleter = MKLocalSearchCompleter()
    private static var isSearchCompleterSetup = false
    private static var searchCompleterDelegate: SearchCompleterDelegate?
    private static var currentSearchField: NativeAddressSearchField?
    
    init(searchText: Binding<String>, selectedAddress: Binding<AddressData?>, unitNumber: Binding<String>, streetNumber: Binding<String>, streetName: Binding<String>, suburb: Binding<String>, postcode: Binding<String>, state: Binding<String>, country: Binding<String>, poBox: Binding<String>) {
        self._searchText = searchText
        self._selectedAddress = selectedAddress
        self._unitNumber = unitNumber
        self._streetNumber = streetNumber
        self._streetName = streetName
        self._suburb = suburb
        self._postcode = postcode
        self._state = state
        self._country = country
        self._poBox = poBox
        
        // Set up search completer immediately
        setupSearchCompleter()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Search:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        TextField("Search for an address", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(searchError != nil ? .red : .blue)
                            .onChange(of: searchText) { _, newValue in
                                // Only perform search if we're not programmatically updating the text
                                if !isProgrammaticallyUpdatingSearchText {
                                    performSearch(query: newValue)
                                }
                            }
                            .onAppear {
                                // If we have existing address data, show it in the search field
                                if searchText.isEmpty && hasExistingAddressData {
                                    searchText = formatExistingAddress()
                                }
                            }
                        
                        // Loading indicator
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                        }
                    }
                    
                    // Error message
                    if let error = searchError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.top, 4)
                    }
                    
                    // Search Results Dropdown
                    if showResults && !searchResults.isEmpty {
                        searchResultsView
                    }
                }
            }
        }
    }
    
    private func setupSearchCompleter() {
        guard !Self.isSearchCompleterSetup else { return }
        
        Self.searchCompleterDelegate = SearchCompleterDelegate(
            onResultsUpdated: { results in
                DispatchQueue.main.async {
                    guard let currentField = Self.currentSearchField else { return }
                    currentField.searchResults = results
                    currentField.showResults = !results.isEmpty && !currentField.searchText.isEmpty
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    guard let currentField = Self.currentSearchField else { return }
                    currentField.searchResults = []
                    currentField.showResults = false
                }
            }
        )
        Self.searchCompleter.delegate = Self.searchCompleterDelegate
        Self.searchCompleter.resultTypes = [.address, .pointOfInterest]
        Self.searchCompleter.pointOfInterestFilter = MKPointOfInterestFilter(including: [])
        Self.isSearchCompleterSetup = true
    }
    
    private func ensureSearchCompleterDelegate() {
        // Set the current search field reference
        Self.currentSearchField = self
        
        // Check if delegate is nil and re-establish if needed
        if Self.searchCompleter.delegate == nil {
            if Self.searchCompleterDelegate == nil {
                Self.searchCompleterDelegate = SearchCompleterDelegate(
                    onResultsUpdated: { results in
                        DispatchQueue.main.async {
                            guard let currentField = Self.currentSearchField else { return }
                            currentField.searchResults = results
                            currentField.showResults = !results.isEmpty && !currentField.searchText.isEmpty
                            currentField.isSearching = false
                            currentField.searchError = nil
                        }
                    },
                    onError: { error in
                        DispatchQueue.main.async {
                            guard let currentField = Self.currentSearchField else { return }
                            currentField.searchResults = []
                            currentField.showResults = false
                            currentField.isSearching = false
                            currentField.searchError = "Search failed. Please try again."
                        }
                    }
                )
            }
            Self.searchCompleter.delegate = Self.searchCompleterDelegate
        }
    }
    
    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(searchResults, id: \.self) { result in
                    Button(action: {
                        selectAddress(result)
                    }) {
                        HStack(spacing: 12) {
                            // Location icon
                            Image(systemName: "location.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 12))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                
                                Text(result.subtitle)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .background(Color("Background", bundle: .sharedUI).opacity(0.3))
                    .contentShape(Rectangle())
                    
                    if result != searchResults.last {
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.horizontal, 12)
                    }
                }
            }
        }
        .frame(maxHeight: 200)
        .background(Color.white.opacity(0.15))
        .cornerRadius(8)
        .padding(.top, 4)
    }
    
    private func performSearch(query: String) {
        searchTimer?.invalidate()
        guard !query.isEmpty else {
            searchResults = []
            showResults = false
            isSearching = false
            searchError = nil
            return
        }
        ensureSearchCompleterDelegate()
        isSearching = true
        searchError = nil
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            Task { @MainActor in
                Self.searchCompleter.queryFragment = query
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if searchResults.isEmpty && isSearching {
                    DispatchQueue.main.async {
                        isSearching = false
                        searchError = "Search timed out. Please try again."
                    }
                }
            }
        }
    }
    
    private func selectAddress(_ result: MKLocalSearchCompletion) {
        // Set flag to prevent search trigger
        isProgrammaticallyUpdatingSearchText = true
        
        // Update search text with selected result
        searchText = result.title + ", " + result.subtitle
        showResults = false
        
        // Reset flag after a short delay to allow the text field to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isProgrammaticallyUpdatingSearchText = false
        }
        
        // Perform geocoding to get detailed address components
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            guard let response = response, let item = response.mapItems.first else { return }
            
            DispatchQueue.main.async {
                fillAddressFields(from: item)
            }
        }
    }
    
    private func fillAddressFields(from mapItem: MKMapItem) {
        let parsed = MapKitAddressResolver.parseAddress(from: mapItem)
        unitNumber = parsed.unitNumber
        streetNumber = parsed.streetNumber
        streetName = parsed.streetName
        suburb = parsed.suburb.isEmpty ? parsed.city : parsed.suburb
        postcode = parsed.postcode
        state = parsed.state
        country = parsed.country
        poBox = parsed.poBox

        selectedAddress = AddressData(
            unitNumber: unitNumber,
            streetNumber: streetNumber,
            streetName: streetName,
            suburb: suburb,
            state: state,
            postcode: postcode,
            country: country,
            poBox: poBox
        )
        
        // Clear the search text after populating fields (without triggering search)
        isProgrammaticallyUpdatingSearchText = true
        searchText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isProgrammaticallyUpdatingSearchText = false
        }
    }
    
    private var hasExistingAddressData: Bool {
        !unitNumber.isEmpty || !streetNumber.isEmpty || !streetName.isEmpty || 
        !suburb.isEmpty || !state.isEmpty || !postcode.isEmpty || 
        !country.isEmpty || !poBox.isEmpty
    }
    
    private func formatExistingAddress() -> String {
        var parts: [String] = []
        
        if !poBox.isEmpty {
            parts.append("PO Box \(poBox)")
        } else {
            // Handle street address components
            var streetComponents: [String] = []
            
            if !unitNumber.isEmpty {
                streetComponents.append("Unit \(unitNumber)")
            }
            
            // Combine street number and name without comma
            var streetAddress = ""
            if !streetNumber.isEmpty {
                streetAddress += streetNumber
            }
            if !streetName.isEmpty {
                if !streetAddress.isEmpty {
                    streetAddress += " "
                }
                streetAddress += streetName
            }
            
            if !streetAddress.isEmpty {
                streetComponents.append(streetAddress)
            }
            
            if !streetComponents.isEmpty {
                parts.append(streetComponents.joined(separator: ", "))
            }
        }
        
        // Add locality components
        if !suburb.isEmpty { parts.append(suburb) }
        if !state.isEmpty { parts.append(state) }
        if !postcode.isEmpty { parts.append(postcode) }
        if !country.isEmpty { parts.append(country) }
        
        return parts.joined(separator: ", ")
    }
}

// MARK: - Search Completer Delegate

class SearchCompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    let onResultsUpdated: ([MKLocalSearchCompletion]) -> Void
    let onError: (Error) -> Void
    
    init(onResultsUpdated: @escaping ([MKLocalSearchCompletion]) -> Void, onError: @escaping (Error) -> Void) {
        self.onResultsUpdated = onResultsUpdated
        self.onError = onError
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResultsUpdated(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        onError(error)
    }
}

// MARK: - Address Editing Sheet

struct AddressEditingSheet: View {
    @ObservedObject var viewModel: NewSessionViewModel
    @Binding var isPresented: Bool
    
    @State private var isManualMode = false
    @State private var originalAddressSnapshot: AddressSnapshot?

    private struct AddressSnapshot {
        var unitNumber: String
        var streetNumber: String
        var streetName: String
        var suburb: String
        var city: String
        var state: String
        var postcode: String
        var country: String
        var poBox: String
        var sessionLatitude: Double
        var sessionLongitude: Double
        var addressSearchText: String
        var selectedAddress: AddressData?
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Address")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Text("Search for an address or enter details manually")
                    .font(.subheadline)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // Address Search (only shown when not in manual mode)
                    if !isManualMode {
                        VStack(spacing: 12) {
                            NativeAddressSearchField(
                                searchText: viewModel.formBinding(\.addressSearchText),
                                selectedAddress: viewModel.formBinding(\.selectedAddress),
                                unitNumber: viewModel.formBinding(\.unitNumber),
                                streetNumber: viewModel.formBinding(\.streetNumber),
                                streetName: viewModel.formBinding(\.streetName),
                                suburb: viewModel.formBinding(\.suburb),
                                postcode: viewModel.formBinding(\.postcode),
                                state: viewModel.formBinding(\.state),
                                country: viewModel.formBinding(\.country),
                                poBox: viewModel.formBinding(\.poBox)
                            )
                            .onChange(of: viewModel.formModel.selectedAddress) { _, newValue in
                                if let address = newValue {
                                    viewModel.updateAddressFromSearchResult(address)
                                }
                            }
                            
                            // Toggle to manual mode
                            HStack {
                                Spacer()
                                Button("Enter Manually") {
                                    isManualMode = true
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                    }
                    
                    // Manual Entry Fields (only shown in manual mode)
                    if isManualMode {
                        VStack(spacing: 12) {
                            // Header with mode toggle
                            HStack {
                                Text("Manual Address Entry")
                                    .font(.headline)
                                    .foregroundColor(Color("Text", bundle: .sharedUI))
                                
                                Spacer()
                                
                                Button("Search Instead") {
                                    isManualMode = false
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            .padding(.bottom, 4)
                            
                            manualAddressFields
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Footer
            HStack {
                Button("Cancel") {
                    restoreOriginalAddress()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                if hasAddressData {
                    Button("Done") {
                        // Address data is already updated through bindings
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color("Background", bundle: .sharedUI),
                    Color("Background", bundle: .sharedUI).opacity(0.95),
                    Color("Background", bundle: .sharedUI).opacity(0.9)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(minWidth: 500, minHeight: 400)
        .onAppear(perform: captureOriginalAddressIfNeeded)
    }
    
    private var hasAddressData: Bool {
        !viewModel.formModel.unitNumber.isEmpty || !viewModel.formModel.streetNumber.isEmpty || 
        !viewModel.formModel.streetName.isEmpty || !viewModel.formModel.suburb.isEmpty || !viewModel.formModel.city.isEmpty ||
        !viewModel.formModel.state.isEmpty || !viewModel.formModel.postcode.isEmpty || 
        !viewModel.formModel.country.isEmpty || !viewModel.formModel.poBox.isEmpty
    }
    
    private var manualAddressFields: some View {
        VStack(spacing: 8) {
            // Header with clear button
            HStack {
                Text("Address Details")
                    .font(.headline)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                Button("Clear") {
                    clearAddressData()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .foregroundColor(.red)
            }
            .padding(.bottom, 4)
            
            // Unit Number
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Unit:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("Unit number (optional)", text: viewModel.formBinding(\.unitNumber))
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // Street Number and Name
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Street:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                HStack(spacing: 8) {
                    TextField("Number", text: viewModel.formBinding(\.streetNumber))
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                        .frame(width: 80)
                    
                    TextField("Street name", text: viewModel.formBinding(\.streetName))
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Suburb
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Suburb:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("Enter suburb", text: viewModel.formBinding(\.suburb))
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // State and Postcode
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("State:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                HStack(spacing: 12) {
                    TextField("State", text: viewModel.formBinding(\.state))
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                    
                    TextField("Postcode", text: viewModel.formBinding(\.postcode))
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Country
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Country:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("Enter country", text: viewModel.formBinding(\.country))
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // PO Box
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PO Box:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("PO Box number (optional)", text: viewModel.formBinding(\.poBox))
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
        }
    }
    
    private func clearAddressData() {
        viewModel.clearFormAddress()
    }

    private func captureOriginalAddressIfNeeded() {
        guard originalAddressSnapshot == nil else { return }
        originalAddressSnapshot = AddressSnapshot(
            unitNumber: viewModel.formModel.unitNumber,
            streetNumber: viewModel.formModel.streetNumber,
            streetName: viewModel.formModel.streetName,
            suburb: viewModel.formModel.suburb,
            city: viewModel.formModel.city,
            state: viewModel.formModel.state,
            postcode: viewModel.formModel.postcode,
            country: viewModel.formModel.country,
            poBox: viewModel.formModel.poBox,
            sessionLatitude: viewModel.formModel.sessionLatitude,
            sessionLongitude: viewModel.formModel.sessionLongitude,
            addressSearchText: viewModel.formModel.addressSearchText,
            selectedAddress: viewModel.formModel.selectedAddress
        )
    }

    private func restoreOriginalAddress() {
        guard let snapshot = originalAddressSnapshot else { return }
        var updated = viewModel.formModel
        updated.unitNumber = snapshot.unitNumber
        updated.streetNumber = snapshot.streetNumber
        updated.streetName = snapshot.streetName
        updated.suburb = snapshot.suburb
        updated.city = snapshot.city
        updated.state = snapshot.state
        updated.postcode = snapshot.postcode
        updated.country = snapshot.country
        updated.poBox = snapshot.poBox
        updated.sessionLatitude = snapshot.sessionLatitude
        updated.sessionLongitude = snapshot.sessionLongitude
        updated.addressSearchText = snapshot.addressSearchText
        updated.selectedAddress = snapshot.selectedAddress
        viewModel.formModel = updated
    }
}

 
}
