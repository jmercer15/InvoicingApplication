import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Data
import Core
import SharedUI

// Import the Data package types directly to avoid Foundation.Data ambiguity
import class Data.TravelChargeAuditLog
import class Data.TravelChargeReviewItem


struct ImportExportView: View {
    @Environment(\.modelContext) private var viewContext
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Source:", "File:", "Successful:", "Failed:"]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    @State private var showingFileImporter = false
    @State private var showingFileExporter = false
    @State private var exportData: Data?
    @State private var exportFileName: String = ""
    @State private var selectedImportSource: ImportSource = .clients
    @State private var selectedExportSource: ImportSource = .clients
    @State private var importResults: ImportResults?
    @State private var isShowingResults = false
    @State private var isLoading = false
    @State private var showingBulkImportView = false
    @State private var isImportingNDISCatalogue = false
    @State private var showingClearNDISConfirmation = false
    @State private var isClearingNDIS = false
    @State private var isUpdatingCurrentStatus = false
    @State private var isUpdatingForSelectedDate = false
    @State private var updateStatusResults: String? = nil
    @State private var showingUpdateStatusResults = false
    @State private var availableEffectiveDates: [Date] = []
    @State private var selectedEffectiveDates: Set<Date> = []
    @State private var showingAllDataFileImporter = false
    @State private var showingAllDataFileExporter = false
    @State private var allDataExport: Data? = nil
    @State private var allDataExportFileName: String = ""
    @State private var allDataImportResult: String? = nil
    @State private var showingAllDataImportResult = false
    @State private var showingWipeAllDataConfirmation = false
    @State private var isWipingAllData = false
    
    enum ImportSource: String, CaseIterable {
        case clients
        case payees
        case services
        case ndisItems
        case invoices
        case sessions
        case allData
        case unknown
        
        var description: String {
            switch self {
            case .clients: return "Clients"
            case .payees: return "Payees"
            case .services: return "Services"
            case .ndisItems: return "NDIS Items"
            case .invoices: return "Invoices"
            case .sessions: return "Sessions"
            case .allData: return "All Data (Export)"
            case .unknown: return "Unknown"
            }
        }
    }
    
    struct ImportResults: Identifiable {
        var id: String { fileName }
        let source: ImportSource
        let successful: Int
        let failed: Int
        let messages: [String]
        let fileName: String
    }
    
    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?
        
        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }
        
        init?(intValue: Int) {
            self.stringValue = "\(intValue)"
            self.intValue = intValue
        }
    }
    
    struct ClientJSON: Codable {
        var fullName: String
        var email: String?
        var phone: String?
        var address: String?
        var addressLine1: String?
        var addressLine2: String?
        var addressCity: String?
        var addressState: String?
        var addressPostalCode: String?
        var city: String?
        var state: String?
        var postalCode: String?
        var zip: String?
        var addressStreet: String?
        var ndisNumber: String?
        var ndis_number: String?
        
        enum CodingKeys: String, CodingKey {
            case fullName = "fullName"
            case email
            case phone
            case address
            case addressLine1 = "address_line_1"
            case addressLine2 = "address_line_2"
            case addressCity = "address_city"
            case addressState = "address_state"
            case addressPostalCode = "address_postal_code"
            case city
            case state
            case postalCode = "postal_code"
            case zip
            case addressStreet = "street"
            case ndisNumber = "ndis_number"
            case ndis_number = "ndis_number_alt"
        }
        
        // For backward compatibility
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Handle different client name fields
            if let name = try? container.decode(String.self, forKey: .fullName) {
                self.fullName = name
            } else {
                // Try to decode from alternative fields that might exist in different JSON formats
                let clientNameKey = "clientName"
                let fullNameKey = "full_name"
                let nameKey = "name"
                
                let additionalContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
                
                if let name = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: clientNameKey)!) {
                    self.fullName = name
                } else if let name = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: fullNameKey)!) {
                    self.fullName = name
                } else if let name = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: nameKey)!) {
                    self.fullName = name
                } else {
                    self.fullName = ""
                }
            }
            
            // Standard fields
            self.email = try? container.decode(String.self, forKey: .email)
            self.phone = try? container.decode(String.self, forKey: .phone)
            self.address = try? container.decode(String.self, forKey: .address)
            
            // Address components
            self.addressLine1 = try? container.decode(String.self, forKey: .addressLine1)
            self.addressLine2 = try? container.decode(String.self, forKey: .addressLine2)
            self.addressCity = try? container.decode(String.self, forKey: .addressCity)
            self.addressState = try? container.decode(String.self, forKey: .addressState)
            self.addressPostalCode = try? container.decode(String.self, forKey: .addressPostalCode)
            
            // Alternative address fields
            self.city = try? container.decode(String.self, forKey: .city)
            self.state = try? container.decode(String.self, forKey: .state)
            self.postalCode = try? container.decode(String.self, forKey: .postalCode)
            self.zip = try? container.decode(String.self, forKey: .zip)
            self.addressStreet = try? container.decode(String.self, forKey: .addressStreet)
            
            // NDIS number fields
            self.ndisNumber = try? container.decode(String.self, forKey: .ndisNumber)
            self.ndis_number = try? container.decode(String.self, forKey: .ndis_number)
            
            // Check for alternative fields using dynamic keys
            let additionalContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
            
            // Try additional address fields that might be present
            if self.addressLine1 == nil {
                self.addressLine1 = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "addressLine1")!)
            }
            if self.addressCity == nil && self.city == nil {
                self.city = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "city")!)
            }
            if self.addressState == nil && self.state == nil {
                self.state = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "state")!)
            }
            if self.addressPostalCode == nil && self.postalCode == nil && self.zip == nil {
                self.zip = try? additionalContainer.decode(String.self, forKey: DynamicCodingKeys(stringValue: "zipCode")!)
            }
        }
        
        // Custom initializer for direct creation
        init(fullName: String, 
             email: String? = nil, 
             phone: String? = nil, 
             address: String? = nil,
             addressLine1: String? = nil, 
             addressLine2: String? = nil, 
             addressCity: String? = nil, 
             addressState: String? = nil, 
             addressPostalCode: String? = nil, 
             city: String? = nil, 
             state: String? = nil, 
             postalCode: String? = nil, 
             zip: String? = nil, 
             addressStreet: String? = nil, 
             ndisNumber: String? = nil, 
             ndis_number: String? = nil) {
            
            self.fullName = fullName
            self.email = email
            self.phone = phone
            self.address = address
            self.addressLine1 = addressLine1
            self.addressLine2 = addressLine2
            self.addressCity = addressCity
            self.addressState = addressState
            self.addressPostalCode = addressPostalCode
            self.city = city
            self.state = state
            self.postalCode = postalCode
            self.zip = zip
            self.addressStreet = addressStreet
            self.ndisNumber = ndisNumber
            self.ndis_number = ndis_number
        }
    }
    
    struct PayeeJSON: Codable {
        let payeeName: String
        let email: String?
        let phone: String?
        let address: String?
        let bankAccount: String?
        let bankBSB: String?
        let status: String?
        let relationToClient: String?
    }
    
    struct ServiceJSON: Codable {
        var name: String
        var description: String
        var unit: String
        var rate: String?
        var rateValue: Double?
        var ndisCode: String?
        
        enum CodingKeys: String, CodingKey {
            case name
            case description
            case unit
            case rate
            case rateValue = "rate_value"
            case ndisCode = "ndis_code"
        }
    }
    
    struct NDISItemJSON: Codable {
        let itemNumber: String
        let description: String?
        let rate: String?
        let rateValue: Double?
        let unit: String?
        let category: String?
        let status: String?
    }
    
    struct InvoiceJSON: Codable {
        let invoiceNumber: String
        let dateIssued: Date?
        let dateIssuedString: String?
        let dateDue: Date?
        let dateDueString: String?
        let totalAmount: Double?
        let totalAmountString: String?
        let status: String?
        let clientName: String?
        var userData: Any? // To store the original data for later processing
        
        // This property won't be encoded/decoded
        private enum CodingKeys: String, CodingKey {
            case invoiceNumber, dateIssued, dateIssuedString, dateDue, dateDueString
            case totalAmount, totalAmountString, status, clientName
        }
    }
    
    // Break up complex inline expressions to help the SwiftUI type-checker
    private let gridColumns: [GridItem] = [GridItem(.adaptive(minimum: 140), spacing: 8)]

    // Precompute description text to avoid complex inline ternaries
    private var importIntroText: String {
        if selectedImportSource == .ndisItems {
            return "Import NDIS Support Catalogue files from any year (2021-2026+) in JSON, CSV, or Excel (.xlsx) formats. The system automatically detects and maps column variations across different years. Essential columns: Item Number, Item Name, Category, Registration Group, Unit, Quote status, and regional pricing (ACT, NSW, NT, QLD, SA, TAS, VIC, WA, Remote, Very Remote)."
        } else {
            return "Import your data from JSON files or folders. Choose the data type and source."
        }
    }

    // Small view helpers to simplify type-checking
    @ViewBuilder private func ImportSourceGrid() -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
            ForEach(ImportSource.allCases, id: \.self) { source in
                let isSelected = (selectedImportSource == source)
                OptionPillButton(
                    title: source.description,
                    isSelected: isSelected,
                    action: { selectedImportSource = source }
                )
            }
        }
    }

    @ViewBuilder private func ExportSourceGrid() -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
            ForEach(ImportSource.allCases, id: \.self) { source in
                let isSelected = (selectedExportSource == source)
                OptionPillButton(
                    title: source.description,
                    isSelected: isSelected,
                    action: { selectedExportSource = source }
                )
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // --- Import Data Section ---
                SettingsSection(
                    icon: "square.and.arrow.down",
                    title: "Import Data",
                    description: importIntroText
                ) {
                    ImportSourceGrid()
                        .padding(.bottom, 8)
                    HStack {
                        Spacer()
                        Button(action: { showingFileImporter = true }) {
                            Label(selectedImportSource == .ndisItems ? "Import From File" : "Import From JSON", systemImage: "doc.badge.plus")
                        }
                        .appInteractiveCursor()
                        .disabled(isLoading)
                        .buttonStyle(.glassProminent)
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle()) }
                    }
                    if selectedImportSource == .ndisItems {
                        HStack {
                            Spacer()
                            Button(action: importNDISCatalogueFromResources) {
                                Label("Import NDIS Catalogue", systemImage: "arrow.down.doc.fill")
                            }
                            .appInteractiveCursor()
                            .buttonStyle(.glass)
                            .disabled(isLoading || isImportingNDISCatalogue)
                            if isImportingNDISCatalogue { ProgressView().progressViewStyle(CircularProgressViewStyle()) }
                        }
                    }
                    HStack {
                        Spacer()
                        Button(action: { showingBulkImportView = true }) {
                            Label("Bulk Import From Folder", systemImage: "folder")
                        }
                        .appInteractiveCursor()
                        .buttonStyle(.glass)
                    }
                    Divider().padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                    HStack {
                        Spacer()
                        Button(action: importAllJSONData) {
                            Label("Import All JSON Data", systemImage: "tray.and.arrow.down.fill")
                        }
                        .appInteractiveCursor()
                        .buttonStyle(.glassProminent)
                        .disabled(isLoading)
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle()) }
                    }
                    HStack {
                        Spacer()
                        Button(action: { showingAllDataFileImporter = true }) {
                            Label("Smart Import (Auto-Detect)", systemImage: "doc.badge.plus")
                        }
                        .appInteractiveCursor()
                        .buttonStyle(.glassProminent)
                        .disabled(isLoading)
                    }
                    Text("Automatically detects and imports JSON, CSV, or Excel files using the enhanced SwiftData service")
                        .formDescriptionStyle()
                        .padding(.horizontal)
                }
                
                // --- Export Data Section ---
                SettingsSection(
                    icon: "square.and.arrow.up",
                    title: "Export Data",
                    description: "Export your data to JSON files for backup or transfer. Choose the data type to export."
                ) {
                    ExportSourceGrid()
                        .padding(.bottom, 8)
                    HStack {
                        Spacer()
                        Button(action: prepareExport) {
                            Label("Export to JSON", systemImage: "square.and.arrow.up")
                        }
                        .appInteractiveCursor()
                        .disabled(isLoading)
                        .buttonStyle(.glassProminent)
                        if isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle()) }
                    }
                    Divider().padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                    HStack {
                        Spacer()
                        Button(action: exportAllData) {
                            Label("Export ALL Data (JSON)", systemImage: "tray.and.arrow.up.fill")
                        }
                        .appInteractiveCursor()
                        .buttonStyle(.glassProminent)
                    }
                }

                // --- Data Management Section ---
                SettingsSection(
                    icon: "trash.circle",
                    title: "Data Management",
                    description: "Manage your stored data. These operations are permanent and cannot be undone."
                ) {
                    SettingsCard(title: "Update Current Status") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recalculate which NDIS items are current based on the most recent effective date across all items.")
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                        
                        HStack {
                            Spacer()
                            Button(action: updateCurrentStatus) {
                                if isUpdatingCurrentStatus {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Updating...")
                                    }
                                } else {
                                    Label("Update Status", systemImage: "arrow.clockwise")
                                }
                            }
                            .appInteractiveCursor()
                            .disabled(isUpdatingCurrentStatus || isLoading)
                            .buttonStyle(.glass)
                            .tint(.accentColor)
                        }
                    }
                    
                    SettingsCard(title: "Set Current Status by Date") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Select an 'effective from' date to mark all associated NDIS items as current.")
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                            
                            VStack {
                                HStack {
                                    Button("Select All") {
                                        selectedEffectiveDates = Set(availableEffectiveDates)
                                    }
                                    .buttonStyle(LinkButtonStyle())
                                    
                                    Spacer()
                                    
                                    Button("Deselect All") {
                                        selectedEffectiveDates.removeAll()
                                    }
                                    .buttonStyle(LinkButtonStyle())
                                }
                                .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
                                
                                List {
                                    ForEach(availableEffectiveDates, id: \.self) { date in
                                        Button(action: {
                                            if selectedEffectiveDates.contains(date) {
                                                selectedEffectiveDates.remove(date)
                                            } else {
                                                selectedEffectiveDates.insert(date)
                                            }
                                        }) {
                                            HStack {
                                                Text(date, style: .date)
                                                Spacer()
                                                if selectedEffectiveDates.contains(date) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.accentColor)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                                }
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .frame(height: 150)
                                .border(Color.secondary.opacity(0.2), width: 1)
                                .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
                            }
                            
                            HStack {
                                Spacer()
                                Button(action: updateCurrentStatusForSelectedDate) {
                                    if isUpdatingForSelectedDate {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Label("Set Current for \(selectedEffectiveDates.count) Dates", systemImage: "calendar.badge.checkmark")
                                    }
                                }
                                .disabled(selectedEffectiveDates.isEmpty || isUpdatingForSelectedDate)
                                .buttonStyle(.glass)
                                .foregroundColor(.accentColor)
                            }
                        }
                    }
                    
                    SettingsCard(title: "Clear NDIS Items") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Remove all NDIS support items from the database. You can re-import them later if needed.")
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                showingClearNDISConfirmation = true
                            }) {
                                if isClearingNDIS {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Clearing...")
                                    }
                                } else {
                                    Label("Clear All", systemImage: "trash")
                                }
                            }
                            .appInteractiveCursor()
                            .disabled(isClearingNDIS || isLoading)
                            .buttonStyle(.glass)
                            .foregroundColor(.red)
                        }
                    }
                    
                    SettingsCard(title: "Wipe All Data") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Permanently delete ALL data from the database. This includes clients, payees, services, invoices, sessions, and all other entities. This action cannot be undone.")
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        }
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                showingWipeAllDataConfirmation = true
                            }) {
                                if isWipingAllData {
                                    HStack {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                        Text("Wiping...")
                                    }
                                } else {
                                    Label("Wipe All Data", systemImage: "trash.circle.fill")
                                }
                            }
                            .appInteractiveCursor()
                            .disabled(isWipingAllData || isLoading)
                            .buttonStyle(.glass)
                            .foregroundColor(.red)
                        }
                    }
                }
                .onAppear(perform: fetchAvailableEffectiveDates)
                .alert("Update Status", isPresented: $showingUpdateStatusResults, actions: {
                    Button("OK", role: .cancel) { }
                }, message: {
                    Text(updateStatusResults ?? "An unknown error occurred.")
                })

                // --- Import Results Section ---
                if isShowingResults, let results = importResults {
                    SettingsSection(
                        icon: "doc.text.magnifyingglass",
                        title: "Import Results",
                        description: "Results from the most recent import operation"
                    ) {
                        SettingsCard(title: "Summary") {
                            SettingsRow(label: "Source:", labelWidth: maxLabelWidth) { 
                                Text(results.source.description).foregroundColor(Color("TextSecondary", bundle: .sharedUI)) 
                            }
                            SettingsRow(label: "File:", labelWidth: maxLabelWidth) { 
                                Text(results.fileName).foregroundColor(Color("TextSecondary", bundle: .sharedUI)) 
                            }
                            SettingsRow(label: "Successful:", labelWidth: maxLabelWidth) { 
                                Text("\(results.successful)").foregroundColor(.green) 
                            }
                            SettingsRow(label: "Failed:", labelWidth: maxLabelWidth) { 
                                Text("\(results.failed)").foregroundColor(results.failed > 0 ? .red : .secondary) 
                            }
                        }
                        
                        SettingsCard(title: "Details") {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(results.messages.enumerated()), id: \.offset) { index, message in
                                        Text(message).font(.caption).foregroundColor(Color("TextSecondary", bundle: .sharedUI)).padding(.vertical, 2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 150)
                            .border(Color.secondary.opacity(0.2))
                        }
                    }
                }
                }
                .padding(.vertical, StyleGuide.Dimensions.paddingXXLarge)
                .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
        }
#if os(macOS)
        .scrollIndicators(.visible)
#endif
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: selectedImportSource == .ndisItems ? [.json, .commaSeparatedText, UTType(filenameExtension: "xlsx")!] : [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleFileImport(result)
            }
        }
        .fileExporter(
            isPresented: $showingFileExporter,
            document: JSONDocument(jsonData: exportData ?? Data()),
            contentType: .json,
            defaultFilename: exportFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Successfully exported to \(url)")
            case .failure(let error):
                print("Export failed: \(error.localizedDescription)")
            }
        }
        .onAppear {
            if let sourceString = UserDefaults.standard.string(forKey: "lastImportSource"),
               let source = ImportSource(rawValue: sourceString) {
                selectedImportSource = source
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Clear All NDIS Items", isPresented: $showingClearNDISConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllNDISItems()
            }
        } message: {
            Text("This will permanently delete all NDIS items from the database. This action cannot be undone. Are you sure you want to continue?")
        }
        .alert("Wipe All Data", isPresented: $showingWipeAllDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Wipe All Data", role: .destructive) {
                wipeAllData()
            }
        } message: {
            Text("This will permanently delete ALL data from the database including clients, payees, services, invoices, sessions, and all other entities. This action cannot be undone. Are you absolutely sure you want to continue?")
        }
        .alert("Import ALL Data", isPresented: $showingAllDataImportResult, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(allDataImportResult ?? "Unknown result.")
        })
        .fileImporter(
            isPresented: $showingAllDataFileImporter,
            allowedContentTypes: [.json, .commaSeparatedText, UTType(filenameExtension: "xlsx")!],
            allowsMultipleSelection: false
        ) { result in
            handleAllDataFileImport(result)
        }
        .fileExporter(
            isPresented: $showingAllDataFileExporter,
            document: JSONDocument(jsonData: allDataExport ?? Data()),
            contentType: .json,
            defaultFilename: allDataExportFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Successfully exported ALL data to \(url)")
            case .failure(let error):
                print("Export ALL data failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchAvailableEffectiveDates() {
        let fetchDescriptor = FetchDescriptor<NDISItemEntity>(
            sortBy: [SortDescriptor(\.effectiveStartDate, order: .reverse)]
        )
        
        do {
            let items = try viewContext.fetch(fetchDescriptor)
            let dates = items.compactMap { $0.effectiveStartDate }
            
            let uniqueDates = Array(Set(dates.map { Calendar.current.startOfDay(for: $0) })).sorted(by: >)
            
            self.availableEffectiveDates = uniqueDates
            if selectedEffectiveDates.isEmpty {
                if let firstDate = uniqueDates.first {
                    selectedEffectiveDates.insert(firstDate)
                }
            }
        } catch {
            print("Failed to fetch NDIS item effective dates: \(error)")
        }
    }

    private func updateCurrentStatusForSelectedDate() {
        guard !selectedEffectiveDates.isEmpty else { return }
        
        isUpdatingForSelectedDate = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let backgroundContext = ModelContext(viewContext.container)
            
            do {
                let result = try NDISVersioningService.setCurrentStatus(forEffectiveDates: selectedEffectiveDates, in: backgroundContext)
                
                try backgroundContext.save()
                
                DispatchQueue.main.async {
                    do {
                        try viewContext.save()
                        let resultMessage = "Successfully updated status for effective date: \(result.updatedCount) items updated out of \(result.totalCount)."
                        self.updateStatusResults = resultMessage
                        self.showingUpdateStatusResults = true
                        self.isUpdatingForSelectedDate = false
                    } catch {
                        let errorMessage = "Failed to save updates for selected date: \(error.localizedDescription)"
                        self.updateStatusResults = errorMessage
                        self.showingUpdateStatusResults = true
                        self.isUpdatingForSelectedDate = false
                    }
                }
            } catch {
                let errorMessage = "Failed to update status for selected date: \(error.localizedDescription)"
                DispatchQueue.main.async {
                    self.updateStatusResults = errorMessage
                    self.showingUpdateStatusResults = true
                    self.isUpdatingForSelectedDate = false
                }
            }
        }
    }
    
    private func clearAllNDISItems() {
        isClearingNDIS = true

        Task(priority: .userInitiated) {
            do {
                let result = try SettingsDataWiper.wipeNDISItems(using: viewContext.container)
                await MainActor.run {
                    importResults = ImportResults(
                        source: .ndisItems,
                        successful: result.totalDeleted,
                        failed: 0,
                        messages: ["Successfully cleared NDIS data (items: \(result.deletedByEntity["NDISItem"] ?? 0), regional prices: \(result.deletedByEntity["RegionalPrice"] ?? 0))."],
                        fileName: "Database Cleared"
                    )
                    isShowingResults = true
                    isClearingNDIS = false
                }
            } catch {
                await MainActor.run {
                    importResults = ImportResults(
                        source: .ndisItems,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to clear NDIS items: \(error.localizedDescription)"],
                        fileName: "Database Clear Error"
                    )
                    isShowingResults = true
                    isClearingNDIS = false
                }
            }
        }
    }
    
    private func wipeAllData() {
        isWipingAllData = true

        Task(priority: .userInitiated) {
            do {
                let result = try SettingsDataWiper.wipeAll(using: viewContext.container)
                await MainActor.run {
                    let breakdown = result.deletedByEntity
                        .sorted(by: { $0.key < $1.key })
                        .map { "• \($0.key): \($0.value)" }
                        .joined(separator: "\n")
                    var messages = ["Successfully wiped all data from the database."]
                    if !breakdown.isEmpty {
                        messages.append(breakdown)
                    }
                    importResults = ImportResults(
                        source: .unknown,
                        successful: result.totalDeleted,
                        failed: 0,
                        messages: messages,
                        fileName: "Database Wiped"
                    )
                    isShowingResults = true
                    isWipingAllData = false
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    importResults = ImportResults(
                        source: .unknown,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to wipe all data: \(error.localizedDescription)"],
                        fileName: "Database Wipe Error"
                    )
                    isShowingResults = true
                    isWipingAllData = false
                }
            }
        }
    }
    
    private func updateCurrentStatus() {
        isUpdatingCurrentStatus = true
        updateStatusResults = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let backgroundContext = ModelContext(viewContext.container)
            
            do {
                // Use the NDISVersioningService to recalculate current flags
                try NDISVersioningService.recalculateAllCurrentFlags(in: backgroundContext)
                
                // Save the context
                try backgroundContext.save()
                
                // Count how many items are now marked as current
                let currentFetchDescriptor = FetchDescriptor<NDISItemEntity>(
                    predicate: #Predicate<NDISItemEntity> { $0.isCurrent }
                )
                let currentItems = try backgroundContext.fetch(currentFetchDescriptor)
                let currentCount = currentItems.count
                
                // Count total items
                let totalFetchDescriptor = FetchDescriptor<NDISItemEntity>()
                let totalItems = try backgroundContext.fetch(totalFetchDescriptor)
                let totalCount = totalItems.count
                
                // Update the parent context on main thread
                DispatchQueue.main.async {
                    do {
                        try viewContext.save()
                        
                        let resultMessage = "Successfully updated current status: \(currentCount) items marked as current out of \(totalCount) total items."
                        updateStatusResults = resultMessage
                        showingUpdateStatusResults = true
                        isUpdatingCurrentStatus = false
                        
                        // Also show in import results for consistency
                        importResults = ImportResults(
                            source: .ndisItems,
                            successful: currentCount,
                            failed: 0,
                            messages: [resultMessage, "Items with the most recent effective start date are now marked as current."],
                            fileName: "Current Status Update"
                        )
                        isShowingResults = true
                        
                    } catch {
                        // Handle save error on main context
                        let errorMessage = "Failed to save current status updates: \(error.localizedDescription)"
                        updateStatusResults = errorMessage
                        showingUpdateStatusResults = true
                        isUpdatingCurrentStatus = false
                        
                        importResults = ImportResults(
                            source: .ndisItems,
                            successful: 0,
                            failed: 1,
                            messages: [errorMessage],
                            fileName: "Current Status Update Error"
                        )
                        isShowingResults = true
                    }
                }
                
            } catch {
                // Handle recalculation error
                DispatchQueue.main.async {
                    let errorMessage = "Failed to update current status: \(error.localizedDescription)"
                    updateStatusResults = errorMessage
                    showingUpdateStatusResults = true
                    isUpdatingCurrentStatus = false
                    
                    importResults = ImportResults(
                        source: .ndisItems,
                        successful: 0,
                        failed: 1,
                        messages: [errorMessage],
                        fileName: "Current Status Update Error"
                    )
                    isShowingResults = true
                }
            }
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        isLoading = true
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importResults = ImportExportView.ImportResults(
                    source: .unknown,
                    successful: 0,
                    failed: 1,
                    messages: ["No file was selected"],
                    fileName: "none"
                )
                isLoading = false
                return
            }
            
            if selectedImportSource == .ndisItems {
                // SwiftData entities are known at compile time, no need for runtime validation
            }
            
            let fileName = url.lastPathComponent
            
            do {
                let data = try Data(contentsOf: url)
                
                switch selectedImportSource {
                case .clients:
                    importResults = try ClientImport.importClients(data: data, fileName: fileName, context: viewContext)
                case .payees:
                    importResults = try PayeeImport.importPayees(data: data, fileName: fileName, context: viewContext)
                case .services:
                    importResults = try ServiceImport.importServices(data: data, fileName: fileName, context: viewContext)
                case .ndisItems:
                    // Determine import method based on file extension
                    if fileName.lowercased().hasSuffix(".csv") {
                        // Use CSV import method
                        importResults = try NDISItemImport.importNDISItemsFromCSV(url: url, fileName: fileName, context: viewContext)
                    } else if fileName.lowercased().hasSuffix(".xlsx") || fileName.lowercased().hasSuffix(".xls") {
                        // Use Excel import method
                        importResults = try NDISItemImport.importNDISItemsFromExcel(url: url, fileName: fileName, context: viewContext)
                    } else {
                        // Use existing JSON import method
                    importResults = try NDISItemImport.importNDISItems(data: data, fileName: fileName, context: viewContext)
                    }
                case .invoices:
                    importResults = try InvoiceImport.importInvoices(data: data, fileName: fileName, context: viewContext)
                case .sessions:
                    importResults = try SessionImport.importSessions(data: data, fileName: fileName, context: viewContext)
                case .allData:
                    let backgroundContext = ModelContext(viewContext.container)
                    let results = try await AllDataImportService.importAllData(from: data, context: backgroundContext)
                    // Combine all results into a single summary
                    let totalSuccessful = results.reduce(0) { $0 + $1.successful }
                    let totalFailed = results.reduce(0) { $0 + $1.failed }
                    var allMessages: [String] = []
                    
                    for result in results {
                        allMessages.append("=== \(result.source.description) ===")
                        allMessages.append("Successful: \(result.successful), Failed: \(result.failed)")
                        allMessages.append(contentsOf: result.messages)
                        allMessages.append("")
                    }
                    
                    importResults = ImportExportView.ImportResults(
                        source: .allData,
                        successful: totalSuccessful,
                        failed: totalFailed,
                        messages: allMessages,
                        fileName: fileName
                    )
                case .unknown:
                    throw NSError(
                        domain: "ImportError",
                        code: 999,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Cannot import unknown source type"
                        ]
                    )
                }
                
                isShowingResults = true
                
                // Notify other views that data has been imported
                NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                
            } catch {
                print("Error processing file: \(error)")
                importResults = ImportResults(
                    source: selectedImportSource,
                    successful: 0,
                    failed: 1,
                    messages: ["Error processing file: \(error.localizedDescription)"],
                    fileName: fileName
                )
                isShowingResults = true
            }
        case .failure(let error):
            print("Error selecting file: \(error)")
        }
        
        isLoading = false
    }
    
    private func prepareExport() {
        isLoading = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        switch selectedExportSource {
        case .clients:
            exportFileName = "Clients-Export-\(dateString).json"
            exportClients()
        case .payees:
            exportFileName = "Payees-Export-\(dateString).json"
            exportPayees()
        case .services:
            exportFileName = "Services-Export-\(dateString).json"
            exportServices()
        case .ndisItems:
            exportFileName = "NDISItems-Export-\(dateString).json"
            exportNDISItems()
        case .invoices:
            exportFileName = "Invoices-Export-\(dateString).json"
            exportInvoices()
        case .sessions:
            exportFileName = "Sessions-Export-\(dateString).json"
            exportSessions()
        case .allData:
            exportFileName = "AllData-Export-\(dateString).json"
            exportAllData()
        case .unknown:
            exportFileName = "Unknown-Export-\(dateString).json"
            self.exportData = "{}".data(using: .utf8)
            self.showingFileExporter = true
            self.isLoading = false
        }
    }
    
    private func exportClients() {
        Task {
            do {
                let fetchDescriptor = FetchDescriptor<ClientEntity>()
                let clients = try viewContext.fetch(fetchDescriptor)
                
                let clientsJSON = clients.map { client -> ClientJSON in
                    let address = client.address
                    
                    return ClientJSON(
                        fullName: client.fullName,
                        email: client.email,
                        phone: client.phone,
                        address: getAddressString(from: address),
                        addressLine1: address?.streetNumber != nil && address?.streetName != nil ? 
                            "\(address?.streetNumber ?? "") \(address?.streetName ?? "")" : nil,
                        addressLine2: address?.unitNumber,
                        addressCity: address?.suburb,
                        addressState: address?.state,
                        addressPostalCode: address?.postcode,
                        city: address?.suburb,
                        state: address?.state,
                        postalCode: address?.postcode,
                        zip: address?.postcode,
                        addressStreet: address?.streetNumber != nil && address?.streetName != nil ? 
                            "\(address?.streetNumber ?? "") \(address?.streetName ?? "")" : nil,
                        ndisNumber: client.ndisNumber,
                        ndis_number: client.ndisNumber
                    )
                }
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(clientsJSON)
                
                await MainActor.run {
                    self.exportData = jsonData
                    self.showingFileExporter = true
                    self.isLoading = false
                }
            } catch {
                print("Error exporting clients: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func exportPayees() {
        Task {
            do {
                let fetchDescriptor = FetchDescriptor<PayeeEntity>()
                let payees = try viewContext.fetch(fetchDescriptor)
                
                let payeesJSON = payees.map { payee -> PayeeJSON in
                    let bankAccount = getBankAccountNumber(from: payee)
                    let bankBSB = getBankBSB(from: payee)
                    
                    return PayeeJSON(
                        payeeName: payee.fullName,
                        email: payee.email,
                        phone: payee.phone,
                        address: getAddressString(from: payee.address),
                        bankAccount: bankAccount,
                        bankBSB: bankBSB,
                        status: payee.status,
                        relationToClient: payee.relationToClient
                    )
                }
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(payeesJSON)
                
                await MainActor.run {
                    self.exportData = jsonData
                    self.showingFileExporter = true
                    self.isLoading = false
                }
            } catch {
                print("Error exporting payees: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func getBankAccountNumber(from payee: PayeeEntity) -> String? {
        // Since PayeeEntity doesn't have bank account properties in SwiftData,
        // we'll return nil for now. This can be implemented when bank details are added to the model.
        return nil
    }
    
    private func getBankBSB(from payee: PayeeEntity) -> String? {
        // Since PayeeEntity doesn't have bank BSB properties in SwiftData,
        // we'll return nil for now. This can be implemented when bank details are added to the model.
        return nil
    }
    
    private func exportServices() {
        Task {
            do {
                let fetchDescriptor = FetchDescriptor<ClientServiceEntity>()
                let services = try viewContext.fetch(fetchDescriptor)

                let servicesJSON = services.map { service -> ServiceJSON in
                    let formattedRate = service.rate > 0 ? String(format: "%.2f", service.rate) : nil
                    let rateValue = service.rate > 0 ? service.rate : nil
                    return ServiceJSON(
                        name: service.serviceName,
                        description: getDescriptionString(from: service) ?? "",
                        unit: service.unit,
                        rate: formattedRate,
                        rateValue: rateValue,
                        ndisCode: service.ndisCode
                    )
                }
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(servicesJSON)
                
                await MainActor.run {
                    self.exportData = jsonData
                    self.showingFileExporter = true
                    self.isLoading = false
                }
            } catch {
                print("Error exporting services: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func exportNDISItems() {
        Task {
            do {
                let fetchDescriptor = FetchDescriptor<NDISItemEntity>()
                let ndisItems = try viewContext.fetch(fetchDescriptor)
                
                let ndisItemsJSON = ndisItems.map { item -> NDISItemJSON in
                    var primaryRateValue: Double = 0.0
                    var primaryRateString: String = "0.00"

                    if !item.regionalPrices.isEmpty {
                        var foundNational = false
                        for price in item.regionalPrices {
                            if price.regionIdentifier == "NATIONAL" {
                                primaryRateValue = price.amount
                                foundNational = true
                            }
                        }
                        if !foundNational, let first = item.regionalPrices.first {
                            primaryRateValue = first.amount
                        }
                    }
                    primaryRateString = String(format: "%.2f", primaryRateValue)

                    return NDISItemJSON(
                        itemNumber: item.itemNumber,
                        description: item.itemDescription,
                        rate: primaryRateString,
                        rateValue: primaryRateValue,
                        unit: item.unit,
                        category: item.category,
                        status: item.status
                    )
                }
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(ndisItemsJSON)
                
                await MainActor.run {
                    self.exportData = jsonData
                    self.showingFileExporter = true
                    self.isLoading = false
                }
            } catch {
                print("Error exporting NDIS items: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func exportInvoices() {
        Task {
            do {
                let fetchDescriptor = FetchDescriptor<InvoiceEntity>()
                let invoices = try viewContext.fetch(fetchDescriptor)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                let invoicesJSON = invoices.map { invoice -> InvoiceJSON in
                    let dateIssuedString = dateFormatter.string(from: invoice.date)
                    
                    var dateDueString: String? = nil
                    if let dueDate = invoice.dueDate {
                        dateDueString = dateFormatter.string(from: dueDate)
                    }
                    
                    return InvoiceJSON(
                        invoiceNumber: invoice.invoiceNumber,
                        dateIssued: invoice.date,
                        dateIssuedString: dateIssuedString,
                        dateDue: invoice.dueDate,
                        dateDueString: dateDueString,
                        totalAmount: invoice.totalAmount,
                        totalAmountString: String(format: "%.2f", invoice.totalAmount),
                        status: invoice.status?.rawValue,
                        clientName: invoice.clientName ?? invoice.client?.fullName,
                        userData: nil
                    )
                }
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let jsonData = try encoder.encode(invoicesJSON)
                
                await MainActor.run {
                    self.exportData = jsonData
                    self.showingFileExporter = true
                    self.isLoading = false
                }
            } catch {
                print("Error exporting invoices: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func exportSessions() {
        Task {
            do {
                let fetchDescriptor = FetchDescriptor<SessionEntity>()
                let sessions = try viewContext.fetch(fetchDescriptor)
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "HH:mm"
                
                let sessionsJSON = sessions.map { session -> SessionJSON in
                    let dateString = session.startTime != nil ? dateFormatter.string(from: session.startTime!) : ""
                    
                    let startTimeString = session.startTime != nil ? timeFormatter.string(from: session.startTime!) : ""
                    let endTimeString = session.endTime != nil ? timeFormatter.string(from: session.endTime!) : nil
                    
                    return SessionJSON(
                        title: session.title,
                        date: dateString,
                        startTime: startTimeString,
                        endTime: endTimeString,
                        clientName: session.client?.fullName ?? "",
                        location: session.location,
                        notes: session.notes,
                        status: session.status?.rawValue
                    )
                }
                
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                
                do {
                    exportData = try encoder.encode(sessionsJSON)
                    showingFileExporter = true
                } catch {
                    print("Error encoding sessions: \(error)")
                }
            } catch {
                print("Error fetching sessions: \(error)")
            }
            
            isLoading = false
        }
    }
    
    // Compact option pill to avoid wide segmented controls
    private struct OptionPillButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        var body: some View {
            ZStack {
                // The background glass is outside the button so the entire area is clickable
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                Button(action: action) {
                    Text(title)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(true), in: .rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(Rectangle())
            .appInteractiveCursor()
        }
    }

    private func getAddressString(from address: Any?) -> String? {
        if let addressStr = address as? String {
            return addressStr
        } else if let addressEntity = address as? AddressEntity {
            var components: [String] = []
            
            if !addressEntity.unitNumber.isEmpty {
                components.append("Unit \(addressEntity.unitNumber)")
            }
            
            if !addressEntity.streetNumber.isEmpty {
                if !addressEntity.streetName.isEmpty {
                    components.append("\(addressEntity.streetNumber) \(addressEntity.streetName)")
                } else {
                    components.append(addressEntity.streetNumber)
                }
            } else if !addressEntity.streetName.isEmpty {
                components.append(addressEntity.streetName)
            }
            
            if !addressEntity.suburb.isEmpty {
                components.append(addressEntity.suburb)
            }
            
            if !addressEntity.state.isEmpty {
                components.append(addressEntity.state)
            }
            
            if !addressEntity.postcode.isEmpty {
                components.append(addressEntity.postcode)
            }
            
            if !addressEntity.country.isEmpty && addressEntity.country.lowercased() != "australia" {
                components.append(addressEntity.country)
            }
            
            return components.isEmpty ? nil : components.joined(separator: ", ")
        }
        
        return nil
    }
    
    private func getDescriptionString(from service: ClientServiceEntity) -> String? {
        if let description = service.ndisItem?.itemDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !description.isEmpty {
            return description
        }
        if let status = service.status?.trimmingCharacters(in: .whitespacesAndNewlines), !status.isEmpty {
            return status
        }
        return nil
    }
    
    private func importAllJSONData() {
        isLoading = true
        
        Task {
            do {
                let backgroundContext = ModelContext(viewContext.container)
                let results = try await UnifiedImportService.importAllDataInternal(context: backgroundContext)
                
                // Combine all results into a single summary
                let totalSuccessful = results.reduce(0) { $0 + $1.successful }
                let totalFailed = results.reduce(0) { $0 + $1.failed }
                var allMessages: [String] = []
                
                for result in results {
                    allMessages.append("=== \(result.source.description) ===")
                    allMessages.append("Successful: \(result.successful), Failed: \(result.failed)")
                    allMessages.append(contentsOf: result.messages)
                    allMessages.append("")
                }
                
                await MainActor.run {
                    importResults = ImportExportView.ImportResults(
                        source: .unknown,
                        successful: totalSuccessful,
                        failed: totalFailed,
                        messages: allMessages,
                        fileName: "All JSON Files"
                    )
                    isShowingResults = true
                    isLoading = false
                    
                    // Notify other views that data has been imported
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    importResults = ImportExportView.ImportResults(
                        source: .unknown,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to import all JSON data: \(error.localizedDescription)"],
                        fileName: "All JSON Files"
                    )
                    isShowingResults = true
                    isLoading = false
                }
            }
        }
    }
    
    private func importAllDataFromExport() {
        isLoading = true
        
        Task {
            do {
                let backgroundContext = ModelContext(viewContext.container)
                let results = try await UnifiedImportService.importAllDataFromExportInternal(context: backgroundContext)
                
                // Combine all results into a single summary
                let totalSuccessful = results.reduce(0) { $0 + $1.successful }
                let totalFailed = results.reduce(0) { $0 + $1.failed }
                var allMessages: [String] = []
                
                for result in results {
                    allMessages.append("=== \(result.source.description) ===")
                    allMessages.append("Successful: \(result.successful), Failed: \(result.failed)")
                    allMessages.append(contentsOf: result.messages)
                    allMessages.append("")
                }
                
                await MainActor.run {
                    importResults = ImportExportView.ImportResults(
                        source: .allData,
                        successful: totalSuccessful,
                        failed: totalFailed,
                        messages: allMessages,
                        fileName: "AllData-Export"
                    )
                    isShowingResults = true
                    isLoading = false
                    
                    // Notify other views that data has been imported
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    importResults = ImportExportView.ImportResults(
                        source: .allData,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to import AllData-Export: \(error.localizedDescription)"],
                        fileName: "AllData-Export"
                    )
                    isShowingResults = true
                    isLoading = false
                }
            }
        }
    }
    
    private func importNDISCatalogueFromResources() {
        isLoading = true
        
        guard let resourceURL = Bundle.main.url(forResource: "NDIS_Support_Catalogue", withExtension: "json") else {
            importResults = ImportExportView.ImportResults(
                source: .ndisItems,
                successful: 0,
                failed: 1,
                messages: ["NDIS Catalogue file not found in app resources"],
                fileName: "NDIS_Support_Catalogue.json"
            )
            isLoading = false
            isShowingResults = true
            return
        }
        
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent("NDIS_Support_Catalogue_temp.json")
        
        do {
            try? FileManager.default.removeItem(at: tempFileURL)
            
            try FileManager.default.copyItem(at: resourceURL, to: tempFileURL)
            
            let data = try Data(contentsOf: tempFileURL)
            
            // SwiftData entities are known at compile time, no need for runtime validation
            
            importResults = try NDISItemImport.importNDISItems(data: data, fileName: "NDIS_Support_Catalogue.json", context: viewContext)
            isShowingResults = true
            
            // Notify other views that data has been imported
            NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
            
        } catch {
            print("Error importing NDIS catalogue: \(error)")
            importResults = ImportExportView.ImportResults(
                source: .ndisItems,
                successful: 0,
                failed: 1,
                messages: ["Error importing NDIS catalogue: \(error.localizedDescription)"],
                fileName: "NDIS_Support_Catalogue.json"
            )
            isShowingResults = true
        }
        
        isLoading = false
    }
    
    private func exportAllData() {
        isLoading = true
        Task {
            do {
                let (data, filename) = try SwiftDataExportService.exportToFile(context: viewContext, format: .json)
                
                await MainActor.run {
                    self.allDataExport = data
                    self.allDataExportFileName = filename
                    self.showingAllDataFileExporter = true
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.allDataImportResult = "Failed to export all data: \(error.localizedDescription)"
                    self.showingAllDataImportResult = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleAllDataFileImport(_ result: Result<[URL], Error>) {
        isLoading = true
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                allDataImportResult = "No file was selected"
                showingAllDataImportResult = true
                isLoading = false
                return
            }
            
            Task {
                do {
                    // Use AllDataImportService for comprehensive import
                    let data = try Data(contentsOf: url)
                    let backgroundContext = ModelContext(viewContext.container)
                    let results = try await AllDataImportService.importAllData(from: data, context: backgroundContext)
                    
                    // Combine all results into a single summary
                    let totalSuccessful = results.reduce(0) { $0 + $1.successful }
                    let totalFailed = results.reduce(0) { $0 + $1.failed }
                    var allMessages: [String] = []
                    
                    for result in results {
                        allMessages.append("=== \(result.source.description) ===")
                        allMessages.append("Successful: \(result.successful), Failed: \(result.failed)")
                        allMessages.append(contentsOf: result.messages)
                        allMessages.append("")
                    }
                    
                    await MainActor.run {
                        allDataImportResult = "Import completed successfully!\n\nTotal: \(totalSuccessful + totalFailed)\nSuccessful: \(totalSuccessful)\nFailed: \(totalFailed)\n\n\(allMessages.joined(separator: "\n"))"
                        showingAllDataImportResult = true
                        isLoading = false
                        
                        // Notify other views that data has been imported
                        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                    }
                } catch {
                    await MainActor.run {
                        allDataImportResult = "Failed to import file: \(error.localizedDescription)"
                        showingAllDataImportResult = true
                        isLoading = false
                    }
                }
            }
        case .failure(let error):
            allDataImportResult = "Error selecting file: \(error.localizedDescription)"
            showingAllDataImportResult = true
            isLoading = false
        }
    }
}

private enum SettingsDataWiper {
    struct Result {
        let totalDeleted: Int
        let deletedByEntity: [String: Int]
    }

    static func wipeNDISItems(using container: ModelContainer) throws -> Result {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let prices = try deleteAll(of: RegionalPriceEntity.self, in: context)
        let items = try deleteAll(of: NDISItemEntity.self, in: context)
        try saveIfNeeded(context)
        return Result(totalDeleted: prices + items, deletedByEntity: ["RegionalPrice": prices, "NDISItem": items])
    }

    static func wipeAll(using container: ModelContainer) throws -> Result {
        let context = ModelContext(container)
        context.autosaveEnabled = false

        var breakdown: [String: Int] = [:]

        breakdown["CreditHistoryEntry"] = try deleteAll(of: CreditHistoryEntryEntity.self, in: context)
        breakdown["RegionalPrice"] = try deleteAll(of: RegionalPriceEntity.self, in: context)
        breakdown["TravelChargeAuditLog"] = try deleteAll(of: TravelChargeAuditLog.self, in: context)
        breakdown["TravelChargeReviewItem"] = try deleteAll(of: TravelChargeReviewItem.self, in: context)
        breakdown["TravelCharge"] = try deleteAll(of: TravelChargeEntity.self, in: context)
        breakdown["Session"] = try deleteAll(of: SessionEntity.self, in: context)
        breakdown["InvoiceItem"] = try deleteAll(of: InvoiceItemEntity.self, in: context)
        breakdown["Invoice"] = try deleteAll(of: InvoiceEntity.self, in: context)
        breakdown["ClientService"] = try deleteAll(of: ClientServiceEntity.self, in: context)
        breakdown["Client"] = try deleteAll(of: ClientEntity.self, in: context)
        breakdown["Business"] = try deleteAll(of: BusinessEntity.self, in: context)
        breakdown["NDISItem"] = try deleteAll(of: NDISItemEntity.self, in: context)
        breakdown["PlanManager"] = try deleteAll(of: PlanManagerEntity.self, in: context)
        breakdown["Payee"] = try deleteAll(of: PayeeEntity.self, in: context)
        breakdown["Address"] = try deleteAll(of: AddressEntity.self, in: context)

        try saveIfNeeded(context)
        let total = breakdown.values.reduce(0, +)
        return Result(totalDeleted: total, deletedByEntity: breakdown)
    }

    @discardableResult
    private static func deleteAll<T: PersistentModel>(of type: T.Type, in context: ModelContext) throws -> Int {
        let descriptor = FetchDescriptor<T>()
        let models = try context.fetch(descriptor)
        for model in models {
            context.delete(model)
        }
        return models.count
    }

    private static func saveIfNeeded(_ context: ModelContext) throws {
        // `ModelContext` currently saves even when there are no changes, so guard explicitly for clarity.
        if context.hasChanges {
            try context.save()
        }
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    
    var jsonData: Data
    
    init(jsonData: Data) {
        self.jsonData = jsonData
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.jsonData = data
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: jsonData)
    }
}
