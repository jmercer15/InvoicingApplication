import Foundation

struct InvoicePartyDraft: Equatable {
    var name: String
    var address: String
    var email: String
    var phone: String
    var taxID: String
}

struct InvoiceBillingRecipientDraft: Equatable {
    var name: String
    var address: String
    var email: String
    var phone: String
}

struct InvoiceBillingDraft: Equatable {
    var billsParticipantDirectly: Bool
    var recipient: InvoiceBillingRecipientDraft
    var authority: String
}

struct InvoicePaymentDraft: Equatable {
    var bankName: String
    var accountName: String
    var bsb: String
    var accountNumber: String
}

struct InvoiceAdjustmentsDraft: Equatable {
    var discountAmount: Decimal
    var discountPercent: Decimal
    var creditApplied: Decimal
}

/// Complete user-editable invoice state passed atomically to the persistence actor.
struct InvoiceDraft: Equatable {
    var clientID: UUID?
    var invoiceNumber: String
    var title: String
    var status: InvoiceStatus
    var issueDate: Date
    var dueDate: Date
    var seller: InvoicePartyDraft
    var billing: InvoiceBillingDraft
    var client: InvoicePartyDraft
    var payment: InvoicePaymentDraft
    var currencyCode: String
    var defaultTaxRate: Decimal
    var paymentTerms: String
    var notes: String
    var adjustments: InvoiceAdjustmentsDraft
    var showsTaxSummary: Bool
    var paperSize: PaperSize
    var pageOrientation: PageOrientation
    var template: InvoiceTemplateConfiguration
    var lineItems: [InvoiceLineItemSnapshot]
}

struct InvoiceClientOption: Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let email: String
    let phone: String
    let taxID: String
    let billsDirectly: Bool
    let billingAuthority: String
    let billToName: String
    let billToAddress: String
    let billToEmail: String
    let billToPhone: String
}

struct InvoiceLineItemSnapshot: Equatable, Identifiable {
    let id: UUID
    var sortOrder: Int
    var itemDescription: String
    var serviceDate: Date
    var itemCode: String
    var quantity: Decimal
    var unit: String
    var unitPrice: Decimal
    var taxRate: Decimal
    var gstCode: String

    var lineSubtotal: Decimal {
        InvoiceCalculations.lineSubtotal(quantity: quantity, unitPrice: unitPrice)
    }

    var lineTax: Decimal {
        InvoiceCalculations.lineTax(subtotal: lineSubtotal, taxRate: taxRate)
    }

    var lineTotal: Decimal {
        InvoiceCalculations.lineTotal(subtotal: lineSubtotal, taxRate: taxRate)
    }

    var calculationInput: InvoiceCalculations.LineItemInput {
        InvoiceCalculations.LineItemInput(
            quantity: quantity,
            unitPrice: unitPrice,
            taxRate: taxRate
        )
    }

    func duplicated(sortOrder: Int) -> InvoiceLineItemSnapshot {
        InvoiceLineItemSnapshot(
            sortOrder: sortOrder,
            itemDescription: itemDescription,
            serviceDate: serviceDate,
            itemCode: itemCode,
            quantity: quantity,
            unit: unit,
            unitPrice: unitPrice,
            taxRate: taxRate,
            gstCode: gstCode
        )
    }

    init(_ item: InvoiceLineItem) {
        id = item.id
        sortOrder = item.sortOrder
        itemDescription = item.itemDescription
        serviceDate = item.serviceDate
        itemCode = item.itemCode
        quantity = item.quantity
        unit = item.unit
        unitPrice = item.unitPrice
        taxRate = item.taxRate
        gstCode = item.gstCode
    }

    /// Builds a snapshot from field values (tests and layout measurement).
    init(
        id: UUID = UUID(),
        sortOrder: Int = 0,
        itemDescription: String = "",
        serviceDate: Date = .now,
        itemCode: String = "",
        quantity: Decimal,
        unit: String = "",
        unitPrice: Decimal,
        taxRate: Decimal,
        gstCode: String = ""
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.itemDescription = itemDescription
        self.serviceDate = serviceDate
        self.itemCode = itemCode
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.taxRate = taxRate
        self.gstCode = gstCode
    }
}

struct InvoiceSnapshot: Equatable, Identifiable {
    let id: UUID
    let clientID: UUID?
    let invoiceNumber: String
    let title: String
    let status: InvoiceStatus
    let issueDate: Date
    let dueDate: Date
    let revision: Int

    let sellerName: String
    let sellerAddress: String
    let sellerEmail: String
    let sellerPhone: String
    let sellerTaxID: String

    let billParticipantDirectly: Bool
    let billToName: String
    let billToEmail: String
    let billToAddress: String
    let billToPhone: String
    let billingAuthority: String

    let clientName: String
    let clientAddress: String
    let clientEmail: String
    let clientPhone: String
    let clientTaxID: String

    let bankName: String
    let bankAccountName: String
    let bankBSB: String
    let bankAccountNumber: String

    let currencyCode: String
    let defaultTaxRate: Decimal
    let paymentTerms: String
    let notes: String
    let discountAmount: Decimal
    let discountPercent: Decimal
    let creditApplied: Decimal
    let showsTaxSummary: Bool

    let paperSize: PaperSize
    let pageOrientation: PageOrientation

    let accentTheme: InvoiceAccentTheme
    let customAccentColor: InvoiceCustomAccentColor?
    let marginPreset: InvoiceMarginPreset
    let customMarginPoints: Double?
    let customPageWidthPoints: Double?
    let customPageHeightPoints: Double?
    let typographyDensity: InvoiceTypographyDensity
    let customTypographyScale: Double?
    let taxLabelStyle: InvoiceTaxLabelStyle
    let showPaymentDetails: Bool
    let showPaymentTerms: Bool
    let showPageNumbers: Bool
    let showPageNumberChrome: Bool
    let showTitleUnderline: Bool
    let showInvoiceDetailLabels: Bool
    let showLineItemsSectionTitle: Bool
    let showLineItemsTableHeader: Bool
    let showPartyLabels: Bool
    let showPartyContactLabels: Bool
    let showPartyCardBorders: Bool
    let showPartyCardFill: Bool
    let showPaymentCardBorders: Bool
    let showPaymentCardFill: Bool
    let showPaymentDetailLabels: Bool
    let showPaymentDetailRowRules: Bool
    let showInvoiceDetailsBorders: Bool
    let showInvoiceDetailGridLines: Bool
    let showTableGridLines: Bool
    let showTableZebraRows: Bool
    let showTableHeaderFill: Bool
    let showTotalsFill: Bool
    let columnVisibility: LineItemColumnVisibility

    let headerStyle: InvoiceHeaderStyle
    let partyLayout: InvoicePartyLayout
    let tableStyle: InvoiceTableStyle
    let fontFamily: InvoiceFontFamilyPreset
    let dateFormatStyle: InvoiceDateFormatStyle
    let documentSpacing: InvoiceDocumentSpacingPreset
    let customSpacingScale: Double?
    let showParticipantSection: Bool
    let showProviderPhone: Bool
    let showProviderEmail: Bool
    let showProviderTaxID: Bool
    let showIssueDateOnDocument: Bool
    let showDueDateOnDocument: Bool
    let showServiceDatesInDescription: Bool
    let showInvoiceNumberOnDocument: Bool
    let showTitleOnDocument: Bool
    let borderWeight: InvoiceBorderWeight
    let customBorderWidth: Double?
    let currencyDisplayStyle: InvoiceCurrencyDisplayStyle
    let logoPlacement: InvoiceLogoPlacement
    let totalsEmphasis: InvoiceTotalsEmphasis

    let subtotal: Decimal
    let taxTotal: Decimal
    let grandTotal: Decimal

    let lineItems: [InvoiceLineItemSnapshot]

    var templateConfiguration: InvoiceTemplateConfiguration {
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

    init(_ document: InvoiceDocument, clientID: UUID? = nil) {
        id = document.id
        self.clientID = clientID
        invoiceNumber = document.invoiceNumber
        title = document.title
        status = document.status
        issueDate = document.issueDate
        dueDate = document.dueDate
        revision = document.revision
        sellerName = document.sellerName
        sellerAddress = document.sellerAddress
        sellerEmail = document.sellerEmail
        sellerPhone = document.sellerPhone
        sellerTaxID = document.sellerTaxID
        billParticipantDirectly = document.billParticipantDirectly
        billToName = document.billToName
        billToEmail = document.billToEmail
        billToAddress = document.billToAddress
        billToPhone = document.billToPhone
        billingAuthority = document.billingAuthority
        clientName = document.clientName
        clientAddress = document.clientAddress
        clientEmail = document.clientEmail
        clientPhone = document.clientPhone
        clientTaxID = document.clientTaxID
        bankName = document.bankName
        bankAccountName = document.bankAccountName
        bankBSB = document.bankBSB
        bankAccountNumber = document.bankAccountNumber
        currencyCode = document.currencyCode
        defaultTaxRate = document.defaultTaxRate
        paymentTerms = document.paymentTerms
        notes = document.notes
        discountAmount = document.discountAmount
        discountPercent = document.discountPercent
        creditApplied = document.creditApplied
        showsTaxSummary = document.showsTaxSummary
        paperSize = document.paperSize
        pageOrientation = document.pageOrientation
        accentTheme = document.accentTheme
        customAccentColor = document.customAccentColor
        marginPreset = document.marginPreset
        customMarginPoints = document.customMarginPoints
        customPageWidthPoints = document.customPageWidthPoints
        customPageHeightPoints = document.customPageHeightPoints
        typographyDensity = document.typographyDensity
        customTypographyScale = document.customTypographyScale
        taxLabelStyle = document.taxLabelStyle
        showPaymentDetails = document.showPaymentDetails
        showPaymentTerms = document.showPaymentTerms
        showPageNumbers = document.showPageNumbers
        showPageNumberChrome = document.showPageNumberChrome
        showTitleUnderline = document.showTitleUnderline
        showInvoiceDetailLabels = document.showInvoiceDetailLabels
        showLineItemsSectionTitle = document.showLineItemsSectionTitle
        showLineItemsTableHeader = document.showLineItemsTableHeader
        showPartyLabels = document.showPartyLabels
        showPartyContactLabels = document.showPartyContactLabels
        showPartyCardBorders = document.showPartyCardBorders
        showPartyCardFill = document.showPartyCardFill
        showPaymentCardBorders = document.showPaymentCardBorders
        showPaymentCardFill = document.showPaymentCardFill
        showPaymentDetailLabels = document.showPaymentDetailLabels
        showPaymentDetailRowRules = document.showPaymentDetailRowRules
        showInvoiceDetailsBorders = document.showInvoiceDetailsBorders
        showInvoiceDetailGridLines = document.showInvoiceDetailGridLines
        showTableGridLines = document.showTableGridLines
        showTableZebraRows = document.showTableZebraRows
        showTableHeaderFill = document.showTableHeaderFill
        showTotalsFill = document.showTotalsFill
        columnVisibility = document.columnVisibility
        headerStyle = document.headerStyle
        partyLayout = document.partyLayout
        tableStyle = document.tableStyle
        fontFamily = document.fontFamily
        dateFormatStyle = document.dateFormatStyle
        documentSpacing = document.documentSpacing
        customSpacingScale = document.customSpacingScale
        showParticipantSection = document.showParticipantSection
        showProviderPhone = document.showProviderPhone
        showProviderEmail = document.showProviderEmail
        showProviderTaxID = document.showProviderTaxID
        showIssueDateOnDocument = document.showIssueDateOnDocument
        showDueDateOnDocument = document.showDueDateOnDocument
        showServiceDatesInDescription = document.showServiceDatesInDescription
        showInvoiceNumberOnDocument = document.showInvoiceNumberOnDocument
        showTitleOnDocument = document.showTitleOnDocument
        borderWeight = document.borderWeight
        customBorderWidth = document.customBorderWidth
        currencyDisplayStyle = document.currencyDisplayStyle
        logoPlacement = document.logoPlacement
        totalsEmphasis = document.totalsEmphasis
        let lineItems = (document.lineItems ?? [])
            .sorted { $0.sortOrder < $1.sortOrder }
            .map(InvoiceLineItemSnapshot.init)
        let totals = InvoiceCalculations.invoiceTotals(
            lineItems: lineItems.map(\.calculationInput),
            discountAmount: document.discountAmount,
            discountPercent: document.discountPercent,
            creditApplied: document.creditApplied
        )
        subtotal = totals.subtotal
        taxTotal = totals.taxTotal
        grandTotal = totals.grandTotal
        self.lineItems = lineItems
    }
}

extension InvoiceDraft {
    init(_ snapshot: InvoiceSnapshot) {
        self.init(
            clientID: snapshot.clientID,
            invoiceNumber: snapshot.invoiceNumber,
            title: snapshot.title,
            status: snapshot.status,
            issueDate: snapshot.issueDate,
            dueDate: snapshot.dueDate,
            seller: InvoicePartyDraft(
                name: snapshot.sellerName,
                address: snapshot.sellerAddress,
                email: snapshot.sellerEmail,
                phone: snapshot.sellerPhone,
                taxID: snapshot.sellerTaxID
            ),
            billing: InvoiceBillingDraft(
                billsParticipantDirectly: snapshot.billParticipantDirectly,
                recipient: InvoiceBillingRecipientDraft(
                    name: snapshot.billToName,
                    address: snapshot.billToAddress,
                    email: snapshot.billToEmail,
                    phone: snapshot.billToPhone
                ),
                authority: snapshot.billingAuthority
            ),
            client: InvoicePartyDraft(
                name: snapshot.clientName,
                address: snapshot.clientAddress,
                email: snapshot.clientEmail,
                phone: snapshot.clientPhone,
                taxID: snapshot.clientTaxID
            ),
            payment: InvoicePaymentDraft(
                bankName: snapshot.bankName,
                accountName: snapshot.bankAccountName,
                bsb: snapshot.bankBSB,
                accountNumber: snapshot.bankAccountNumber
            ),
            currencyCode: snapshot.currencyCode,
            defaultTaxRate: snapshot.defaultTaxRate,
            paymentTerms: snapshot.paymentTerms,
            notes: snapshot.notes,
            adjustments: InvoiceAdjustmentsDraft(
                discountAmount: snapshot.discountAmount,
                discountPercent: snapshot.discountPercent,
                creditApplied: snapshot.creditApplied
            ),
            showsTaxSummary: snapshot.showsTaxSummary,
            paperSize: snapshot.paperSize,
            pageOrientation: snapshot.pageOrientation,
            template: snapshot.templateConfiguration,
            lineItems: snapshot.lineItems
        )
    }
}
