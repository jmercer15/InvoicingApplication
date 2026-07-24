//
//  InvoicesView.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers
import InvoiceTableLayoutEditor
import Core
import SharedUI

enum InvoiceBulkActionPhase: Equatable {
    case idle
    case preparing
    case sharing
}

enum InvoiceBulkActionOperation: Equatable {
    case export
    case email
    case delete

    var progressTitle: String {
        switch self {
        case .export: "Exporting PDFs"
        case .email: "Preparing email"
        case .delete: "Deleting invoices"
        }
    }

    var supportsCancellation: Bool {
        self != .delete
    }
}

struct InvoiceBulkActionActivity: Equatable {
    private(set) var phase: InvoiceBulkActionPhase = .idle
    private(set) var operation: InvoiceBulkActionOperation?
    private(set) var completedCount = 0
    private(set) var totalCount = 0

    var isBusy: Bool { phase != .idle }
    var canCancel: Bool {
        phase == .preparing && operation?.supportsCancellation == true
    }

    var progressTitle: String {
        guard let operation else { return "Working" }
        if phase == .sharing { return "Opening email composer" }
        return operation.progressTitle
    }

    @discardableResult
    mutating func begin(_ operation: InvoiceBulkActionOperation, totalCount: Int) -> Bool {
        guard phase == .idle else { return false }
        phase = .preparing
        self.operation = operation
        self.totalCount = max(0, totalCount)
        completedCount = 0
        return true
    }

    mutating func advance() {
        guard phase == .preparing else { return }
        completedCount = min(completedCount + 1, totalCount)
    }

    mutating func beginSharing() {
        guard phase == .preparing else { return }
        phase = .sharing
    }

    mutating func finish() {
        phase = .idle
        operation = nil
        completedCount = 0
        totalCount = 0
    }
}

enum InvoiceMultiSelectExitAction: Equatable {
    case endSelection
    case cancelActivity
    case ignore

    static func resolve(
        isMultiSelectMode: Bool,
        activity: InvoiceBulkActionActivity
    ) -> Self {
        guard isMultiSelectMode else { return .ignore }
        if activity.canCancel { return .cancelActivity }
        if activity.isBusy { return .ignore }
        return .endSelection
    }
}

enum InvoicesListEmptyState: Equatable {
    case content
    case noInvoices
    case noMatches
    case needsRefresh
}

enum InvoicesListEmptyStatePolicy {
    static func resolve(
        totalInvoiceCount: Int,
        filteredCount: Int,
        hasActiveFilters: Bool
    ) -> InvoicesListEmptyState {
        guard totalInvoiceCount > 0 else { return .noInvoices }
        guard filteredCount == 0 else { return .content }
        return hasActiveFilters ? .noMatches : .needsRefresh
    }
}

enum InvoiceDeleteCopy {
    static func title(count: Int) -> String {
        count == 1 ? "Delete Invoice" : "Delete Invoices"
    }

    static func actionTitle(count: Int) -> String {
        count == 1 ? "Delete Invoice" : "Delete \(count) Invoices"
    }

    static func message(count: Int, discardsUnsavedChanges: Bool = false) -> String {
        let noun = count == 1 ? "invoice" : "invoices"
        let draftWarning = discardsUnsavedChanges
            ? " Unsaved changes to the open invoice will also be discarded."
            : ""
        return "Delete \(count) \(noun)? This action cannot be undone.\(draftWarning)"
    }
}

struct InvoiceBulkFailure: Equatable {
    let invoiceNumber: String
    let reason: String
}

struct InvoiceBulkDocumentRequest: Equatable, Sendable {
    let invoiceID: UUID
    let invoiceNumber: String

    init(invoiceID: UUID, invoiceNumber: String) {
        self.invoiceID = invoiceID
        self.invoiceNumber = invoiceNumber
    }

    init(invoice: Invoice) {
        self.init(invoiceID: invoice.id, invoiceNumber: invoice.invoiceNumber)
    }
}

enum InvoiceBulkResultCopy {
    static func message(
        completed: Int,
        action: String,
        failures: [InvoiceBulkFailure]
    ) -> String {
        let completedNoun = completed == 1 ? "invoice" : "invoices"
        guard !failures.isEmpty else {
            return "\(completed) \(completedNoun) \(action) successfully."
        }

        let failedNoun = failures.count == 1 ? "invoice" : "invoices"
        let base = "\(completed) \(completedNoun) \(action); \(failures.count) \(failedNoun) failed."
        let visibleFailures = failures.prefix(3).map { failure in
            "\(failure.invoiceNumber): \(failure.reason)"
        }.joined(separator: "\n")
        let remainingCount = failures.count - min(failures.count, 3)
        let remainder = remainingCount > 0 ? "\nAnd \(remainingCount) more." : ""
        return "\(base)\n\(visibleFailures)\(remainder)"
    }
}

enum InvoiceBulkCancellationCopy {
    static func exportMessage(
        exportedCount: Int,
        processedCount: Int,
        totalCount: Int,
        failures: [InvoiceBulkFailure]
    ) -> String {
        guard processedCount > 0 else {
            return "Export cancelled before any PDFs were created."
        }

        let invoiceNoun = totalCount == 1 ? "invoice" : "invoices"
        let pdfNoun = exportedCount == 1 ? "PDF was" : "PDFs were"
        var message =
            "Export cancelled after processing \(processedCount) of \(totalCount) \(invoiceNoun). "
            + "\(exportedCount) \(pdfNoun) kept."
        if !failures.isEmpty {
            message += "\n\n" + InvoiceBulkResultCopy.message(
                completed: exportedCount,
                action: "exported",
                failures: failures
            )
        }
        return message
    }
}

enum InvoiceEmailCopy {
    static func subject(invoiceNumbers: [String]) -> String {
        let numbers = normalized(invoiceNumbers)
        guard invoiceNumbers.count == 1 else {
            return "\(invoiceNumbers.count) Invoices"
        }
        guard let number = numbers.first else { return "Invoice" }
        return "Invoice \(number)"
    }

    static func body(invoiceNumbers: [String]) -> String {
        let numbers = normalized(invoiceNumbers)
        guard invoiceNumbers.count == 1 else {
            return "Please find attached the selected invoices."
        }
        guard let number = numbers.first else {
            return "Please find attached the invoice."
        }
        return "Please find attached invoice \(number)."
    }

    private static func normalized(_ invoiceNumbers: [String]) -> [String] {
        invoiceNumbers.compactMap { number in
            let trimmed = number.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
}

struct InvoiceEmailAttachmentManifest: Equatable {
    private(set) var invoiceNumbers: [String] = []

    var subject: String {
        InvoiceEmailCopy.subject(invoiceNumbers: invoiceNumbers)
    }

    var body: String {
        InvoiceEmailCopy.body(invoiceNumbers: invoiceNumbers)
    }

    mutating func recordAttachment(invoiceNumber: String) {
        invoiceNumbers.append(invoiceNumber)
    }
}

struct InvoicesView: View {
    @Binding var selectedInvoice: Invoice?
    // Container view model for toolbar actions
    @Bindable var containerViewModel: InvoicesContainerViewModel

    @State private var isMultiSelectMode = false
    @State private var selectedInvoiceIDs: Set<UUID> = []
    @State private var bulkActionActivity = InvoiceBulkActionActivity()
    @State private var bulkActionResult: BulkActionResult?
    @State private var emailShareCoordinator: InvoiceEmailShareCoordinator?
    @State private var bulkExportTask: Task<Void, Never>?
    @State private var bulkEmailPreparationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Add state variables for confirmation dialog
    @State private var deleteBatch: InvoiceDeleteBatch?

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { deleteBatch != nil },
            set: { if !$0 { deleteBatch = nil } }
        )
    }

    private struct InvoiceDeleteBatch: Identifiable {
        let id = UUID()
        let invoiceIDs: Set<UUID>
    }

    private struct BulkActionResult: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    private var isPerformingBulkAction: Bool {
        bulkActionActivity.isBusy
    }

    private let projection: InvoicesListProjection
    private let onSelectionChanged: ((AppSelection?) -> Void)?
    private let onCreateInvoice: @MainActor () -> Void

    // Initializer
    init(selectedInvoice: Binding<Invoice?>,
         projection: InvoicesListProjection,
         containerViewModel: InvoicesContainerViewModel,
         onSelectionChanged: ((AppSelection?) -> Void)? = nil,
         onCreateInvoice: @escaping @MainActor () -> Void
    ) {
        self._selectedInvoice = selectedInvoice
        self.projection = projection
        self.containerViewModel = containerViewModel
        self.onSelectionChanged = onSelectionChanged
        self.onCreateInvoice = onCreateInvoice
    }

    var body: some View {
        VStack(spacing: 0) {
            // Invoice list with real-time filtering
            invoiceList
        }
        .background(Color.clear)
        .onChange(of: selectedInvoice) { _, newInvoice in
            onSelectionChanged?(newInvoice.map { .invoice($0.id) })
        }
        .confirmationDialog(
            InvoiceDeleteCopy.title(count: deleteBatch?.invoiceIDs.count ?? 0),
            isPresented: isDeleteConfirmationPresented,
            presenting: deleteBatch,
            actions: { batch in
                Button(
                    InvoiceDeleteCopy.actionTitle(count: batch.invoiceIDs.count),
                    role: .destructive
                ) {
                    performDeleteInvoices(batch.invoiceIDs)
                }
                Button("Cancel", role: .cancel) {}
            },
            message: { batch in
                Text(InvoiceDeleteCopy.message(
                    count: batch.invoiceIDs.count,
                    discardsUnsavedChanges: discardsOpenDraft(batch)
                ))
            }
        )
        .alert(item: $bulkActionResult) { result in
            Alert(
                title: Text(result.title),
                message: Text(result.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onExitCommand(perform: handleMultiSelectExit)
        .onDisappear {
            bulkExportTask?.cancel()
            bulkExportTask = nil
            bulkEmailPreparationTask?.cancel()
            bulkEmailPreparationTask = nil
        }
        .onChange(of: visibleInvoiceIDs) { _, visibleIDs in
            let prunedSelection = selectedInvoiceIDs.intersection(visibleIDs)
            if prunedSelection != selectedInvoiceIDs {
                selectedInvoiceIDs = prunedSelection
            }
            containerViewModel.reconcileSelection(visibleInvoiceIDs: visibleIDs)
        }
        .onChange(of: selectedInvoiceIDs) { _, newIDs in
            if isMultiSelectMode {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: newIDs.count)
                )
            }
        }
        .onChange(of: isMultiSelectMode) { _, isMulti in
            if isMulti {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.selectionChanged(selectedCount: selectedInvoiceIDs.count)
                )
            }
        }
        .onChange(of: containerViewModel.hasActiveListFilters) { oldValue, newValue in
            if oldValue && !newValue {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.filtersCleared(totalCount: containerViewModel.totalInvoiceCount)
                )
            }
        }
        .onChange(of: projection.filteredInvoices.count) { _, newCount in
            if containerViewModel.hasActiveListFilters {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.filterChanged(
                        filteredCount: newCount,
                        totalCount: containerViewModel.totalInvoiceCount
                    )
                )
            }
        }
        .onChange(of: currentEmptyState) { _, newState in
            if newState == .noMatches || newState == .noInvoices {
                InvoiceAccessibilityAnnouncement.announce(
                    InvoiceAccessibilityAnnouncement.emptyState(state: newState)
                )
            }
        }
        .background(
            Group {
                Button("Delete Selected Invoices", action: deleteSelectedInvoices)
                    .keyboardShortcut(.delete, modifiers: [.command])
                    .disabled(isDeleteShortcutDisabled)
                    .opacity(0)
                    .allowsHitTesting(false)

                Button("Delete Selected Invoices", action: deleteSelectedInvoices)
                    .keyboardShortcut(.delete, modifiers: [])
                    .disabled(isDeleteShortcutDisabled)
                    .opacity(0)
                    .allowsHitTesting(false)
            }
        )
    }

    private var currentEmptyState: InvoicesListEmptyState {
        InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: containerViewModel.totalInvoiceCount,
            filteredCount: projection.filteredInvoices.count,
            hasActiveFilters: containerViewModel.hasActiveListFilters
        )
    }

    public static func canBatchDelete(
        isMultiSelectMode: Bool,
        selectedInvoiceIDs: Set<UUID>,
        selectedInvoiceID: UUID?,
        isPerformingBulkAction: Bool
    ) -> Bool {
        guard !isPerformingBulkAction else { return false }
        if isMultiSelectMode {
            return !selectedInvoiceIDs.isEmpty
        } else {
            return selectedInvoiceID != nil
        }
    }

    private var isDeleteShortcutDisabled: Bool {
        !Self.canBatchDelete(
            isMultiSelectMode: isMultiSelectMode,
            selectedInvoiceIDs: selectedInvoiceIDs,
            selectedInvoiceID: selectedInvoice?.id,
            isPerformingBulkAction: isPerformingBulkAction
        )
    }

    // MARK: - Helper Methods

    // Handle item tap from hierarchical list
    private func handleItemTap(_ item: TreeItem) {
        guard let entityID = item.entityID,
              let uuid = UUID(uuidString: entityID) else { return }

        // Find the invoice by ID
        if let invoice = projection.filteredInvoices.first(where: { $0.id == uuid }) {
            handleInvoiceTap(invoice: invoice)
        }
    }

    // Update the deleteSelectedInvoices function to show confirmation dialog
    private func deleteSelectedInvoices() {
        let targetIDs: Set<UUID>
        if isMultiSelectMode {
            targetIDs = selectedInvoiceIDs
        } else if let singleID = selectedInvoice?.id {
            targetIDs = [singleID]
        } else {
            targetIDs = []
        }
        guard !targetIDs.isEmpty, !isPerformingBulkAction else { return }
        deleteBatch = InvoiceDeleteBatch(invoiceIDs: targetIDs)
    }

    private func discardsOpenDraft(_ batch: InvoiceDeleteBatch) -> Bool {
        guard containerViewModel.editorSession.hasUnsavedChanges,
              let openInvoiceID = containerViewModel.editorSession.selectedInvoiceID
        else { return false }
        return batch.invoiceIDs.contains(openInvoiceID)
    }

    // MARK: - Bulk Operations
    private func bulkExportSelectedInvoices() {
        let requests = selectedDocumentRequests
        guard !requests.isEmpty,
              bulkActionActivity.begin(.export, totalCount: requests.count)
        else { return }

        bulkExportTask = Task { @MainActor in
            defer {
                bulkActionActivity.finish()
                bulkExportTask = nil
            }
            guard let destinationFolder = await InvoiceBulkExportFolderPanel.destination(
                invoiceCount: requests.count
            ), !Task.isCancelled else { return }
            await exportInvoices(requests, to: destinationFolder)
        }
    }

    @MainActor
    private func exportInvoices(
        _ requests: [InvoiceBulkDocumentRequest],
        to destinationFolder: URL
    ) async {
        var exportedURLs: [URL] = []
        var failures: [InvoiceBulkFailure] = []
        var wasCancelled = false
        for request in requests {
            guard !Task.isCancelled else {
                wasCancelled = true
                break
            }
            do {
                let temporaryPDF = try await temporaryPDF(for: request)
                defer { temporaryPDF.discard() }
                try Task.checkCancellation()
                let destination = InvoiceBulkExportNaming.availableDestination(
                    in: destinationFolder,
                    preferredFilename: temporaryPDF.url.lastPathComponent
                )
                try FileManager.default.copyItem(at: temporaryPDF.url, to: destination)
                exportedURLs.append(destination)
            } catch is CancellationError {
                wasCancelled = true
                break
            } catch {
                failures.append(bulkFailure(for: request, error: error))
            }
            bulkActionActivity.advance()
        }

        if !exportedURLs.isEmpty {
            NSWorkspace.shared.activateFileViewerSelecting(exportedURLs)
        }

        if wasCancelled {
            bulkActionResult = BulkActionResult(
                title: "Export Cancelled",
                message: InvoiceBulkCancellationCopy.exportMessage(
                    exportedCount: exportedURLs.count,
                    processedCount: exportedURLs.count + failures.count,
                    totalCount: requests.count,
                    failures: failures
                )
            )
            return
        }

        bulkActionResult = BulkActionResult(
            title: failures.isEmpty ? "Export Complete" : "Export Incomplete",
            message: InvoiceBulkResultCopy.message(
                completed: exportedURLs.count,
                action: "exported",
                failures: failures
            )
        )
    }

    private func bulkEmailSelectedInvoices() {
        let requests = selectedDocumentRequests
        guard !requests.isEmpty,
              bulkActionActivity.begin(.email, totalCount: requests.count)
        else { return }

        bulkEmailPreparationTask = Task { @MainActor in
            var handedOffToSharingService = false
            var temporaryPDFs: [InvoiceTemporaryPDF] = []
            defer {
                if !handedOffToSharingService {
                    temporaryPDFs.forEach { $0.discard() }
                    bulkActionActivity.finish()
                }
                bulkEmailPreparationTask = nil
            }

            var attachmentItems: [Any] = []
            var attachmentManifest = InvoiceEmailAttachmentManifest()
            var attachedCount = 0
            var failures: [InvoiceBulkFailure] = []
            for request in requests {
                guard !Task.isCancelled else { return }
                do {
                    let temporaryPDF = try await temporaryPDF(for: request)
                    temporaryPDFs.append(temporaryPDF)
                    try Task.checkCancellation()
                    attachmentItems.append(temporaryPDF.url as NSURL)
                    attachmentManifest.recordAttachment(invoiceNumber: request.invoiceNumber)
                    attachedCount += 1
                } catch is CancellationError {
                    return
                } catch {
                    failures.append(bulkFailure(for: request, error: error))
                }
                bulkActionActivity.advance()
            }

            guard attachedCount > 0 else {
                bulkActionResult = BulkActionResult(
                    title: "Email Not Created",
                    message: InvoiceBulkResultCopy.message(
                        completed: 0,
                        action: "attached",
                        failures: failures
                    )
                )
                return
            }

            guard let service = NSSharingService(named: .composeEmail) else {
                bulkActionResult = BulkActionResult(
                    title: "Email Unavailable",
                    message: "No email sharing service is configured on this Mac."
                )
                return
            }
            service.subject = attachmentManifest.subject
            let items: [Any] = [
                attachmentManifest.body as NSString
            ] + attachmentItems
            let coordinator = InvoiceEmailShareCoordinator(
                service: service,
                temporaryPDFs: temporaryPDFs
            ) { outcome in
                emailShareCoordinator = nil
                bulkActionActivity.finish()
                switch outcome {
                case .completed:
                    bulkActionResult = BulkActionResult(
                        title: failures.isEmpty ? "Email Shared" : "Email Shared with Missing Attachments",
                        message: InvoiceBulkResultCopy.message(
                            completed: attachedCount,
                            action: "attached",
                            failures: failures
                        )
                    )
                case .cancelled:
                    break
                case .failed(let message):
                    bulkActionResult = BulkActionResult(
                        title: "Email Failed",
                        message: message
                    )
                }
            }
            emailShareCoordinator = coordinator
            bulkActionActivity.beginSharing()
            handedOffToSharingService = true
            coordinator.perform(with: items)
        }
    }

    // Render PDF through table-layout editor's canonical document pipeline.
    private func temporaryPDF(
        for request: InvoiceBulkDocumentRequest
    ) async throws -> InvoiceTemporaryPDF {
        try await containerViewModel.editorSession.temporaryPDF(invoiceID: request.invoiceID)
    }

    private func bulkFailure(
        for request: InvoiceBulkDocumentRequest,
        error: Error
    ) -> InvoiceBulkFailure {
        let number = request.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = InvoiceOperationErrorPresentation.detail(
            for: error,
            fallback: "PDF could not be created. Try again."
        )
        return InvoiceBulkFailure(
            invoiceNumber: number.isEmpty ? "Untitled invoice" : number,
            reason: reason
        )
    }

    // Add handler functions for tap gestures
    private func handleInvoiceTap(invoice: Invoice) {
        if isMultiSelectMode {
            if selectedInvoiceIDs.contains(invoice.id) {
                selectedInvoiceIDs.remove(invoice.id)
            } else {
                selectedInvoiceIDs.insert(invoice.id)
            }
        } else {
            // Normal mode, select the invoice
            withAnimation(
                reduceMotion
                    ? nil
                    : .easeOut(duration: StyleGuide.Animations.durationShort)
            ) {
                containerViewModel.requestSelectInvoice(invoice)
            }
        }
    }

    // Add a function to perform the actual deletion after confirmation
    private func performDeleteInvoices(_ invoiceIDs: Set<UUID>) {
        guard bulkActionActivity.begin(.delete, totalCount: invoiceIDs.count) else { return }
        Task {
            defer {
                bulkActionActivity.finish()
                deleteBatch = nil
            }

            do {
                let count = try await containerViewModel.deleteInvoices(ids: Array(invoiceIDs))
                endMultiSelection()
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
                if count == 0 {
                    bulkActionResult = BulkActionResult(
                        title: "Invoices Already Removed",
                        message: "Selected invoices no longer exist."
                    )
                } else {
                    bulkActionResult = BulkActionResult(
                        title: count == 1 ? "Invoice Deleted" : "Invoices Deleted",
                        message: "Deleted \(count) \(count == 1 ? "invoice" : "invoices")."
                    )
                }
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice data could not be deleted. Try again."
                )
                bulkActionResult = BulkActionResult(
                    title: "Delete Failed",
                    message: "Selected invoices could not be deleted. \(detail)"
                )
            }
        }
    }

    // MARK: - Invoice List
    private var invoiceList: some View {
        VStack(spacing: 0) {
            if containerViewModel.totalInvoiceCount > 0 {
                RevenueAnalyticsSummaryView(summary: containerViewModel.analyticsSummary)
                    .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                    .padding(.top, StyleGuide.Dimensions.paddingSmall)
                listContextBar
            }

            ScrollableInvoicesList(
                totalInvoiceCount: containerViewModel.totalInvoiceCount,
                filteredCount: projection.filteredInvoices.count,
                groupedCount: projection.groupedInvoices.count,
                treeItems: projection.treeItems,
                selectedItemIDs: highlightedTreeItemIDs,
                hasActiveFilters: containerViewModel.hasActiveListFilters,
                activeFilterSummaryText: containerViewModel.activeFilterSummaryText,
                activeFilterTags: containerViewModel.activeFilterTags,
                isRefreshing: containerViewModel.isLoading,
                creationPhase: containerViewModel.invoiceCreationPhase,
                onItemTap: handleItemTap,
                onItemContextMenu: { item in
                    guard let entityID = item.entityID,
                          let uuid = UUID(uuidString: entityID),
                          let invoice = projection.filteredInvoices.first(where: { $0.id == uuid })
                    else { return nil }

                    return AnyView(
                        Group {
                            Button("Duplicate Invoice", systemImage: "doc.on.doc") {
                                duplicateInvoice(invoice)
                            }
                            Button("Export CSV", systemImage: "tablecells") {
                                exportSingleInvoiceCSV(invoice)
                            }
                            Button("Export JSON", systemImage: "arrow.triangle.2.circlepath") {
                                exportSingleInvoiceJSON(invoice)
                            }
                            Divider()
                            Button("Delete Invoice", systemImage: "trash", role: .destructive) {
                                deleteBatch = InvoiceDeleteBatch(invoiceIDs: [invoice.id])
                            }
                        }
                    )
                },
                onCreateInvoice: onCreateInvoice,
                onClearFilters: containerViewModel.clearListFilters,
                onClearFilterTag: { category in containerViewModel.clearFilter(category: category) },
                onRefresh: refreshInvoiceList
            )

            if isMultiSelectMode {
                multiSelectBar
            }
        }
        .background(.clear)
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: StyleGuide.Animations.durationMedium),
            value: isMultiSelectMode
        )
    }

    private var multiSelectBar: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            if isPerformingBulkAction {
                bulkActionProgress
            }

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(isPerformingBulkAction ? bulkActionActivity.progressTitle : "\(selectedInvoiceIDs.count) selected")
                    .foregroundStyle(ColorSystem.Neutral.white)
                    .font(StyleGuide.Typography.bodyMedium)
                    .monospacedDigit()
                Text(multiSelectDetailText)
                    .foregroundStyle(ColorSystem.Neutral.white.opacity(0.8))
                    .font(StyleGuide.Typography.caption)
                    .lineLimit(1)
            }

            Spacer(minLength: StyleGuide.Dimensions.paddingSmall)

            Button(allVisibleInvoicesSelected ? "Clear Selection" : "Select All") {
                if allVisibleInvoicesSelected {
                    selectedInvoiceIDs.removeAll()
                } else {
                    selectedInvoiceIDs = visibleInvoiceIDs
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(ColorSystem.Neutral.white)
            .disabled(isPerformingBulkAction)
            .help(allVisibleInvoicesSelected ? "Clear invoice selection" : "Select all visible invoices")

            Menu("Actions", systemImage: "ellipsis.circle") {
                Button("Export PDFs", systemImage: "square.and.arrow.up", action: bulkExportSelectedInvoices)
                Button("Export CSV", systemImage: "tablecells", action: bulkExportCSVSelectedInvoices)
                Button("Export JSON", systemImage: "arrow.triangle.2.circlepath", action: bulkExportJSONSelectedInvoices)
                Button("Email Selected", systemImage: "envelope", action: bulkEmailSelectedInvoices)

                Divider()

                Button("Delete Selected", systemImage: "trash", role: .destructive) {
                    deleteSelectedInvoices()
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedInvoiceIDs.isEmpty || isPerformingBulkAction)

            if bulkActionActivity.canCancel {
                Button("Cancel") {
                    cancelActiveBulkAction()
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                .help("Cancel \(bulkActionActivity.progressTitle.lowercased())")
            } else {
                Button("Done") {
                    endMultiSelection()
                }
                .buttonStyle(.bordered)
                .disabled(isPerformingBulkAction)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(StyleGuide.Dimensions.paddingMedium)
        .glassEffect(
            .regular.interactive(true),
            in: .rect(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium)
        )
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
    }

    @ViewBuilder
    private var bulkActionProgress: some View {
        if bulkActionActivity.phase == .preparing,
           bulkActionActivity.totalCount > 0,
           bulkActionActivity.operation != .delete {
            ProgressView(
                value: Double(bulkActionActivity.completedCount),
                total: Double(bulkActionActivity.totalCount)
            )
            .progressViewStyle(.circular)
            .controlSize(.small)
            .accessibilityLabel(bulkActionActivity.progressTitle)
            .accessibilityValue(
                "\(bulkActionActivity.completedCount) of \(bulkActionActivity.totalCount)"
            )
        } else {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel(bulkActionActivity.progressTitle)
        }
    }

    private func endMultiSelection() {
        withAnimation(
            reduceMotion
                ? nil
                : .easeInOut(duration: StyleGuide.Animations.durationMedium)
        ) {
            isMultiSelectMode = false
            selectedInvoiceIDs.removeAll()
        }
    }

    private var multiSelectDetailText: String {
        if bulkActionActivity.phase == .preparing,
           bulkActionActivity.totalCount > 0,
           bulkActionActivity.operation != .delete {
            return "\(bulkActionActivity.completedCount) of \(bulkActionActivity.totalCount) prepared"
        }
        if bulkActionActivity.phase == .sharing {
            return "Complete or cancel sharing in Mail"
        }
        if bulkActionActivity.operation == .delete {
            return "Removing selected invoices"
        }
        return selectedInvoiceIDs.isEmpty
            ? "Click invoices to select them"
            : "Choose an action or keep selecting"
    }

    private func cancelActiveBulkAction() {
        guard bulkActionActivity.canCancel else { return }
        switch bulkActionActivity.operation {
        case .export:
            bulkExportTask?.cancel()
        case .email:
            bulkEmailPreparationTask?.cancel()
        case .delete, .none:
            break
        }
    }

    private func handleMultiSelectExit() {
        switch InvoiceMultiSelectExitAction.resolve(
            isMultiSelectMode: isMultiSelectMode,
            activity: bulkActionActivity
        ) {
        case .endSelection:
            endMultiSelection()
        case .cancelActivity:
            cancelActiveBulkAction()
        case .ignore:
            break
        }
    }

    private var listContextBar: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Text(resultSummary)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .monospacedDigit()

            if selectedInvoiceIsHiddenByFilters {
                Label("Selected invoice hidden", systemImage: "eye.slash")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(.orange)
                    .help("Current invoice remains open but is hidden by list filters")
            }

            Spacer()

            if selectedInvoiceIsHiddenByFilters {
                Button("Reveal Selected", systemImage: "eye") {
                    containerViewModel.clearListFilters()
                }
                .buttonStyle(.borderless)
                .help("Clear filters and reveal current invoice")
            } else if containerViewModel.hasActiveListFilters {
                Button("Clear Filters", systemImage: "line.3.horizontal.decrease.circle") {
                    containerViewModel.clearListFilters()
                }
                .buttonStyle(.borderless)
                .help("Show all invoices")
            }

            if !isMultiSelectMode, let selected = selectedInvoice {
                Button("Duplicate", systemImage: "doc.on.doc") {
                    duplicateInvoice(selected)
                }
                .buttonStyle(.borderless)
                .help("Duplicate current invoice")
            }

            if !isMultiSelectMode, !projection.filteredInvoices.isEmpty {
                Button("Select", systemImage: "checkmark.circle") {
                    isMultiSelectMode = true
                }
                .buttonStyle(.borderless)
                .help("Select multiple invoices")
            }
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var resultSummary: String {
        let count = projection.filteredInvoices.count
        if containerViewModel.isShowingPreviousQueryResults {
            let noun = count == 1 ? "result" : "results"
            return "\(count) previous \(noun)"
        }
        if containerViewModel.hasActiveListFilters {
            let totalNoun = containerViewModel.totalInvoiceCount == 1 ? "invoice" : "invoices"
            return "\(count) of \(containerViewModel.totalInvoiceCount) \(totalNoun)"
        }
        let noun = count == 1 ? "invoice" : "invoices"
        return "\(count) \(noun)"
    }

    private var highlightedTreeItemIDs: Set<String> {
        let selectedIDs: [UUID]
        if isMultiSelectMode {
            selectedIDs = Array(selectedInvoiceIDs)
        } else {
            selectedIDs = selectedInvoice.map { [$0.id] } ?? []
        }
        return Set(selectedIDs.map { "invoice_\($0)" })
    }

    private var selectedInvoiceEntities: [Invoice] {
        projection.filteredInvoices.filter { selectedInvoiceIDs.contains($0.id) }
    }

    private var selectedDocumentRequests: [InvoiceBulkDocumentRequest] {
        selectedInvoiceEntities.map(InvoiceBulkDocumentRequest.init(invoice:))
    }

    private var allVisibleInvoicesSelected: Bool {
        !visibleInvoiceIDs.isEmpty && selectedInvoiceIDs == visibleInvoiceIDs
    }

    private var visibleInvoiceIDs: Set<UUID> {
        Set(projection.filteredInvoices.map(\.id))
    }

    private var selectedInvoiceIsHiddenByFilters: Bool {
        guard let selectedID = selectedInvoice?.id else { return false }
        return containerViewModel.hasActiveListFilters && !visibleInvoiceIDs.contains(selectedID)
    }

    private func duplicateInvoice(_ invoice: Invoice) {
        Task {
            do {
                _ = try await containerViewModel.duplicateInvoice(invoice)
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .default)
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice could not be duplicated. Try again."
                )
                containerViewModel.reportActionError("Duplicate failed. \(detail)")
            }
        }
    }

    private func bulkExportCSVSelectedInvoices() {
        let selectedInvoices = selectedInvoiceEntities
        guard !selectedInvoices.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title = "Export Invoices to CSV"
        panel.nameFieldStringValue = "Invoices.csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let csvText = InvoiceDataExporter.exportCSV(invoices: selectedInvoices)
            do {
                try csvText.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                bulkActionResult = BulkActionResult(
                    title: "CSV Export Complete",
                    message: "Exported \(selectedInvoices.count) \(selectedInvoices.count == 1 ? "invoice" : "invoices") to CSV."
                )
            } catch {
                bulkActionResult = BulkActionResult(
                    title: "CSV Export Failed",
                    message: InvoiceOperationErrorPresentation.detail(
                        for: error,
                        fallback: "Invoices could not be exported to CSV. Try again."
                    )
                )
            }
        }
    }

    private func bulkExportJSONSelectedInvoices() {
        let selectedInvoices = selectedInvoiceEntities
        guard !selectedInvoices.isEmpty else { return }

        let panel = NSSavePanel()
        panel.title = "Export Invoices to JSON"
        panel.nameFieldStringValue = "Invoices.json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try InvoiceDataExporter.exportJSONData(invoices: selectedInvoices)
                try data.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
                bulkActionResult = BulkActionResult(
                    title: "JSON Export Complete",
                    message: "Exported \(selectedInvoices.count) \(selectedInvoices.count == 1 ? "invoice" : "invoices") to JSON."
                )
            } catch {
                bulkActionResult = BulkActionResult(
                    title: "JSON Export Failed",
                    message: InvoiceOperationErrorPresentation.detail(
                        for: error,
                        fallback: "Invoices could not be exported to JSON. Try again."
                    )
                )
            }
        }
    }

    private func exportSingleInvoiceCSV(_ invoice: Invoice) {
        let panel = NSSavePanel()
        panel.title = "Export Invoice to CSV"
        let number = invoice.invoiceNumber.isEmpty ? "Draft" : invoice.invoiceNumber
        panel.nameFieldStringValue = "\(number).csv"
        panel.allowedContentTypes = [.commaSeparatedText]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let csvText = InvoiceDataExporter.exportCSV(invoices: [invoice])
            do {
                try csvText.write(to: url, atomically: true, encoding: .utf8)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice could not be exported to CSV. Try again."
                )
                containerViewModel.reportActionError("Export failed. \(detail)")
            }
        }
    }

    private func exportSingleInvoiceJSON(_ invoice: Invoice) {
        let panel = NSSavePanel()
        panel.title = "Export Invoice to JSON"
        let number = invoice.invoiceNumber.isEmpty ? "Draft" : invoice.invoiceNumber
        panel.nameFieldStringValue = "\(number).json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                let data = try InvoiceDataExporter.exportJSONData(invoices: [invoice])
                try data.write(to: url, options: .atomic)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                let detail = InvoiceOperationErrorPresentation.detail(
                    for: error,
                    fallback: "Invoice could not be exported to JSON. Try again."
                )
                containerViewModel.reportActionError("Export failed. \(detail)")
            }
        }
    }

    private func refreshInvoiceList() {
        Task {
            await containerViewModel.reloadInvoices(
                matching: InvoicesListQueryEngine.buildPersistenceDescriptor(
                    from: containerViewModel.listQuerySpec
                )
            )
        }
    }

}

@MainActor
private enum InvoiceBulkExportFolderPanel {
    static func destination(invoiceCount: Int) async -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Export Invoice PDFs"
        let documentNoun = invoiceCount == 1 ? "PDF" : "PDFs"
        panel.message = "Choose a folder for \(invoiceCount) invoice \(documentNoun)."
        panel.prompt = "Export"
        panel.allowedContentTypes = [.folder]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        let session = InvoiceBulkExportFolderPanelSession(panel: panel)

        return await withTaskCancellationHandler {
            if Task.isCancelled {
                session.cancel()
                return nil
            }
            return await session.destination()
        } onCancel: {
            Task { @MainActor in session.cancel() }
        }
    }
}

@MainActor
private final class InvoiceBulkExportFolderPanelSession {
    private let panel: NSOpenPanel
    private var continuation: CheckedContinuation<URL?, Never>?
    private var isFinished = false

    init(panel: NSOpenPanel) {
        self.panel = panel
    }

    func destination() async -> URL? {
        await withCheckedContinuation { continuation in
            guard !isFinished else {
                continuation.resume(returning: nil)
                return
            }
            self.continuation = continuation
            panel.begin { [weak self] response in
                guard let self else { return }
                finish(with: response == .OK ? panel.url : nil)
            }
        }
    }

    func cancel() {
        guard !isFinished else { return }
        panel.cancel(nil)
        finish(with: nil)
    }

    private func finish(with destination: URL?) {
        guard !isFinished else { return }
        isFinished = true
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: destination)
    }
}

enum InvoiceBulkExportNaming {
    static func availableDestination(
        in directory: URL,
        preferredFilename: String,
        fileManager: FileManager = .default
    ) -> URL {
        let preferredURL = directory.appendingPathComponent(preferredFilename)
        guard fileManager.fileExists(atPath: preferredURL.path) else { return preferredURL }

        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        let pathExtension = preferredURL.pathExtension
        var copyNumber = 2
        while true {
            let filename = pathExtension.isEmpty
                ? "\(baseName) \(copyNumber)"
                : "\(baseName) \(copyNumber).\(pathExtension)"
            let candidate = directory.appendingPathComponent(filename)
            if !fileManager.fileExists(atPath: candidate.path) {
                return candidate
            }
            copyNumber += 1
        }
    }
}

@MainActor
final class InvoiceShareLifetime {
    private var retainedOwner: AnyObject?

    var isActive: Bool { retainedOwner != nil }

    func begin(retaining owner: AnyObject) {
        retainedOwner = owner
    }

    func finish() {
        retainedOwner = nil
    }
}

@MainActor
final class InvoiceEmailShareCoordinator: NSObject, NSSharingServiceDelegate {
    enum Outcome: Equatable {
        case completed
        case cancelled
        case failed(String)
    }

    private let service: NSSharingService
    private var temporaryPDFs: [InvoiceTemporaryPDF]
    private let completion: (Outcome) -> Void
    private var hasFinished = false
    /// Keeps attachments alive if invoice workspace leaves hierarchy while sharing UI is open.
    /// Released by every terminal delegate callback in `finish(with:)`.
    private let activeShareLifetime = InvoiceShareLifetime()

    init(
        service: NSSharingService,
        temporaryPDFs: [InvoiceTemporaryPDF],
        completion: @escaping (Outcome) -> Void
    ) {
        self.service = service
        self.temporaryPDFs = temporaryPDFs
        self.completion = completion
        super.init()
        service.delegate = self
    }

    deinit {
        temporaryPDFs.forEach { $0.discard() }
    }

    func perform(with items: [Any]) {
        activeShareLifetime.begin(retaining: self)
        service.perform(withItems: items)
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) {
        finish(with: .completed)
    }

    func sharingService(
        _ sharingService: NSSharingService,
        didFailToShareItems items: [Any],
        error: Error
    ) {
        let cocoaError = error as NSError
        if cocoaError.domain == NSCocoaErrorDomain, cocoaError.code == NSUserCancelledError {
            finish(with: .cancelled)
        } else {
            finish(with: .failed("Selected invoices could not be shared. \(error.localizedDescription)"))
        }
    }

    private func finish(with outcome: Outcome) {
        guard !hasFinished else { return }
        hasFinished = true
        service.delegate = nil
        temporaryPDFs.forEach { $0.discard() }
        temporaryPDFs.removeAll()
        completion(outcome)
        activeShareLifetime.finish()
    }
}

private struct ScrollableInvoicesList: View {
    let totalInvoiceCount: Int
    let filteredCount: Int
    let groupedCount: Int
    let treeItems: [TreeItem]
    let selectedItemIDs: Set<String>
    let hasActiveFilters: Bool
    let activeFilterSummaryText: String
    let activeFilterTags: [InvoiceFilterTag]
    let isRefreshing: Bool
    let creationPhase: InvoiceCreationPhase
    let onItemTap: (TreeItem) -> Void
    let onItemContextMenu: ((TreeItem) -> AnyView?)?
    let onCreateInvoice: @MainActor () -> Void
    let onClearFilters: @MainActor () -> Void
    let onClearFilterTag: @MainActor (InvoiceFilterTag.FilterCategory) -> Void
    let onRefresh: @MainActor () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        totalInvoiceCount: Int,
        filteredCount: Int,
        groupedCount: Int,
        treeItems: [TreeItem],
        selectedItemIDs: Set<String>,
        hasActiveFilters: Bool,
        activeFilterSummaryText: String,
        activeFilterTags: [InvoiceFilterTag],
        isRefreshing: Bool,
        creationPhase: InvoiceCreationPhase,
        onItemTap: @escaping (TreeItem) -> Void,
        onItemContextMenu: ((TreeItem) -> AnyView?)? = nil,
        onCreateInvoice: @escaping @MainActor () -> Void,
        onClearFilters: @escaping @MainActor () -> Void,
        onClearFilterTag: @escaping @MainActor (InvoiceFilterTag.FilterCategory) -> Void,
        onRefresh: @escaping @MainActor () -> Void
    ) {
        self.totalInvoiceCount = totalInvoiceCount
        self.filteredCount = filteredCount
        self.groupedCount = groupedCount
        self.treeItems = treeItems
        self.selectedItemIDs = selectedItemIDs
        self.hasActiveFilters = hasActiveFilters
        self.activeFilterSummaryText = activeFilterSummaryText
        self.activeFilterTags = activeFilterTags
        self.isRefreshing = isRefreshing
        self.creationPhase = creationPhase
        self.onItemTap = onItemTap
        self.onItemContextMenu = onItemContextMenu
        self.onCreateInvoice = onCreateInvoice
        self.onClearFilters = onClearFilters
        self.onClearFilterTag = onClearFilterTag
        self.onRefresh = onRefresh
    }

    @ViewBuilder
    var body: some View {
        switch InvoicesListEmptyStatePolicy.resolve(
            totalInvoiceCount: totalInvoiceCount,
            filteredCount: filteredCount,
            hasActiveFilters: hasActiveFilters
        ) {
        case .noInvoices:
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Invoices Yet",
                    message: "Create your first invoice to start tracking billing."
                )
                if creationPhase.isActive {
                    ProgressView(creationPhase.progressTitle)
                        .controlSize(.small)
                } else {
                    Button("New Invoice", systemImage: "plus") {
                        onCreateInvoice()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxHeight: .infinity)
            .standardContentPanelListInsets()
            .fluidTransition()
        case .noMatches:
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                EmptyStateView(
                    icon: "line.3.horizontal.decrease.circle",
                    title: "No Matching Invoices",
                    message: activeFilterSummaryText.isEmpty ? "Change search or filters to see more results." : activeFilterSummaryText
                )

                if !activeFilterTags.isEmpty {
                    VStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                        Text("Active Filters")
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
                                ForEach(activeFilterTags, id: \.id) { tag in
                                    HStack(spacing: StyleGuide.Dimensions.paddingXXSmall) {
                                        Text(tag.label)
                                            .font(StyleGuide.Typography.caption)
                                            .foregroundStyle(.primary)
                                        Button {
                                            onClearFilterTag(tag.id)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(StyleGuide.Colors.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Clear \(tag.label) filter")
                                    }
                                    .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                                    .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                                    .background(
                                        Capsule()
                                            .fill(ColorSystem.Neutral.gray100)
                                            .overlay(Capsule().stroke(ColorSystem.Neutral.gray300, lineWidth: 1))
                                    )
                                }
                            }
                            .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                        }
                    }
                    .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                }

                Button("Clear Search and Filters", systemImage: "xmark.circle") {
                    onClearFilters()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Clear search and all active filters")
            }
            .frame(maxHeight: .infinity)
            .standardContentPanelListInsets()
            .fluidTransition()
        case .needsRefresh:
            VStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                EmptyStateView(
                    icon: "arrow.clockwise.circle",
                    title: "Invoices Need Refresh",
                    message: "Invoice records changed while this list was updating."
                )
                if isRefreshing {
                    ProgressView("Refreshing invoices…")
                        .controlSize(.small)
                } else {
                    Button("Refresh Invoices", systemImage: "arrow.clockwise") {
                        onRefresh()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxHeight: .infinity)
            .standardContentPanelListInsets()
            .fluidTransition()
        case .content:
            // Use hierarchical list
            FoldPaperContainer(
                items: .constant(treeItems),
                selectedItemIDs: selectedItemIDs,
                rootTitle: "All Invoices",
                onItemTap: onItemTap,
                onItemContextMenu: onItemContextMenu
            )
        }
    }
}
