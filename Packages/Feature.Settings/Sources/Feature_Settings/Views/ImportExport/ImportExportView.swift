import SwiftUI
import UniformTypeIdentifiers
import Core
import SharedUI

struct ImportExportView: View {
    @State internal var viewModel: ImportExportViewModel
    @State private var activeSheet: ImportExportSheet?

    private enum ImportExportSheet: Identifiable {
        case claimReconciliation
        case importDetails

        var id: Self { self }
    }
    
    public init(viewModel: @autoclosure @escaping () -> ImportExportViewModel) {
        _viewModel = State(initialValue: viewModel())
    }
    
    internal var maxLabelWidth: CGFloat {
        let labels = ["Source:", "File:", "Successful:", "Failed:"]
        return labels.map { $0.width() }.max() ?? 120
    }
    
    private let gridColumns: [GridItem] = [GridItem(.adaptive(minimum: 140), spacing: FormSectionTokens.fieldStackSpacing)]
    
    @ScaledMetric(relativeTo: .body) private var paddingSmall = StyleGuide.Dimensions.paddingSmall
    @ScaledMetric(relativeTo: .body) private var paddingXSmall = StyleGuide.Dimensions.paddingXSmall
    @ScaledMetric(relativeTo: .body) private var cornerRadiusSmall = StyleGuide.Dimensions.cornerRadiusSmall
    @ScaledMetric(relativeTo: .body) private var paddingXXLarge = StyleGuide.Dimensions.paddingXXLarge
    @ScaledMetric(relativeTo: .body) private var paddingXLarge = StyleGuide.Dimensions.paddingXLarge

    // MARK: - Description Helpers

    private var importIntroText: String {
        if viewModel.selectedImportSource == .ndisItems {
            return "Import NDIS Support Catalogue files from any year (2021-2026+) in JSON, CSV, .xls, or Excel (.xlsx) formats. The system automatically detects and maps column variations across different years. Essential columns: Item Number, Item Name, Category, Registration Group, Unit, Quote status, and regional pricing (ACT, NSW, NT, QLD, SA, TAS, VIC, WA, Remote, Very Remote)."
        } else {
            return "Import your data from JSON files or folders. Choose the data type and source."
        }
    }

    // MARK: - View Builders
    
    @ViewBuilder private func ImportSourceGrid() -> some View {
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
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
        LazyVGrid(columns: gridColumns, alignment: .leading, spacing: FormSectionTokens.fieldStackSpacing) {
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

    var body: some View {
        ScrollView {
            VStack(spacing: FormSectionTokens.pageStackSpacing) {
                // --- Import Data Section ---
                SettingsSection(
                    icon: "square.and.arrow.down",
                    title: "Import Data",
                    description: importIntroText
                ) {
                    ImportSourceGrid()
                        .padding(.bottom, StyleGuide.Dimensions.paddingMedium)
                    HStack {
                        Spacer()
                        Button(action: { viewModel.showingFileImporter = true }) {
                            Label(viewModel.selectedImportSource == .ndisItems ? "Import From File" : "Import From JSON", systemImage: "doc.badge.plus")
                        }
                        .pointerStyle(.link)
                        .disabled(viewModel.isLoading)
                        .buttonStyle(.glassProminent)
                    }
                    HStack {
                        Spacer()
                        Button(action: { viewModel.showingBulkImportView = true }) {
                            Label("Bulk Import From Folder", systemImage: "folder")
                        }
                        .pointerStyle(.link)
                        .buttonStyle(.glass)
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
                    Label {
                        Text("Exports include client names, contact details, NDIS service codes, invoice amounts, and other personally identifiable information. Files are saved in plaintext at the path you choose—protect exported files like any sensitive business record.")
                            .font(.caption)
                            .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                    } icon: {
                        Image(systemName: "exclamationmark.shield")
                            .foregroundStyle(.orange)
                    }
                    .padding(.bottom, StyleGuide.Dimensions.paddingSmall)

                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                        Toggle("Encrypt export (AES-GCM)", isOn: $viewModel.exportUseEncryption)
                        if viewModel.exportUseEncryption {
                            SecureField("Passphrase", text: $viewModel.exportPassphrase)
                            SecureField("Confirm passphrase", text: $viewModel.exportPassphraseConfirmation)
                            Text("Encrypted exports use the .invoicing-export container format. Keep your passphrase safe—lost passphrases cannot be recovered.")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                        }
                        if let validationMessage = viewModel.exportEncryptionValidationMessage {
                            Text(validationMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.bottom, StyleGuide.Dimensions.paddingSmall)

                    VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                        Picker("Redaction preset", selection: $viewModel.exportRedactionPreset) {
                            ForEach(ExportRedactionPreset.allCases) { preset in
                                Text(preset.displayName).tag(preset)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(viewModel.exportRedactionPreset.summary)
                            .font(.caption)
                            .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                    }
                    .padding(.bottom, StyleGuide.Dimensions.paddingSmall)

                    ExportSourceGrid()
                        .padding(.bottom, StyleGuide.Dimensions.paddingMedium)
                    HStack {
                        Spacer()
                        Button(action: viewModel.requestPrepareExport) {
                            Label("Export to JSON", systemImage: "square.and.arrow.up")
                        }
                        .pointerStyle(.link)
                        .disabled(viewModel.isLoading)
                        .buttonStyle(.glassProminent)
                    }
                    Divider().padding(.vertical, paddingSmall)
                    HStack {
                        Spacer()
                        Button(action: viewModel.requestExportAllData) {
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
                        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                            Text("Recalculate which NDIS items are current based on the most recent effective date across all items.")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
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
                        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                            Text("Select an 'effective from' date to mark all associated NDIS items as current.")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                            
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
                                .padding(.horizontal, paddingXSmall)
                                
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
                                                        .foregroundStyle(Color.accentColor)
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                                                }
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .frame(height: 150)
                                .border(Color.secondary.opacity(0.2), width: 1)
                                .clipShape(.rect(cornerRadius: cornerRadiusSmall))
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
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    
                    SettingsCard(title: "Clear NDIS Items") {
                        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                            Text("Remove all NDIS support items from the database. You can re-import them later if needed.")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
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
                            .foregroundStyle(ColorSystem.Status.error)
                        }
                    }
                    
                    SettingsCard(title: "Wipe All Data") {
                        VStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                            Text("Permanently delete ALL data from the database. This includes clients, payees, services, invoices, sessions, and all other entities. This action cannot be undone.")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
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
                            .foregroundStyle(ColorSystem.Status.error)
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
                                Text(results.source.description).foregroundStyle(Color("TextSecondary", bundle: .sharedUI)) 
                            }
                            SettingsRow(label: "File:", labelWidth: maxLabelWidth) { 
                                Text(results.fileName).foregroundStyle(Color("TextSecondary", bundle: .sharedUI)) 
                            }
                            SettingsRow(label: "Successful:", labelWidth: maxLabelWidth) { 
                                Text("\(results.successful)").foregroundStyle(ColorSystem.Status.success) 
                            }
                            SettingsRow(label: "Failed:", labelWidth: maxLabelWidth) { 
                                Text("\(results.failed)").foregroundStyle(results.failed > 0 ? .red : .secondary) 
                            }
                        }
                        
                        SettingsCard(title: "Details") {
                            HStack {
                                Text("\(results.messages.count) log messages generated.")
                                    .font(.caption)
                                    .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                                Spacer()
                                Button(action: { activeSheet = .importDetails }) {
                                    Label("View Log Details", systemImage: "doc.plaintext")
                                }
                                .pointerStyle(.link)
                                .buttonStyle(.glass)
                            }
                            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                        }
                    }
                }
            }
            .padding(.vertical, paddingXXLarge)
            .padding(.horizontal, paddingXLarge)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
#if os(macOS)
        .scrollIndicators(.visible)
#endif
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: viewModel.selectedImportSource == .ndisItems
            ? [.json, .commaSeparatedText, UTType(filenameExtension: "xls")!, UTType(filenameExtension: "xlsx")!]
            : [.json],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.handleFileImport(result: result)
            }
        }
        .fileExporter(
            isPresented: $viewModel.showingFileExporter,
            document: JSONDocument(jsonData: viewModel.exportData ?? Data()),
            contentType: viewModel.exportUsesEncryptedContainer
                ? (UTType(filenameExtension: EncryptedExportContainer.fileExtension) ?? .data)
                : .json,
            defaultFilename: viewModel.exportFileName
        ) { _ in }
        .onAppear {
            if let sourceString = UserDefaults.standard.string(forKey: "lastImportSource"),
               let source = Core.ImportSource(rawValue: sourceString) {
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
        .alert(viewModel.pendingExportConsentTitle, isPresented: $viewModel.showingExportConsentAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingExport()
            }
            Button("Export", role: .destructive) {
                viewModel.confirmPendingExport()
            }
        } message: {
            Text(viewModel.pendingExportConsentMessage)
        }
        .alert("Import ALL Data", isPresented: $viewModel.showingAllDataImportResult, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(viewModel.allDataImportResult ?? "Unknown result.")
        })
        .fileImporter(
            isPresented: $viewModel.showingAllDataFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            viewModel.handleAllDataFileImport(result: result)
        }
        .fileExporter(
            isPresented: $viewModel.showingAllDataFileExporter,
            document: JSONDocument(jsonData: viewModel.allDataExport ?? Data()),
            contentType: viewModel.exportUsesEncryptedContainer
                ? (UTType(filenameExtension: EncryptedExportContainer.fileExtension) ?? .data)
                : .json,
            defaultFilename: viewModel.allDataExportFileName
        ) { _ in }
        .fileExporter(
            isPresented: $viewModel.showingClaimCSVExporter,
            document: CSVDocument(csvData: viewModel.claimCSVData ?? Data()),
            contentType: .commaSeparatedText,
            defaultFilename: viewModel.claimCSVFileName
        ) { _ in }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .claimReconciliation:
                claimReconciliationSheetView()
            case .importDetails:
                VStack(alignment: .leading, spacing: FormSectionTokens.formGroupSpacing) {
                    HStack {
                        Text("Import Detailed Log")
                            .font(.headline)
                        Spacer()
                        Button("Close") {
                            activeSheet = nil
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    Divider()

                    ScrollView {
                        if let results = viewModel.importResults {
                            LazyVStack(alignment: .leading, spacing: FormSectionTokens.labelFieldSpacing) {
                                ForEach(Array(results.messages.enumerated()), id: \.offset) { _, message in
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                                        .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text("No details available")
                                .font(.caption)
                                .foregroundStyle(Color("TextSecondary", bundle: .sharedUI))
                                .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                        }
                    }
                    .padding(.horizontal)
                    .frame(minWidth: StyleGuide.Dimensions.settingsSheetStandardMinWidth, minHeight: StyleGuide.Dimensions.settingsSheetStandardMinHeight)
                }
                .presentationDetents([.medium, .large])
            }
        }
        .onChange(of: viewModel.isPresentingClaimReconciliationSheet) { _, isPresented in
            activeSheet = isPresented ? .claimReconciliation : (activeSheet == .claimReconciliation ? nil : activeSheet)
        }
        .loadingOverlay(isLoading: viewModel.isLoading || viewModel.isImportingNDISCatalogue, message: viewModel.isImportingNDISCatalogue ? "Importing Catalogue..." : "Processing data...")
    }
}
