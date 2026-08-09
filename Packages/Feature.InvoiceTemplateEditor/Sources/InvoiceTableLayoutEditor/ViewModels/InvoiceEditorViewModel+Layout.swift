import Accessibility
import Core
import Foundation
import Observation

extension InvoiceEditorViewModel {
  var themePalette: InvoiceThemePalette {
    customAccentColor.map(InvoiceThemePalette.init(customAccentColor:)) ?? accentTheme.palette
  }

  var resolvedDocumentStyle: InvoiceDocumentResolvedStyle {
    InvoiceDocumentResolvedStyle(
      typographyScale: CGFloat(
        InvoiceTemplateLayoutLimits.optionalValue(
          customTypographyScale,
          clampedTo: InvoiceTemplateLayoutLimits.typographyScaleRange
        ) ?? Double(typographyDensity.scale)
      ),
      spacingScale: CGFloat(
        InvoiceTemplateLayoutLimits.optionalValue(
          customSpacingScale,
          clampedTo: InvoiceTemplateLayoutLimits.spacingScaleRange
        ) ?? Double(documentSpacing.scale)
      ),
      borderWidth: CGFloat(
        InvoiceTemplateLayoutLimits.optionalValue(
          customBorderWidth,
          clampedTo: InvoiceTemplateLayoutLimits.borderWidthRange
        ) ?? Double(borderWeight.detailsBorderWidth)
      )
    )
  }

  var effectiveMarginPoints: CGFloat {
    InvoiceTemplateLayoutLimits.effectiveMargin(
      customMarginPoints ?? Double(marginPreset.marginPoints),
      pageSize: pageSizePoints
    )
  }

  var columnVisibility: LineItemColumnVisibility {
    LineItemColumnVisibility(
      showDate: showDateColumn,
      showItemCode: showItemCode,
      showQty: showQtyColumn,
      showUnit: showUnitColumn,
      showRate: showRateColumn
    )
  }

  var templateConfiguration: InvoiceTemplateConfiguration {
    get {
      InvoiceTemplateConfiguration(
        accentTheme: accentTheme,
        customAccentColor: customAccentColor,
        marginPreset: marginPreset,
        customMarginPoints: customMarginPoints,
        customPageWidthPoints: customPageWidthPoints,
        customPageHeightPoints: customPageHeightPoints,
        customTypographyScale: customTypographyScale,
        customSpacingScale: customSpacingScale,
        customBorderWidth: customBorderWidth,
        typographyDensity: typographyDensity,
        taxLabelStyle: taxLabelStyle,
        showPaymentDetails: showPaymentDetails,
        showPaymentTerms: showPaymentTerms,
        showPageNumbers: showPageNumbers,
        showPageNumberChrome: showPageNumberChrome,
        showTitleUnderline: showTitleUnderline,
        showInvoiceDetailLabels: showInvoiceDetailLabels,
        showLineItemsSectionTitle: showLineItemsSectionTitle,
        showLineItemsTableHeader: showLineItemsTableHeader,
        showPartyLabels: showPartyLabels,
        showPartyContactLabels: showPartyContactLabels,
        showPartyCardBorders: showPartyCardBorders,
        showPartyCardFill: showPartyCardFill,
        showPaymentCardBorders: showPaymentCardBorders,
        showPaymentCardFill: showPaymentCardFill,
        showPaymentDetailLabels: showPaymentDetailLabels,
        showPaymentDetailRowRules: showPaymentDetailRowRules,
        showInvoiceDetailsBorders: showInvoiceDetailsBorders,
        showInvoiceDetailGridLines: showInvoiceDetailGridLines,
        showTableGridLines: showTableGridLines,
        showTableZebraRows: showTableZebraRows,
        showTableHeaderFill: showTableHeaderFill,
        showTotalsFill: showTotalsFill,
        columnVisibility: columnVisibility,
        headerStyle: headerStyle,
        partyLayout: partyLayout,
        tableStyle: tableStyle,
        fontFamily: fontFamily,
        dateFormatStyle: dateFormatStyle,
        documentSpacing: documentSpacing,
        showParticipantSection: showParticipantSection,
        showProviderPhone: showProviderPhone,
        showProviderEmail: showProviderEmail,
        showProviderTaxID: showProviderTaxID,
        showIssueDateOnDocument: showIssueDateOnDocument,
        showDueDateOnDocument: showDueDateOnDocument,
        showServiceDatesInDescription: showServiceDatesInDescription,
        showInvoiceNumberOnDocument: showInvoiceNumberOnDocument,
        showTitleOnDocument: showTitleOnDocument,
        borderWeight: borderWeight,
        currencyDisplayStyle: currencyDisplayStyle,
        logoPlacement: logoPlacement,
        totalsEmphasis: totalsEmphasis
      )
    }
    set { applyTemplateConfiguration(newValue) }
  }

  /// Preset that exactly matches the current template fields, if any.
  var matchingTemplatePreset: InvoiceTemplatePreset? {
    InvoiceTemplatePreset.allCases.first { $0.configuration == templateConfiguration }
  }

  var isUsingDefaultTemplate: Bool {
    paperSize == .default
      && pageOrientation == .portrait
      && templateConfiguration == .default
  }

  func applyTemplatePreset(_ preset: InvoiceTemplatePreset) {
    applyTemplateConfiguration(preset.configuration)
    statusMessage = "Applied \(preset.displayName) template."
  }

  func resetTemplateToDefaults() {
    paperSize = .default
    pageOrientation = .portrait
    applyTemplateConfiguration(.default)
    statusMessage = "Template reset to defaults."
  }

  func applyTemplateConfiguration(_ configuration: InvoiceTemplateConfiguration) {
    accentTheme = configuration.accentTheme
    customAccentColor = configuration.customAccentColor
    marginPreset = configuration.marginPreset
    customMarginPoints = configuration.customMarginPoints
    customPageWidthPoints = configuration.customPageWidthPoints
    customPageHeightPoints = configuration.customPageHeightPoints
    typographyDensity = configuration.typographyDensity
    customTypographyScale = configuration.customTypographyScale
    taxLabelStyle = configuration.taxLabelStyle
    showPaymentDetails = configuration.showPaymentDetails
    showPaymentTerms = configuration.showPaymentTerms
    showPageNumbers = configuration.showPageNumbers
    showPageNumberChrome = configuration.showPageNumberChrome
    showTitleUnderline = configuration.showTitleUnderline
    showInvoiceDetailLabels = configuration.showInvoiceDetailLabels
    showLineItemsSectionTitle = configuration.showLineItemsSectionTitle
    showLineItemsTableHeader = configuration.showLineItemsTableHeader
    showPartyLabels = configuration.showPartyLabels
    showPartyContactLabels = configuration.showPartyContactLabels
    showPartyCardBorders = configuration.showPartyCardBorders
    showPartyCardFill = configuration.showPartyCardFill
    showPaymentCardBorders = configuration.showPaymentCardBorders
    showPaymentCardFill = configuration.showPaymentCardFill
    showPaymentDetailLabels = configuration.showPaymentDetailLabels
    showPaymentDetailRowRules = configuration.showPaymentDetailRowRules
    showInvoiceDetailsBorders = configuration.showInvoiceDetailsBorders
    showInvoiceDetailGridLines = configuration.showInvoiceDetailGridLines
    showTableGridLines = configuration.showTableGridLines
    showTableZebraRows = configuration.showTableZebraRows
    showTableHeaderFill = configuration.showTableHeaderFill
    showTotalsFill = configuration.showTotalsFill
    showDateColumn = configuration.columnVisibility.showDate
    showItemCode = configuration.columnVisibility.showItemCode
    showQtyColumn = configuration.columnVisibility.showQty
    showUnitColumn = configuration.columnVisibility.showUnit
    showRateColumn = configuration.columnVisibility.showRate
    headerStyle = configuration.headerStyle
    partyLayout = configuration.partyLayout
    tableStyle = configuration.tableStyle
    fontFamily = configuration.fontFamily
    dateFormatStyle = configuration.dateFormatStyle
    documentSpacing = configuration.documentSpacing
    customSpacingScale = configuration.customSpacingScale
    showParticipantSection = configuration.showParticipantSection
    showProviderPhone = configuration.showProviderPhone
    showProviderEmail = configuration.showProviderEmail
    showProviderTaxID = configuration.showProviderTaxID
    showIssueDateOnDocument = configuration.showIssueDateOnDocument
    showDueDateOnDocument = configuration.showDueDateOnDocument
    showServiceDatesInDescription = configuration.showServiceDatesInDescription
    showInvoiceNumberOnDocument = configuration.showInvoiceNumberOnDocument
    showTitleOnDocument = configuration.showTitleOnDocument
    borderWeight = configuration.borderWeight
    customBorderWidth = configuration.customBorderWidth
    currencyDisplayStyle = configuration.currencyDisplayStyle
    logoPlacement = configuration.logoPlacement
    totalsEmphasis = configuration.totalsEmphasis
  }

  var pageSizePoints: CGSize {
    let standardSize = paperSize.sizePoints(for: pageOrientation)
    return CGSize(
      width: customPageWidthPoints.map(InvoiceTemplateLayoutLimits.pageDimension)
        ?? standardSize.width,
      height: customPageHeightPoints.map(InvoiceTemplateLayoutLimits.pageDimension)
        ?? standardSize.height
    )
  }

  var pageDimensionsLabel: String {
    guard customPageWidthPoints != nil || customPageHeightPoints != nil else {
      return paperSize.dimensionsLabel(for: pageOrientation)
    }
    let size = pageSizePoints
    let width = Double(size.width).formatted(.number.precision(.fractionLength(0...1)))
    let height = Double(size.height).formatted(.number.precision(.fractionLength(0...1)))
    return "\(width) × \(height) pt"
  }

  func updatePageOrientation(_ newOrientation: PageOrientation) {
    guard newOrientation != pageOrientation else { return }
    let hasCustomPageSize = customPageWidthPoints != nil || customPageHeightPoints != nil
    let currentSize = pageSizePoints
    pageOrientation = newOrientation
    if hasCustomPageSize {
      customPageWidthPoints = Double(currentSize.height)
      customPageHeightPoints = Double(currentSize.width)
    }
  }

  var hasCustomPageSize: Bool {
    customPageWidthPoints != nil || customPageHeightPoints != nil
  }

  func useSelectedPaperSize() {
    customPageWidthPoints = nil
    customPageHeightPoints = nil
  }

  var hasCustomMargin: Bool {
    customMarginPoints != nil
  }

  func useSelectedMarginPreset() {
    customMarginPoints = nil
  }

  func updateCustomTypographyScale(_ value: Double) {
    customTypographyScale = InvoiceTemplateLayoutLimits.optionalValue(
      value,
      clampedTo: InvoiceTemplateLayoutLimits.typographyScaleRange
    )
  }

  func updateCustomSpacingScale(_ value: Double) {
    customSpacingScale = InvoiceTemplateLayoutLimits.optionalValue(
      value,
      clampedTo: InvoiceTemplateLayoutLimits.spacingScaleRange
    )
  }

  func updateCustomBorderWidth(_ value: Double) {
    customBorderWidth = InvoiceTemplateLayoutLimits.optionalValue(
      value,
      clampedTo: InvoiceTemplateLayoutLimits.borderWidthRange
    )
  }

  var invoicePages: [InvoicePageContent] {
    _ = pageProjectionRevision
    let expectedToken = invoicePagesCacheToken
    if expectedToken != cachedInvoicePagesToken {
      refreshInvoicePagesProjection()
    }
    return cachedInvoicePages
  }

  private var invoicePagesCacheToken: String {
    if let measuredDimensions {
      return [
        measurementContentToken,
        "measured",
        String(describing: measuredDimensions),
      ].joined(separator: "|")
    }
    return measurementContentToken + "|provisional"
  }

  func refreshInvoicePagesProjection() {
    let token = invoicePagesCacheToken
    let pages: [InvoicePageContent]
    if let measuredDimensions {
      pages = InvoicePagination.paginate(
        input: paginationInput,
        dimensions: measuredDimensions
      )
    } else {
      pages = provisionalPages
    }
    guard token != cachedInvoicePagesToken || pages != cachedInvoicePages else {
      installInvoicePagesTrackingIfNeeded()
      return
    }
    cachedInvoicePagesToken = token
    cachedInvoicePages = pages
    pageProjectionRevision &+= 1
    installInvoicePagesTrackingIfNeeded()
  }

  func installInvoicePagesTrackingIfNeeded() {
    guard !isTrackingInvoicePages else { return }
    isTrackingInvoicePages = true
    withObservationTracking {
      _ = measurementContentToken
      _ = measuredDimensions
      _ = paginationInput
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.isTrackingInvoicePages = false
        self.refreshInvoicePagesProjection()
      }
    }
  }

  var hasUnsavedChanges: Bool {
    if hasInvalidNumericInput { return true }
    guard let savedDraft else { return false }
    return savedDraft != draftPayload
  }

  var hasInvalidNumericInput: Bool {
    !invalidNumericInputIDs.isEmpty
  }

  var revisionConflictTitle: String {
    revisionConflictCanReload
      ? "Invoice Changed in Another Window"
      : "Invoice Deleted in Another Window"
  }

  var revisionConflictMessage: String {
    revisionConflictCanReload
      ? "This invoice was saved in another window. Your draft is still available and has not overwritten those changes. Save it as a new invoice before discarding it to reload the latest version."
      : "This invoice was deleted in another window. Your local draft is still available. Save it as a new invoice before discarding it to close this invoice."
  }

  var hasPendingDiscardTransition: Bool {
    pendingDiscardTransition != nil
  }

  var pendingDiscardTransitionTitle: String {
    switch pendingDiscardTransition {
    case .close:
      "Discard Changes and Close?"
    case .select:
      "Discard Changes and Switch Invoices?"
    case .duplicate:
      "Discard Changes and Duplicate Invoice?"
    case nil:
      "Discard Unsaved Changes?"
    }
  }

  var pendingDiscardTransitionMessage: String {
    switch pendingDiscardTransition {
    case .close:
      "Current draft could not be saved. Discard its unsaved changes and close this invoice?"
    case .select:
      "Current draft could not be saved. Discard its unsaved changes and open selected invoice?"
    case .duplicate:
      "Current draft could not be saved. Discard its unsaved changes and duplicate last saved version?"
    case nil:
      "Current draft could not be saved. Discard its unsaved changes?"
    }
  }

  /// Stable token used to invalidate measurement when draft content changes.
  var paginationMeasurementToken: String {
    measurementContentToken
  }

  var measurementContentToken: String {
    Self.measurementToken([
      invoiceNumber,
      title,
      status.rawValue,
      String(describing: issueDate.timeIntervalSinceReferenceDate),
      String(describing: dueDate.timeIntervalSinceReferenceDate),
      sellerName,
      sellerAddress,
      sellerEmail,
      sellerPhone,
      sellerTaxID,
      billParticipantDirectly ? "1" : "0",
      billToName,
      billToEmail,
      billToAddress,
      billToPhone,
      billingAuthority,
      clientName,
      clientAddress,
      clientEmail,
      clientPhone,
      clientTaxID,
      bankName,
      bankAccountName,
      bankBSB,
      bankAccountNumber,
      currencyCode,
      String(describing: defaultTaxRate),
      paymentTerms,
      notes,
      String(describing: discountAmount),
      String(describing: discountPercent),
      String(describing: creditApplied),
      showsTaxSummary ? "1" : "0",
      paperSize.rawValue,
      customPageWidthPoints.map { "\($0)" } ?? "",
      customPageHeightPoints.map { "\($0)" } ?? "",
      pageOrientation.rawValue,
      accentTheme.rawValue,
      customAccentColor.map { "\($0.red),\($0.green),\($0.blue),\($0.opacity)" } ?? "",
      marginPreset.rawValue,
      customMarginPoints.map { "\($0)" } ?? "",
      typographyDensity.rawValue,
      customTypographyScale.map { "\($0)" } ?? "",
      taxLabelStyle.rawValue,
      showPaymentDetails ? "1" : "0",
      showPaymentTerms ? "1" : "0",
      showPageNumbers ? "1" : "0",
      showPageNumberChrome ? "1" : "0",
      showTitleUnderline ? "1" : "0",
      showInvoiceDetailLabels ? "1" : "0",
      showLineItemsSectionTitle ? "1" : "0",
      showLineItemsTableHeader ? "1" : "0",
      showPartyLabels ? "1" : "0",
      showPartyContactLabels ? "1" : "0",
      showPartyCardBorders ? "1" : "0",
      showPartyCardFill ? "1" : "0",
      showPaymentCardBorders ? "1" : "0",
      showPaymentCardFill ? "1" : "0",
      showPaymentDetailLabels ? "1" : "0",
      showPaymentDetailRowRules ? "1" : "0",
      showInvoiceDetailsBorders ? "1" : "0",
      showInvoiceDetailGridLines ? "1" : "0",
      showTableGridLines ? "1" : "0",
      showTableZebraRows ? "1" : "0",
      showTableHeaderFill ? "1" : "0",
      showTotalsFill ? "1" : "0",
      showDateColumn ? "1" : "0",
      showItemCode ? "1" : "0",
      showQtyColumn ? "1" : "0",
      showUnitColumn ? "1" : "0",
      showRateColumn ? "1" : "0",
      headerStyle.rawValue,
      partyLayout.rawValue,
      tableStyle.rawValue,
      fontFamily.rawValue,
      dateFormatStyle.rawValue,
      documentSpacing.rawValue,
      customSpacingScale.map { "\($0)" } ?? "",
      showParticipantSection ? "1" : "0",
      showProviderPhone ? "1" : "0",
      showProviderEmail ? "1" : "0",
      showProviderTaxID ? "1" : "0",
      showIssueDateOnDocument ? "1" : "0",
      showDueDateOnDocument ? "1" : "0",
      showServiceDatesInDescription ? "1" : "0",
      showInvoiceNumberOnDocument ? "1" : "0",
      showTitleOnDocument ? "1" : "0",
      borderWeight.rawValue,
      customBorderWidth.map { "\($0)" } ?? "",
      currencyDisplayStyle.rawValue,
      logoPlacement.rawValue,
      totalsEmphasis.rawValue,
      Self.measurementToken(lineItems.map(lineItemMeasurementToken)),
    ])
  }

  var provisionalPages: [InvoicePageContent] {
    [
      InvoicePageContent(
        pageIndex: 0,
        totalPages: 1,
        showsDocumentHeader: true,
        showsLineItemsSectionTitle: true,
        lineItemIDs: lineItems.map(\.id),
        showsTableHeader: true,
        showsTotals: true,
        showsFooter: true
      )
    ]
  }

  func updateMeasuredDimensions(_ dimensions: InvoicePagination.MeasuredDimensions) {
    guard measuredDimensions != dimensions else { return }
    measuredDimensions = dimensions
    clampPageIndex()
  }

  func lineItemMeasurementToken(_ item: InvoiceLineItemSnapshot) -> String {
    Self.measurementToken([
      item.id.uuidString,
      String(item.sortOrder),
      item.itemDescription,
      String(describing: item.serviceDate.timeIntervalSinceReferenceDate),
      item.itemCode,
      String(describing: item.quantity),
      item.unit,
      String(describing: item.unitPrice),
      String(describing: item.taxRate),
      item.gstCode,
    ])
  }

  static func measurementToken(_ parts: [String]) -> String {
    parts.map { part in
      "\(part.utf8.count):\(part)"
    }.joined()
  }

  var paginationInput: InvoicePagination.LayoutInput {
    InvoicePagination.LayoutInput(
      lineItems: lineItems,
      paperSize: paperSize,
      pageOrientation: pageOrientation,
      marginPoints: effectiveMarginPoints,
      showPageNumbers: showPageNumbers
    )
  }

  var liveTotals: InvoiceCalculations.InvoiceTotals {
    InvoiceCalculations.invoiceTotals(
      lineItems: lineItems.map(\.calculationInput),
      discountAmount: discountAmount,
      discountPercent: discountPercent,
      creditApplied: creditApplied
    )
  }

}
