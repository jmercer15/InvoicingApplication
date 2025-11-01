import SwiftUI
import Core
import Data
import SharedUI

struct ClientServiceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    // The service being edited. Can be nil if creating a new one from scratch (non-NDIS).
    @Binding var service: ClientServiceEntity?
    
    // Bindings for the form fields, now derived from the 'service' object
    // or handled internally if creating a new service.
    @State private var serviceName: String
    @State private var ndisCode: String
    @State private var rate: Double
    @State private var unit: String
    @State private var isActive: Bool
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date?
    
    // The NDIS Item that this service is being created FROM.
    // This is non-nil only when adding a new service from the catalogue.
    let sourceNdisItem: NDISItemEntity?
    
    // Actions
    let onSave: (ClientServiceEntity) -> Void
    let onCancel: () -> Void
    
    // Internal State
    @State private var priceMode: PriceMode = .custom
    @State private var selectedNdisPriceKey: String? = nil
    @State private var availableNdisPrices: [String: Double]? = nil
    @State private var rateString: String = ""
    @State private var isDerivedFromNdisItem: Bool = false
    @State private var validationErrors: [String: String] = [:]
    @State private var isEditingExistingService: Bool
    @State private var restrictEditing: Bool
    
    // Focus state for form fields
    @FocusState private var focusedField: Field?
    
    // Constants
    private let unitOptions = ["hour", "session", "day", "week", "month", "item"]
    
    // Field enum for FocusState
    enum Field: Hashable {
        case serviceName
        case ndisCode
        case rate
    }
    
    // Form component state - REMOVED
    // @StateObject private var formState = FormComponentState()
    
    // Validation
    private var isFormValid: Bool {
        !serviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        rate > 0
    }
    
    private var accentColor: Color {
        Color("Indigo", bundle: .sharedUI)
    }
    
    enum PriceMode: String, CaseIterable, Identifiable {
        case ndis = "NDIS Rate"
        case custom = "Custom Rate"
        var id: String { rawValue }
    }
    
    // Initializer
    init(
        service: Binding<ClientServiceEntity?>,
        sourceNdisItem: NDISItemEntity? = nil, // For adding new
        isEditingExistingService: Bool = false, // Add this parameter
        restrictEditing: Bool = false,
        isCustomService: Bool = false,
        onSave: @escaping (ClientServiceEntity) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._service = service
        self.sourceNdisItem = sourceNdisItem
        self.onSave = onSave
        self.onCancel = onCancel
        self._isEditingExistingService = State(initialValue: isEditingExistingService) // Initialize the state
        self._restrictEditing = State(initialValue: restrictEditing)
        
        // Initialize state from the service object or source NDIS item
        let currentService = service.wrappedValue
        let itemToUse = currentService?.ndisItem ?? sourceNdisItem
        
        let serviceNameValue = currentService?.serviceName ?? itemToUse?.name ?? ""
        _serviceName = State(initialValue: serviceNameValue)
        let ndisCodeValue = currentService?.ndisCode ?? itemToUse?.itemNumber ?? ""
        _ndisCode = State(initialValue: ndisCodeValue)
        let rateValue = currentService?.rate ?? 0
        _rate = State(initialValue: rateValue)
        let unitValue = currentService?.unit ?? itemToUse?.unit ?? "Hour"
        _unit = State(initialValue: unitValue)
        _isActive = State(initialValue: currentService?.isActive ?? true)
        _startDate = State(initialValue: currentService?.startDate ?? Date())
        _hasEndDate = State(initialValue: currentService?.endDate != nil)
        _endDate = State(initialValue: currentService?.endDate)
        
        // For custom services, don't set isDerivedFromNdisItem
        if isCustomService {
            _isDerivedFromNdisItem = State(initialValue: false)
        } else {
            _isDerivedFromNdisItem = State(initialValue: itemToUse != nil)
        }
    }
    
    // Formatters
    private static let rateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with service name
            Text(serviceName)
                .font(.headline)
                .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassEffect(.regular, in: .rect())
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color("White10", bundle: .sharedUI)),
                    alignment: .bottom
                )
            
            // Content
            if restrictEditing {
                // Simplified inline editing layout that matches ServiceTemplateRow
                VStack(spacing: 16) {
                    // Allow editing service name for custom services
                    if !isDerivedFromNdisItem {
                        FormField("Service Name") {
                            TextField("Service Name", text: $serviceName)
                        }
                        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                        .padding(.top, StyleGuide.Dimensions.paddingLarge)
                    }
                    
                    HStack(alignment: .top, spacing: 16) {
                        // Only show NDIS Code field for NDIS-derived services
                        if isDerivedFromNdisItem {
                            FormField("NDIS Code") {
                                TextField("e.g., 01_001_0107_1_1", text: $ndisCode)
                            }
                            .disabled(isDerivedFromNdisItem || restrictEditing)
                            .opacity(isDerivedFromNdisItem ? 0.6 : 1.0)
                            .focused($focusedField, equals: .ndisCode)
                        } else {
                            // For custom services, leave this space empty or show a spacer
                            Spacer().frame(maxWidth: .infinity)
                        }
                        
                        // Only show NDIS price options for NDIS-derived services
                        if isDerivedFromNdisItem {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Price Mode")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                Picker("Price Mode", selection: $priceMode) {
                                    ForEach(PriceMode.allCases, id: \.self) { mode in
                                        Text(String(describing: mode)).tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                            
                            if priceMode == .ndis {
                                if let ndisPrices = availableNdisPrices, !ndisPrices.isEmpty {
                                    let optionLabels = Dictionary(uniqueKeysWithValues:
                                                                    sortedNdisPriceKeys.map { key in
                                        let price = Self.rateFormatter.string(from: NSNumber(value: ndisPrices[key] ?? 0)) ?? ""
                                        return (key, "\(key) (\(price))")
                                    }
                                    )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("NDIS Rate")
                                            .font(.caption)
                                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                        Picker("NDIS Rate", selection: $selectedNdisPriceKey) {
                                            ForEach(sortedNdisPriceKeys, id: \.self) { key in
                                                Text(optionLabels[key] ?? key).tag(key as String?)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    .onChange(of: selectedNdisPriceKey) { _, newKey in
                                        if let key = newKey, let newRate = ndisPrices[key] {
                                            rate = newRate
                                        }
                                    }
                                } else {
                                    Text("No NDIS price available.")
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                        .font(.caption)
                                        .frame(maxHeight: .infinity, alignment: .center)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Custom Rate")
                                        .font(.caption)
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    HStack {
                                        Text("$")
                                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                        TextField("0.00", text: $rateString)
                                    }
                                }
                                .onChange(of: rateString) { _, newValue in
                                    if let doubleValue = Double(newValue.replacingOccurrences(of: "$", with: "")) {
                                        rate = doubleValue
                                    }
                                }
                            }
                        } else {
                            // For custom services, always show rate field
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Rate")
                                    .font(.caption)
                                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                HStack {
                                    Text("$")
                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                    TextField("0.00", text: $rateString)
                                }
                            }
                            .onChange(of: rateString) { _, newValue in
                                if let doubleValue = Double(newValue.replacingOccurrences(of: "$", with: "")) {
                                    rate = doubleValue
                                }
                            }
                        }
                        
                        // Use standard Picker for unit selection for both custom and NDIS services
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Unit")
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            Picker("Unit", selection: $unit) {
                                ForEach(unitOptions, id: \.self) { unit in
                                    Text(unit).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .disabled(isDerivedFromNdisItem && restrictEditing)
                    }
                    .padding(16)
                    
                    // Footer with save/cancel buttons
                    HStack {
                        Spacer()
                        Button("Cancel") { onCancel() }
                            .buttonStyle(.glass)
                            .appInteractiveCursor()
                        Button("Save") { updateAndSaveService() }
                            .buttonStyle(.glassProminent)
                            .disabled(!isFormValid)
                            .appInteractiveCursor()
                    }
                    .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                    .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
                }
            } else {
                ScrollView {
                    formContent
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color("Black30", bundle: .sharedUI).opacity(0.17),
                            Color("Black30", bundle: .sharedUI).opacity(0.5)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .background(Color("Black30", bundle: .sharedUI).opacity(0.1))
        .onAppear(perform: initializeForm)
        .onChange(of: rate) { _, newValue in
            // Keep rateString in sync with rate, unless user is typing in the box.
            if focusedField != .rate {
                rateString = Self.numberFormatter.string(from: NSNumber(value: newValue)) ?? ""
            }
        }
    }
    
    // MARK: - Form Content
    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // NDIS Source Information Section
            if let ndisItem = service?.ndisItem ?? sourceNdisItem {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Source NDIS Catalogue Item")
                        .font(.headline)
                        .foregroundColor(Color("White", bundle: .sharedUI).opacity(0.9))
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ndisItem.name)
                                .fontWeight(.bold)
                            Text(ndisItem.itemNumber)
                                .font(.subheadline)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                        Spacer()
                        Button("Reset to Defaults") {
                            resetToNdisDefaults(ndisItem)
                        }
                        .buttonStyle(.glass)
                        .appInteractiveCursor()
                    }
                }
                .padding()
                .background(Color("Primary", bundle: .sharedUI).opacity(StyleGuide.Opacity.light))
                .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusSmall)
                        .stroke(Color("Primary", bundle: .sharedUI).opacity(0.4), lineWidth: 1)
                )
            }
            
            // Service Name Section
            FormField("Custom Service Name") {
                TextField("Enter service name", text: $serviceName)
            }
            .disabled(restrictEditing && isDerivedFromNdisItem)
            .focused($focusedField, equals: .serviceName)
            
            // Three Column Layout for second row
            HStack(alignment: .top) {
                // NDIS Code (1st position) - only show for NDIS-derived services
                if isDerivedFromNdisItem {
                    FormField("NDIS Code") {
                        TextField("e.g., 01_001_0107_1_1", text: $ndisCode)
                    }
                    .disabled(isDerivedFromNdisItem || restrictEditing)
                    .opacity(isDerivedFromNdisItem ? 0.6 : 1.0)
                    .focused($focusedField, equals: .ndisCode)
                } else {
                    // For custom services, leave this space empty
                    Spacer().frame(maxWidth: .infinity)
                }
                
                Spacer().frame(maxWidth: .infinity)
                Spacer().frame(maxWidth: .infinity)
                
                // Rate (2nd position)
                if priceMode == .ndis {
                    // NDIS Rate Display
                    VStack(alignment: .leading) {
                        Text("Rate")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        
                        Text(Self.rateFormatter.string(from: NSNumber(value: rate)) ?? "$0.00")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(accentColor)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color("Black30", bundle: .sharedUI))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(accentColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }
                } else {
                    // Custom Rate Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Rate")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        HStack {
                            Text("$")
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            TextField("0.00", text: $rateString)
                        }
                    }
                    .focused($focusedField, equals: .rate)
                    .onChange(of: rateString) { _, newValue in
                        if let doubleValue = Double(newValue.replacingOccurrences(of: "$", with: "")) {
                            rate = doubleValue
                        }
                    }
                }
                
                // Unit (3rd position)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Unit")
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    Picker("Unit", selection: $unit) {
                        ForEach(unitOptions, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .disabled(isDerivedFromNdisItem && restrictEditing)
            }
            
            // Price Mode Selection and Regional Pricing (if applicable)
            if availableNdisPrices != nil && !availableNdisPrices!.isEmpty {
                VStack {
                    VStack(alignment: .leading) {
                        Text("Price Source")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        
                        Picker("Price Source", selection: $priceMode) {
                            ForEach(PriceMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: priceMode) { _, newValue in
                            if newValue == .ndis {
                                if let firstKey = sortedNdisPriceKeys.first,
                                   let firstPrice = availableNdisPrices?[firstKey] {
                                    selectedNdisPriceKey = firstKey
                                    rate = firstPrice
                                }
                            } else {
                                selectedNdisPriceKey = nil
                            }
                        }
                    }
                    
                    // NDIS Price Selection
                    if priceMode == .ndis, let ndisPrices = availableNdisPrices, !ndisPrices.isEmpty {
                        let optionLabels = Dictionary(uniqueKeysWithValues:
                                                        sortedNdisPriceKeys.map { key in
                            let price = Self.rateFormatter.string(from: NSNumber(value: ndisPrices[key] ?? 0)) ?? ""
                            return (key, "\(key): \(price)")
                        }
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Regional Price")
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            Picker("Regional Price", selection: $selectedNdisPriceKey) {
                                Text("Select regional pricing").tag(nil as String?)
                                ForEach(sortedNdisPriceKeys, id: \.self) { key in
                                    Text(optionLabels[key] ?? key).tag(key as String?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .onChange(of: selectedNdisPriceKey) { _, newKey in
                            if let key = newKey, let newRate = ndisPrices[key] {
                                rate = newRate
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingLarge)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text(isEditingExistingService ? "Edit Service" : "Add New Service")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("White", bundle: .sharedUI))
                    
                    if isDerivedFromNdisItem {
                        Text("Based on NDIS catalogue item")
                            .font(.caption)
                            .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    }
                }
                
                Spacer()
                
                // Buttons row
                HStack(spacing: 12) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.escape)
                    .appInteractiveCursor()
                    
                    Button("Save") {
                        updateAndSaveService()
                    }
                    .buttonStyle(PrimaryButtonStyle(isEnabled: isFormValid))
                    .disabled(!isFormValid)
                    .keyboardShortcut(.return, modifiers: .command)
                    .appInteractiveCursor()
                }
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
            
            Divider()
                .background(Color("White10", bundle: .sharedUI))
        }
        .background(Color("Black30", bundle: .sharedUI).opacity(0.67))
    }
    
    // MARK: - Helper Views
    
    private var sortedNdisPriceKeys: [String] {
        guard let prices = availableNdisPrices else { return [] }
        return prices.keys.sorted()
    }
    
    // MARK: - Methods
    
    private func initializeForm() {
        let itemForPricing = service?.ndisItem ?? sourceNdisItem
        isDerivedFromNdisItem = itemForPricing != nil

        var prices: [String: Double] = [:]
        if let ndisItem = itemForPricing {
            let regionalPrices = ndisItem.regionalPrices
            _ = Set(regionalPrices)
            for priceInfo in regionalPrices {
                if let region = priceInfo.regionIdentifier, priceInfo.amount > 0 {
                    prices[region] = priceInfo.amount
                }
            }
        }
        // Add a "National" price if it's not in the regional set (older items might have it on the item itself)

        self.availableNdisPrices = prices.isEmpty ? nil : prices

        // Set initial price mode
        if service?.rate == 0, let firstKey = prices.keys.sorted().first, let firstPrice = prices[firstKey] {
            // If service rate is zero, default to first NDIS price
            priceMode = .ndis
            selectedNdisPriceKey = firstKey
            rate = firstPrice
        } else if availableNdisPrices?.values.contains(service?.rate ?? -1) == true {
            // If the current rate matches one of the NDIS prices, set mode to NDIS
            priceMode = .ndis
            selectedNdisPriceKey = availableNdisPrices?.first(where: { $0.value == service?.rate })?.key
        } else {
            self.availableNdisPrices = nil
            priceMode = .custom
        }

        // Initialize rateString from the model
        rateString = Self.numberFormatter.string(from: NSNumber(value: rate)) ?? ""
    }
    
    private func updateAndSaveService() {
        // This function now needs to update the bound service object
        // For simplicity, we'll assume the onSave closure handles the actual Core Data save.
        
        // If the service is nil, it means we are creating a new one.
        // The calling view is responsible for creating the new instance.
        guard let serviceToSave = self.service else {
            // This path should ideally not be taken if the view is used correctly.
            // The caller should provide a new ClientService instance.
            print("Error: Save was called but the service object is nil.")
            return
        }
        
        serviceToSave.serviceName = serviceName
        
        // For custom services, ensure both ndisItem and ndisCode are nil
        if !isDerivedFromNdisItem {
            serviceToSave.ndisItem = nil
            serviceToSave.ndisCode = nil
        } else {
            serviceToSave.ndisCode = ndisCode
        }
        
        serviceToSave.rate = rate
        serviceToSave.unit = unit
        serviceToSave.isActive = isActive
        serviceToSave.startDate = startDate
        serviceToSave.endDate = hasEndDate ? endDate : nil
        
        onSave(serviceToSave)
    }

    private func resetToNdisDefaults(_ ndisItem: NDISItemEntity) {
        serviceName = ndisItem.name
        unit = ndisItem.unit ?? "Hour"

        // Reset to the primary/first available NDIS price
        if let prices = availableNdisPrices,
           let firstKey = sortedNdisPriceKeys.first,
           let firstPrice = prices[firstKey] {
            rate = firstPrice
            selectedNdisPriceKey = firstKey
            priceMode = .ndis
        } else {
            // Fallback if no regional prices found
            rate = 0 // Or some other default
            priceMode = .custom
        }
    }
    
    // MARK: - Dropdown Option
    
    struct DropdownOption: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String?
        
        init(id: String, title: String, subtitle: String? = nil) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
        }
    }
    
    // MARK: - Button Styles
    
    struct PrimaryButtonStyle: ButtonStyle {
        let isEnabled: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color("White", bundle: .sharedUI))
                .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: isEnabled ? [
                                    Color("Indigo", bundle: .sharedUI),
                                    Color("DarkIndigo", bundle: .sharedUI)
                                ] : [
                                    Color("Gray20", bundle: .sharedUI),
                                    Color("Gray10", bundle: .sharedUI)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    isEnabled ? Color("Indigo", bundle: .sharedUI).opacity(0.8) : Color("Gray20", bundle: .sharedUI),
                                    lineWidth: 1
                                )
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: configuration.isPressed)
        }
    }
    
    struct SecondaryButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color("Black30", bundle: .sharedUI))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color("White20", bundle: .sharedUI), lineWidth: 1)
                        )
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: configuration.isPressed)
        }
    }
}

