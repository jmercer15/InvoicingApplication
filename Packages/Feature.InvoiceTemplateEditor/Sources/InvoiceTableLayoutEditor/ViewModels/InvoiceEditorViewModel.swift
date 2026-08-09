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
  let actor: InvoiceModelActor?
  var mutationHandler: ((InvoiceEditorMutation) -> Void)?

  var selectedInvoiceID: UUID?
  var currentInvoice: InvoiceSnapshot?
  var loadingActivity = InvoiceLatestRequestActivity()
  var isLoading: Bool { loadingActivity.isActive }
  var isSaving = false
  var isGeneratingDocument = false
  @ObservationIgnored
  let documentActionCancellation = InvoiceDocumentActionCancellation()
  var isPerformingLifecycleOperation = false
  var statusMessage: String? {
    didSet { statusMessageID = UUID() }
  }

  private(set) var statusMessageID = UUID()
  var validationRecoveryRequestRevision = 0
  var savedDraft: InvoiceDraft?
  var selectionRequestID = UUID()
  var owningDeletionLeaseToken: UUID?
  var hasAttemptedSave = false {
    didSet {
      if hasAttemptedSave {
        refreshValidationProjection()
        installValidationTrackingIfNeeded()
      } else {
        validationProjection.clear()
        isTrackingValidation = false
      }
    }
  }
  var hasRevisionConflict = false
  var revisionConflictCanReload = true
  var isResolvingRevisionConflict = false
  var pendingDiscardTransition: InvoicePendingDiscardTransition?
  var invalidNumericInputIDs = Set<String>()

  /// Validation UI observes this object instead of re-entering `draftPayload` on every keystroke.
  let validationProjection = InvoiceEditorValidationProjection()
  @ObservationIgnored
  private var isTrackingValidation = false

  @ObservationIgnored
  var cachedInvoicePages: [InvoicePageContent] = []
  @ObservationIgnored
  var cachedInvoicePagesToken: String = ""
  @ObservationIgnored
  var isTrackingInvoicePages = false
  var pageProjectionRevision = 0

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
    validationProjection.errors
  }

  var validationIssues: [InvoiceValidationIssue] {
    validationProjection.issues
  }

  func refreshValidationProjection() {
    guard hasAttemptedSave else {
      validationProjection.clear()
      return
    }
    var errors = InvoiceValidation.validate(draft: draftPayload).errors
    if hasInvalidNumericInput {
      errors.append("Enter valid numeric values before saving.")
    }
    let issues = errors.map { error in
      InvoiceValidationIssue(
        message: error,
        target: validationFocusTarget(for: error)
      )
    }
    validationProjection.apply(errors: errors, issues: issues)
  }

  func installValidationTrackingIfNeeded() {
    guard hasAttemptedSave, !isTrackingValidation else { return }
    isTrackingValidation = true
    withObservationTracking {
      _ = draftPayload
      _ = hasInvalidNumericInput
      _ = hasAttemptedSave
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.isTrackingValidation = false
        if self.hasAttemptedSave {
          self.refreshValidationProjection()
          self.installValidationTrackingIfNeeded()
        } else {
          self.validationProjection.clear()
        }
      }
    }
  }

  func validationFocusTarget(for error: String) -> InvoiceInspectorFocusTarget? {
    if error.hasPrefix("Invoice number") { return .invoiceNumber }
    if error.hasPrefix("Client name") { return .clientName }
    if error.hasPrefix("Due date") { return .dueDate }
    if error.hasPrefix("Currency") { return .currencyCode }
    if error.hasPrefix("Default tax rate") { return .defaultTaxRate }
    if error.hasPrefix("Discount percentage") { return .discountPercent }
    if error.hasPrefix("Discount amount") { return .discountAmount }
    if error.hasPrefix("Credit applied") { return .creditApplied }
    if error.hasPrefix("At least one line item") || error.hasPrefix("Duplicate line items") {
      return .lineItems
    }
    if error.hasPrefix("Line item quantity") {
      if let item = lineItems.first(where: { $0.quantity <= 0 }) {
        return .lineItemQuantity(item.id)
      }
      return .lineItems
    }
    if error.hasPrefix("Line item tax rate") {
      if let item = lineItems.first(where: { $0.taxRate < 0 || $0.taxRate > 100 }) {
        return .lineItemTaxRate(item.id)
      }
      return .lineItems
    }
    if error.hasPrefix("Line item") {
      if let item = lineItems.first(where: { $0.unitPrice < 0 }) {
        return .lineItemUnitPrice(item.id)
      }
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
  var clientOptions: [InvoiceClientOption] = []
  var isLoadingClientOptions = false
  var clientOptionsLoadError: String?
  var hasLoadedClientOptions = false
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
  var pdfTitleOverride: String?
  var pdfNotesOverride: String?
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
  var measuredDimensions: InvoicePagination.MeasuredDimensions?

  var documentTitleForRender: String {
    pdfTitleOverride ?? title
  }

  var notesForRender: String {
    pdfNotesOverride ?? notes
  }

  func applyPDFPresentation(_ presentation: InvoicePDFPresentation) {
    switch presentation {
    case .invoice:
      pdfTitleOverride = nil
      pdfNotesOverride = nil
    case .receipt(let paymentSummary):
      pdfTitleOverride = "Receipt"
      let trimmedSummary = paymentSummary.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmedSummary.isEmpty {
        pdfNotesOverride = notes
      } else if notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        pdfNotesOverride = trimmedSummary
      } else {
        pdfNotesOverride = trimmedSummary + "\n\n" + notes
      }
    }
  }

  func clearPDFPresentationOverrides() {
    pdfTitleOverride = nil
    pdfNotesOverride = nil
  }

  init(actor: InvoiceModelActor) {
    self.actor = actor
  }

  /// Mock-only template workspace. Persistence operations remain unavailable by design.
  init() {
    actor = nil
  }

  func persistenceActor() throws -> InvoiceModelActor {
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

}
