import Accessibility
import Core
import Foundation
import Observation

extension InvoiceEditorViewModel {
  var draftPayload: InvoiceDraft {
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

  func requestValidationRecovery() {
    validationRecoveryRequestRevision &+= 1
  }

  func clearInvalidNumericInputs(for itemIDs: [UUID]) {
    let prefixes = itemIDs.flatMap { id in
      let identifier = id.uuidString
      return ["lineItem.\(identifier).", "lineItemTable.\(identifier)."]
    }
    let staleInputIDs = invalidNumericInputIDs.filter { inputID in
      prefixes.contains { inputID.hasPrefix($0) }
    }
    invalidNumericInputIDs.subtract(staleInputIDs)
  }

  func updateLineItem(
    id: UUID,
    mutate: (inout InvoiceLineItemSnapshot) -> Void
  ) {
    guard let index = lineItems.firstIndex(where: { $0.id == id }) else { return }
    mutate(&lineItems[index])
  }

  func applySnapshot(_ snapshot: InvoiceSnapshot) {
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

  func clearDraft() {
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
