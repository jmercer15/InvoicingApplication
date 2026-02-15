import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Data
import Core
import SharedUI

// Import the Data package types directly to avoid ambiguity if needed,
// but usually import Data is enough.
// We'll rely on Data.ImportResult and Data.ImportSource
typealias DataImportResult = DataLayerImportResult

struct ImportExportView: View {
    @StateObject private var viewModel: ImportExportViewModel
    
    public init(viewModel: @autoclosure @escaping () -> ImportExportViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }
    
    // Better way: use a factory method from assembly in the parent view.
    // Let's adjust the init to be simpler and let the caller provide the viewModel.
    
    private var maxLabelWidth: CGFloat {
        let labels = ["Source:", "File:", "Successful:", "Failed:"]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    private let gridColumns: [GridItem] = [GridItem(.adaptive(minimum: 140), spacing: 8)]
    
    // MARK: - Export Logic

    // Precompute description text to avoid complex inline ternaries
    private var importIntroText: String {
        if viewModel.selectedImportSource == .ndisItems {
            return "Import NDIS Support Catalogue files from any year (2021-2026+) in JSON, CSV, or Excel (.xlsx) formats. The system automatically detects and maps column variations across different years. Essential columns: Item Number, Item Name, Category, Registration Group, Unit, Quote status, and regional pricing (ACT, NSW, NT, QLD, SA, TAS, VIC, WA, Remote, Very Remote)."
        } else {
            return "Import your data from JSON files or folders. Choose the data type and source."
        }
    }

    // Small view helpers to simplify type-checking
    @ViewBuilder private func ImportSourceGrid() -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
            ForEach(ImportSource.allCases, id: \.self) { source in
                let isSelected = (viewModel.selectedImportSource == source)
                OptionPillButton(
                    title: source.description,
                    isSelected: isSelected,
                    action: { viewModel.selectedImportSource = source }
                )
            }
        }
    }

    @ViewBuilder private func ExportSourceGrid() -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
            ForEach(ImportSource.allCases, id: \.self) { source in
                let isSelected = (viewModel.selectedExportSource == source)
                OptionPillButton(
                    title: source.description,
                    isSelected: isSelected,
                    action: { viewModel.selectedExportSource = source }
                )
            }
        }
    }

    @ViewBuilder private func claimsExportSection() -> some View {
        if viewModel.claimsExportEnabled {
            SettingsSection(
                icon: "list.bullet.rectangle.portrait",
                title: "NDIS Claims Export",
                description: "Create, validate, preview, and export NDIS claim batches as CSV."
            ) {
                SettingsCard(title: "Batch Setup") {
                    HStack(spacing: 16) {
                        DatePicker("From", selection: $viewModel.claimFromDate, displayedComponents: .date)
                        DatePicker("To", selection: $viewModel.claimToDate, displayedComponents: .date)
                    }

                    Toggle("Include Travel Claims", isOn: $viewModel.includeTravelClaims)
                    Toggle("Include Cancellation Claims", isOn: $viewModel.includeCancellationClaims)

                    Picker("Claim Reference", selection: $viewModel.claimReferenceStrategy) {
                        Text("Invoice Number").tag("invoice_number")
                        Text("Invoice Item ID").tag("invoice_item_id")
                        Text("Session ID").tag("session_id")
                    }
                    .pickerStyle(.menu)
                }

                SettingsCard(title: "Actions") {
                    HStack {
                        Button("Create Batch") {
                            viewModel.createClaimBatch()
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(viewModel.isLoading)

                        Button("Validate Batch") {
                            viewModel.validateClaimBatch()
                        }
                        .buttonStyle(.glass)
                        .disabled(viewModel.claimBatch == nil || viewModel.isLoading)

                        Button("Preview Rows") {
                            viewModel.previewClaimBatch()
                        }
                        .buttonStyle(.glass)
                        .disabled(viewModel.claimBatch == nil || viewModel.isLoading)

                        Button("Export CSV") {
                            viewModel.exportClaimBatchCSV()
                        }
                        .buttonStyle(.glassProminent)
                        .disabled(!viewModel.canExportClaimCSV || viewModel.isLoading)
                    }
                }

                if let summary = viewModel.claimValidationSummary {
                    Text(summary)
                        .formDescriptionStyle()
                }

                if let message = viewModel.claimExportStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                }

                if let batch = viewModel.claimBatch {
                    SettingsCard(title: "Current Batch") {
                        SettingsRow(label: "Status:", labelWidth: maxLabelWidth) {
                            Text(batch.status)
                        }
                        SettingsRow(label: "Rows:", labelWidth: maxLabelWidth) {
                            Text("\(batch.rowCount)")
                        }
                        SettingsRow(label: "Errors:", labelWidth: maxLabelWidth) {
                            Text("\(batch.errorCount)")
                                .foregroundColor(batch.errorCount > 0 ? .red : .green)
                        }
                    }
                }

                if !viewModel.claimPreviewLines.isEmpty {
                    SettingsCard(title: "Preview (First 100 Rows)") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(Array(viewModel.claimPreviewLines.enumerated()), id: \.element.id) { index, line in
                                    Text("\(index + 1). \(line.ndisNumber) · \(line.supportNumber) · \(line.unitPrice, specifier: "%.2f") · \(line.isValid ? "valid" : "invalid")")
                                        .font(.caption)
                                        .foregroundColor(line.isValid ? Color("TextSecondary", bundle: .sharedUI) : .red)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 180)
                    }
                }

                claimHistoryCard()
            }
        }
    }

    @ViewBuilder private func claimHistoryCard() -> some View {
        SettingsCard(title: "Batch History") {
            Toggle("Filter by Date", isOn: $viewModel.claimHistoryUseDateFilter)

            if viewModel.claimHistoryUseDateFilter {
                HStack(spacing: 16) {
                    DatePicker("Created From", selection: $viewModel.claimHistoryFromDate, displayedComponents: .date)
                    DatePicker("Created To", selection: $viewModel.claimHistoryToDate, displayedComponents: .date)
                }
            }

            HStack(spacing: 16) {
                Picker("Status", selection: $viewModel.claimHistoryStatusFilter) {
                    Text("All").tag("all")
                    ForEach(viewModel.claimHistoryStatusOptions.filter { $0 != "all" }, id: \.self) { status in
                        Text(status).tag(status)
                    }
                }
                .pickerStyle(.menu)

                Picker("Client", selection: $viewModel.claimHistoryClientFilter) {
                    Text("All Clients").tag("all")
                    ForEach(viewModel.claimHistoryClientOptions) { option in
                        Text(option.displayName).tag(option.id.uuidString)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack {
                Button("Refresh") {
                    viewModel.refreshClaimBatchHistory()
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isRefreshingClaimHistory || viewModel.isLoading)

                Button("Clear Filters") {
                    viewModel.clearClaimHistoryFilters()
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isRefreshingClaimHistory || viewModel.isLoading)
            }

            if let historyMessage = viewModel.claimHistoryStatusMessage {
                Text(historyMessage)
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }

            if viewModel.filteredClaimBatchHistoryRows.isEmpty {
                Text("No batches match the current filters.")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.filteredClaimBatchHistoryRows) { row in
                            claimHistoryRowView(row)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
            }
        }
    }

    @ViewBuilder private func claimHistoryRowView(_ row: ClaimBatchHistoryRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(row.batch.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(row.batch.status)")
                .font(.caption.weight(.semibold))

            Text("Rows \(row.batch.rowCount) · Errors \(row.batch.errorCount)")
                .font(.caption2)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))

            if row.lineCount > 0 {
                Text(row.reconciliationSummary)
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }

            if !row.clientNames.isEmpty {
                Text("Clients: \(row.clientNames.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }

            if let fileName = row.batch.exportFileName {
                Text("File: \(fileName)")
                    .font(.caption2)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }

            if let checksum = row.batch.checksumSHA256 {
                let statusText: String = {
                    if let verified = row.exportHashVerified {
                        return verified ? "verified" : "mismatch"
                    }
                    return "not verified"
                }()
                Text("SHA256: \(checksum) (\(statusText))")
                    .font(.caption2)
                    .foregroundColor(row.exportHashVerified == false ? .red : Color("TextSecondary", bundle: .sharedUI))
            }

            HStack {
                Spacer()
                Button("Reconcile") {
                    viewModel.beginClaimReconciliation(for: row)
                }
                .buttonStyle(.glass)
                .disabled(viewModel.isLoading || viewModel.isApplyingClaimReconciliation || row.lineCount == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    @ViewBuilder private func claimReconciliationSheetView() -> some View {
        NavigationStack {
            Form {
                Section("Batch") {
                    Text(viewModel.claimReconciliationTargetTitle.isEmpty ? "Selected Batch" : viewModel.claimReconciliationTargetTitle)
                        .font(.callout)
                }

                Section("Submission") {
                    Picker("Status", selection: $viewModel.claimReconciliationStatus) {
                        ForEach(viewModel.claimReconciliationStatusOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)

                    TextField("Submission Reference", text: $viewModel.claimReconciliationSubmissionRef)
                        .disableAutocorrection(true)
                }

                Section("Notes") {
                    TextField("Reconciliation notes", text: $viewModel.claimReconciliationNotes, axis: .vertical)
                        .lineLimit(3...8)
                }

                if let message = viewModel.claimReconciliationResultMessage, !message.isEmpty {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Reconcile Batch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelClaimReconciliation()
                    }
                    .disabled(viewModel.isApplyingClaimReconciliation)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isApplyingClaimReconciliation ? "Applying..." : "Apply") {
                        viewModel.applyClaimReconciliation()
                    }
                    .disabled(viewModel.isApplyingClaimReconciliation)
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
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
                        Button(action: { viewModel.showingFileImporter = true }) {
                            Label(viewModel.selectedImportSource == .ndisItems ? "Import From File" : "Import From JSON", systemImage: "doc.badge.plus")
                        }
                        .pointerStyle(.link)
                        .disabled(viewModel.isLoading)
                        .buttonStyle(.glassProminent)
                        if viewModel.isLoading { /* ProgressView handled by overlay */ }
                    }
                    if viewModel.selectedImportSource == .ndisItems {
                        HStack {
                            Spacer()
                        Button(action: viewModel.importNDISCatalogueFromResources) {
                                Label("Import NDIS Catalogue", systemImage: "arrow.down.doc.fill")
                            }
                            .pointerStyle(.link)
                            .buttonStyle(.glass)
                            .disabled(viewModel.isLoading || viewModel.isImportingNDISCatalogue)
                            if viewModel.isImportingNDISCatalogue { /* ProgressView handled by overlay */ }
                        }
                    }
                    HStack {
                        Spacer()
                        Button(action: { viewModel.showingBulkImportView = true }) {
                            Label("Bulk Import From Folder", systemImage: "folder")
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.glass)
                    }
                    Divider().padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                    HStack {
                        Spacer()
                        Button(action: viewModel.importAllJSONData) {
                            Label("Import All JSON Data", systemImage: "tray.and.arrow.down.fill")
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.glassProminent)
                        .disabled(viewModel.isLoading)
                        // ProgressView handled by overlay
                    }
                    HStack {
                        Spacer()
                        Button(action: { viewModel.showingAllDataFileImporter = true }) {
                            Label("Smart Import (Auto-Detect)", systemImage: "doc.badge.plus")
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.glassProminent)
                        .disabled(viewModel.isLoading)
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
                        Button(action: viewModel.prepareExport) {
                            Label("Export to JSON", systemImage: "square.and.arrow.up")
                        }
                        .pointerStyle(.link)
                        .disabled(viewModel.isLoading)
                        .buttonStyle(.glassProminent)
                        if viewModel.isLoading { /* ProgressView handled by overlay */ }
                    }
                    Divider().padding(.vertical, StyleGuide.Dimensions.paddingSmall)
                    HStack {
                        Spacer()
                        Button(action: viewModel.exportAllData) {
                            Label("Export ALL Data (JSON)", systemImage: "tray.and.arrow.up.fill")
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.glassProminent)
                    }
                }

                claimsExportSection()

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
                            Button(action: viewModel.updateCurrentStatus) {
                                if viewModel.isUpdatingCurrentStatus {
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
                            .pointerStyle(.link)
                            .disabled(viewModel.isUpdatingCurrentStatus || viewModel.isLoading)
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
                                        viewModel.selectedEffectiveDates = Set(viewModel.availableEffectiveDates)
                                    }
                                    .buttonStyle(LinkButtonStyle())
                                    
                                    Spacer()
                                    
                                    Button("Deselect All") {
                                        viewModel.selectedEffectiveDates.removeAll()
                                    }
                                    .buttonStyle(LinkButtonStyle())
                                }
                                .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
                                
                                List {
                                    ForEach(viewModel.availableEffectiveDates, id: \.self) { date in
                                        Button(action: {
                                            if viewModel.selectedEffectiveDates.contains(date) {
                                                viewModel.selectedEffectiveDates.remove(date)
                                            } else {
                                                viewModel.selectedEffectiveDates.insert(date)
                                            }
                                        }) {
                                            HStack {
                                                Text(date, style: .date)
                                                Spacer()
                                                if viewModel.selectedEffectiveDates.contains(date) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.accentColor)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                                                }
                                            }
                                            .contentShape(Rectangle())
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
                                Button(action: viewModel.updateCurrentStatusForSelectedDate) {
                                    if viewModel.isUpdatingForSelectedDate {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Label("Set Current for \(viewModel.selectedEffectiveDates.count) Dates", systemImage: "calendar.badge.checkmark")
                                    }
                                }
                                .disabled(viewModel.selectedEffectiveDates.isEmpty || viewModel.isUpdatingForSelectedDate)
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
                                viewModel.showingClearNDISConfirmation = true
                            }) {
                                if viewModel.isClearingNDIS {
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
                            .pointerStyle(.link)
                            .disabled(viewModel.isClearingNDIS || viewModel.isLoading)
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
                                viewModel.showingWipeAllDataConfirmation = true
                            }) {
                                if viewModel.isWipingAllData {
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
                            .pointerStyle(.link)
                            .disabled(viewModel.isWipingAllData || viewModel.isLoading)
                            .buttonStyle(.glass)
                            .foregroundColor(.red)
                        }
                    }
                }
                .alert("Update Status", isPresented: $viewModel.showingUpdateStatusResults, actions: {
                    Button("OK", role: .cancel) { }
                }, message: {
                    Text(viewModel.updateStatusResults ?? "An unknown error occurred.")
                })

                // --- Import Results Section ---
                if viewModel.isShowingResults, let results = viewModel.importResults {
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
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: viewModel.selectedImportSource == .ndisItems ? [.json, .commaSeparatedText, UTType(filenameExtension: "xlsx")!] : [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.handleFileImport(result: result)
            }
        }
        .fileExporter(
            isPresented: $viewModel.showingFileExporter,
            document: JSONDocument(jsonData: viewModel.exportData ?? Data()),
            contentType: .json,
            defaultFilename: viewModel.exportFileName
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
                viewModel.selectedImportSource = source
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Clear All NDIS Items", isPresented: $viewModel.showingClearNDISConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                viewModel.clearAllNDISItems()
            }
        } message: {
            Text("This will permanently delete all NDIS items from the database. This action cannot be undone. Are you sure you want to continue?")
        }
        .alert("Wipe All Data", isPresented: $viewModel.showingWipeAllDataConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Wipe All Data", role: .destructive) {
                viewModel.wipeAllData()
            }
        } message: {
            Text("This will permanently delete ALL data from the database including clients, payees, services, invoices, sessions, and all other entities. This action cannot be undone. Are you absolutely sure you want to continue?")
        }
        .alert("Import ALL Data", isPresented: $viewModel.showingAllDataImportResult, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(viewModel.allDataImportResult ?? "Unknown result.")
        })
        .fileImporter(
            isPresented: $viewModel.showingAllDataFileImporter,
            allowedContentTypes: [.json, .commaSeparatedText, UTType(filenameExtension: "xlsx")!],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleAllDataFileImport(result: result)
        }
        .fileExporter(
            isPresented: $viewModel.showingAllDataFileExporter,
            document: JSONDocument(jsonData: viewModel.allDataExport ?? Data()),
            contentType: .json,
            defaultFilename: viewModel.allDataExportFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Successfully exported ALL data to \(url)")
            case .failure(let error):
                print("Export ALL data failed: \(error.localizedDescription)")
            }
        }
        .fileExporter(
            isPresented: $viewModel.showingClaimCSVExporter,
            document: CSVDocument(csvData: viewModel.claimCSVData ?? Data()),
            contentType: .commaSeparatedText,
            defaultFilename: viewModel.claimCSVFileName
        ) { result in
            switch result {
            case .success(let url):
                print("Successfully exported claims CSV to \(url)")
            case .failure(let error):
                print("Claims CSV export failed: \(error.localizedDescription)")
            }
        }
        .sheet(isPresented: $viewModel.isPresentingClaimReconciliationSheet) {
            claimReconciliationSheetView()
        }
        .loadingOverlay(isLoading: viewModel.isLoading || viewModel.isImportingNDISCatalogue, message: viewModel.isImportingNDISCatalogue ? "Importing Catalogue..." : "Processing data...")
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
                    .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
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
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .pointerStyle(.link)
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

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var csvData: Data

    init(csvData: Data) {
        self.csvData = csvData
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.csvData = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: csvData)
    }
}
