import SwiftUI
import SwiftData
import Core
import PersistenceModels
import UniformTypeIdentifiers
import os

extension ImportExportViewModel {

    public var canExportClaimCSV: Bool {
        guard let claimBatch else { return false }
        return claimBatch.rowCount > 0 && claimBatch.errorCount == 0
    }

    public var claimHistoryStatusOptions: [String] {
        ["all"] + BulkClaimBatchStatus.allCases.map(\.rawValue)
    }

    public var claimHistoryClientOptions: [ClaimHistoryClientOption] {
        var clientNameById: [UUID: String] = [:]
        for row in claimBatchHistoryRows {
            for (clientId, clientName) in zip(row.clientIds, row.clientNames) {
                clientNameById[clientId] = clientName
            }
        }
        return clientNameById
            .map { ClaimHistoryClientOption(id: $0.key, displayName: $0.value) }
            .sorted { lhs, rhs in
                lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
    }

    public var filteredClaimBatchHistoryRows: [ClaimBatchHistoryRow] {
        let dateBounds: (from: Date, to: Date)? = claimHistoryUseDateFilter
            ? (startOfDay(claimHistoryFromDate), endOfDay(claimHistoryToDate))
            : nil
        let statusFilter = claimHistoryStatusFilter == "all" ? nil : claimHistoryStatusFilter
        let clientIdFilter = claimHistoryClientFilter == "all" ? nil : UUID(uuidString: claimHistoryClientFilter)

        return claimBatchHistoryRows.filter { row in
            if let dateBounds {
                guard row.batch.createdAt >= dateBounds.from && row.batch.createdAt <= dateBounds.to else {
                    return false
                }
            }
            if let statusFilter {
                guard row.batch.status == statusFilter else { return false }
            }
            if let clientIdFilter {
                guard row.clientIds.contains(clientIdFilter) else { return false }
            }
            return true
        }
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
                let updatedCount = try await importExportCoordinator.applyClaimReconciliation(
                    batchId: batchId,
                    submissionStatus: submissionStatus,
                    submissionRef: claimReconciliationSubmissionRef.isEmpty ? nil : claimReconciliationSubmissionRef,
                    notes: claimReconciliationNotes.isEmpty ? nil : claimReconciliationNotes
                )

                if claimBatch?.id == batchId {
                    let refreshedLines = try fetchBulkClaimLineEntities(batchId: batchId)
                    await MainActor.run {
                        self.claimPreviewLines = Array(refreshedLines.prefix(100))
                    }
                }

                await MainActor.run {
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

        let batches = fetchClaimHistoryBatches().map { BulkClaimBatchSnapshot($0) }
        let allLines = fetchClaimHistoryLines().map { BulkClaimLineSnapshot($0) }
        
        let clients = fetchClaimHistoryClients()
        var clientNames: [UUID: String] = [:]
        for c in clients {
            clientNames[c.id] = c.fullName
        }

        let invoices = fetchClaimHistoryInvoices()
        var invoiceClientIds: [UUID: UUID] = [:]
        for inv in invoices {
            if let clientId = inv.clientId {
                invoiceClientIds[inv.id] = clientId
            }
        }

        let hashVerifier = bulkClaimExportHashVerifier

        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let rows = ImportExportClaimBatchHistory.buildRows(
                batches: batches,
                allLines: allLines,
                clientNames: clientNames,
                invoiceClientIds: invoiceClientIds,
                exportHashVerifier: hashVerifier
            )

            self.claimBatchHistoryRows = rows
            self.claimHistoryStatusMessage = rows.isEmpty
                ? "No batches found."
                : "Loaded \(rows.count) batch(es)."
            self.isRefreshingClaimHistory = false
        }
    }

    public func clearClaimHistoryFilters() {
        claimHistoryUseDateFilter = false
        claimHistoryFromDate = Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date()
        claimHistoryToDate = Date()
        claimHistoryStatusFilter = "all"
        claimHistoryClientFilter = "all"
    }

    public func createClaimBatch() {
        isLoading = true
        claimExportStatusMessage = nil

        Task(priority: .userInitiated) { @MainActor in
            do {
                let result = try await importExportCoordinator.createClaimBatch(
                    fromDate: startOfDay(claimFromDate),
                    toDate: endOfDay(claimToDate),
                    includeTravel: includeTravelClaims,
                    includeCancellations: includeCancellationClaims,
                    claimReferenceStrategy: claimReferenceStrategy
                )
                let batch = try fetchClaimBatch(by: result.batchId)
                logBatchValidationSummary(
                    action: "create_batch",
                    batchId: batch.id,
                    summary: result.summary
                )
                let previewLines = try fetchBulkClaimLineEntities(batchId: batch.id)
                self.claimBatch = batch
                self.claimPreviewLines = Array(previewLines.prefix(100))
                self.claimValidationSummary = formatClaimSummary(result.summary)
                self.claimExportStatusMessage = "Created batch with \(result.summary.totalRows) row(s)."
                self.isLoading = false
            } catch {
                self.claimExportStatusMessage = "Failed to create claim batch: \(error.localizedDescription)"
                self.isLoading = false
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

        Task(priority: .userInitiated) { @MainActor in
            do {
                let summary = try await importExportCoordinator.validateClaimBatch(batchId: batch.id)
                let existingEntities = try fetchBulkClaimLineEntities(batchId: batch.id)
                let refreshedBatch = try fetchClaimBatch(by: batch.id)
                self.claimBatch = refreshedBatch
                logBatchValidationSummary(
                    action: "validate_batch",
                    batchId: batch.id,
                    summary: summary
                )
                self.claimPreviewLines = Array(existingEntities.prefix(100))
                self.claimValidationSummary = formatClaimSummary(summary)
                self.claimExportStatusMessage = "Validated batch."
                self.isLoading = false
            } catch {
                self.claimExportStatusMessage = "Failed to validate claim batch: \(error.localizedDescription)"
                self.isLoading = false
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
                let lines = try fetchBulkClaimLineEntities(batchId: batch.id)
                let summary = try await importExportCoordinator.summarizeClaimBatch(batchId: batch.id)
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
                let summary = try await importExportCoordinator.summarizeClaimBatch(batchId: batch.id)
                if summary.totalRows == 0 {
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
                if summary.invalidRows > 0 {
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
                let preparedExport = try await importExportCoordinator.prepareClaimBatchCSVExport(batchId: batch.id, dateString: nil)
                logBatchValidationSummary(
                    action: "export_batch_prepared",
                    batchId: batch.id,
                    summary: preparedExport.summary
                )
                let refreshedBatch = try fetchClaimBatch(by: batch.id)

                await MainActor.run {
                    self.claimBatch = refreshedBatch
                    self.claimCSVData = preparedExport.data
                    self.claimCSVFileName = preparedExport.fileName
                    self.showingClaimCSVExporter = true
                    self.claimExportStatusMessage = "Prepared CSV export for \(summary.totalRows) row(s)."
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

    func fetchBulkClaimLineEntities(batchId: UUID) throws -> [BulkClaimLine] {
        try claimPersistence.fetchBulkClaimLineEntities(batchId: batchId)
    }

    func fetchClaimBatch(by id: UUID) throws -> BulkClaimBatch {
        try claimPersistence.fetchClaimBatch(by: id)
    }

    func fetchClaimHistoryBatches() -> [BulkClaimBatch] {
        claimPersistence.fetchClaimHistoryBatches()
    }

    func fetchClaimHistoryLines() -> [BulkClaimLine] {
        claimPersistence.fetchClaimHistoryLines()
    }

    func fetchClaimHistoryClients() -> [Client] {
        claimPersistence.fetchClaimHistoryClients()
    }

    func fetchClaimHistoryInvoices() -> [Invoice] {
        claimPersistence.fetchClaimHistoryInvoices()
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
}
