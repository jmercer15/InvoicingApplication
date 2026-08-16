import AppKit
import PDFKit
import SwiftUI

// MARK: - PDF Rendering

@MainActor
enum InvoicePDFRenderer {
  static func temporaryPDF(viewModel: InvoiceEditorViewModel) throws -> InvoiceTemporaryPDF {
    let document = PDFDocument()
    let pageSize = viewModel.pageSizePoints
    let margin = viewModel.effectiveMarginPoints
    let contentWidth = InvoiceLineItemsTypography.contentWidth(
      pageWidth: pageSize.width,
      margin: margin
    )

    for (index, page) in viewModel.invoicePages.enumerated() {
      let interaction = InvoicePreviewInspectorInteraction(isEnabled: false)
      let pageView = InvoiceDocumentPreviewPage(
        viewModel: viewModel,
        page: page,
        lineItemsContentWidth: contentWidth,
        margin: margin,
        inspectorInteraction: interaction
      )
      .invoiceTemplateAppearance(
        theme: viewModel.themePalette,
        tableStyle: viewModel.tableStyle,
        fontFamily: viewModel.fontFamily,
        borderWeight: viewModel.borderWeight,
        tablePresentation: InvoiceTablePresentation(
          showsGridLines: viewModel.showTableGridLines,
          showsZebraRows: viewModel.showTableZebraRows,
          showsHeaderFill: viewModel.showTableHeaderFill,
          showsTotalsFill: viewModel.showTotalsFill
        ),
        resolvedStyle: viewModel.resolvedDocumentStyle
      )
      .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)

      let hostingView = NSHostingView(rootView: pageView)
      hostingView.frame = CGRect(origin: .zero, size: pageSize)
      hostingView.layoutSubtreeIfNeeded()
      let pageData = hostingView.dataWithPDF(inside: hostingView.bounds)
      guard let rendered = PDFDocument(data: pageData), let pdfPage = rendered.page(at: 0) else {
        throw CocoaError(.fileWriteUnknown)
      }
      document.insert(pdfPage, at: index)
    }

    let workspaceDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("InvoicePDF-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
      at: workspaceDirectory,
      withIntermediateDirectories: true
    )
    let url = workspaceDirectory.appendingPathComponent(
      InvoiceDocumentFilename.pdf(invoiceNumber: viewModel.invoiceNumber)
    )
    guard document.write(to: url) else {
      try? FileManager.default.removeItem(at: workspaceDirectory)
      throw CocoaError(.fileWriteUnknown)
    }
    return InvoiceTemporaryPDF(url: url, workspaceDirectory: workspaceDirectory)
  }
}

@MainActor
private enum InvoicePDFSavePanel {
  static func destination(
    suggestedFilename: String,
    cancellation: InvoiceDocumentActionCancellation
  ) async -> URL? {
    let panel = NSSavePanel()
    panel.allowedContentTypes = [.pdf]
    panel.canCreateDirectories = true
    panel.nameFieldStringValue = suggestedFilename
    let session = InvoicePDFSavePanelSession(panel: panel)
    cancellation.install { session.cancel() }
    defer { cancellation.clear() }

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
private final class InvoicePDFSavePanelSession {
  private let panel: NSSavePanel
  private var continuation: CheckedContinuation<URL?, Never>?
  private var isFinished = false

  init(panel: NSSavePanel) {
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

extension InvoiceEditorViewModel {
  func exportCurrentInvoicePDF() async {
    guard !isGeneratingDocument else { return }
    isGeneratingDocument = true
    defer { isGeneratingDocument = false }

    if hasUnsavedChanges {
      await saveCurrentInvoice(successMessage: "Invoice saved before export.")
      guard !hasUnsavedChanges else { return }
    }

    do {
      await Task.yield()
      let temporaryPDF = try InvoicePDFRenderer.temporaryPDF(viewModel: self)
      defer { temporaryPDF.discard() }
      guard let destination = await InvoicePDFSavePanel.destination(
        suggestedFilename: temporaryPDF.url.lastPathComponent,
        cancellation: documentActionCancellation
      ) else {
        statusMessage = "Export cancelled."
        return
      }
      try Task.checkCancellation()
      try InvoicePDFFileWriter.write(source: temporaryPDF.url, to: destination)
      statusMessage = "Exported invoice PDF."
    } catch is CancellationError {
      statusMessage = "Export cancelled."
    } catch {
      statusMessage = "Failed to export invoice: \(error.localizedDescription)"
    }
  }

  func printCurrentInvoice() async {
    guard !isGeneratingDocument else { return }
    isGeneratingDocument = true
    defer { isGeneratingDocument = false }

    if hasUnsavedChanges {
      await saveCurrentInvoice(successMessage: "Invoice saved before printing.")
      guard !hasUnsavedChanges else { return }
    }

    do {
      await Task.yield()
      try Task.checkCancellation()
      let temporaryPDF = try InvoicePDFRenderer.temporaryPDF(viewModel: self)
      defer { temporaryPDF.discard() }
      guard let document = PDFDocument(url: temporaryPDF.url),
            let operation = document.printOperation(
              for: NSPrintInfo.shared,
              scalingMode: .pageScaleDownToFit,
              autoRotate: true
            )
      else { throw CocoaError(.fileReadCorruptFile) }
      statusMessage = operation.run()
        ? "Invoice sent to printer."
        : "Printing cancelled."
    } catch is CancellationError {
      statusMessage = "Printing cancelled."
    } catch {
      statusMessage = "Failed to print invoice: \(error.localizedDescription)"
    }
  }
}
