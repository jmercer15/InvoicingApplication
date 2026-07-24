import Accessibility
import Core
import Foundation
import Observation

struct InvoiceLineItemRemoval {
  let item: InvoiceLineItemSnapshot
  let index: Int
}

struct InvoiceValidationIssue: Identifiable, Equatable {
  let message: String
  let target: InvoiceInspectorFocusTarget?

  var id: String { message }
}

struct InvoiceLatestRequestActivity: Equatable {
  private(set) var requestID: UUID?

  var isActive: Bool { requestID != nil }

  mutating func begin(_ requestID: UUID) {
    self.requestID = requestID
  }

  mutating func finish(_ requestID: UUID) {
    guard self.requestID == requestID else { return }
    self.requestID = nil
  }
}

enum InvoicePendingDiscardTransition: Equatable {
  case close
  case select(UUID)
  case duplicate
}

enum InvoiceRevisionConflictResolution: Equatable {
  case saveDraftAsNew
  case reloadLatest
  case closeDeleted
}

@Observable
@MainActor
final class InvoiceEditorViewModel {
  private let actor: InvoiceModelActor?
  var mutationHandler: ((InvoiceEditorMutation) -> Void)?

  var selectedInvoiceID: UUID?
  var currentInvoice: InvoiceSnapshot?
  private var loadingActivity = InvoiceLatestRequestActivity()
  var isLoading: Bool { loadingActivity.isActive }
  var isSaving = false
  var isGeneratingDocument = false
  @ObservationIgnored
  let documentActionCancellation = InvoiceDocumentActionCancellation()
  private(set) var isPerformingLifecycleOperation = false
  var statusMessage: String? {
    didSet { statusMessageID = UUID() }
  }

  private(set) var statusMessageID = UUID()
  private(set) var validationRecoveryRequestRevision = 0
  private var savedDraft: InvoiceDraft?
  private var selectionRequestID = UUID()
  private var owningDeletionLeaseToken: UUID?
  private var hasAttemptedSave = false
  private(set) var hasRevisionConflict = false
  private(set) var revisionConflictCanReload = true
  private(set) var isResolvingRevisionConflict = false
  private var pendingDiscardTransition: InvoicePendingDiscardTransition?
  private var invalidNumericInputIDs = Set<String>()

  var currentPageIndex: Int = 0 {
    didSet {
      let maxIndex = max(0, totalPages - 1)
      if currentPageIndex < 0 {
        currentPageIndex = 0
      } else if currentPageIndex > maxIndex {
        currentPageIndex = maxIndex
      }
    }
  }

  var totalPages: Int {
    max(1, invoicePages.count)
  }

  func goToPage(_ index: Int) {
    let target = max(0, min(index, totalPages - 1))
    guard target != currentPageIndex else { return }
    currentPageIndex = target
    postPageAnnouncement()
  }

  func goToNextPage() {
    goToPage(currentPageIndex + 1)
  }

  func goToPreviousPage() {
    goToPage(currentPageIndex - 1)
  }

  func goToFirstPage() {
    goToPage(0)
  }

  func goToLastPage() {
    goToPage(totalPages - 1)
  }

  func postPageAnnouncement() {
    AccessibilityNotification.Announcement("Page \(currentPageIndex + 1) of \(totalPages)").post()
  }

  func clampPageIndex() {
    if currentPageIndex >= totalPages {
      currentPageIndex = max(0, totalPages - 1)
    }
  }

  var isBusy: Bool {
    isLoading || isSaving || isGeneratingDocument || isPerformingLifecycleOperation
  }

  func dismissStatusMessage(id: UUID) {
    guard statusMessageID == id else { return }
    statusMessage = nil
  }

  func cancelActiveDocumentAction() {
    documentActionCancellation.cancel()
  }

  var validationErrors: [String] {
    guard hasAttemptedSave else { return [] }
    var errors = InvoiceValidation.validate(draft: draftPayload).errors
    if hasInvalidNumericInput {
      errors.append("Enter valid numeric values before saving.")
    }
    return errors
  }

  var validationIssues: [InvoiceValidationIssue] {
    validationErrors.map { error in
      InvoiceValidationIssue(
        message: error,
        target: Self.validationFocusTarget(for: error)
      )
    }
  }

  private static func validationFocusTarget(for error: String) -> InvoiceInspectorFocusTarget? {
    if error.hasPrefix("Invoice number") { return .invoiceNumber }
    if error.hasPrefix("Client name") { return .clientName }
    if error.hasPrefix("Due date") { return .dueDate }
    if error.hasPrefix("Currency") { return .currencyCode }
    if error.hasPrefix("Default tax rate") { return .defaultTaxRate }
    if error.hasPrefix("Discount percentage") { return .discountPercent }
    if error.hasPrefix("Discount amount") { return .discountAmount }
    if error.hasPrefix("Credit applied") { return .creditApplied }
    if error.hasPrefix("At least one line item")
      || error.hasPrefix("Duplicate line items")
      || error.hasPrefix("Line item")
    {
      return .lineItems
    }
    return nil
  }

  // Editable draft fields
  var invoiceNumber = ""
  var title = ""
  var status: InvoiceStatus = .draft
  var issueDate = Date.now
  var dueDate = Date.now
  var sellerName = ""
  var sellerAddress = ""
  var sellerEmail = ""
  var sellerPhone = ""
  var sellerTaxID = ""
  var billParticipantDirectly = true
  var billToName = ""
  var billToEmail = ""
  var billToAddress = ""
  var billToPhone = ""
  var billingAuthority = ""
  var selectedClientID: UUID?
  private(set) var clientOptions: [InvoiceClientOption] = []
  private(set) var isLoadingClientOptions = false
  private(set) var clientOptionsLoadError: String?
  private var hasLoadedClientOptions = false
  var clientName = ""
  var clientAddress = ""
  var clientEmail = ""
  var clientPhone = ""
  var clientTaxID = ""
  var bankName = ""
  var bankAccountName = ""
  var bankBSB = ""
  var bankAccountNumber = ""
  var currencyCode = InvoiceCurrencyCode.defaultValue
  var defaultTaxRate: Decimal = 0
  var paymentTerms = ""
  var notes = ""
  var discountAmount: Decimal = 0
  var discountPercent: Decimal = 0
  var creditApplied: Decimal = 0
  var showsTaxSummary = true
  var paperSize: PaperSize = .default
  var customPageWidthPoints: Double?
  var customPageHeightPoints: Double?
  var pageOrientation: PageOrientation = .portrait
  var accentTheme: InvoiceAccentTheme = .default
  var customAccentColor: InvoiceCustomAccentColor?
  var marginPreset: InvoiceMarginPreset = .default
  var customMarginPoints: Double?
  var typographyDensity: InvoiceTypographyDensity = .default
  var customTypographyScale: Double?
  var taxLabelStyle: InvoiceTaxLabelStyle = .default
  var showPaymentDetails: Bool = true
  var showPaymentTerms: Bool = true
  var showPageNumbers: Bool = true
  var showPageNumberChrome: Bool = true
  var showTitleUnderline: Bool = true
  var showInvoiceDetailLabels: Bool = true
  var showLineItemsSectionTitle: Bool = true
  var showLineItemsTableHeader: Bool = true
  var showPartyLabels: Bool = true
  var showPartyContactLabels: Bool = true
  var showPartyCardBorders: Bool = true
  var showPartyCardFill: Bool = true
  var showPaymentCardBorders: Bool = true
  var showPaymentCardFill: Bool = true
  var showPaymentDetailLabels: Bool = true
  var showPaymentDetailRowRules: Bool = true
  var showInvoiceDetailsBorders: Bool = true
  var showInvoiceDetailGridLines: Bool = true
  var showTableGridLines: Bool = true
  var showTableZebraRows: Bool = true
  var showTableHeaderFill: Bool = true
  var showTotalsFill: Bool = true
  var showDateColumn: Bool = true
  var showItemCode: Bool = true
  var showQtyColumn: Bool = true
  var showUnitColumn: Bool = true
  var showRateColumn: Bool = true
  var headerStyle: InvoiceHeaderStyle = .default
  var partyLayout: InvoicePartyLayout = .default
  var tableStyle: InvoiceTableStyle = .default
  var fontFamily: InvoiceFontFamilyPreset = .default
  var dateFormatStyle: InvoiceDateFormatStyle = .default
  var documentSpacing: InvoiceDocumentSpacingPreset = .default
  var customSpacingScale: Double?
  var showParticipantSection: Bool = true
  var showProviderPhone: Bool = true
  var showProviderEmail: Bool = true
  var showProviderTaxID: Bool = true
  var showIssueDateOnDocument: Bool = true
  var showDueDateOnDocument: Bool = true
  var showServiceDatesInDescription: Bool = false
  var showInvoiceNumberOnDocument: Bool = true
  var showTitleOnDocument: Bool = true
  var borderWeight: InvoiceBorderWeight = .default
  var customBorderWidth: Double?
  var currencyDisplayStyle: InvoiceCurrencyDisplayStyle = .default
  var logoPlacement: InvoiceLogoPlacement = .default
  var totalsEmphasis: InvoiceTotalsEmphasis = .default
  var lineItems: [InvoiceLineItemSnapshot] = []

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

  /// Current draft template fields as a configuration snapshot.
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

  var measuredDimensions: InvoicePagination.MeasuredDimensions?

  var invoicePages: [InvoicePageContent] {
    guard let measuredDimensions else {
      return provisionalPages
    }
    return InvoicePagination.paginate(
      input: paginationInput,
      dimensions: measuredDimensions
    )
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

  private var measurementContentToken: String {
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

  private var provisionalPages: [InvoicePageContent] {
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

  private func lineItemMeasurementToken(_ item: InvoiceLineItemSnapshot) -> String {
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

  private static func measurementToken(_ parts: [String]) -> String {
    parts.map { part in
      "\(part.utf8.count):\(part)"
    }.joined()
  }

  private var paginationInput: InvoicePagination.LayoutInput {
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

  private var draftPayload: InvoiceDraft {
    InvoiceDraft(
      clientID: selectedClientID,
      invoiceNumber: invoiceNumber,
      title: title,
      status: status,
      issueDate: issueDate,
      dueDate: dueDate,
      seller: InvoicePartyDraft(
        name: sellerName,
        address: sellerAddress,
        email: sellerEmail,
        phone: sellerPhone,
        taxID: sellerTaxID
      ),
      billing: InvoiceBillingDraft(
        billsParticipantDirectly: billParticipantDirectly,
        recipient: InvoiceBillingRecipientDraft(
          name: billToName,
          address: billToAddress,
          email: billToEmail,
          phone: billToPhone
        ),
        authority: billingAuthority
      ),
      client: InvoicePartyDraft(
        name: clientName,
        address: clientAddress,
        email: clientEmail,
        phone: clientPhone,
        taxID: clientTaxID
      ),
      payment: InvoicePaymentDraft(
        bankName: bankName,
        accountName: bankAccountName,
        bsb: bankBSB,
        accountNumber: bankAccountNumber
      ),
      currencyCode: currencyCode,
      defaultTaxRate: defaultTaxRate,
      paymentTerms: paymentTerms,
      notes: notes,
      adjustments: InvoiceAdjustmentsDraft(
        discountAmount: discountAmount,
        discountPercent: discountPercent,
        creditApplied: creditApplied
      ),
      showsTaxSummary: showsTaxSummary,
      paperSize: paperSize,
      pageOrientation: pageOrientation,
      template: templateConfiguration,
      lineItems: lineItems
    )
  }

  init(actor: InvoiceModelActor) {
    self.actor = actor
  }

  /// Mock-only template workspace. Persistence operations remain unavailable by design.
  init() {
    actor = nil
  }

  private func persistenceActor() throws -> InvoiceModelActor {
    guard let actor else { throw InvoiceModelError.persistenceUnavailable }
    return actor
  }

  /// Loads deterministic preview content without reading or writing invoice persistence.
  func bootstrapMock(template: InvoiceTemplateConfiguration) {
    bootstrapMock(defaults: InvoiceTemplateDefaults(configuration: template))
  }

  /// Applies complete Template Editor defaults before accepting the mock snapshot, keeping
  /// page setup, format state, and the draft baseline synchronized from the first render.
  func bootstrapMock(defaults: InvoiceTemplateDefaults) {
    selectionRequestID = UUID()
    let snapshot = InvoiceTemplateMockData.snapshot(defaults: defaults)
    selectedInvoiceID = snapshot.id
    acceptLoadedSnapshot(snapshot)
    statusMessage = nil
  }

  func loadClientOptions() async {
    guard !isLoadingClientOptions else { return }
    isLoadingClientOptions = true
    clientOptionsLoadError = nil
    defer { isLoadingClientOptions = false }
    do {
      clientOptions = try await persistenceActor().fetchClientOptions()
      hasLoadedClientOptions = true
    } catch {
      let message = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Client records could not be read. Try again."
      )
      clientOptionsLoadError = message
      statusMessage = "Failed to load clients: \(message)"
    }
  }

  /// Cold invoice workspaces may open before a list selection exists. Load picker data when
  /// first document later arrives, while avoiding a fetch on every within-workspace switch.
  func loadClientOptionsIfNeeded() async {
    guard !hasLoadedClientOptions else { return }
    await loadClientOptions()
  }

  func selectClient(id: UUID?) {
    selectedClientID = id
    guard let id,
      let option = clientOptions.first(where: { $0.id == id })
    else { return }

    clientName = option.name
    clientAddress = option.address
    clientEmail = option.email
    clientPhone = option.phone
    clientTaxID = option.taxID
    billParticipantDirectly = option.billsDirectly
    billingAuthority = option.billingAuthority
    billToName = option.billToName
    billToAddress = option.billToAddress
    billToEmail = option.billToEmail
    billToPhone = option.billToPhone
    statusMessage = "Loaded \(option.name) billing details."
  }

  func updateBillingAuthority(_ authority: Core.BillingAuthority?) {
    billingAuthority = authority?.rawValue ?? ""
    billParticipantDirectly = authority == .client
  }

  func bootstrap(preferredInvoiceID: UUID? = nil) async {
    guard !isLoading else { return }
    if let preferredInvoiceID, currentInvoice?.id == preferredInvoiceID {
      selectedInvoiceID = preferredInvoiceID
      return
    }
    let requestID = UUID()
    selectionRequestID = requestID
    loadingActivity.begin(requestID)
    defer { loadingActivity.finish(requestID) }
    guard let preferredInvoiceID else {
      selectedInvoiceID = nil
      currentInvoice = nil
      clearDraft()
      return
    }
    do {
      guard let snapshot = try await persistenceActor().fetchInvoice(id: preferredInvoiceID) else {
        throw InvoiceModelError.invoiceNotFound
      }
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = preferredInvoiceID
      acceptLoadedSnapshot(snapshot)
    } catch {
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = nil
      currentInvoice = nil
      clearDraft()
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be read. Try again."
      )
      statusMessage = "Failed to load invoice: \(detail)"
    }
  }

  /// Opens initial workspace state without bypassing normal draft transitions on re-entry.
  /// `InvoiceEditorSession` outlives feature views, so a later route must save or explicitly
  /// discard its existing draft instead of replacing it through bootstrap.
  func openForWorkspace(requestedInvoiceID: UUID?) async {
    if currentInvoice == nil {
      await bootstrap(preferredInvoiceID: requestedInvoiceID)
    } else {
      await selectInvoice(id: requestedInvoiceID)
    }
  }

  func loadInvoice(id: UUID) async throws {
    guard let snapshot = try await persistenceActor().fetchInvoice(id: id) else {
      if selectedInvoiceID == id {
        selectedInvoiceID = nil
      }
      currentInvoice = nil
      clearDraft()
      throw InvoiceModelError.invoiceNotFound
    }
    acceptLoadedSnapshot(snapshot)
  }

  private func acceptLoadedSnapshot(_ snapshot: InvoiceSnapshot) {
    currentInvoice = snapshot
    applySnapshot(snapshot)
    hasAttemptedSave = false
    hasRevisionConflict = false
    revisionConflictCanReload = true
    pendingDiscardTransition = nil
    invalidNumericInputIDs.removeAll()
    savedDraft = draftPayload
    statusMessage = nil
  }

  func selectInvoice(id: UUID?) async {
    let requestID = UUID()
    selectionRequestID = requestID
    pendingDiscardTransition = nil

    guard let id else {
      guard await waitForActiveOperation() else { return }
      guard selectionRequestID == requestID else { return }
      if hasUnsavedChanges {
        await saveCurrentInvoice(successMessage: "Changes saved.")
        guard selectionRequestID == requestID else { return }
        guard !hasUnsavedChanges else {
          reportBlockedTransition(
            pending: .close,
            validationMessage:
              "Fix the errors in the Validation section before closing this invoice."
          )
          return
        }
      }
      selectedInvoiceID = nil
      currentInvoice = nil
      hasAttemptedSave = false
      statusMessage = nil
      return
    }

    guard id != currentInvoice?.id else {
      return
    }

    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID else { return }

    if hasUnsavedChanges {
      await saveCurrentInvoice(successMessage: "Changes saved.")
      guard selectionRequestID == requestID else { return }
      guard !hasUnsavedChanges else {
        reportBlockedTransition(
          pending: .select(id),
          validationMessage: "Fix the errors in the Validation section before switching invoices."
        )
        return
      }
    }

    loadingActivity.begin(requestID)
    defer { loadingActivity.finish(requestID) }
    do {
      guard let snapshot = try await persistenceActor().fetchInvoice(id: id) else {
        throw InvoiceModelError.invoiceNotFound
      }
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = id
      acceptLoadedSnapshot(snapshot)
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be read. Try again."
      )
      statusMessage = "Failed to load invoice: \(detail)"
    }
  }

  private func waitForActiveOperation() async -> Bool {
    while isSaving || isGeneratingDocument || isPerformingLifecycleOperation {
      do {
        try Task.checkCancellation()
        try await Task.sleep(for: .milliseconds(20))
      } catch {
        return false
      }
    }
    return !Task.isCancelled
  }

  private func waitForActiveOperationBeforeWorkspaceExit() async {
    while isSaving || isGeneratingDocument || isPerformingLifecycleOperation {
      // Workspace teardown can cancel its unstructured task. Final persistence must still wait
      // for document/lifecycle work to release ownership instead of abandoning a valid draft.
      await withCheckedContinuation { continuation in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
          continuation.resume()
        }
      }
    }
  }

  private func reportBlockedTransition(
    pending: InvoicePendingDiscardTransition? = nil,
    validationMessage: String
  ) {
    guard !hasRevisionConflict else { return }
    pendingDiscardTransition = pending
    statusMessage = validationMessage
  }

  func keepEditingAfterBlockedTransition() {
    pendingDiscardTransition = nil
  }

  /// Captures recovery destination before SwiftUI dismisses its confirmation dialog.
  /// Dialog dismissal writes `false` to presentation binding synchronously and may otherwise
  /// clear this payload before button's asynchronous continuation begins.
  func prepareToDiscardDraftAndContinueTransition() -> InvoicePendingDiscardTransition? {
    guard let transition = pendingDiscardTransition else { return nil }
    pendingDiscardTransition = nil
    discardCurrentDraftChanges()
    return transition
  }

  func continueDiscardedTransition(_ transition: InvoicePendingDiscardTransition) async {
    switch transition {
    case .close:
      await selectInvoice(id: nil)
      if selectedInvoiceID == nil {
        statusMessage = "Unsaved changes discarded."
      }
    case .select(let id):
      await selectInvoice(id: id)
      if selectedInvoiceID == id {
        statusMessage = "Unsaved changes discarded."
      }
    case .duplicate:
      await duplicateSelectedInvoice()
    }
  }

  private func discardCurrentDraftChanges() {
    guard let currentInvoice else {
      clearDraft()
      return
    }
    applySnapshot(currentInvoice)
    hasAttemptedSave = false
    invalidNumericInputIDs.removeAll()
    savedDraft = draftPayload
  }

  func saveCurrentInvoice(
    successMessage: String = "Invoice saved.",
    allowsLifecycleOperation: Bool = false
  ) async {
    hasAttemptedSave = true
    guard !hasInvalidNumericInput else {
      statusMessage = "Enter valid numeric values before saving."
      requestValidationRecovery()
      return
    }
    guard let currentInvoice,
      !isSaving,
      allowsLifecycleOperation || !isPerformingLifecycleOperation
    else { return }
    let id = currentInvoice.id
    isSaving = true
    defer { isSaving = false }
    do {
      let result = try await persistenceActor().updateInvoice(
        id: id,
        expectedRevision: currentInvoice.revision,
        draft: draftPayload
      )
      if let savedSnapshot = result.savedSnapshot {
        acceptLoadedSnapshot(savedSnapshot)
        mutationHandler?(.updated(id))
        statusMessage = successMessage
      } else {
        statusMessage =
          result.errors == validationErrors
          ? "Review the Validation section and try again."
          : result.errors.joined(separator: " ")
        requestValidationRecovery()
      }
    } catch InvoiceModelError.revisionConflict {
      hasRevisionConflict = true
      revisionConflictCanReload = true
      statusMessage =
        "Failed to save invoice: \(InvoiceModelError.revisionConflict.localizedDescription)"
    } catch InvoiceModelError.invoiceNotFound {
      hasRevisionConflict = true
      revisionConflictCanReload = false
      statusMessage = "Failed to save invoice: This invoice was deleted in another window."
    } catch {
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be saved. Try again."
      )
      statusMessage = "Failed to save invoice: \(detail)"
    }
  }

  /// Commits current draft before Feature.Invoices creates another record. Creation remains
  /// feature-owned; false prevents orphan rows when validation, persistence, or revision fails.
  func prepareForFeatureOwnedInvoiceCreation() async -> Bool {
    guard !isBusy, !hasRevisionConflict else { return false }
    guard hasUnsavedChanges else { return true }
    await saveCurrentInvoice(successMessage: "Changes saved before creating invoice.")
    return !hasUnsavedChanges && !hasRevisionConflict
  }

  /// Explicit cross-feature navigation waits for current document work, then commits a valid
  /// draft before AppShell changes tabs. Failed validation or revision ownership keeps user in
  /// Invoices with existing recovery UI visible.
  func prepareForWorkspaceHandoff() async -> Bool {
    guard !hasRevisionConflict else { return false }
    await waitForActiveOperationBeforeWorkspaceExit()
    guard !hasRevisionConflict else { return false }
    guard hasUnsavedChanges else { return true }
    await saveCurrentInvoice(successMessage: "Changes saved.")
    return !hasUnsavedChanges && !hasRevisionConflict
  }

  /// Persists a valid draft when its workspace leaves the hierarchy. Invalid drafts remain in
  /// the owning ``InvoiceEditorSession`` and reappear when the user returns to Invoices.
  func saveBeforeLeavingWorkspace() async {
    guard hasUnsavedChanges, !hasRevisionConflict else { return }
    await waitForActiveOperationBeforeWorkspaceExit()
    // Active work may have saved, replaced, or conflicted with this draft while we waited.
    guard hasUnsavedChanges, !hasRevisionConflict else { return }
    await saveCurrentInvoice(successMessage: "Changes saved.")
  }

  func keepEditingAfterRevisionConflict() {
    guard !isResolvingRevisionConflict else { return }
    hasRevisionConflict = false
    revisionConflictCanReload = true
  }

  func beginRevisionConflictResolution(
    _ resolution: InvoiceRevisionConflictResolution
  ) -> InvoiceRevisionConflictResolution? {
    guard hasRevisionConflict, !isResolvingRevisionConflict else { return nil }
    switch resolution {
    case .saveDraftAsNew:
      guard hasUnsavedChanges else { return nil }
    case .reloadLatest:
      guard revisionConflictCanReload else { return nil }
    case .closeDeleted:
      guard !revisionConflictCanReload else { return nil }
    }
    isResolvingRevisionConflict = true
    return resolution
  }

  func continueRevisionConflictResolution(
    _ resolution: InvoiceRevisionConflictResolution
  ) async {
    defer { isResolvingRevisionConflict = false }
    switch resolution {
    case .saveDraftAsNew:
      await saveRevisionConflictAsNewInvoice()
    case .reloadLatest:
      await reloadAfterRevisionConflict()
    case .closeDeleted:
      await closeDeletedInvoiceAfterRevisionConflict()
    }
  }

  private func reloadAfterRevisionConflict() async {
    guard revisionConflictCanReload, !isBusy else { return }
    guard let id = currentInvoice?.id else {
      hasRevisionConflict = false
      return
    }
    let requestID = UUID()
    selectionRequestID = requestID
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    do {
      // Do not use `loadInvoice` here: its normal selection behavior clears
      // the draft when a record is missing. A second window can delete this
      // invoice after the conflict is detected but before this reload runs;
      // the user's unsaved draft must remain available in that case.
      guard let snapshot = try await persistenceActor().fetchInvoice(id: id) else {
        guard selectionRequestID == requestID else { return }
        hasRevisionConflict = true
        revisionConflictCanReload = false
        statusMessage =
          "This invoice was deleted in another window. Your local draft is still available."
        return
      }
      guard selectionRequestID == requestID else { return }
      acceptLoadedSnapshot(snapshot)
      statusMessage = "Reloaded the latest saved invoice."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Latest invoice data could not be read. Try again."
      )
      statusMessage = "Failed to reload invoice: \(detail)"
    }
  }

  private func closeDeletedInvoiceAfterRevisionConflict() async {
    guard let id = currentInvoice?.id else { return }
    await closeInvoiceDeletedExternally(id: id)
  }

  func prepareForOwningDeletion(
    invoiceIDs: Set<UUID>
  ) async -> InvoiceEditorDeletionLease? {
    guard let activeID = currentInvoice?.id ?? selectedInvoiceID,
      invoiceIDs.contains(activeID)
    else { return nil }

    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return nil }
    guard selectionRequestID == requestID,
      !isPerformingLifecycleOperation,
      let currentActiveID = currentInvoice?.id ?? selectedInvoiceID,
      invoiceIDs.contains(currentActiveID)
    else { return nil }

    isPerformingLifecycleOperation = true
    owningDeletionLeaseToken = requestID
    return InvoiceEditorDeletionLease(token: requestID, invoiceID: currentActiveID)
  }

  func completeOwningDeletion(
    lease: InvoiceEditorDeletionLease,
    deletedInvoiceIDs: Set<UUID>
  ) {
    guard owningDeletionLeaseToken == lease.token else { return }
    defer { releaseOwningDeletionLease() }
    guard deletedInvoiceIDs.contains(lease.invoiceID),
      currentInvoice?.id == lease.invoiceID || selectedInvoiceID == lease.invoiceID
    else { return }

    selectedInvoiceID = nil
    currentInvoice = nil
    clearDraft()
    statusMessage = "Closed the deleted invoice."
  }

  func cancelOwningDeletion(lease: InvoiceEditorDeletionLease) {
    guard owningDeletionLeaseToken == lease.token else { return }
    releaseOwningDeletionLease()
  }

  private func releaseOwningDeletionLease() {
    owningDeletionLeaseToken = nil
    isPerformingLifecycleOperation = false
  }

  func closeInvoiceDeletedExternally(id: UUID) async {
    // Owning-feature deletion is authoritative. Supersede any in-flight lifecycle request and
    // wait for it to release mutation ownership; returning early would leave a deleted invoice
    // open in the editor with a stale draft.
    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID, !isPerformingLifecycleOperation else { return }
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    guard currentInvoice?.id == id || selectedInvoiceID == id else { return }
    selectedInvoiceID = nil
    currentInvoice = nil
    clearDraft()
    statusMessage = "Closed the deleted invoice."
  }

  private func saveRevisionConflictAsNewInvoice() async {
    guard !isBusy else { return }
    hasAttemptedSave = true
    guard validationErrors.isEmpty else {
      hasRevisionConflict = false
      statusMessage = "Review the Validation section before saving as a new invoice."
      requestValidationRecovery()
      return
    }

    let requestID = UUID()
    selectionRequestID = requestID
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    do {
      let newID = try await persistenceActor().createInvoice(from: draftPayload)
      mutationHandler?(.inserted(newID))
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = newID
      try await loadInvoice(id: newID)
      guard selectionRequestID == requestID else { return }
      statusMessage = "Saved your draft as a new invoice."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be created. Try again."
      )
      statusMessage = "Failed to save draft as a new invoice: \(detail)"
    }
  }

  func deleteSelectedInvoice() async {
    guard !isPerformingLifecycleOperation else { return }
    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID, !isPerformingLifecycleOperation else { return }
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }
    guard let invoice = currentInvoice else { return }
    do {
      try await persistenceActor().deleteInvoice(
        id: invoice.id,
        expectedRevision: invoice.revision
      )
      currentInvoice = nil
      clearDraft()
      mutationHandler?(.deleted(invoice.id))
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = nil
      statusMessage = "Invoice deleted."
    } catch InvoiceModelError.revisionConflict {
      guard selectionRequestID == requestID else { return }
      hasRevisionConflict = true
      revisionConflictCanReload = true
      statusMessage =
        "Failed to delete invoice: \(InvoiceModelError.revisionConflict.localizedDescription)"
    } catch InvoiceModelError.invoiceNotFound {
      guard selectionRequestID == requestID else { return }
      hasRevisionConflict = true
      revisionConflictCanReload = false
      statusMessage = "Failed to delete invoice: This invoice was deleted in another window."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be deleted. Try again."
      )
      statusMessage = "Failed to delete invoice: \(detail)"
    }
  }

  func duplicateSelectedInvoice() async {
    guard !isPerformingLifecycleOperation else { return }
    let requestID = UUID()
    selectionRequestID = requestID
    guard await waitForActiveOperation() else { return }
    guard selectionRequestID == requestID, !isPerformingLifecycleOperation else { return }
    isPerformingLifecycleOperation = true
    defer { isPerformingLifecycleOperation = false }

    if hasUnsavedChanges {
      await saveCurrentInvoice(
        successMessage: "Changes saved.",
        allowsLifecycleOperation: true
      )
      guard selectionRequestID == requestID else { return }
      guard !hasUnsavedChanges else {
        reportBlockedTransition(
          pending: .duplicate,
          validationMessage:
            "Fix the errors in the Validation section before duplicating this invoice."
        )
        return
      }
    }

    guard let id = currentInvoice?.id else { return }
    do {
      let newID = try await persistenceActor().duplicateInvoice(id: id)
      mutationHandler?(.inserted(newID))
      guard selectionRequestID == requestID else { return }
      selectedInvoiceID = newID
      try await loadInvoice(id: newID)
      guard selectionRequestID == requestID else { return }
      statusMessage = "Invoice duplicated."
    } catch {
      guard selectionRequestID == requestID else { return }
      let detail = InvoiceOperationErrorPresentation.detail(
        for: error,
        fallback: "Invoice data could not be duplicated. Try again."
      )
      statusMessage = "Failed to duplicate invoice: \(detail)"
    }
  }

  @discardableResult
  func addLineItem() -> UUID {
    let nextOrder = (lineItems.map(\.sortOrder).max() ?? -1) + 1
    let item = InvoiceLineItemSnapshot(
      sortOrder: nextOrder,
      quantity: 1,
      unitPrice: 0,
      taxRate: defaultTaxRate
    )
    lineItems.append(item)
    return item.id
  }

  func updateIssueDate(_ newIssueDate: Date, calendar: Calendar = .current) {
    let paymentTermDays = max(
      calendar.dateComponents([.day], from: issueDate, to: dueDate).day ?? 0,
      0
    )
    issueDate = newIssueDate

    if dueDate < newIssueDate {
      dueDate =
        calendar.date(
          byAdding: .day,
          value: paymentTermDays,
          to: newIssueDate
        ) ?? newIssueDate
    }
  }

  /// Keeps the date range valid as the user edits, rather than deferring a
  /// recoverable error until save time. Validation still enforces the same
  /// invariant for imported and programmatic drafts.
  func updateDueDate(_ newDueDate: Date) {
    dueDate = max(issueDate, newDueDate)
  }

  /// Keeps the persisted adjustment unambiguous: a percentage discount takes
  /// precedence in calculations, so entering one clears any fixed discount.
  func updateDiscountPercent(_ value: Decimal) {
    discountPercent = value
    if value != 0 {
      discountAmount = 0
    }
  }

  /// Selecting a fixed discount replaces any percentage discount.
  func updateDiscountAmount(_ value: Decimal) {
    discountAmount = value
    if value != 0 {
      discountPercent = 0
    }
  }

  func removeLineItems(at offsets: IndexSet) {
    let removedIDs = offsets.compactMap { index in
      lineItems.indices.contains(index) ? lineItems[index].id : nil
    }
    lineItems.remove(atOffsets: offsets)
    clearInvalidNumericInputs(for: removedIDs)
    for index in lineItems.indices {
      updateLineItem(id: lineItems[index].id) { $0.sortOrder = index }
    }
    measuredDimensions = nil
    clampPageIndex()
  }

  func removeLineItem(id: UUID) {
    _ = removeLineItemForUndo(id: id)
  }

  func removeLineItemForUndo(id: UUID) -> InvoiceLineItemRemoval? {
    guard let index = lineItems.firstIndex(where: { $0.id == id }) else { return nil }
    let removal = InvoiceLineItemRemoval(item: lineItems[index], index: index)
    removeLineItems(at: IndexSet(integer: index))
    return removal
  }

  func restoreLineItem(_ removal: InvoiceLineItemRemoval) {
    lineItems.insert(removal.item, at: min(max(removal.index, 0), lineItems.count))
    for index in lineItems.indices {
      updateLineItem(id: lineItems[index].id) { $0.sortOrder = index }
    }
    measuredDimensions = nil
    clampPageIndex()
  }

  func updateLineItemDescription(id: UUID, description: String) {
    updateLineItem(id: id) { $0.itemDescription = description }
  }

  func updateLineItemQuantity(id: UUID, quantity: Decimal) {
    updateLineItem(id: id) { $0.quantity = quantity }
  }

  func updateLineItemUnitPrice(id: UUID, unitPrice: Decimal) {
    updateLineItem(id: id) { $0.unitPrice = unitPrice }
  }

  func updateLineItemTaxRate(id: UUID, taxRate: Decimal) {
    updateLineItem(id: id) { $0.taxRate = taxRate }
  }

  func updateLineItemServiceDate(id: UUID, serviceDate: Date) {
    updateLineItem(id: id) { $0.serviceDate = serviceDate }
  }

  func updateLineItemCode(id: UUID, itemCode: String) {
    updateLineItem(id: id) { $0.itemCode = itemCode }
  }

  func updateLineItemUnit(id: UUID, unit: String) {
    updateLineItem(id: id) { $0.unit = unit }
  }

  func updateLineItemGSTCode(id: UUID, gstCode: String) {
    updateLineItem(id: id) { $0.gstCode = gstCode }
  }

  func updateNumericInputValidity(id: String, isInvalid: Bool) {
    if isInvalid {
      invalidNumericInputIDs.insert(id)
    } else {
      invalidNumericInputIDs.remove(id)
    }
  }

  private func requestValidationRecovery() {
    validationRecoveryRequestRevision &+= 1
  }

  private func clearInvalidNumericInputs(for itemIDs: [UUID]) {
    let prefixes = itemIDs.flatMap { id in
      let identifier = id.uuidString
      return ["lineItem.\(identifier).", "lineItemTable.\(identifier)."]
    }
    let staleInputIDs = invalidNumericInputIDs.filter { inputID in
      prefixes.contains { inputID.hasPrefix($0) }
    }
    invalidNumericInputIDs.subtract(staleInputIDs)
  }

  private func updateLineItem(
    id: UUID,
    mutate: (inout InvoiceLineItemSnapshot) -> Void
  ) {
    guard let index = lineItems.firstIndex(where: { $0.id == id }) else { return }
    mutate(&lineItems[index])
  }

  private func applySnapshot(_ snapshot: InvoiceSnapshot) {
    let previousMeasurementToken = measurementContentToken
    selectedClientID = snapshot.clientID
    invoiceNumber = snapshot.invoiceNumber
    title = snapshot.title
    status = snapshot.status
    issueDate = snapshot.issueDate
    dueDate = snapshot.dueDate
    sellerName = snapshot.sellerName
    sellerAddress = snapshot.sellerAddress
    sellerEmail = snapshot.sellerEmail
    sellerPhone = snapshot.sellerPhone
    sellerTaxID = snapshot.sellerTaxID
    billParticipantDirectly = snapshot.billParticipantDirectly
    billToName = snapshot.billToName
    billToEmail = snapshot.billToEmail
    billToAddress = snapshot.billToAddress
    billToPhone = snapshot.billToPhone
    billingAuthority = snapshot.billingAuthority
    clientName = snapshot.clientName
    clientAddress = snapshot.clientAddress
    clientEmail = snapshot.clientEmail
    clientPhone = snapshot.clientPhone
    clientTaxID = snapshot.clientTaxID
    bankName = snapshot.bankName
    bankAccountName = snapshot.bankAccountName
    bankBSB = snapshot.bankBSB
    bankAccountNumber = snapshot.bankAccountNumber
    currencyCode = snapshot.currencyCode
    defaultTaxRate = snapshot.defaultTaxRate
    paymentTerms = snapshot.paymentTerms
    notes = snapshot.notes
    discountAmount = snapshot.discountAmount
    discountPercent = snapshot.discountPercent
    creditApplied = snapshot.creditApplied
    showsTaxSummary = snapshot.showsTaxSummary
    paperSize = snapshot.paperSize
    pageOrientation = snapshot.pageOrientation
    applyTemplateConfiguration(snapshot.templateConfiguration)
    lineItems = snapshot.lineItems
    if previousMeasurementToken != measurementContentToken {
      measuredDimensions = nil
    }
  }

  private func clearDraft() {
    let now = Date.now
    savedDraft = nil
    hasAttemptedSave = false
    hasRevisionConflict = false
    revisionConflictCanReload = true
    pendingDiscardTransition = nil
    invalidNumericInputIDs.removeAll()
    invoiceNumber = ""
    title = ""
    status = .draft
    issueDate = now
    dueDate = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
    sellerName = ""
    sellerAddress = ""
    sellerEmail = ""
    sellerPhone = ""
    sellerTaxID = ""
    billParticipantDirectly = true
    billToName = ""
    billToEmail = ""
    billToAddress = ""
    billToPhone = ""
    billingAuthority = ""
    selectedClientID = nil
    clientName = ""
    clientAddress = ""
    clientEmail = ""
    clientPhone = ""
    clientTaxID = ""
    bankName = ""
    bankAccountName = ""
    bankBSB = ""
    bankAccountNumber = ""
    currencyCode = InvoiceCurrencyCode.defaultValue
    defaultTaxRate = 0
    paymentTerms = ""
    notes = ""
    discountAmount = 0
    discountPercent = 0
    creditApplied = 0
    showsTaxSummary = true
    paperSize = .default
    customPageWidthPoints = nil
    customPageHeightPoints = nil
    pageOrientation = .portrait
    accentTheme = .default
    customAccentColor = nil
    marginPreset = .default
    customMarginPoints = nil
    typographyDensity = .default
    customTypographyScale = nil
    taxLabelStyle = .default
    showPaymentDetails = true
    showPaymentTerms = true
    showPageNumbers = true
    showPageNumberChrome = true
    showTitleUnderline = true
    showInvoiceDetailLabels = true
    showLineItemsSectionTitle = true
    showLineItemsTableHeader = true
    showPartyLabels = true
    showPartyContactLabels = true
    showPartyCardBorders = true
    showPartyCardFill = true
    showPaymentCardBorders = true
    showPaymentCardFill = true
    showPaymentDetailLabels = true
    showPaymentDetailRowRules = true
    showInvoiceDetailsBorders = true
    showInvoiceDetailGridLines = true
    showTableGridLines = true
    showTableZebraRows = true
    showTableHeaderFill = true
    showTotalsFill = true
    showDateColumn = true
    showItemCode = true
    showQtyColumn = true
    showUnitColumn = true
    showRateColumn = true
    headerStyle = .default
    partyLayout = .default
    tableStyle = .default
    fontFamily = .default
    dateFormatStyle = .default
    documentSpacing = .default
    customSpacingScale = nil
    showParticipantSection = true
    showProviderPhone = true
    showProviderEmail = true
    showProviderTaxID = true
    showIssueDateOnDocument = true
    showDueDateOnDocument = true
    showServiceDatesInDescription = false
    showInvoiceNumberOnDocument = true
    showTitleOnDocument = true
    borderWeight = .default
    customBorderWidth = nil
    currencyDisplayStyle = .default
    logoPlacement = .default
    totalsEmphasis = .default
    lineItems = []
    measuredDimensions = nil
  }
}
