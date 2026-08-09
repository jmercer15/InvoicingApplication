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
import PersistenceModels
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


extension InvoicesView {
    func bulkExportSelectedInvoices() {
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

    func bulkEmailSelectedInvoices() {
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
    func handleInvoiceTap(invoice: Invoice) {
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
    func performDeleteInvoices(_ invoiceIDs: Set<UUID>) {
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

    func endMultiSelection() {
        withAnimation(
            reduceMotion
                ? nil
                : .easeInOut(duration: StyleGuide.Animations.durationMedium)
        ) {
            isMultiSelectMode = false
            selectedInvoiceIDs.removeAll()
        }
    }

    func cancelActiveBulkAction() {
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

    func handleMultiSelectExit() {
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
