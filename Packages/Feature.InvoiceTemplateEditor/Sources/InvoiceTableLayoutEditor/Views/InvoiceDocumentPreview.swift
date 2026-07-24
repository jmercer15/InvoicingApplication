import AppKit
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Live paginated preview of the invoice document (presentation only).
struct InvoiceDocumentPreview: View {
  @Bindable var viewModel: InvoiceEditorViewModel
  @Binding var zoom: InvoiceDocumentPreviewZoom
  /// Shared with the toolbar, but observed there rather than by the whole editor.
  let viewport: InvoicePreviewViewportState
  let inspectorInteraction: InvoicePreviewInspectorInteraction

  @State private var magnifyBaseScale: CGFloat?
  @GestureState private var liveMagnification: CGFloat = 1
  @State private var fitScaleReporter = InvoicePreviewFitScaleReporter()
  @State private var measurementReporter = InvoicePaginationMeasurementReporter()
  /// Pagination is driven by draft content and measured document dimensions, neither of which
  /// changes while the user resizes the preview viewport.
  @State private var renderedPages: [InvoicePageContent] = []

  private var pages: [InvoicePageContent] {
    renderedPages.isEmpty ? viewModel.invoicePages : renderedPages
  }

  private var documentContentWidth: CGFloat {
    InvoiceLineItemsTypography.contentWidth(
      pageWidth: viewModel.pageSizePoints.width,
      margin: viewModel.effectiveMarginPoints
    )
  }

  private var printableHeight: CGFloat {
    let pageSize = viewModel.pageSizePoints
    return pageSize.height - (viewModel.effectiveMarginPoints * 2)
  }

  var body: some View {
    GeometryReader { geometry in
      let pageSize = viewModel.pageSizePoints
      let margin = viewModel.effectiveMarginPoints
      let availableWidth = max(geometry.size.width - 48, 200)
      let computedFitScale = InvoiceDocumentPreviewZoom.stabilizedFitScale(
        InvoiceLineItemsTypography.previewScale(
          availableWidth: availableWidth,
          pageWidth: pageSize.width
        )
      )
      let committedScale = zoom.displayScale(fitScale: computedFitScale)
      let displayScale = InvoiceDocumentPreviewZoom.clamp(
        (magnifyBaseScale ?? committedScale) * liveMagnification
      )
      ScrollViewReader { scrollProxy in
        ScrollView([.horizontal, .vertical]) {
          VStack(spacing: 20) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
              InvoiceDocumentPreviewScaledPage(
                viewModel: viewModel,
                page: page,
                lineItemsContentWidth: documentContentWidth,
                margin: margin,
                pageSize: pageSize,
                scale: displayScale,
                inspectorInteraction: inspectorInteraction
              )
              .id(index)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.horizontal, 24)
          .padding(.bottom, 24)
          // The zoom label changes during a live resize. Keep it out of the scroll
          // content so that text updates never reflow the scaled pages.
          .padding(.top, 56)
          // When the fitted document is smaller than the canvas, make the
          // scroll content canvas-sized and center the document within it.
          // Once a zoomed document exceeds either dimension this frame
          // adopts its natural size, retaining native panning in both axes.
          .frame(
            minWidth: geometry.size.width,
            minHeight: geometry.size.height,
            alignment: .center
          )
        }
        .onChange(of: viewModel.currentPageIndex) { _, newIndex in
          withAnimation {
            scrollProxy.scrollTo(newIndex, anchor: .top)
          }
        }
      }
      .overlay(alignment: .topTrailing) {
        pageChromeLabel(fitScale: computedFitScale)
          .padding(12)
          .allowsHitTesting(false)
      }
      .simultaneousGesture(magnifyGesture(fitScale: computedFitScale))
      .background {
        PreviewCommandScrollZoomMonitor { factor in
          zoom.multiplyScale(by: factor, relativeTo: computedFitScale)
        }
      }
      .background {
        Group {
          Button("Previous Page") {
            viewModel.goToPreviousPage()
          }
          .keyboardShortcut(.pageUp, modifiers: [])

          Button("Next Page") {
            viewModel.goToNextPage()
          }
          .keyboardShortcut(.pageDown, modifiers: [])

          Button("First Page") {
            viewModel.goToFirstPage()
          }
          .keyboardShortcut(.home, modifiers: [])

          Button("Last Page") {
            viewModel.goToLastPage()
          }
          .keyboardShortcut(.end, modifiers: [])
        }
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
      }
      .task(id: computedFitScale) {
        fitScaleReporter.receive(computedFitScale, viewport: viewport)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background {
      InvoicePaginationMeasurer(
        viewModel: viewModel,
        contentWidth: documentContentWidth,
        printableHeight: printableHeight
      ) { dimensions in
        measurementReporter.receive(
          dimensions,
          contentToken: viewModel.paginationMeasurementToken,
          viewModel: viewModel
        )
      }
    }
    .background(Color(nsColor: .underPageBackgroundColor))
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
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Invoice document preview")
    .accessibilityValue("Page \(viewModel.currentPageIndex + 1) of \(pages.count), zoom \(zoom.percentLabel(fitScale: viewport.fitScale))")
    .accessibilityHint(
      "Page Up, Page Down, Home, and End navigate pages. Pinch or hold Command while scrolling to zoom. Drag scrollbars or swipe to pan when zoomed in."
    )
    .task(id: pageRenderTaskID) {
      // Content edits and their resulting measurements often arrive in adjacent layout passes.
      // Coalesce them before publishing cached pages so SwiftUI never receives multiple page
      // state writes in one frame.
      do {
        try await Task.sleep(for: .milliseconds(16))
        try Task.checkCancellation()
      } catch {
        return
      }
      refreshRenderedPages()
    }
  }

  private var pageRenderTaskID: InvoiceDocumentPreviewRenderTaskID {
    InvoiceDocumentPreviewRenderTaskID(
      contentToken: viewModel.paginationMeasurementToken,
      measuredDimensions: viewModel.measuredDimensions
    )
  }

  private func pageChromeLabel(fitScale: CGFloat) -> some View {
    let pageCount = pages.count
    let currentPage = min(viewModel.currentPageIndex + 1, max(1, pageCount))
    let pageLabel = pageCount <= 1 ? "1 page" : "Page \(currentPage) of \(pageCount)"
    let zoomLabel =
      zoom.isFitWidth
      ? "\(zoom.percentLabel(fitScale: fitScale)) · Fit width"
      : zoom.percentLabel(fitScale: fitScale)
    return Text(
      "\(viewModel.paperSize.displayName) · \(viewModel.pageOrientation.displayName) · \(viewModel.pageDimensionsLabel) · \(pageLabel) · \(zoomLabel)"
    )
    .font(InvoiceDocumentDesign.chromeFont)
    .foregroundStyle(InvoiceDocumentDesign.inkMuted)
    .documentChromeCapsule(horizontalPadding: 12, verticalPadding: 5)
    .accessibilityLabel("\(viewModel.paperSize.displayName) \(viewModel.pageOrientation.displayName), \(pageLabel), zoom \(zoomLabel)")
  }

  private func magnifyGesture(fitScale: CGFloat) -> some Gesture {
    MagnifyGesture()
      .updating($liveMagnification) { value, state, _ in
        state = value.magnification
      }
      .onChanged { _ in
        if magnifyBaseScale == nil {
          magnifyBaseScale = zoom.displayScale(fitScale: fitScale)
        }
      }
      .onEnded { value in
        let base = magnifyBaseScale ?? zoom.displayScale(fitScale: fitScale)
        zoom.applyMagnification(value.magnification, baseScale: base)
        magnifyBaseScale = nil
      }
  }

  private func refreshRenderedPages() {
    let nextPages = viewModel.invoicePages
    guard renderedPages != nextPages else { return }
    renderedPages = nextPages
  }
}

private struct InvoiceDocumentPreviewRenderTaskID: Equatable {
  let contentToken: String
  let measuredDimensions: InvoicePagination.MeasuredDimensions?
}

enum InvoicePaginationMeasurementPublicationPolicy {
  /// Reporter cache and model cache have separate lifetimes. A selection can invalidate model
  /// measurements while producing same dimensions as previous document, which must republish.
  static func shouldStage(
    incoming: InvoicePagination.MeasuredDimensions,
    reporterLatest: InvoicePagination.MeasuredDimensions?,
    modelCurrent: InvoicePagination.MeasuredDimensions?
  ) -> Bool {
    incoming != reporterLatest || incoming != modelCurrent
  }

  static func ownsCurrentContent(
    stagedContentToken: String,
    currentContentToken: String
  ) -> Bool {
    stagedContentToken == currentContentToken
  }
}

/// Publishes settled pagination measurements after AppKit's active layout pass.
/// Synchronous model mutation from an off-screen geometry callback can otherwise
/// relayout the preview while its hosting view is already in `layoutSubtreeIfNeeded`.
@MainActor
private final class InvoicePaginationMeasurementReporter {
  private static let reportingDelay: Duration = .milliseconds(80)

  private var latestDimensions: InvoicePagination.MeasuredDimensions?
  private var latestContentToken = ""
  private var revision = 0
  private var reportingTask: Task<Void, Never>?

  func receive(
    _ dimensions: InvoicePagination.MeasuredDimensions,
    contentToken: String,
    viewModel: InvoiceEditorViewModel
  ) {
    guard InvoicePaginationMeasurementPublicationPolicy.shouldStage(
      incoming: dimensions,
      reporterLatest: latestDimensions,
      modelCurrent: viewModel.measuredDimensions
    ) else { return }
    latestDimensions = dimensions
    latestContentToken = contentToken
    revision &+= 1

    guard reportingTask == nil else { return }
    reportingTask = Task { [weak self, weak viewModel] in
      guard let self else { return }
      defer { self.reportingTask = nil }
      guard let viewModel else { return }

      while !Task.isCancelled {
        let observedRevision = self.revision
        do {
          try await Task.sleep(for: Self.reportingDelay)
        } catch {
          break
        }

        guard observedRevision == self.revision else { continue }
        if let latestDimensions = self.latestDimensions,
          InvoicePaginationMeasurementPublicationPolicy.ownsCurrentContent(
            stagedContentToken: self.latestContentToken,
            currentContentToken: viewModel.paginationMeasurementToken
          )
        {
          viewModel.updateMeasuredDimensions(latestDimensions)
        }
        return
      }
    }
  }
}

/// Debounces fit-scale publication with one task for an entire resize gesture. The toolbar is
/// updated after the system sidebar/inspector transition settles, never in its middle.
@MainActor
private final class InvoicePreviewFitScaleReporter {
  private static let reportingDelay: Duration = .milliseconds(450)

  private var latestScale: CGFloat = 1
  private var revision = 0
  private var reportingTask: Task<Void, Never>?

  func receive(_ scale: CGFloat, viewport: InvoicePreviewViewportState) {
    latestScale = scale
    revision &+= 1

    guard reportingTask == nil else { return }

    reportingTask = Task { [weak self, weak viewport] in
      guard let self else { return }
      defer { self.reportingTask = nil }
      guard let viewport else { return }

      while !Task.isCancelled {
        let observedRevision = self.revision
        do {
          try await Task.sleep(for: Self.reportingDelay)
        } catch {
          break
        }

        guard self.revision == observedRevision else { continue }
        if viewport.fitScale != self.latestScale {
          viewport.fitScale = self.latestScale
        }
        return
      }
    }
  }
}

/// Applies resize-only transform and scroll-extent changes around an independently cached page.
private struct InvoiceDocumentPreviewScaledPage: View {
  @Bindable var viewModel: InvoiceEditorViewModel
  let page: InvoicePageContent
  let lineItemsContentWidth: CGFloat
  let margin: CGFloat
  let pageSize: CGSize
  let scale: CGFloat
  let inspectorInteraction: InvoicePreviewInspectorInteraction

  var body: some View {
    InvoiceDocumentPreviewPage(
      viewModel: viewModel,
      page: page,
      lineItemsContentWidth: lineItemsContentWidth,
      margin: margin,
      inspectorInteraction: inspectorInteraction
    )
    .equatable()
    .frame(width: pageSize.width, height: pageSize.height, alignment: .topLeading)
    .scaleEffect(scale, anchor: .top)
    .frame(
      width: pageSize.width * scale,
      height: pageSize.height * scale,
      alignment: .top
    )
  }
}

/// The document hierarchy is independent of viewport geometry. Equatable comparison prevents
/// a resize from rebuilding its sections; direct observation still refreshes it for draft edits.
private struct InvoiceDocumentPreviewPage: View, Equatable {
  /// This comparison is intentionally independent of the main-actor view model. Observable
  /// draft changes still invalidate the page directly; viewport resizing compares this stable
  /// render key and skips rebuilding the document tree.
  nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.renderKey == rhs.renderKey
  }

  @Bindable var viewModel: InvoiceEditorViewModel
  let page: InvoicePageContent
  let lineItemsContentWidth: CGFloat
  let margin: CGFloat
  let inspectorInteraction: InvoicePreviewInspectorInteraction

  private let renderKey: InvoiceDocumentPreviewPageRenderKey

  init(
    viewModel: InvoiceEditorViewModel,
    page: InvoicePageContent,
    lineItemsContentWidth: CGFloat,
    margin: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction
  ) {
    self.viewModel = viewModel
    self.page = page
    self.lineItemsContentWidth = lineItemsContentWidth
    self.margin = margin
    self.inspectorInteraction = inspectorInteraction
    renderKey = InvoiceDocumentPreviewPageRenderKey(
      page: page,
      lineItemsContentWidth: lineItemsContentWidth,
      margin: margin,
      style: viewModel.resolvedDocumentStyle
    )
  }

  var body: some View {
    invoiceContent
      .padding(margin)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color.white)
      .clipShape(Rectangle())
      .overlay {
        Rectangle()
          .strokeBorder(
            InvoiceDocumentDesign.stroke, lineWidth: InvoiceDocumentDesign.cardBorderWidth)
      }
      .overlay(alignment: .bottom) {
        if viewModel.showPageNumbers {
          InvoiceDocumentSections.pageNumberLabel(
            pageIndex: page.pageIndex,
            totalPages: page.totalPages,
            showsChrome: viewModel.showPageNumberChrome
          )
        }
      }
      .shadow(color: .black.opacity(0.08), radius: 16, y: 4)
      .preferredColorScheme(.light)
  }

  private var invoiceContent: some View {
    let pinsPaymentToBottom = page.showsFooter

    return VStack(
      alignment: .leading,
      spacing: InvoiceDocumentLayout.sectionSpacing(
        scale: viewModel.resolvedDocumentStyle.spacingScale)
    ) {
      if page.showsDocumentHeader {
        InvoiceDocumentSections.documentHeader(
          viewModel: viewModel,
          contentWidth: lineItemsContentWidth,
          bleed: viewModel.effectiveMarginPoints,
          margin: viewModel.effectiveMarginPoints,
          inspectorInteraction: inspectorInteraction
        )
        InvoiceDocumentSections.parties(
          viewModel: viewModel,
          contentWidth: lineItemsContentWidth,
          inspectorInteraction: inspectorInteraction
        )
      }

      if page.showsLineItemsSectionTitle || !page.lineItemIDs.isEmpty {
        lineItemsAndFooterSection
          .padding(
            .top,
            page.showsDocumentHeader
              ? InvoiceDocumentLayout.lineItemsTopPadding(
                scale: viewModel.resolvedDocumentStyle.spacingScale)
              : 0
          )
      } else if page.showsTotals || page.showsFooter {
        pinnedPaymentFooterSection
          .padding(
            .top,
            page.showsDocumentHeader
              ? InvoiceDocumentLayout.lineItemsTopPadding(
                scale: viewModel.resolvedDocumentStyle.spacingScale)
              : 0
          )
      }

      if !pinsPaymentToBottom {
        Spacer(minLength: 0)
      }
    }
    .frame(maxHeight: .infinity, alignment: .topLeading)
  }

  private var lineItemsAndFooterSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(
        alignment: .leading,
        spacing: InvoiceDocumentLayout.lineItemsTitleSpacing(
          scale: viewModel.resolvedDocumentStyle.spacingScale)
      ) {
        if page.showsLineItemsSectionTitle, viewModel.showLineItemsSectionTitle {
          InvoiceDocumentSections.lineItemsSectionTitle()
            .previewInspectorTarget(.lineItems, interaction: inspectorInteraction)
        }

        InvoiceLineItemsPreviewTable(
          viewModel: viewModel,
          contentWidth: lineItemsContentWidth,
          lineItemIDs: page.lineItemIDs,
          showsHeader: page.showsTableHeader && viewModel.showLineItemsTableHeader,
          showsTotals: page.showsTotals,
          inspectorInteraction: inspectorInteraction
        )
        .frame(width: lineItemsContentWidth, alignment: .leading)
      }

      if page.showsFooter {
        Spacer(minLength: 0)
        InvoiceDocumentSections.documentPaymentFooter(
          viewModel: viewModel,
          contentWidth: lineItemsContentWidth,
          inspectorInteraction: inspectorInteraction
        )
      }
    }
    .frame(maxHeight: page.showsFooter ? .infinity : nil, alignment: .topLeading)
    .frame(width: lineItemsContentWidth, alignment: .leading)
  }

  private var pinnedPaymentFooterSection: some View {
    VStack(
      alignment: .leading,
      spacing: InvoiceDocumentLayout.footerSpacing(
        scale: viewModel.resolvedDocumentStyle.spacingScale)
    ) {
      if page.showsTotals {
        InvoiceLineItemsPreviewTable(
          viewModel: viewModel,
          contentWidth: lineItemsContentWidth,
          lineItemIDs: [],
          showsHeader: page.showsTableHeader && viewModel.showLineItemsTableHeader,
          showsTotals: true,
          inspectorInteraction: inspectorInteraction
        )
        .frame(width: lineItemsContentWidth, alignment: .leading)
      }

      if page.showsFooter {
        Spacer(minLength: 0)
        InvoiceDocumentSections.documentPaymentFooter(
          viewModel: viewModel,
          contentWidth: lineItemsContentWidth,
          inspectorInteraction: inspectorInteraction
        )
      }
    }
    .frame(maxHeight: page.showsFooter ? .infinity : nil, alignment: .topLeading)
    .frame(width: lineItemsContentWidth, alignment: .leading)
  }
}

private struct InvoiceDocumentPreviewPageRenderKey: Equatable {
  let page: InvoicePageContent
  let lineItemsContentWidth: CGFloat
  let margin: CGFloat
  let style: InvoiceDocumentResolvedStyle
}

extension View {
  func previewInspectorTarget(
    _ target: InvoiceInspectorFocusTarget,
    interaction: InvoicePreviewInspectorInteraction
  ) -> some View {
    modifier(InvoicePreviewInspectorTargetModifier(target: target, interaction: interaction))
  }

  /// Avoids introducing an interactive wrapper in shared pagination views.
  /// Live preview leaves opt in with an interaction; each leaf is targeted
  /// individually so a parent never competes with a nested region.
  @ViewBuilder
  func previewInspectorTargetIfPresent(
    _ target: InvoiceInspectorFocusTarget,
    interaction: InvoicePreviewInspectorInteraction?
  ) -> some View {
    if let interaction {
      previewInspectorTarget(target, interaction: interaction)
    } else {
      self
    }
  }

  @ViewBuilder
  func previewInspectorTargetIfPresent(
    _ target: InvoiceInspectorFocusTarget?,
    interaction: InvoicePreviewInspectorInteraction?
  ) -> some View {
    if let target {
      previewInspectorTargetIfPresent(target, interaction: interaction)
    } else {
      self
    }
  }
}

private struct InvoicePreviewInspectorTargetModifier: ViewModifier {
  let target: InvoiceInspectorFocusTarget
  let interaction: InvoicePreviewInspectorInteraction
  @State private var isHovered = false

  @ViewBuilder
  func body(content: Content) -> some View {
    if interaction.allowsPreviewTargetSelection {
      content
      .contentShape(Rectangle())
      .overlay {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
          .fill(Color.accentColor.opacity(isHovered ? 0.10 : 0))
          .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .stroke(Color.accentColor.opacity(isHovered ? 0.7 : 0), lineWidth: 1)
          }
          .allowsHitTesting(false)
      }
      .onHover { isHovered = $0 }
      .onTapGesture { interaction.select(target) }
      .accessibilityAddTraits(.isButton)
      .accessibilityLabel(interaction.accessibilityLabel(for: target))
      .accessibilityHint(interaction.accessibilityHint(for: target))
      .accessibilityAction { interaction.select(target) }
      .help(interaction.helpText(for: target))
    } else {
      content
    }
  }
}

extension InvoiceInspectorFocusTarget {
  var previewInteractionLabel: String {
    switch self {
    case .header: "invoice header"
    case .invoiceNumber: "invoice number"
    case .issueDate: "issue date"
    case .dueDate: "due date"
    case .from: "sender details"
    case .billedTo: "billing details"
    case .recipient: "recipient details"
    case .lineItems: "line items"
    case .lineItem: "line item"
    case .totals: "invoice totals"
    case .paymentDetails: "payment details"
    case .paymentTerms: "payment terms"
    case .notes: "invoice notes"
    case .sellerName: "sender name"
    case .sellerAddress: "sender address"
    case .sellerEmail: "sender email"
    case .sellerPhone: "sender phone number"
    case .sellerTaxID: "sender tax ID"
    case .billParticipantDirectly: "billing recipient selection"
    case .billToName: "billing contact name"
    case .billToAddress: "billing contact address"
    case .billToEmail: "billing contact email"
    case .billToPhone: "billing contact phone number"
    case .billingAuthority: "billing authority"
    case .clientName: "client name"
    case .clientAddress: "client address"
    case .clientEmail: "client email"
    case .clientPhone: "client phone number"
    case .clientTaxID: "client tax ID"
    case .lineItemServiceDate: "line item service date"
    case .lineItemDescription: "line item description"
    case .lineItemCode: "line item code"
    case .lineItemQuantity: "line item quantity"
    case .lineItemUnit: "line item unit"
    case .lineItemUnitPrice: "line item rate"
    case .lineItemTaxRate: "line item tax rate"
    case .discountPercent: "discount percentage"
    case .discountAmount: "discount amount"
    case .creditApplied: "credit applied"
    case .bankName: "bank name"
    case .bankAccountName: "account name"
    case .bankBSB: "BSB"
    case .bankAccountNumber: "account number"
    case .currencyCode: "currency"
    case .defaultTaxRate: "default tax rate"
    }
  }
}

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

// MARK: - Command–scroll zoom (macOS)

/// Captures Command–scroll-wheel / Command–trackpad-scroll over the preview to adjust zoom.
private struct PreviewCommandScrollZoomMonitor: NSViewRepresentable {
  var onZoomFactor: (CGFloat) -> Void

  func makeNSView(context _: Context) -> PreviewZoomScrollCatcherView {
    let view = PreviewZoomScrollCatcherView()
    view.onZoomFactor = onZoomFactor
    return view
  }

  func updateNSView(_ nsView: PreviewZoomScrollCatcherView, context _: Context) {
    nsView.onZoomFactor = onZoomFactor
  }
}

private final class PreviewZoomScrollCatcherView: NSView {
  var onZoomFactor: ((CGFloat) -> Void)?
  private var monitor: Any?

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window != nil {
      installMonitor()
    } else {
      removeMonitor()
    }
  }

  private func installMonitor() {
    removeMonitor()
    monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      guard let self else { return event }
      guard event.modifierFlags.contains(.command) else { return event }
      guard self.isMouseInside(event) else { return event }

      // Positive scrollingDeltaY (scroll up) zooms in.
      let factor = pow(1.015, event.scrollingDeltaY)
      guard factor.isFinite, abs(factor - 1) > 0.000_1 else { return nil }
      self.onZoomFactor?(factor)
      return nil
    }
  }

  private func removeMonitor() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
  }

  private func isMouseInside(_ event: NSEvent) -> Bool {
    guard let window else { return false }
    let eventWindow = event.window ?? window
    guard eventWindow === window else { return false }
    let locationInWindow = event.locationInWindow
    // Hit-test the SwiftUI host that fills the preview area.
    let hostBounds = superview?.bounds ?? bounds
    let locationInHost =
      superview?.convert(locationInWindow, from: nil)
      ?? convert(locationInWindow, from: nil)
    return hostBounds.contains(locationInHost)
  }
}
