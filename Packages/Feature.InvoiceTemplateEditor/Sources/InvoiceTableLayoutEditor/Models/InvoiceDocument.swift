import Core
import Foundation
final class InvoiceDocument {
    var id: UUID
    var invoiceNumber: String
    var title: String
    var statusRaw: String
    var issueDate: Date
    var dueDate: Date
    /// Incremented after each successful edit save for optimistic concurrency checks.
    var revision: Int = 0

    // Seller / business
    var sellerName: String
    var sellerAddress: String
    var sellerEmail: String
    var sellerPhone: String = ""
    var sellerTaxID: String

    /// When true, Billed To mirrors the participant (For) section.
    /// When false, bill-to fields identify the invoice recipient.
    var billParticipantDirectly: Bool = true

    // Bill To (billing contact — plan manager, parent/guardian, etc.)
    var billToName: String = ""
    var billToEmail: String = ""
    var billToAddress: String = ""
    var billToPhone: String = ""
    var billingAuthority: String = ""

    // Client / participant
    var clientName: String
    var clientAddress: String
    var clientEmail: String
    var clientPhone: String = ""
    var clientTaxID: String

    // Payment details
    var bankName: String = ""
    var bankAccountName: String = ""
    var bankBSB: String = ""
    var bankAccountNumber: String = ""

    // Settings
    var currencyCode: String
    var defaultTaxRate: Decimal
    var paymentTerms: String
    var notes: String
    var discountAmount: Decimal
    var discountPercent: Decimal = 0
    var creditApplied: Decimal = 0
    var showsTaxSummary: Bool = true

    // Page layout (declaration defaults support SwiftData lightweight migration)
    var paperSizeRaw: String = PaperSize.default.rawValue
    var orientationRaw: String = PageOrientation.portrait.rawValue

    // Template appearance (defaults support SwiftData lightweight migration)
    var accentThemeRaw: String = InvoiceAccentTheme.default.rawValue
    var customAccentRed: Double?
    var customAccentGreen: Double?
    var customAccentBlue: Double?
    var customAccentOpacity: Double?
    var marginPresetRaw: String = InvoiceMarginPreset.default.rawValue
    var customMarginPoints: Double?
    var customPageWidthPoints: Double?
    var customPageHeightPoints: Double?
    var typographyDensityRaw: String = InvoiceTypographyDensity.default.rawValue
    var customTypographyScale: Double?
    var taxLabelStyleRaw: String = InvoiceTaxLabelStyle.default.rawValue
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
    var headerStyleRaw: String = InvoiceHeaderStyle.default.rawValue
    var partyLayoutRaw: String = InvoicePartyLayout.default.rawValue
    var tableStyleRaw: String = InvoiceTableStyle.default.rawValue
    var fontFamilyRaw: String = InvoiceFontFamilyPreset.default.rawValue
    var dateFormatStyleRaw: String = InvoiceDateFormatStyle.default.rawValue
    var documentSpacingRaw: String = InvoiceDocumentSpacingPreset.default.rawValue
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
    var borderWeightRaw: String = InvoiceBorderWeight.default.rawValue
    var customBorderWidth: Double?
    var currencyDisplayStyleRaw: String = InvoiceCurrencyDisplayStyle.default.rawValue
    var logoPlacementRaw: String = InvoiceLogoPlacement.default.rawValue
    var totalsEmphasisRaw: String = InvoiceTotalsEmphasis.default.rawValue

    // Persisted totals (recalculated on save)
    var subtotal: Decimal
    var taxTotal: Decimal
    var grandTotal: Decimal

    var lineItems: [InvoiceLineItem]?

    var status: InvoiceStatus {
        get { InvoiceStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    var paperSize: PaperSize {
        get { PaperSize(rawValue: paperSizeRaw) ?? .default }
        set { paperSizeRaw = newValue.rawValue }
    }

    var pageOrientation: PageOrientation {
        get { PageOrientation(rawValue: orientationRaw) ?? .portrait }
        set { orientationRaw = newValue.rawValue }
    }

    var accentTheme: InvoiceAccentTheme {
        get { InvoiceAccentTheme(rawValue: accentThemeRaw) ?? .default }
        set { accentThemeRaw = newValue.rawValue }
    }

    var marginPreset: InvoiceMarginPreset {
        get { InvoiceMarginPreset(rawValue: marginPresetRaw) ?? .default }
        set { marginPresetRaw = newValue.rawValue }
    }

    var typographyDensity: InvoiceTypographyDensity {
        get { InvoiceTypographyDensity(rawValue: typographyDensityRaw) ?? .default }
        set { typographyDensityRaw = newValue.rawValue }
    }

    var taxLabelStyle: InvoiceTaxLabelStyle {
        get { InvoiceTaxLabelStyle(rawValue: taxLabelStyleRaw) ?? .default }
        set { taxLabelStyleRaw = newValue.rawValue }
    }

    var columnVisibility: LineItemColumnVisibility {
        get {
            LineItemColumnVisibility(
                showDate: showDateColumn,
                showItemCode: showItemCode,
                showQty: showQtyColumn,
                showUnit: showUnitColumn,
                showRate: showRateColumn
            )
        }
        set {
            showDateColumn = newValue.showDate
            showItemCode = newValue.showItemCode
            showQtyColumn = newValue.showQty
            showUnitColumn = newValue.showUnit
            showRateColumn = newValue.showRate
        }
    }

    var headerStyle: InvoiceHeaderStyle {
        get { InvoiceHeaderStyle(rawValue: headerStyleRaw) ?? .default }
        set { headerStyleRaw = newValue.rawValue }
    }

    var partyLayout: InvoicePartyLayout {
        get { InvoicePartyLayout(rawValue: partyLayoutRaw) ?? .default }
        set { partyLayoutRaw = newValue.rawValue }
    }

    var tableStyle: InvoiceTableStyle {
        get { InvoiceTableStyle(rawValue: tableStyleRaw) ?? .default }
        set { tableStyleRaw = newValue.rawValue }
    }

    var fontFamily: InvoiceFontFamilyPreset {
        get { InvoiceFontFamilyPreset(rawValue: fontFamilyRaw) ?? .default }
        set { fontFamilyRaw = newValue.rawValue }
    }

    var dateFormatStyle: InvoiceDateFormatStyle {
        get { InvoiceDateFormatStyle(rawValue: dateFormatStyleRaw) ?? .default }
        set { dateFormatStyleRaw = newValue.rawValue }
    }

    var documentSpacing: InvoiceDocumentSpacingPreset {
        get { InvoiceDocumentSpacingPreset(rawValue: documentSpacingRaw) ?? .default }
        set { documentSpacingRaw = newValue.rawValue }
    }

    var borderWeight: InvoiceBorderWeight {
        get { InvoiceBorderWeight(rawValue: borderWeightRaw) ?? .default }
        set { borderWeightRaw = newValue.rawValue }
    }

    var currencyDisplayStyle: InvoiceCurrencyDisplayStyle {
        get { InvoiceCurrencyDisplayStyle(rawValue: currencyDisplayStyleRaw) ?? .default }
        set { currencyDisplayStyleRaw = newValue.rawValue }
    }

    var logoPlacement: InvoiceLogoPlacement {
        get { InvoiceLogoPlacement(rawValue: logoPlacementRaw) ?? .default }
        set { logoPlacementRaw = newValue.rawValue }
    }

    var totalsEmphasis: InvoiceTotalsEmphasis {
        get { InvoiceTotalsEmphasis(rawValue: totalsEmphasisRaw) ?? .default }
        set { totalsEmphasisRaw = newValue.rawValue }
    }

    /// Current template appearance as a configuration snapshot (for presets / reset).
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
        set {
            accentTheme = newValue.accentTheme
            customAccentColor = newValue.customAccentColor
            marginPreset = newValue.marginPreset
            customMarginPoints = newValue.customMarginPoints
            customPageWidthPoints = newValue.customPageWidthPoints
            customPageHeightPoints = newValue.customPageHeightPoints
            typographyDensity = newValue.typographyDensity
            customTypographyScale = newValue.customTypographyScale
            taxLabelStyle = newValue.taxLabelStyle
            showPaymentDetails = newValue.showPaymentDetails
            showPaymentTerms = newValue.showPaymentTerms
            showPageNumbers = newValue.showPageNumbers
            showPageNumberChrome = newValue.showPageNumberChrome
            showTitleUnderline = newValue.showTitleUnderline
            showInvoiceDetailLabels = newValue.showInvoiceDetailLabels
            showLineItemsSectionTitle = newValue.showLineItemsSectionTitle
            showLineItemsTableHeader = newValue.showLineItemsTableHeader
            showPartyLabels = newValue.showPartyLabels
            showPartyContactLabels = newValue.showPartyContactLabels
            showPartyCardBorders = newValue.showPartyCardBorders
            showPartyCardFill = newValue.showPartyCardFill
            showPaymentCardBorders = newValue.showPaymentCardBorders
            showPaymentCardFill = newValue.showPaymentCardFill
            showPaymentDetailLabels = newValue.showPaymentDetailLabels
            showPaymentDetailRowRules = newValue.showPaymentDetailRowRules
            showInvoiceDetailsBorders = newValue.showInvoiceDetailsBorders
            showInvoiceDetailGridLines = newValue.showInvoiceDetailGridLines
            showTableGridLines = newValue.showTableGridLines
            showTableZebraRows = newValue.showTableZebraRows
            showTableHeaderFill = newValue.showTableHeaderFill
            showTotalsFill = newValue.showTotalsFill
            columnVisibility = newValue.columnVisibility
            headerStyle = newValue.headerStyle
            partyLayout = newValue.partyLayout
            tableStyle = newValue.tableStyle
            fontFamily = newValue.fontFamily
            dateFormatStyle = newValue.dateFormatStyle
            documentSpacing = newValue.documentSpacing
            customSpacingScale = newValue.customSpacingScale
            showParticipantSection = newValue.showParticipantSection
            showProviderPhone = newValue.showProviderPhone
            showProviderEmail = newValue.showProviderEmail
            showProviderTaxID = newValue.showProviderTaxID
            showIssueDateOnDocument = newValue.showIssueDateOnDocument
            showDueDateOnDocument = newValue.showDueDateOnDocument
            showServiceDatesInDescription = newValue.showServiceDatesInDescription
            showInvoiceNumberOnDocument = newValue.showInvoiceNumberOnDocument
            showTitleOnDocument = newValue.showTitleOnDocument
            borderWeight = newValue.borderWeight
            customBorderWidth = newValue.customBorderWidth
            currencyDisplayStyle = newValue.currencyDisplayStyle
            logoPlacement = newValue.logoPlacement
            totalsEmphasis = newValue.totalsEmphasis
        }
    }

    var customAccentColor: InvoiceCustomAccentColor? {
        get {
            guard let customAccentRed, let customAccentGreen, let customAccentBlue else { return nil }
            return InvoiceCustomAccentColor(
                red: customAccentRed,
                green: customAccentGreen,
                blue: customAccentBlue,
                opacity: customAccentOpacity ?? 1
            )
        }
        set {
            customAccentRed = newValue?.red
            customAccentGreen = newValue?.green
            customAccentBlue = newValue?.blue
            customAccentOpacity = newValue?.opacity
        }
    }

    init(
        id: UUID = UUID(),
        invoiceNumber: String = "",
        title: String = "Tax Invoice",
        status: InvoiceStatus = .draft,
        issueDate: Date = .now,
        dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now,
        sellerName: String = "",
        sellerAddress: String = "",
        sellerEmail: String = "",
        sellerPhone: String = "",
        sellerTaxID: String = "",
        billParticipantDirectly: Bool = true,
        billToName: String = "",
        billToEmail: String = "",
        billToAddress: String = "",
        billToPhone: String = "",
        billingAuthority: String = "",
        clientName: String = "",
        clientAddress: String = "",
        clientEmail: String = "",
        clientPhone: String = "",
        clientTaxID: String = "",
        bankName: String = "",
        bankAccountName: String = "",
        bankBSB: String = "",
        bankAccountNumber: String = "",
        currencyCode: String = InvoiceCurrencyCode.defaultValue,
        defaultTaxRate: Decimal = 0,
        paymentTerms: String = "Net 30",
        notes: String = "",
        discountAmount: Decimal = 0,
        discountPercent: Decimal = 0,
        creditApplied: Decimal = 0,
        showsTaxSummary: Bool = true,
        paperSize: PaperSize = .default,
        pageOrientation: PageOrientation = .portrait,
        accentTheme: InvoiceAccentTheme = .default,
        marginPreset: InvoiceMarginPreset = .default,
        typographyDensity: InvoiceTypographyDensity = .default,
        taxLabelStyle: InvoiceTaxLabelStyle = .default,
        showPaymentDetails: Bool = true,
        showPaymentTerms: Bool = true,
        showPageNumbers: Bool = true,
        showPageNumberChrome: Bool = true,
        showTitleUnderline: Bool = true,
        showInvoiceDetailLabels: Bool = true,
        showLineItemsSectionTitle: Bool = true,
        showLineItemsTableHeader: Bool = true,
        showPartyLabels: Bool = true,
        showPartyContactLabels: Bool = true,
        showPartyCardBorders: Bool = true,
        showPartyCardFill: Bool = true,
        showPaymentCardBorders: Bool = true,
        showPaymentCardFill: Bool = true,
        showPaymentDetailLabels: Bool = true,
        showPaymentDetailRowRules: Bool = true,
        showInvoiceDetailsBorders: Bool = true,
        showInvoiceDetailGridLines: Bool = true,
        showTableGridLines: Bool = true,
        showTableZebraRows: Bool = true,
        showTableHeaderFill: Bool = true,
        showTotalsFill: Bool = true,
        columnVisibility: LineItemColumnVisibility = .allVisible,
        headerStyle: InvoiceHeaderStyle = .default,
        partyLayout: InvoicePartyLayout = .default,
        tableStyle: InvoiceTableStyle = .default,
        fontFamily: InvoiceFontFamilyPreset = .default,
        dateFormatStyle: InvoiceDateFormatStyle = .default,
        documentSpacing: InvoiceDocumentSpacingPreset = .default,
        showParticipantSection: Bool = true,
        showProviderPhone: Bool = true,
        showProviderEmail: Bool = true,
        showProviderTaxID: Bool = true,
        showIssueDateOnDocument: Bool = true,
        showDueDateOnDocument: Bool = true,
        showServiceDatesInDescription: Bool = false,
        showInvoiceNumberOnDocument: Bool = true,
        showTitleOnDocument: Bool = true,
        borderWeight: InvoiceBorderWeight = .default,
        currencyDisplayStyle: InvoiceCurrencyDisplayStyle = .default,
        logoPlacement: InvoiceLogoPlacement = .default,
        totalsEmphasis: InvoiceTotalsEmphasis = .default,
        subtotal: Decimal = 0,
        taxTotal: Decimal = 0,
        grandTotal: Decimal = 0
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.title = title
        statusRaw = status.rawValue
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.sellerName = sellerName
        self.sellerAddress = sellerAddress
        self.sellerEmail = sellerEmail
        self.sellerPhone = sellerPhone
        self.sellerTaxID = sellerTaxID
        self.billParticipantDirectly = billParticipantDirectly
        self.billToName = billToName
        self.billToEmail = billToEmail
        self.billToAddress = billToAddress
        self.billToPhone = billToPhone
        self.billingAuthority = billingAuthority
        self.clientName = clientName
        self.clientAddress = clientAddress
        self.clientEmail = clientEmail
        self.clientPhone = clientPhone
        self.clientTaxID = clientTaxID
        self.bankName = bankName
        self.bankAccountName = bankAccountName
        self.bankBSB = bankBSB
        self.bankAccountNumber = bankAccountNumber
        self.currencyCode = currencyCode
        self.defaultTaxRate = defaultTaxRate
        self.paymentTerms = paymentTerms
        self.notes = notes
        self.discountAmount = discountAmount
        self.discountPercent = discountPercent
        self.creditApplied = creditApplied
        self.showsTaxSummary = showsTaxSummary
        paperSizeRaw = paperSize.rawValue
        orientationRaw = pageOrientation.rawValue
        accentThemeRaw = accentTheme.rawValue
        marginPresetRaw = marginPreset.rawValue
        typographyDensityRaw = typographyDensity.rawValue
        taxLabelStyleRaw = taxLabelStyle.rawValue
        self.showPaymentDetails = showPaymentDetails
        self.showPaymentTerms = showPaymentTerms
        self.showPageNumbers = showPageNumbers
        self.showPageNumberChrome = showPageNumberChrome
        self.showTitleUnderline = showTitleUnderline
        self.showInvoiceDetailLabels = showInvoiceDetailLabels
        self.showLineItemsSectionTitle = showLineItemsSectionTitle
        self.showLineItemsTableHeader = showLineItemsTableHeader
        self.showPartyLabels = showPartyLabels
        self.showPartyContactLabels = showPartyContactLabels
        self.showPartyCardBorders = showPartyCardBorders
        self.showPartyCardFill = showPartyCardFill
        self.showPaymentCardBorders = showPaymentCardBorders
        self.showPaymentCardFill = showPaymentCardFill
        self.showPaymentDetailLabels = showPaymentDetailLabels
        self.showPaymentDetailRowRules = showPaymentDetailRowRules
        self.showInvoiceDetailsBorders = showInvoiceDetailsBorders
        self.showInvoiceDetailGridLines = showInvoiceDetailGridLines
        self.showTableGridLines = showTableGridLines
        self.showTableZebraRows = showTableZebraRows
        self.showTableHeaderFill = showTableHeaderFill
        self.showTotalsFill = showTotalsFill
        showDateColumn = columnVisibility.showDate
        showItemCode = columnVisibility.showItemCode
        showQtyColumn = columnVisibility.showQty
        showUnitColumn = columnVisibility.showUnit
        showRateColumn = columnVisibility.showRate
        headerStyleRaw = headerStyle.rawValue
        partyLayoutRaw = partyLayout.rawValue
        tableStyleRaw = tableStyle.rawValue
        fontFamilyRaw = fontFamily.rawValue
        dateFormatStyleRaw = dateFormatStyle.rawValue
        documentSpacingRaw = documentSpacing.rawValue
        self.showParticipantSection = showParticipantSection
        self.showProviderPhone = showProviderPhone
        self.showProviderEmail = showProviderEmail
        self.showProviderTaxID = showProviderTaxID
        self.showIssueDateOnDocument = showIssueDateOnDocument
        self.showDueDateOnDocument = showDueDateOnDocument
        self.showServiceDatesInDescription = showServiceDatesInDescription
        self.showInvoiceNumberOnDocument = showInvoiceNumberOnDocument
        self.showTitleOnDocument = showTitleOnDocument
        borderWeightRaw = borderWeight.rawValue
        currencyDisplayStyleRaw = currencyDisplayStyle.rawValue
        logoPlacementRaw = logoPlacement.rawValue
        totalsEmphasisRaw = totalsEmphasis.rawValue
        self.subtotal = subtotal
        self.taxTotal = taxTotal
        self.grandTotal = grandTotal
    }

    func recalculateTotals() {
        let items = (lineItems ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let totals = InvoiceCalculations.invoiceTotals(
            lineItems: items.map(\.calculationInput),
            discountAmount: discountAmount,
            discountPercent: discountPercent,
            creditApplied: creditApplied
        )
        subtotal = totals.subtotal
        taxTotal = totals.taxTotal
        grandTotal = totals.grandTotal
    }

    func apply(_ draft: InvoiceDraft) {
        invoiceNumber = draft.invoiceNumber
        title = draft.title
        status = draft.status
        issueDate = draft.issueDate
        dueDate = draft.dueDate

        sellerName = draft.seller.name
        sellerAddress = draft.seller.address
        sellerEmail = draft.seller.email
        sellerPhone = draft.seller.phone
        sellerTaxID = draft.seller.taxID

        billParticipantDirectly = draft.billing.billsParticipantDirectly
        billToName = draft.billing.recipient.name
        billToAddress = draft.billing.recipient.address
        billToEmail = draft.billing.recipient.email
        billToPhone = draft.billing.recipient.phone
        billingAuthority = draft.billing.authority

        clientName = draft.client.name
        clientAddress = draft.client.address
        clientEmail = draft.client.email
        clientPhone = draft.client.phone
        clientTaxID = draft.client.taxID

        bankName = draft.payment.bankName
        bankAccountName = draft.payment.accountName
        bankBSB = draft.payment.bsb
        bankAccountNumber = draft.payment.accountNumber

        currencyCode = InvoiceCurrencyCode.normalizedOrDefault(draft.currencyCode)
        defaultTaxRate = draft.defaultTaxRate
        paymentTerms = draft.paymentTerms
        notes = draft.notes
        discountPercent = draft.adjustments.discountPercent
        // Percentage discounts are the canonical mode whenever both values are
        // present (for example, an imported or older draft).
        discountAmount = discountPercent == 0 ? draft.adjustments.discountAmount : 0
        creditApplied = draft.adjustments.creditApplied
        showsTaxSummary = draft.showsTaxSummary
        paperSize = draft.paperSize
        pageOrientation = draft.pageOrientation
        templateConfiguration = draft.template
    }
}
