import SwiftUI
import SwiftData
import Data
import Core
import UniformTypeIdentifiers
import os

import struct Data.ImportResult

// Explicitly define ImportResult to use Data's version
// public typealias ImportResult = Data.ImportResult

public struct ClaimHistoryClientOption: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String

    public init(id: UUID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct ClaimBatchHistoryRow: Identifiable, Equatable, Hashable, Sendable {
    public let batch: BulkClaimBatch
    public let clientIds: [UUID]
    public let clientNames: [String]
    public let lineCount: Int
    public let submittedLineCount: Int
    public let reconciledLineCount: Int
    public let exportHashVerified: Bool?

    public var id: UUID { batch.id }
    public var hasReconciliationData: Bool { submittedLineCount > 0 || reconciledLineCount > 0 }
    public var reconciliationSummary: String {
        "Submitted \(submittedLineCount)/\(lineCount) · Reconciled \(reconciledLineCount)/\(lineCount)"
    }

    public init(
        batch: BulkClaimBatch,
        clientIds: [UUID],
        clientNames: [String],
        lineCount: Int,
        submittedLineCount: Int,
        reconciledLineCount: Int,
        exportHashVerified: Bool?
    ) {
        self.batch = batch
        self.clientIds = clientIds
        self.clientNames = clientNames
        self.lineCount = lineCount
        self.submittedLineCount = submittedLineCount
        self.reconciledLineCount = reconciledLineCount
        self.exportHashVerified = exportHashVerified
    }
}

@MainActor
public final class ImportExportViewModel: ObservableObject {
    // MARK: - Dependencies
    private let unitOfWork: UnitOfWorkService
    private let dataImporterActor: DataImporterActor
    private let dataExporterActor: DataExporterActor
    private let bulkClaimBuilderService: BulkClaimBuilderService
    private let bulkClaimValidationService: BulkClaimValidationService
    private let bprCSVWriter: BPRCSVWriter
    private let bulkClaimExportHashVerifier: BulkClaimExportHashVerifier
    private let claimLogger = Logger(subsystem: "com.invoicing.compliance", category: "ClaimsExport")
    
    // MARK: - Published Properties
    @Published public var selectedImportSource: ImportSource = .clients
    @Published public var selectedExportSource: ImportSource = .clients
    @Published public var importResults: ImportResult?
    @Published public var isShowingResults = false
    @Published public var isLoading = false
    @Published public var isImportingNDISCatalogue = false
    @Published public var isClearingNDIS = false
    @Published public var isUpdatingCurrentStatus = false
    @Published public var isUpdatingForSelectedDate = false
    @Published public var isWipingAllData = false
    
    @Published public var availableEffectiveDates: [Date] = []
    @Published public var selectedEffectiveDates: Set<Date> = []
    @Published public var updateStatusResults: String? = nil
    @Published public var showingUpdateStatusResults = false
    
    @Published public var exportData: Data?
    @Published public var exportFileName: String = ""
    @Published public var allDataExport: Data? = nil
    @Published public var allDataExportFileName: String = ""
    @Published public var allDataImportResult: String? = nil
    @Published public var showingAllDataImportResult = false

    // Phase 2: NDIS Claims Export
    @Published public var claimsExportEnabled = true
    @Published public var claimFromDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published public var claimToDate: Date = Date()
    @Published public var includeTravelClaims = true
    @Published public var includeCancellationClaims = true
    @Published public var claimReferenceStrategy = "invoice_number"
    @Published public var claimBatch: BulkClaimBatch?
    @Published public var claimPreviewLines: [BulkClaimLine] = []
    @Published public var claimValidationSummary: String?
    @Published public var claimExportStatusMessage: String?
    @Published public var claimCSVData: Data?
    @Published public var claimCSVFileName: String = ""
    @Published public var isRefreshingClaimHistory = false
    @Published public var claimBatchHistoryRows: [ClaimBatchHistoryRow] = []
    @Published public var filteredClaimBatchHistoryRows: [ClaimBatchHistoryRow] = []
    @Published public var claimHistoryClientOptions: [ClaimHistoryClientOption] = []
    @Published public var claimHistoryStatusMessage: String?
    @Published public var claimHistoryUseDateFilter = false {
        didSet { applyClaimHistoryFilters() }
    }
    @Published public var claimHistoryFromDate: Date = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date() {
        didSet { if claimHistoryUseDateFilter { applyClaimHistoryFilters() } }
    }
    @Published public var claimHistoryToDate: Date = Date() {
        didSet { if claimHistoryUseDateFilter { applyClaimHistoryFilters() } }
    }
    @Published public var claimHistoryStatusFilter: String = "all" {
        didSet { applyClaimHistoryFilters() }
    }
    @Published public var claimHistoryClientFilter: String = "all" {
        didSet { applyClaimHistoryFilters() }
    }
    @Published public var isPresentingClaimReconciliationSheet = false
    @Published public var claimReconciliationTargetBatchId: UUID?
    @Published public var claimReconciliationTargetTitle: String = ""
    @Published public var claimReconciliationStatus: String = BulkClaimSubmissionStatus.reconciled.rawValue
    @Published public var claimReconciliationSubmissionRef: String = ""
    @Published public var claimReconciliationNotes: String = ""
    @Published public var claimReconciliationResultMessage: String?
    @Published public var isApplyingClaimReconciliation = false
    
    // UI selection states for File Importer/Exporter
    @Published public var showingFileImporter = false
    @Published public var showingFileExporter = false
    @Published public var showingBulkImportView = false
    @Published public var showingClearNDISConfirmation = false
    @Published public var showingAllDataFileImporter = false
    @Published public var showingAllDataFileExporter = false
    @Published public var showingWipeAllDataConfirmation = false
    @Published public var showingClaimCSVExporter = false

    public init(
        unitOfWork: UnitOfWorkService,
        dataImporterActor: DataImporterActor,
        dataExporterActor: DataExporterActor
    ) {
        self.unitOfWork = unitOfWork
        self.dataImporterActor = dataImporterActor
        self.dataExporterActor = dataExporterActor
        self.bulkClaimBuilderService = BulkClaimBuilderService(
            invoicesRepository: unitOfWork.invoices,
            sessionsRepository: unitOfWork.sessions,
            businessRepository: unitOfWork.business,
            clientsRepository: unitOfWork.clients,
            serviceAgreementRepository: unitOfWork.serviceAgreements,
            supportLogRepository: unitOfWork.supportLogs
        )
        self.bulkClaimValidationService = BulkClaimValidationService()
        self.bprCSVWriter = BPRCSVWriter()
        self.bulkClaimExportHashVerifier = BulkClaimExportHashVerifier(csvWriter: bprCSVWriter)
        
        // Initial data loading
        Task {
            await fetchAvailableEffectiveDates()
            refreshClaimBatchHistory()
        }
    }
    
    // MARK: - Public Methods
    
    public func fetchAvailableEffectiveDates() async {
        do {
            let uniqueDates = try await dataImporterActor.fetchNDISEffectiveDates()
            availableEffectiveDates = uniqueDates
            if selectedEffectiveDates.isEmpty, let firstDate = uniqueDates.first {
                selectedEffectiveDates.insert(firstDate)
            }
        } catch {
            print("Failed to fetch NDIS item effective dates: \(error)")
        }
    }
    
    public func handleFileImport(result: Result<[URL], Error>) async {
        isLoading = true
        defer { isLoading = false }
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                importResults = ImportResult(
                    source: .unknown,
                    successful: 0,
                    failed: 1,
                    messages: ["No file was selected"],
                    fileName: "none"
                )
                isShowingResults = true
                return
            }
            
            let fileName = url.lastPathComponent
            
            do {
                let data = try Data(contentsOf: url)
                
                switch selectedImportSource {
                case .ndisItems:
                    if fileName.lowercased().hasSuffix(".csv") {
                        importResults = try await dataImporterActor.importNDISItemsFromCSV(url: url, fileName: fileName)
                    } else if fileName.lowercased().hasSuffix(".xlsx") || fileName.lowercased().hasSuffix(".xls") {
                        importResults = try await dataImporterActor.importNDISItemsFromExcel(url: url, fileName: fileName)
                    } else {
                        importResults = try await dataImporterActor.importSpecificData(type: .ndisItems, data: data, fileName: fileName)
                    }
                default:
                    importResults = try await dataImporterActor.importSpecificData(type: selectedImportSource, data: data, fileName: fileName)
                }
                
                isShowingResults = true
                NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                
            } catch {
                print("Error processing file: \(error)")
                importResults = ImportResult(
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
    }
    
    public func importNDISCatalogueFromResources() {
        isImportingNDISCatalogue = true
        
        Task(priority: .userInitiated) {
            do {
                let result = try await dataImporterActor.importAllData()
                await MainActor.run {
                    // Extract NDIS result specifically if possible, or just use the first one
                    if let ndisResult = result.first(where: { $0.source == .ndisItems }) {
                        self.importResults = ndisResult
                    } else if let first = result.first {
                        self.importResults = first
                    }
                    
                    self.isShowingResults = true
                    self.isImportingNDISCatalogue = false
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.importResults = ImportResult(
                        source: .ndisItems,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to import NDIS Catalogue: \(error.localizedDescription)"],
                        fileName: "App Resources"
                    )
                    self.isShowingResults = true
                    self.isImportingNDISCatalogue = false
                }
            }
        }
    }
    
    public func importAllJSONData() {
        isLoading = true
        
        Task(priority: .userInitiated) {
            do {
                let results = try await dataImporterActor.importAllData()
                await MainActor.run {
                    // Create a summary result
                    let totalSuccessful = results.reduce(0) { $0 + $1.successful }
                    let totalFailed = results.reduce(0) { $0 + $1.failed }
                    let allMessages = results.flatMap { $0.messages }
                    
                    self.importResults = ImportResult(
                        source: .allData,
                        successful: totalSuccessful,
                        failed: totalFailed,
                        messages: allMessages,
                        fileName: "Internal Resource Bundle"
                    )
                    self.isShowingResults = true
                    self.isLoading = false
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.importResults = ImportResult(
                        source: .allData,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to import JSON data: \(error.localizedDescription)"],
                        fileName: "Internal Resource Bundle"
                    )
                    self.isShowingResults = true
                    self.isLoading = false
                }
            }
        }
    }
    
    public func handleAllDataFileImport(result: Result<[URL], Error>) {
        isLoading = true
        
        switch result {
        case .success(let urls):
            guard let url = urls.first else {
                isLoading = false
                return
            }
            
            Task(priority: .userInitiated) {
                do {
                    let data = try Data(contentsOf: url)
                    let result = try await dataImporterActor.importSpecificData(type: .allData, data: data, fileName: url.lastPathComponent)
                    
                    await MainActor.run {
                        let totalSuccessful = result.successful
                        let totalFailed = result.failed
                        
                        self.allDataImportResult = "Successfully imported \(totalSuccessful) items. \(totalFailed) items failed."
                        self.showingAllDataImportResult = true
                        self.isLoading = false
                        NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                    }
                } catch {
                    await MainActor.run {
                        self.allDataImportResult = "Import failed: \(error.localizedDescription)"
                        self.showingAllDataImportResult = true
                        self.isLoading = false
                    }
                }
            }
            
        case .failure(let error):
            print("Error selecting file for all data import: \(error)")
            isLoading = false
        }
    }
    
    public func prepareExport() {
        isLoading = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        Task {
            do {
                let data: Data
                switch selectedExportSource {
                case .clients:
                    exportFileName = "Clients-Export-\(dateString).json"
                    data = try await dataExporterActor.exportClients()
                case .payees:
                    exportFileName = "Payees-Export-\(dateString).json"
                    data = try await dataExporterActor.exportPayees()
                case .services:
                    exportFileName = "Services-Export-\(dateString).json"
                    data = try await dataExporterActor.exportServices()
                case .ndisItems:
                    exportFileName = "NDISItems-Export-\(dateString).json"
                    data = try await dataExporterActor.exportNDISItems()
                case .invoices:
                    exportFileName = "Invoices-Export-\(dateString).json"
                    data = try await dataExporterActor.exportInvoices()
                case .sessions:
                    exportFileName = "Sessions-Export-\(dateString).json"
                    data = try await dataExporterActor.exportSessions()
                case .allData:
                    exportFileName = "AllData-Export-\(dateString).json"
                    data = try await dataExporterActor.exportAllEntitiesToJSON()
                default:
                    throw NSError(domain: "ExportError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Unsupported export source"])
                }
                
                await MainActor.run {
                    self.exportData = data
                    self.isLoading = false
                    self.showingFileExporter = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    // Show error in import results for visibility
                    self.importResults = ImportResult(
                        source: selectedExportSource,
                        successful: 0,
                        failed: 1,
                        messages: ["Export failed: \(error.localizedDescription)"],
                        fileName: "Export Process"
                    )
                    self.isShowingResults = true
                }
            }
        }
    }
    
    public func exportAllData() {
        isLoading = true
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = dateFormatter.string(from: Date())
        
        Task {
            do {
                let data = try await dataExporterActor.exportAllEntitiesToJSON()
                await MainActor.run {
                    self.allDataExport = data
                    self.allDataExportFileName = "AllData-Export-\(dateString).json"
                    self.isLoading = false
                    self.showingAllDataFileExporter = true
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.importResults = ImportResult(
                        source: .allData,
                        successful: 0,
                        failed: 1,
                        messages: ["Export ALL data failed: \(error.localizedDescription)"],
                        fileName: "Export Process"
                    )
                    self.isShowingResults = true
                }
            }
        }
    }
    
    public func updateCurrentStatus() {
        isUpdatingCurrentStatus = true
        updateStatusResults = nil
        
        Task {
            do {
                // Use the dataImporterActor or localized logic to recalculate status
                // Since NDISVersioningService.recalculateAllCurrentFlags requires ModelContext,
                // we should expose this through an Actor or perform it internally in unitOfWork if possible.
                // For now, we'll use a detached task with a background context.
                let results = try await Task.detached(priority: .userInitiated) {
                    // Use UnitOfWork repository method for recalculation
                    // We need a new child context or just use the repo if it handles its own context
                    // Since UnitOfWork is an actor or main-actor bound service, accessed via `unitOfWork` which is injected.
                    // However, `unitOfWork` is MainActor isolated.
                    // The view model is MainActor.
                    // We can call `unitOfWork.ndisItems.recalculateAllCurrentFlags()` directly from MainActor task.
                    
                    // Actually, the previous code was running in detached task.
                    // `recalculateAllCurrentFlags` in `NDISItemRepositorySwiftData` uses `MainActor.run`.
                    // So we can just call it from the ViewModel's Task.
                    
                    let count = try await self.unitOfWork.ndisItems.recalculateAllCurrentFlags()
                    let totalCount = try await self.unitOfWork.ndisItems.count()
                    
                    return (currentCount: count, totalCount: totalCount)
                }.value
                
                await MainActor.run {
                    let resultMessage = "Successfully updated current status: \(results.currentCount) items marked as current out of \(results.totalCount) total items."
                    self.updateStatusResults = resultMessage
                    self.showingUpdateStatusResults = true
                    self.isUpdatingCurrentStatus = false
                    
                    self.importResults = ImportResult(
                        source: .ndisItems,
                        successful: results.currentCount,
                        failed: 0,
                        messages: [resultMessage, "Items with the most recent effective start date are now marked as current."],
                        fileName: "Current Status Update"
                    )
                    self.isShowingResults = true
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = "Failed to update current status: \(error.localizedDescription)"
                    self.updateStatusResults = errorMessage
                    self.showingUpdateStatusResults = true
                    self.isUpdatingCurrentStatus = false
                    
                    self.importResults = ImportResult(
                        source: .ndisItems,
                        successful: 0,
                        failed: 1,
                        messages: [errorMessage],
                        fileName: "Current Status Update Error"
                    )
                    self.isShowingResults = true
                }
            }
        }
    }
    
    public func updateCurrentStatusForSelectedDate() {
        guard !selectedEffectiveDates.isEmpty else { return }
        
        isUpdatingForSelectedDate = true
        
        Task {
            do {
                let results = try await Task.detached(priority: .userInitiated) {
                    let count = try await self.unitOfWork.ndisItems.recalculateAllCurrentFlags()
                    let totalCount = try await self.unitOfWork.ndisItems.count()
                    
                    return (updatedCount: count, totalCount: totalCount)
                }.value
                
                await MainActor.run {
                    let resultMessage = "Successfully updated status: \(results.updatedCount) items updated out of \(results.totalCount)."
                    self.updateStatusResults = resultMessage
                    self.showingUpdateStatusResults = true
                    self.isUpdatingForSelectedDate = false
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = "Failed to update status for selected date: \(error.localizedDescription)"
                    self.updateStatusResults = errorMessage
                    self.showingUpdateStatusResults = true
                    self.isUpdatingForSelectedDate = false
                }
            }
        }
    }
    
    public func clearAllNDISItems() {
        isClearingNDIS = true
        
        Task(priority: .userInitiated) {
            do {
                let result = try await unitOfWork.ndisItems.removeAll()
                await MainActor.run {
                    self.importResults = ImportResult(
                        source: .ndisItems,
                        successful: result.deletedItems + result.deletedPrices,
                        failed: 0,
                        messages: ["Successfully cleared NDIS data (items: \(result.deletedItems), regional prices: \(result.deletedPrices))."],
                        fileName: "Database Cleared"
                    )
                    self.isShowingResults = true
                    self.isClearingNDIS = false
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.importResults = ImportResult(
                        source: .ndisItems,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to clear NDIS items: \(error.localizedDescription)"],
                        fileName: "Database Clear Error"
                    )
                    self.isShowingResults = true
                    self.isClearingNDIS = false
                }
            }
        }
    }
    
    public func wipeAllData() {
        isWipingAllData = true
        
        Task(priority: .userInitiated) {
            do {
                let result = try await unitOfWork.wipeAllData()
                await MainActor.run {
                    let breakdown = result.deletedByEntity
                        .sorted(by: { $0.key < $1.key })
                        .map { "• \($0.key): \($0.value)" }
                        .joined(separator: "\n")
                    var messages = ["Successfully wiped all data from the database."]
                    if !breakdown.isEmpty {
                        messages.append(breakdown)
                    }
                    self.importResults = ImportResult(
                        source: .unknown,
                        successful: result.totalDeleted,
                        failed: 0,
                        messages: messages,
                        fileName: "Database Wiped"
                    )
                    self.isShowingResults = true
                    self.isWipingAllData = false
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                }
            } catch {
                await MainActor.run {
                    self.importResults = ImportResult(
                        source: .unknown,
                        successful: 0,
                        failed: 1,
                        messages: ["Failed to wipe all data: \(error.localizedDescription)"],
                        fileName: "Database Wipe Error"
                    )
                    self.isShowingResults = true
                    self.isWipingAllData = false
                }
            }
        }
    }

    public var canExportClaimCSV: Bool {
        guard let claimBatch else { return false }
        return claimBatch.rowCount > 0 && claimBatch.errorCount == 0
    }

    public var claimHistoryStatusOptions: [String] {
        ["all"] + BulkClaimBatchStatus.allCases.map(\.rawValue)
    }

    public var claimReconciliationStatusOptions: [String] {
        BulkClaimSubmissionStatus.allCases.map(\.rawValue)
    }

    public func beginClaimReconciliation(for row: ClaimBatchHistoryRow) {
        claimReconciliationTargetBatchId = row.batch.id
        claimReconciliationTargetTitle = row.batch.exportFileName ?? row.batch.id.uuidString
        claimReconciliationStatus = row.reconciledLineCount == row.lineCount && row.lineCount > 0
            ? BulkClaimSubmissionStatus.reconciled.rawValue
            : BulkClaimSubmissionStatus.submitted.rawValue
        claimReconciliationSubmissionRef = ""
        claimReconciliationNotes = ""
        claimReconciliationResultMessage = nil
        isPresentingClaimReconciliationSheet = true
    }

    public func cancelClaimReconciliation() {
        isPresentingClaimReconciliationSheet = false
        claimReconciliationTargetBatchId = nil
        claimReconciliationTargetTitle = ""
        claimReconciliationResultMessage = nil
        isApplyingClaimReconciliation = false
    }

    public func applyClaimReconciliation() {
        guard let batchId = claimReconciliationTargetBatchId else {
            claimReconciliationResultMessage = "Select a batch before applying reconciliation."
            return
        }
        guard let submissionStatus = BulkClaimSubmissionStatus(rawValue: claimReconciliationStatus) else {
            claimReconciliationResultMessage = "Invalid reconciliation status."
            return
        }

        isApplyingClaimReconciliation = true
        claimReconciliationResultMessage = nil

        Task(priority: .userInitiated) {
            do {
                let reconciledAt = submissionStatus == .reconciled ? Date() : nil
                let updatedCount = try await unitOfWork.bulkClaims.updateBatchLineReconciliation(
                    batchId: batchId,
                    submissionStatus: submissionStatus,
                    submissionRef: claimReconciliationSubmissionRef,
                    reconciliationNotes: claimReconciliationNotes,
                    reconciledAt: reconciledAt
                )

                let historyRows = try await buildClaimBatchHistoryRows()
                if claimBatch?.id == batchId {
                    let refreshedLines = try await unitOfWork.bulkClaims.fetchLines(batchId: batchId)
                    await MainActor.run {
                        self.claimPreviewLines = Array(refreshedLines.prefix(100))
                    }
                }

                await MainActor.run {
                    self.applyClaimHistoryRows(historyRows)
                    self.claimHistoryStatusMessage = "Updated reconciliation on \(updatedCount) line(s)."
                    self.claimReconciliationResultMessage = "Updated \(updatedCount) line(s)."
                    self.isApplyingClaimReconciliation = false
                    self.isPresentingClaimReconciliationSheet = false
                }
            } catch {
                await MainActor.run {
                    self.claimReconciliationResultMessage = "Failed to apply reconciliation: \(error.localizedDescription)"
                    self.isApplyingClaimReconciliation = false
                }
            }
        }
    }

    public func refreshClaimBatchHistory() {
        isRefreshingClaimHistory = true
        claimHistoryStatusMessage = nil

        Task(priority: .userInitiated) {
            do {
                let rows = try await buildClaimBatchHistoryRows()
                await MainActor.run {
                    applyClaimHistoryRows(rows)
                    claimHistoryStatusMessage = rows.isEmpty ? "No batches found." : "Loaded \(rows.count) batch(es)."
                    isRefreshingClaimHistory = false
                }
            } catch {
                await MainActor.run {
                    claimHistoryStatusMessage = "Failed to load history: \(error.localizedDescription)"
                    isRefreshingClaimHistory = false
                }
            }
        }
    }

    public func clearClaimHistoryFilters() {
        claimHistoryUseDateFilter = false
        claimHistoryFromDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        claimHistoryToDate = Date()
        claimHistoryStatusFilter = "all"
        claimHistoryClientFilter = "all"
        applyClaimHistoryFilters()
    }

    public func createClaimBatch() {
        isLoading = true
        claimExportStatusMessage = nil

        Task(priority: .userInitiated) {
            do {
                let batch = BulkClaimBatch(
                    id: UUID(),
                    fromDate: startOfDay(claimFromDate),
                    toDate: endOfDay(claimToDate),
                    includeTravel: includeTravelClaims,
                    includeCancellations: includeCancellationClaims,
                    claimReferenceStrategy: claimReferenceStrategy
                )

                let createdBatch = try await unitOfWork.bulkClaims.createBatch(batch)
                let builtLines = try await bulkClaimBuilderService.buildLines(for: createdBatch)
                let validation = bulkClaimValidationService.validateAndSummarize(lines: builtLines)
                try await unitOfWork.bulkClaims.replaceLines(batchId: createdBatch.id, lines: validation.lines)
                logBatchValidationSummary(
                    action: "create_batch",
                    batchId: createdBatch.id,
                    summary: validation.summary
                )

                let refreshedBatch = try await unitOfWork.bulkClaims.fetchBatch(by: createdBatch.id)
                let historyRows = try await buildClaimBatchHistoryRows()
                await MainActor.run {
                    self.claimBatch = refreshedBatch
                    self.claimPreviewLines = Array(validation.lines.prefix(100))
                    self.claimValidationSummary = formatClaimSummary(validation.summary)
                    self.claimExportStatusMessage = "Created batch with \(validation.summary.totalRows) row(s)."
                    self.applyClaimHistoryRows(historyRows)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.claimExportStatusMessage = "Failed to create claim batch: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    public func validateClaimBatch() {
        guard let batch = claimBatch else {
            claimExportStatusMessage = "Create a batch before validating."
            return
        }

        isLoading = true
        claimExportStatusMessage = nil

        Task(priority: .userInitiated) {
            do {
                let existingLines = try await unitOfWork.bulkClaims.fetchLines(batchId: batch.id)
                let validation = bulkClaimValidationService.validateAndSummarize(lines: existingLines)
                try await unitOfWork.bulkClaims.replaceLines(batchId: batch.id, lines: validation.lines)
                logBatchValidationSummary(
                    action: "validate_batch",
                    batchId: batch.id,
                    summary: validation.summary
                )
                let refreshedBatch = try await unitOfWork.bulkClaims.fetchBatch(by: batch.id)
                let historyRows = try await buildClaimBatchHistoryRows()

                await MainActor.run {
                    self.claimBatch = refreshedBatch
                    self.claimPreviewLines = Array(validation.lines.prefix(100))
                    self.claimValidationSummary = formatClaimSummary(validation.summary)
                    self.claimExportStatusMessage = "Validated batch."
                    self.applyClaimHistoryRows(historyRows)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.claimExportStatusMessage = "Failed to validate claim batch: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    public func previewClaimBatch() {
        guard let batch = claimBatch else {
            claimExportStatusMessage = "Create a batch before previewing."
            return
        }

        isLoading = true
        claimExportStatusMessage = nil

        Task(priority: .userInitiated) {
            do {
                let lines = try await unitOfWork.bulkClaims.fetchLines(batchId: batch.id)
                let summary = bulkClaimValidationService.summarize(lines: lines)
                logBatchValidationSummary(
                    action: "preview_batch",
                    batchId: batch.id,
                    summary: summary
                )

                await MainActor.run {
                    self.claimPreviewLines = Array(lines.prefix(100))
                    self.claimValidationSummary = formatClaimSummary(summary)
                    self.claimExportStatusMessage = "Loaded preview for \(summary.totalRows) row(s)."
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.claimExportStatusMessage = "Failed to preview claim batch: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    public func exportClaimBatchCSV() {
        guard let batch = claimBatch else {
            claimExportStatusMessage = "Create and validate a batch before export."
            return
        }

        isLoading = true
        claimExportStatusMessage = nil

        Task(priority: .userInitiated) {
            do {
                let lines = try await unitOfWork.bulkClaims.fetchLines(batchId: batch.id)
                let summary = bulkClaimValidationService.summarize(lines: lines)
                guard summary.totalRows > 0 else {
                    logBatchValidationSummary(
                        action: "export_batch_blocked_empty",
                        batchId: batch.id,
                        summary: summary
                    )
                    await MainActor.run {
                        self.claimExportStatusMessage = "No rows available to export."
                        self.isLoading = false
                    }
                    return
                }

                guard summary.invalidRows == 0 else {
                    logBatchValidationSummary(
                        action: "export_batch_blocked_invalid_rows",
                        batchId: batch.id,
                        summary: summary
                    )
                    await MainActor.run {
                        self.claimExportStatusMessage = "Export blocked: \(summary.invalidRows) row(s) have validation errors."
                        self.isLoading = false
                    }
                    return
                }

                let csvData = bprCSVWriter.csvData(lines: lines)
                let checksum = bprCSVWriter.sha256Hex(for: csvData)
                guard bulkClaimExportHashVerifier.verify(data: csvData, expectedSHA256: checksum) else {
                    throw NSError(
                        domain: "BulkClaimExport",
                        code: 4001,
                        userInfo: [NSLocalizedDescriptionKey: "Generated export checksum failed local verification."]
                    )
                }
                let fileName = "NDIS-Claims-\(timestampString()).csv"

                try await unitOfWork.bulkClaims.markExported(
                    id: batch.id,
                    fileName: fileName,
                    checksumSHA256: checksum,
                    rowCount: lines.count
                )
                logBatchValidationSummary(
                    action: "export_batch_prepared",
                    batchId: batch.id,
                    summary: summary
                )

                let refreshedBatch = try await unitOfWork.bulkClaims.fetchBatch(by: batch.id)
                let historyRows = try await buildClaimBatchHistoryRows()
                await MainActor.run {
                    self.claimBatch = refreshedBatch
                    self.claimCSVData = csvData
                    self.claimCSVFileName = fileName
                    self.showingClaimCSVExporter = true
                    self.claimExportStatusMessage = "Prepared CSV export for \(lines.count) row(s)."
                    self.applyClaimHistoryRows(historyRows)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.claimExportStatusMessage = "Failed to export claims CSV: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func buildClaimBatchHistoryRows() async throws -> [ClaimBatchHistoryRow] {
        let batches = try await unitOfWork.bulkClaims.fetchBatches()
        guard !batches.isEmpty else { return [] }

        let clients = try await unitOfWork.clients.fetchAll()
        let clientNameById = Dictionary(uniqueKeysWithValues: clients.map { ($0.id, $0.fullName) })

        var invoiceClientCache: [UUID: UUID?] = [:]
        var rows: [ClaimBatchHistoryRow] = []
        rows.reserveCapacity(batches.count)

        for batch in batches {
            let lines = try await unitOfWork.bulkClaims.fetchLines(batchId: batch.id)
            let invoiceIds = Set(lines.compactMap(\.invoiceId))
            var clientIds = Set<UUID>()

            for invoiceId in invoiceIds {
                if let cached = invoiceClientCache[invoiceId] {
                    if let cached {
                        clientIds.insert(cached)
                    }
                    continue
                }

                let invoice = try await unitOfWork.invoices.fetch(by: invoiceId)
                invoiceClientCache[invoiceId] = invoice?.clientId
                if let clientId = invoice?.clientId {
                    clientIds.insert(clientId)
                }
            }

            let sortedClientIds = clientIds.sorted { $0.uuidString < $1.uuidString }
            let clientNames = sortedClientIds.map { clientNameById[$0] ?? $0.uuidString }
            let hashVerified: Bool?
            if let checksum = batch.checksumSHA256, !checksum.isEmpty {
                hashVerified = bulkClaimExportHashVerifier.verify(lines: lines, expectedSHA256: checksum)
            } else {
                hashVerified = nil
            }
            let submittedLineCount = lines.filter { line in
                guard let status = line.submissionStatus else { return false }
                let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                return !normalized.isEmpty && normalized != BulkClaimSubmissionStatus.pending.rawValue
            }.count
            let reconciledLineCount = lines.filter { line in
                line.submissionStatus?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == BulkClaimSubmissionStatus.reconciled.rawValue
            }.count

            rows.append(
                ClaimBatchHistoryRow(
                    batch: batch,
                    clientIds: sortedClientIds,
                    clientNames: clientNames,
                    lineCount: lines.count,
                    submittedLineCount: submittedLineCount,
                    reconciledLineCount: reconciledLineCount,
                    exportHashVerified: hashVerified
                )
            )
        }

        return rows.sorted { $0.batch.createdAt > $1.batch.createdAt }
    }

    private func applyClaimHistoryRows(_ rows: [ClaimBatchHistoryRow]) {
        claimBatchHistoryRows = rows

        var clientNameById: [UUID: String] = [:]
        for row in rows {
            for index in row.clientIds.indices {
                clientNameById[row.clientIds[index]] = row.clientNames[index]
            }
        }
        claimHistoryClientOptions = clientNameById
            .map { ClaimHistoryClientOption(id: $0.key, displayName: $0.value) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        applyClaimHistoryFilters()
    }

    private func applyClaimHistoryFilters() {
        var rows = claimBatchHistoryRows

        if claimHistoryUseDateFilter {
            let from = startOfDay(claimHistoryFromDate)
            let to = endOfDay(claimHistoryToDate)
            rows = rows.filter { row in
                row.batch.createdAt >= from && row.batch.createdAt <= to
            }
        }

        if claimHistoryStatusFilter != "all" {
            rows = rows.filter { $0.batch.status == claimHistoryStatusFilter }
        }

        if claimHistoryClientFilter != "all", let clientId = UUID(uuidString: claimHistoryClientFilter) {
            rows = rows.filter { $0.clientIds.contains(clientId) }
        }

        filteredClaimBatchHistoryRows = rows
    }

    private func formatClaimSummary(_ summary: BulkClaimValidationSummary) -> String {
        "Rows: \(summary.totalRows)  Valid: \(summary.validRows)  Invalid: \(summary.invalidRows)"
    }

    private func logBatchValidationSummary(
        action: String,
        batchId: UUID,
        summary: BulkClaimValidationSummary
    ) {
        claimLogger.info(
            "batch_validation_summary action=\(action, privacy: .public) batch_id=\(batchId.uuidString, privacy: .public) total_rows=\(summary.totalRows, privacy: .public) valid_rows=\(summary.validRows, privacy: .public) invalid_rows=\(summary.invalidRows, privacy: .public)"
        )
    }

    private func startOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func endOfDay(_ date: Date) -> Date {
        let start = Calendar.current.startOfDay(for: date)
        return Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? date
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
