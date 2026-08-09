import Foundation
import SwiftData
import Core

/// Isolated rendered PDF workspace with explicit cleanup ownership.
public struct InvoiceTemporaryPDF: Sendable {
    public let url: URL
    private let workspaceDirectory: URL

    init(url: URL, workspaceDirectory: URL) {
        self.url = url
        self.workspaceDirectory = workspaceDirectory
    }

    public func discard() {
        InvoiceTemporaryPDFWorkspace.securelyDeleteWorkspace(at: workspaceDirectory)
    }
}

/// Persistence entry points used by owning invoice workflows outside editor view hierarchy.
/// Template workspace never constructs or calls this API.
public enum InvoiceEditorStore {
    public static func createInvoice(in container: ModelContainer) async throws -> UUID {
        let creationDefaults = InvoiceCreationDefaults.load(from: .standard)
        let templateDefaults = InvoiceTemplatePreferenceStore.loadDefaults()
        return try await InvoiceModelActor(modelContainer: container).createInvoice(
            defaults: creationDefaults,
            templateDefaults: templateDefaults
        )
    }

    public static func duplicateInvoice(id: UUID, in container: ModelContainer) async throws -> UUID {
        try await InvoiceModelActor(modelContainer: container).duplicateInvoice(id: id)
    }

    @MainActor
    public static func temporaryPDF(
        invoiceID: UUID,
        in container: ModelContainer,
        presentation: InvoicePDFPresentation = .invoice
    ) async throws -> InvoiceTemporaryPDF {
        _ = presentation
        let viewModel = InvoiceEditorViewModel(
            actor: InvoiceModelActor(modelContainer: container)
        )
        await viewModel.bootstrap(preferredInvoiceID: invoiceID)
        guard viewModel.currentInvoice?.id == invoiceID else {
            throw InvoiceModelError.invoiceNotFound
        }
        return try InvoicePDFRenderer.temporaryPDF(viewModel: viewModel)
    }
}
