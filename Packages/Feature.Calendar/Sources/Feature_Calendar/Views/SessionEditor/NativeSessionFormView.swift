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
    @State private var showCustomRecurrence = false
    @State private var showAddressEditingSheet = false
    @State private var validationErrors: [String: String] = [:]
    
    // Clients are fetched via ViewModel
    
    // Computed bindings for dropdown compatibility
    private var statusBinding: Binding<SessionStatus> {
        Binding(
            get: { 
                SessionStatus(rawValue: viewModel.formModel.status) ?? .scheduled 
            },
            set: { 
                viewModel.formModel.status = $0.rawValue 
            }
        )
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
                        TextField("Session title", text: $viewModel.formModel.title)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .onChange(of: viewModel.formModel.title) { _, _ in
                                if !viewModel.formModel.title.isEmpty {
                                    validationErrors["title"] = nil
                                }
                            }
                            .onSubmit {
                                // Trim on submit to avoid trailing spaces creating validation failures
                                viewModel.formModel.title = viewModel.formModel.title.trimmingCharacters(in: .whitespacesAndNewlines)
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
                        DatePicker("", selection: $viewModel.formModel.startTime, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .accentColor(.blue)
                            .onChange(of: viewModel.formModel.startTime) { _, newValue in
                                // Adjust end time if needed
                                if viewModel.formModel.isAllDay && viewModel.formModel.endTime < newValue {
                                    viewModel.formModel.endTime = newValue
                                }
                            }
                        
                        Toggle("All Day", isOn: $viewModel.formModel.isAllDay)
                            .toggleStyle(.switch)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                            .onChange(of: viewModel.formModel.isAllDay) { _, isAllDay in
                                if isAllDay {
                                    // Snap times to full-day alignment by preserving date and clearing time range issues
                                    let cal = Calendar.current
                                    let dayStart = cal.startOfDay(for: viewModel.formModel.startTime)
                                    viewModel.formModel.startTime = dayStart
                                    // keep end at least start
                                    if viewModel.formModel.endTime < viewModel.formModel.startTime {
                                        viewModel.formModel.endTime = viewModel.formModel.startTime
                                    }
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
                            DatePicker("Start", selection: $viewModel.formModel.startTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                                .accentColor(.blue)
                                .onChange(of: viewModel.formModel.startTime) { _, newValue in
                                    if !viewModel.formModel.isAllDay && viewModel.formModel.endTime <= newValue {
                                        viewModel.formModel.endTime = newValue.addingTimeInterval(3600)
                                    }
                                }
                            
                            Text("to")
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            
                            DatePicker("End", selection: $viewModel.formModel.endTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .foregroundColor(Color("Text", bundle: .sharedUI))
                                .accentColor(.blue)
                                .onChange(of: viewModel.formModel.endTime) { _, newValue in
                                    if !viewModel.formModel.isAllDay && newValue <= viewModel.formModel.startTime {
                                        viewModel.formModel.startTime = newValue.addingTimeInterval(-3600)
                                    }
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
                    
                    Picker("", selection: Binding(
                        get: { viewModel.formModel.selectedClientID },
                        set: { newID in
                            viewModel.formModel.selectedClientID = newID
                            // Reset service when client changes
                            viewModel.formModel.selectedClientServiceID = nil
                        }
                    )) {
                        Text("Select a client").tag(nil as UUID?)
                        ForEach(viewModel.availableClients, id: \.id) { client in
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
                    
                    if let selectedClient = viewModel.selectedClient {
                        Picker("", selection: Binding(
                            get: { viewModel.formModel.selectedClientServiceID },
                            set: { newID in
                                viewModel.formModel.selectedClientServiceID = newID
                            }
                        )) {
                            Text("Select a service").tag(nil as UUID?)
                            ForEach(viewModel.availableServices, id: \.id) { service in
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
                .onChange(of: viewModel.selectedClient) { _, newClient in
                    // Keep IDs in sync if client is set externally
                    viewModel.formModel.selectedClientID = newClient?.id
                    if newClient == nil {
                        viewModel.formModel.selectedClientServiceID = nil
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
                        if let newValue = newValue {
                            if newValue == .custom {
                                showCustomRecurrence = true
                            } else {
                                applyRepeatOption(newValue)
                            }
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
                if selectedRepeatOption != .never {
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
                
                Picker("Frequency", selection: $viewModel.formModel.recurrenceFrequency) {
                    ForEach(RecurrenceFrequency.allCases, id: \.self) { frequency in
                        Text(frequency.rawValue).tag(frequency)
                    }
                }
                .onChange(of: viewModel.formModel.recurrenceFrequency) { _, newValue in
                    switch newValue {
                    case .weekly:
                        // Set default weekday if none selected
                        if viewModel.formModel.selectedWeekdays.isEmpty {
                            let weekday = Calendar.current.component(.weekday, from: viewModel.formModel.startTime)
                            viewModel.formModel.selectedWeekdays = [SelectableWeekday(rawValue: weekday) ?? .monday]
                        }
                    default:
                        break
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
                    Stepper("", value: $viewModel.formModel.recurrenceInterval, in: 1...100)
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
                                    if isSelected {
                                        viewModel.formModel.selectedWeekdays.insert(weekday)
                                    } else {
                                        viewModel.formModel.selectedWeekdays.remove(weekday)
                                    }
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

            // Ordinal options for monthly/yearly
            if viewModel.formModel.recurrenceFrequency == .monthly || viewModel.formModel.recurrenceFrequency == .yearly {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Pattern:")
                        .frame(width: 80, alignment: .trailing)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    Picker("Type", selection: viewModel.formModel.recurrenceFrequency == .monthly ? $viewModel.formModel.monthlyRecurrenceType : $viewModel.formModel.yearlyRecurrenceType) {
                        Text("On specific day(s)").tag(PositionalRecurrenceType.onSpecificDays)
                        Text("On the ordinal weekday").tag(PositionalRecurrenceType.onTheOrdinalDayOfWeek)
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .fluidListTransition()
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceFrequency)
                if viewModel.formModel.recurrenceFrequency == .monthly && viewModel.formModel.monthlyRecurrenceType == .onTheOrdinalDayOfWeek ||
                   viewModel.formModel.recurrenceFrequency == .yearly && viewModel.formModel.yearlyRecurrenceType == .onTheOrdinalDayOfWeek {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ordinal:")
                            .frame(width: 80, alignment: .trailing)
                            .foregroundColor(Color("Text", bundle: .sharedUI))
                        Picker("Ordinal", selection: $viewModel.formModel.selectedOrdinal) {
                            ForEach([1,2,3,4,-1], id: \.self) { value in
                                Text(value == -1 ? "Last" : [1:"First",2:"Second",3:"Third",4:"Fourth"][value]!).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        Picker("Weekday", selection: $viewModel.formModel.selectedDayOfWeekForOrdinal) {
                            ForEach(DayOfWeekOption.allCases, id: \.self) { option in
                                if option.rawValue >= 3 { // real weekdays
                                    Text(option.displayName).tag(option)
                                }
                            }
                        }
                        .pickerStyle(.menu)
                        Spacer()
                    }
                    .fluidListTransition()
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: viewModel.formModel.recurrenceFrequency)
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
                
                Picker("End Type", selection: $viewModel.formModel.recurrenceEndType) {
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
                        Stepper("", value: $viewModel.formModel.recurrenceCount, in: 1...999)
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
                    
                    DatePicker("", selection: $viewModel.formModel.recurrenceEndDate, displayedComponents: .date)
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
                    AddressDisplayView(addressId: addressId, addressRepository: viewModel.addressRepository)
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
    
    private var shouldShowManualFields: Bool {
        (!viewModel.formModel.addressSearchText.isEmpty && !hasAddressData) || 
        viewModel.formModel.selectedAddress != nil
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
        if !viewModel.formModel.suburb.isEmpty { parts.append(viewModel.formModel.suburb) }
        if !viewModel.formModel.state.isEmpty { parts.append(viewModel.formModel.state) }
        if !viewModel.formModel.postcode.isEmpty { parts.append(viewModel.formModel.postcode) }
        if !viewModel.formModel.country.isEmpty { parts.append(viewModel.formModel.country) }
        
        return parts.joined(separator: ", ")
    }
    
    private var hasAddressData: Bool {
        !viewModel.formModel.unitNumber.isEmpty || !viewModel.formModel.streetNumber.isEmpty || 
        !viewModel.formModel.streetName.isEmpty || !viewModel.formModel.suburb.isEmpty || 
        !viewModel.formModel.state.isEmpty || !viewModel.formModel.postcode.isEmpty || 
        !viewModel.formModel.country.isEmpty || !viewModel.formModel.poBox.isEmpty
    }
    
    private func updateAddressFromSearchResult(_ address: AddressData) {
        viewModel.formModel.unitNumber = address.unitNumber
        viewModel.formModel.streetNumber = address.streetNumber
        viewModel.formModel.streetName = address.streetName
        viewModel.formModel.suburb = address.suburb
        viewModel.formModel.state = address.state
        viewModel.formModel.postcode = address.postcode
        viewModel.formModel.country = address.country
        viewModel.formModel.poBox = address.poBox
        // Note: AddressData no longer has coordinate property
        // Coordinates would need to be set separately if needed
        // viewModel.formModel.sessionLatitude = coordinate.latitude
        // viewModel.formModel.sessionLongitude = coordinate.longitude
    }
    
    private func clearAddressData() {
        viewModel.formModel.unitNumber = ""
        viewModel.formModel.streetNumber = ""
        viewModel.formModel.streetName = ""
        viewModel.formModel.suburb = ""
        viewModel.formModel.state = ""
        viewModel.formModel.postcode = ""
        viewModel.formModel.country = ""
        viewModel.formModel.poBox = ""
        viewModel.formModel.sessionLatitude = 0.0
        viewModel.formModel.sessionLongitude = 0.0
        viewModel.formModel.addressSearchText = ""
        viewModel.formModel.selectedAddress = nil
    }
    
    private func currentAddressView(_ address: AddressEntity) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Address:")
                    .font(.headline)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Edit") {
                        // Populate form fields with existing address data
                        viewModel.formModel.unitNumber = address.unitNumber
                        viewModel.formModel.streetNumber = address.streetNumber
                        viewModel.formModel.streetName = address.streetName
                        viewModel.formModel.suburb = address.suburb
                        viewModel.formModel.state = address.state
                        viewModel.formModel.postcode = address.postcode
                        viewModel.formModel.country = address.country
                        viewModel.formModel.poBox = address.poBox
                        viewModel.formModel.sessionLatitude = address.latitude
                        viewModel.formModel.sessionLongitude = address.longitude
                        viewModel.formModel.addressSearchText = address.fullAddressText
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button("Clear") {
                        // Clear all address fields
                        viewModel.formModel.unitNumber = ""
                        viewModel.formModel.streetNumber = ""
                        viewModel.formModel.streetName = ""
                        viewModel.formModel.suburb = ""
                        viewModel.formModel.state = ""
                        viewModel.formModel.postcode = ""
                        viewModel.formModel.country = ""
                        viewModel.formModel.poBox = ""
                        viewModel.formModel.sessionLatitude = 0.0
                        viewModel.formModel.sessionLongitude = 0.0
                        viewModel.formModel.addressSearchText = ""
                        viewModel.formModel.selectedAddress = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
            
            Text(address.fullFormattedAddress)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .font(.system(size: 14))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
        }
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
                
                TextField("Unit number (optional)", text: $viewModel.formModel.unitNumber)
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
                    TextField("Number", text: $viewModel.formModel.streetNumber)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                        .frame(width: 80)
                    
                    TextField("Street name", text: $viewModel.formModel.streetName)
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
                
                TextField("Enter suburb", text: $viewModel.formModel.suburb)
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
                    TextField("State", text: $viewModel.formModel.state)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                    
                    TextField("Postcode", text: $viewModel.formModel.postcode)
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
                
                TextField("Enter country", text: $viewModel.formModel.country)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // PO Box
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PO Box:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("PO Box number (optional)", text: $viewModel.formModel.poBox)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
        }
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        GroupBox("Notes") {
            VStack(spacing: 8) {
                    TextEditor(text: $viewModel.formModel.notes)
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
            break // Handled separately
        }
    }
    
    private func getRecurrenceSummaryText() -> String {
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



struct EnhancedGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            configuration.label
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.15)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
            
            configuration.content
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }
}

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
                                print("🎨 Search TextField appeared")
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
        .onAppear {
            print("🎨 NativeAddressSearchField body appeared")
        }
        .onChange(of: showResults) { _, newValue in
            print("🔄 showResults changed to: \(newValue)")
        }
        .onChange(of: searchResults.count) { _, newValue in
            print("🔄 searchResults.count changed to: \(newValue)")
        }
    }
    
    private func setupSearchCompleter() {
        print("🔧 setupSearchCompleter called, isSearchCompleterSetup: \(Self.isSearchCompleterSetup)")
        
        guard !Self.isSearchCompleterSetup else {
            print("🔧 Search completer already set up, skipping...")
            return
        }
        
        print("🔧 Setting up search completer...")
        
        // Create and store the delegate as a static property to ensure it persists
        Self.searchCompleterDelegate = SearchCompleterDelegate(
            onResultsUpdated: { results in
                DispatchQueue.main.async {
                    guard let currentField = Self.currentSearchField else { return }
                    print("📥 Received \(results.count) search results from delegate")
                    currentField.searchResults = results
                    currentField.showResults = !results.isEmpty && !currentField.searchText.isEmpty
                    print("📊 Updated state - searchResults: \(currentField.searchResults.count), showResults: \(currentField.showResults)")
                    
                    // Debug each result
                    for (index, result) in results.enumerated() {
                        print("   Result \(index + 1): '\(result.title)' - '\(result.subtitle)'")
                    }
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    guard let currentField = Self.currentSearchField else { return }
                    print("❌ Search completer error: \(error.localizedDescription)")
                    currentField.searchResults = []
                    currentField.showResults = false
                }
            }
        )
        
        print("🔧 Created delegate: \(Self.searchCompleterDelegate!)")
        Self.searchCompleter.delegate = Self.searchCompleterDelegate
        print("🔧 Assigned delegate to searchCompleter")
        
        // Configure search completer for better results
        Self.searchCompleter.resultTypes = [.address, .pointOfInterest]
        Self.searchCompleter.pointOfInterestFilter = MKPointOfInterestFilter(including: [])
        

        print("✅ Search completer configured for global search (no region restriction)")
        print("✅ Result types: \(Self.searchCompleter.resultTypes)")
        print("✅ Delegate set: \(Self.searchCompleter.delegate != nil)")
        print("✅ Delegate object: \(Self.searchCompleter.delegate != nil ? "set" : "nil")")
        
        // Test the search completer with a simple query
        print("🧪 Testing search completer with 'test' query...")
        Self.searchCompleter.queryFragment = "test"
        
        Self.isSearchCompleterSetup = true
        print("✅ Search completer setup completed")
    }
    
    private func ensureSearchCompleterDelegate() {
        // Set the current search field reference
        Self.currentSearchField = self
        
        // Check if delegate is nil and re-establish if needed
        if Self.searchCompleter.delegate == nil {
            print("🔧 Delegate is nil, re-establishing...")
            if Self.searchCompleterDelegate == nil {
                print("🔧 Creating new delegate...")
                Self.searchCompleterDelegate = SearchCompleterDelegate(
                    onResultsUpdated: { results in
                        DispatchQueue.main.async {
                            guard let currentField = Self.currentSearchField else { return }
                            print("📥 Received \(results.count) search results from delegate")
                            currentField.searchResults = results
                            currentField.showResults = !results.isEmpty && !currentField.searchText.isEmpty
                            currentField.isSearching = false
                            currentField.searchError = nil
                            print("📊 Updated state - searchResults: \(currentField.searchResults.count), showResults: \(currentField.showResults)")
                            
                            // Debug each result
                            for (index, result) in results.enumerated() {
                                print("   Result \(index + 1): '\(result.title)' - '\(result.subtitle)'")
                            }
                        }
                    },
                    onError: { error in
                        DispatchQueue.main.async {
                            guard let currentField = Self.currentSearchField else { return }
                            print("❌ Search completer error: \(error.localizedDescription)")
                            currentField.searchResults = []
                            currentField.showResults = false
                            currentField.isSearching = false
                            currentField.searchError = "Search failed. Please try again."
                        }
                    }
                )
            }
            Self.searchCompleter.delegate = Self.searchCompleterDelegate
            print("🔧 Delegate re-established: \(Self.searchCompleter.delegate != nil)")
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
        print("🔍 performSearch called with query: '\(query)'")
        
        // Cancel previous timer
        searchTimer?.invalidate()
        print("⏰ Cancelled previous timer")
        
        guard !query.isEmpty else {
            searchResults = []
            showResults = false
            isSearching = false
            searchError = nil
            print("🚫 Search cleared - empty query")
            return
        }
        
        // Ensure delegate is set before performing search
        ensureSearchCompleterDelegate()
        
        // Set loading state
        isSearching = true
        searchError = nil
        
        // Create new timer for debounced search
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            print("🚀 Timer fired - performing actual search for: '\(query)'")
            print("🔧 Setting queryFragment on searchCompleter...")
            print("🔧 searchCompleter delegate: \(Self.searchCompleter.delegate != nil ? "SET" : "NOT SET")")
            print("🔧 searchCompleter resultTypes: \(Self.searchCompleter.resultTypes)")
            Self.searchCompleter.queryFragment = query
            print("✅ queryFragment set to: '\(query)'")
            print("🔧 Will wait for delegate callbacks...")
            
            // Add timeout to detect if search completer is not responding
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if searchResults.isEmpty && isSearching {
                    print("⏰ TIMEOUT: No search results received after 3 seconds")
                    print("🔧 This might indicate network issues or MapKit problems")
                    DispatchQueue.main.async {
                        isSearching = false
                        searchError = "Search timed out. Please try again."
                    }
                }
            }
        }
        
        print("⏰ Created new timer for query: '\(query)'")
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
            guard let response = response, let item = response.mapItems.first else { 
                print("❌ Geocoding failed: \(error?.localizedDescription ?? "Unknown error")")
                return 
            }
            
            DispatchQueue.main.async {
                fillAddressFields(from: item)
            }
        }
    }
    
    private func fillAddressFields(from mapItem: MKMapItem) {
        // Use the new location and address properties instead of deprecated placemark
        let address = mapItem.address
        
        // Try to extract address components from MKAddress first
        var extractedComponents: [String: String] = [:]
        if let address = address {
            extractedComponents = parseAddressString(address.fullAddress)
        }
        
        // Fall back to placemark if MKAddress parsing didn't provide sufficient data
        let placemark = mapItem.placemark
        
        // Extract address components - prefer MKAddress parsed components, fall back to placemark
        unitNumber = extractedComponents["unit"] ?? ""
        streetNumber = extractedComponents["streetNumber"] ?? placemark.subThoroughfare ?? ""
        streetName = extractedComponents["streetName"] ?? placemark.thoroughfare ?? ""
        suburb = extractedComponents["suburb"] ?? placemark.locality ?? ""
        postcode = extractedComponents["postcode"] ?? placemark.postalCode ?? ""
        state = extractedComponents["state"] ?? placemark.administrativeArea ?? ""
        country = extractedComponents["country"] ?? placemark.country ?? ""
        poBox = ""
        
        // Create AddressData for the viewModel
        selectedAddress = AddressData()
        
        // Update the AddressData with mapItem details
        // Note: AddressData no longer has update method
        // Address data would need to be updated manually if needed
        
        // Clear the search text after populating fields (without triggering search)
        isProgrammaticallyUpdatingSearchText = true
        searchText = ""
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isProgrammaticallyUpdatingSearchText = false
        }
        
        print("✅ Address fields populated from search result")
    }
    
    /// Parses an address string to extract individual components
    /// This is a best-effort parsing that may not work for all address formats
    private func parseAddressString(_ addressString: String) -> [String: String] {
        var components: [String: String] = [:]
        let address = addressString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Common patterns for address parsing
        let patterns: [(String, String)] = [
            // Unit/Street Number/Street Name pattern: "Unit 1, 123 Main St"
            (#"Unit\s+([^,]+),\s*(\d+)\s+(.+?)(?:,|$)"#, "unit"),
            // Street Number/Street Name pattern: "123 Main St"
            (#"^(\d+)\s+(.+?)(?:,|$)"#, "streetNumber"),
            // Postcode pattern: "NSW 2000" or "2000"
            (#"([A-Z]{2,3})\s+(\d{4})"#, "state"),
            (#"(\d{4})"#, "postcode"),
            // Country pattern: "Australia" at the end
            (#"([A-Za-z]+)$"#, "country")
        ]
        
        for (pattern, componentType) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: address, options: [], range: NSRange(location: 0, length: address.utf16.count))
                
                for match in matches {
                    switch componentType {
                    case "unit":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["unit"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "streetNumber":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["streetNumber"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if match.numberOfRanges > 2, let range = Range(match.range(at: 2), in: address) {
                            components["streetName"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "state":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["state"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        if match.numberOfRanges > 2, let range = Range(match.range(at: 2), in: address) {
                            components["postcode"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "postcode":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["postcode"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "suburb":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["suburb"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    case "country":
                        if match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: address) {
                            components["country"] = String(address[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        return components
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
        print("🔧 SearchCompleterDelegate initialized")
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        print("📡 completerDidUpdateResults called with \(completer.results.count) results")
        print("📡 Current queryFragment: '\(completer.queryFragment)'")
        
        // Debug each result
        for (index, result) in completer.results.enumerated() {
            print("   📍 Result \(index + 1): '\(result.title)' - '\(result.subtitle)'")
        }
        
        onResultsUpdated(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("💥 completer didFailWithError: \(error.localizedDescription)")
        print("💥 Error domain: \((error as NSError).domain)")
        print("💥 Error code: \((error as NSError).code)")
        onError(error)
    }
}

// MARK: - Address Editing Sheet

struct AddressEditingSheet: View {
    @ObservedObject var viewModel: NewSessionViewModel
    @Binding var isPresented: Bool
    
    @State private var isManualMode = false
    
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
    }
    
    private var hasAddressData: Bool {
        !viewModel.formModel.unitNumber.isEmpty || !viewModel.formModel.streetNumber.isEmpty || 
        !viewModel.formModel.streetName.isEmpty || !viewModel.formModel.suburb.isEmpty || 
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
                
                TextField("Unit number (optional)", text: $viewModel.formModel.unitNumber)
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
                    TextField("Number", text: $viewModel.formModel.streetNumber)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                        .frame(width: 80)
                    
                    TextField("Street name", text: $viewModel.formModel.streetName)
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
                
                TextField("Enter suburb", text: $viewModel.formModel.suburb)
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
                    TextField("State", text: $viewModel.formModel.state)
                        .textFieldStyle(.roundedBorder)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                        .accentColor(.blue)
                    
                    TextField("Postcode", text: $viewModel.formModel.postcode)
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
                
                TextField("Enter country", text: $viewModel.formModel.country)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
            
            // PO Box
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("PO Box:")
                    .frame(width: 80, alignment: .trailing)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                
                TextField("PO Box number (optional)", text: $viewModel.formModel.poBox)
                    .textFieldStyle(.roundedBorder)
                    .foregroundColor(Color("Text", bundle: .sharedUI))
                    .accentColor(.blue)
            }
        }
    }
    
    private func clearAddressData() {
        viewModel.formModel.unitNumber = ""
        viewModel.formModel.streetNumber = ""
        viewModel.formModel.streetName = ""
        viewModel.formModel.suburb = ""
        viewModel.formModel.state = ""
        viewModel.formModel.postcode = ""
        viewModel.formModel.country = ""
        viewModel.formModel.poBox = ""
        viewModel.formModel.sessionLatitude = 0.0
        viewModel.formModel.sessionLongitude = 0.0
        viewModel.formModel.addressSearchText = ""
        viewModel.formModel.selectedAddress = nil
    }
}

 
}
