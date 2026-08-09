import SwiftUI
import SwiftData
import DataInterfaces
import Core
import PersistenceModels
import PersistenceModels
import UniformTypeIdentifiers
import os
import Observation

@Observable
@MainActor
public final class ImportExportViewModel {
    public static let claimsExportFeatureFlagKey = "feature.claimsExportEnabled"

    // MARK: - Dependencies
    let claimPersistence: any ImportExportClaimPersisting
    let importExportCoordinator: any ImportExportCoordinating
    let bulkClaimExportHashVerifier: any BulkClaimExportHashVerifying
    let claimLogger = Logger(subsystem: "com.invoicing.compliance", category: "ClaimsExport")
    
    // MARK: - Published Properties
    public var selectedImportSource: Core.ImportSource = .clients
    public var selectedExportSource: Core.ImportSource = .clients
    public var importResults: Core.ImportResult?
    public var isShowingResults = false
    public var isLoading = false
    public var isImportingNDISCatalogue = false
    public var isClearingNDIS = false
    public var isUpdatingCurrentStatus = false
    public var isUpdatingForSelectedDate = false
    public var isWipingAllData = false
    
    public var availableEffectiveDates: [Date] = []
    public var selectedEffectiveDates: Set<Date> = []
    public var updateStatusResults: String? = nil
    public var showingUpdateStatusResults = false
    
    public var exportData: Data?
    public var exportFileName: String = ""
    public var exportRedactionPreset: ExportRedactionPreset = .none
    public var exportUseEncryption = false
    public var exportPassphrase = ""
    public var exportPassphraseConfirmation = ""
    public var exportEncryptionValidationMessage: String?
    public var pendingExportKind: ExportConsentKind?
    public var showingExportConsentAlert = false
    public var allDataExport: Data? = nil
    public var allDataExportFileName: String = ""
    public var allDataImportResult: String? = nil
    public var showingAllDataImportResult = false

    // Phase 2: NDIS Claims Export
    public var claimsExportEnabled: Bool = false
    public var claimFromDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    public var claimToDate: Date = Date()
    public var includeTravelClaims = true
    public var includeCancellationClaims = true
    public var claimReferenceStrategy = "invoice_number"
    public var claimBatch: BulkClaimBatch?
    public var claimPreviewLines: [BulkClaimLine] = []
    public var claimValidationSummary: String?
    public var claimExportStatusMessage: String?
    public var claimCSVData: Data?
    public var claimCSVFileName: String = ""
    public var isRefreshingClaimHistory = false
    public internal(set) var claimBatchHistoryRows: [ClaimBatchHistoryRow] = []
    public var claimHistoryStatusMessage: String?
    public var claimHistoryUseDateFilter = false
    public var claimHistoryFromDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    public var claimHistoryToDate: Date = Date()
    public var claimHistoryStatusFilter: String = "all"
    public var claimHistoryClientFilter: String = "all"
    public var isPresentingClaimReconciliationSheet = false
    public var claimReconciliationTargetBatchId: UUID?
    public var claimReconciliationTargetTitle: String = ""
    public var claimReconciliationStatus: String = BulkClaimSubmissionStatus.reconciled.rawValue
    public var claimReconciliationSubmissionRef: String = ""
    public var claimReconciliationNotes: String = ""
    public var claimReconciliationResultMessage: String?
    public var isApplyingClaimReconciliation = false
    
    // UI selection states for File Importer/Exporter
    public var showingFileImporter = false
    public var showingFileExporter = false
    public var showingBulkImportView = false
    public var showingClearNDISConfirmation = false
    public var showingAllDataFileImporter = false
    public var showingAllDataFileExporter = false
    public var showingWipeAllDataConfirmation = false
    public var showingClaimCSVExporter = false

    public init(
        claimPersistence: any ImportExportClaimPersisting,
        importExportCoordinator: any ImportExportCoordinating,
        bulkClaimExportHashVerifier: any BulkClaimExportHashVerifying
    ) {
        self.claimPersistence = claimPersistence
        self.importExportCoordinator = importExportCoordinator
        self.bulkClaimExportHashVerifier = bulkClaimExportHashVerifier
        self.claimsExportEnabled = UserDefaults.standard.bool(forKey: Self.claimsExportFeatureFlagKey)
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name.NSManagedObjectContextDidSave,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshClaimBatchHistory()
            }
        }

        Task {
            await fetchAvailableEffectiveDates()
        }
        
        self.refreshClaimBatchHistory()
    }

    // MARK: - Public Methods
    
    public func fetchAvailableEffectiveDates() async {
        do {
            let uniqueDates = try await importExportCoordinator.fetchAvailableEffectiveDates()
            availableEffectiveDates = uniqueDates
            if selectedEffectiveDates.isEmpty, let firstDate = uniqueDates.first {
                selectedEffectiveDates.insert(firstDate)
            }
        } catch {
            claimLogger.error("Failed to fetch NDIS item effective dates")
        }
    }
    
    public func handleFileImport(result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                isShowingResults = true
                importResults = ImportExportImportResultMapping.makeFailure(
                    source: .unknown,
                    fileName: "none",
                    message: "No file was selected"
                )
                return
            }

            runTask(\.isLoading) {
                let selectedSource = self.selectedImportSource
                let result = try await self.importExportCoordinator.importFromFile(url: url, source: selectedSource)
                self.importResults = ImportExportImportResultMapping.make(result)
                self.isShowingResults = true
            } onFailure: { error in
                self.claimLogger.error("Import file processing failed")
                self.importResults = ImportExportImportResultMapping.make(
                    from: error,
                    source: self.selectedImportSource,
                    fileName: url.lastPathComponent
                )
                self.isShowingResults = true
            }
        case .failure(let error):
            importResults = ImportExportImportResultMapping.makeFailure(
                source: selectedImportSource,
                fileName: "File selection",
                message: "File selection failed: \(error.localizedDescription)"
            )
            isShowingResults = true
        }
    }
    
    public func handleAllDataFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                isLoading = false
                allDataImportResult = "No file was selected."
                showingAllDataImportResult = true
                isShowingResults = false
                return
            }
            
            runTask(\.isLoading, priority: .userInitiated) {
                let result = try await self.importExportCoordinator.importAllData(url: url)
                
                let mappedResult = ImportExportImportResultMapping.make(result)
                self.importResults = mappedResult
                self.isShowingResults = true
                self.allDataImportResult = mappedResult.messages.isEmpty
                    ? "\(mappedResult.success ? "Successfully imported" : "Import completed") \(mappedResult.successful) items from \(mappedResult.fileName), failed: \(mappedResult.failed)."
                    : mappedResult.messages.joined(separator: "\n")
                self.showingAllDataImportResult = true
            } onFailure: { error in
                let mappedError = ImportExportImportResultMapping.make(
                    from: error,
                    source: .allData,
                    fileName: url.lastPathComponent
                )
                self.importResults = mappedError
                self.isShowingResults = true
                self.allDataImportResult = mappedError.success ? mappedError.messages.joined(separator: "\n") : mappedError.messages.joined(separator: "\n")
                self.showingAllDataImportResult = true
            }
            
        case .failure(let error):
            isLoading = false
            importResults = ImportExportImportResultMapping.makeFailure(
                source: .allData,
                fileName: "File selection",
                message: "Error selecting file for all data import: \(error.localizedDescription)"
            )
            allDataImportResult = "Error selecting file for all data import: \(error.localizedDescription)"
            showingAllDataImportResult = true
        }
    }
    
    public func requestPrepareExport() {
        if ExportSensitivity.requiresConsent(for: selectedExportSource) {
            pendingExportKind = .single(selectedExportSource)
            showingExportConsentAlert = true
            return
        }
        prepareExport()
    }

    public func requestExportAllData() {
        pendingExportKind = .allData
        showingExportConsentAlert = true
    }

    public func confirmPendingExport() {
        guard validateExportEncryption() else { return }
        guard let kind = pendingExportKind else { return }
        pendingExportKind = nil
        switch kind {
        case .single:
            prepareExport()
        case .allData:
            exportAllData()
        }
    }

    public func cancelPendingExport() {
        pendingExportKind = nil
    }

    public var pendingExportConsentTitle: String {
        guard let kind = pendingExportKind else { return "Export data?" }
        return ExportSensitivity.consentTitle(for: kind)
    }

    public var pendingExportConsentMessage: String {
        guard let kind = pendingExportKind else {
            return ExportSensitivity.consentMessage(for: .allData, preset: exportRedactionPreset)
        }
        return ExportSensitivity.consentMessage(for: kind, preset: exportRedactionPreset)
    }

    public func prepareExport() {
        guard validateExportEncryption() else { return }
        runTask(\.isLoading) {
            let result = try await self.importExportCoordinator.export(
                source: self.selectedExportSource,
                redaction: self.exportRedactionPreset,
                dateString: nil,
                encryption: self.resolvedExportEncryption()
            )
            self.exportData = result.data
            self.exportFileName = result.fileName
            self.showingFileExporter = true
        } onFailure: { error in
            self.importResults = ImportExportImportResultMapping.makeFailure(
                source: self.selectedExportSource,
                fileName: "Export Process",
                message: "Export failed: \(error.localizedDescription)"
            )
            self.isShowingResults = true
        }
    }
    
    public func exportAllData() {
        guard validateExportEncryption() else { return }
        runTask(\.isLoading) {
            let result = try await self.importExportCoordinator.exportAllData(
                redaction: self.exportRedactionPreset,
                dateString: nil,
                encryption: self.resolvedExportEncryption()
            )
            self.allDataExport = result.data
            self.allDataExportFileName = result.fileName
            self.showingAllDataFileExporter = true
        } onFailure: { error in
            self.importResults = ImportExportImportResultMapping.makeFailure(
                source: .allData,
                fileName: "Export Process",
                message: "Export ALL data failed: \(error.localizedDescription)"
            )
            self.isShowingResults = true
        }
    }
    
    public func updateCurrentStatus() {
        runTask(\.isUpdatingCurrentStatus) {
            self.updateStatusResults = nil
            let result = try await self.importExportCoordinator.recalculateCurrentStatus()
            let count = result.updated
            let totalCount = result.total
            let resultMessage = "Successfully updated current status: \(count) items marked as current out of \(totalCount) total items."
            self.updateStatusResults = resultMessage
            self.showingUpdateStatusResults = true
            self.importResults = ImportExportImportResultMapping.make(
                sourceRawValue: Core.ImportSource.ndisItems.rawValue,
                successful: count,
                failed: 0,
                messages: [resultMessage, "Items with the most recent effective start date are now marked as current."],
                fileName: "Current Status Update"
            )
            self.isShowingResults = true
        } onFailure: { error in
            let errorMessage = "Failed to update current status: \(error.localizedDescription)"
            self.updateStatusResults = errorMessage
            self.showingUpdateStatusResults = true
            self.importResults = ImportExportImportResultMapping.makeFailure(
                source: .ndisItems,
                fileName: "Current Status Update Error",
                message: errorMessage
            )
            self.isShowingResults = true
        }
    }

    public func updateCurrentStatusForSelectedDate() {
        guard !selectedEffectiveDates.isEmpty else { return }
        
        runTask(\.isUpdatingForSelectedDate) {
            let result = try await self.importExportCoordinator.recalculateCurrentStatus()
            let count = result.updated
            let totalCount = result.total
            let resultMessage = "Successfully updated status: \(count) items updated out of \(totalCount)."
            self.updateStatusResults = resultMessage
            self.showingUpdateStatusResults = true
        } onFailure: { error in
            let errorMessage = "Failed to update status for selected date: \(error.localizedDescription)"
            self.updateStatusResults = errorMessage
            self.showingUpdateStatusResults = true
        }
    }

    public func clearAllNDISItems() {
        runTask(\.isClearingNDIS, priority: .userInitiated) {
            let result = try await self.importExportCoordinator.clearAllNDISItems()
            self.importResults = ImportExportImportResultMapping.make(
                sourceRawValue: Core.ImportSource.ndisItems.rawValue,
                successful: result.deletedItems + result.deletedPrices,
                failed: 0,
                messages: ["Successfully cleared NDIS data (items: \(result.deletedItems), regional prices: \(result.deletedPrices))."],
                fileName: "Database Cleared"
            )
            self.isShowingResults = true
        } onFailure: { error in
            self.importResults = ImportExportImportResultMapping.makeFailure(
                source: .ndisItems,
                fileName: "Database Clear Error",
                message: "Failed to clear NDIS items: \(error.localizedDescription)"
            )
            self.isShowingResults = true
        }
    }

    public func wipeAllData() {
        runTask(\.isWipingAllData, priority: .userInitiated) {
            let result = try await self.importExportCoordinator.wipeAllData()
            let breakdown = result.deletedByEntity
                .sorted(by: { $0.key < $1.key })
                .map { "• \($0.key): \($0.value)" }
                .joined(separator: "\n")
            var messages = ["Successfully wiped all data from the database."]
            if !breakdown.isEmpty {
                messages.append(breakdown)
            }
            self.importResults = ImportExportImportResultMapping.make(
                sourceRawValue: Core.ImportSource.unknown.rawValue,
                successful: result.totalDeleted,
                failed: 0,
                messages: messages,
                fileName: "Database Wiped"
            )
            self.isShowingResults = true
        } onFailure: { error in
            self.importResults = ImportExportImportResultMapping.makeFailure(
                source: .unknown,
                fileName: "Database Wipe Error",
                message: "Failed to wipe all data: \(error.localizedDescription)"
            )
            self.isShowingResults = true
        }
    }

    // MARK: - Claims Export & History (moved to ImportExportViewModel+Claims.swift)

    func resolvedExportEncryption() -> ExportEncryptionOptions? {
        guard exportUseEncryption else { return nil }
        return ExportEncryptionOptions(passphrase: exportPassphrase)
    }

    var exportUsesEncryptedContainer: Bool {
        exportUseEncryption
    }

    @discardableResult
    func validateExportEncryption() -> Bool {
        exportEncryptionValidationMessage = nil
        guard exportUseEncryption else { return true }
        guard exportPassphrase.count >= 8 else {
            exportEncryptionValidationMessage = "Passphrase must be at least 8 characters."
            return false
        }
        guard exportPassphrase == exportPassphraseConfirmation else {
            exportEncryptionValidationMessage = "Passphrase and confirmation do not match."
            return false
        }
        return true
    }
    
    private func runTask(
        _ busyFlag: ReferenceWritableKeyPath<ImportExportViewModel, Bool>,
        priority: TaskPriority? = nil,
        execute: @escaping () async throws -> Void,
        onFailure: ((Error) -> Void)? = nil
    ) {
        self[keyPath: busyFlag] = true
        Task(priority: priority) { @MainActor in
            defer { self[keyPath: busyFlag] = false }
            do {
                try await execute()
            } catch {
                onFailure?(error)
            }
        }
    }
}
