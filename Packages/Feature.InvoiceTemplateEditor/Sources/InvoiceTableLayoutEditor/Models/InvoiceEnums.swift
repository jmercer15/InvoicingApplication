import CoreGraphics
import Foundation
import SwiftUI

enum InvoiceStatus: String, Codable, CaseIterable {
    case draft
    case readyToSend
    case sent
    case paid
    case overdue
    case cancelled
    case voided

    var displayName: String {
        switch self {
        case .draft: "Review Draft"
        case .readyToSend: "Ready to Send"
        case .sent: "Sent"
        case .paid: "Payment Received"
        case .overdue: "Overdue"
        case .cancelled: "Cancelled"
        case .voided: "Voided"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .draft: "pencil.circle"
        case .readyToSend: "checkmark.circle"
        case .sent: "paperplane"
        case .paid: "checkmark.circle.fill"
        case .overdue: "exclamationmark.circle"
        case .cancelled: "xmark.circle"
        case .voided: "nosign"
        }
    }
}

enum PageOrientation: String, Codable, CaseIterable {
    case portrait
    case landscape

    var displayName: String {
        switch self {
        case .portrait: "Portrait"
        case .landscape: "Landscape"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .portrait: "rectangle.portrait"
        case .landscape: "rectangle.landscape"
        }
    }
}

/// Standard printable paper sizes. Dimensions are portrait points at 72 dpi (1 in = 72 pt).
enum PaperSize: String, Codable, CaseIterable {
    case a3
    case a4
    case a5
    case a6
    case letter
    case legal
    case tabloid
    case executive

    static let `default`: PaperSize = .a4

    var displayName: String {
        switch self {
        case .a3: "A3"
        case .a4: "A4"
        case .a5: "A5"
        case .a6: "A6"
        case .letter: "Letter"
        case .legal: "Legal"
        case .tabloid: "Tabloid"
        case .executive: "Executive"
        }
    }

    /// Portrait width × height in points (72 pt = 1 inch).
    var portraitSizePoints: CGSize {
        switch self {
        case .a3: CGSize(width: 841.89, height: 1190.55)
        case .a4: CGSize(width: 595.28, height: 841.89)
        case .a5: CGSize(width: 419.53, height: 595.28)
        case .a6: CGSize(width: 297.64, height: 419.53)
        case .letter: CGSize(width: 612, height: 792)
        case .legal: CGSize(width: 612, height: 1008)
        case .tabloid: CGSize(width: 792, height: 1224)
        case .executive: CGSize(width: 522, height: 756)
        }
    }

    /// Page size in points for the given orientation.
    func sizePoints(for orientation: PageOrientation) -> CGSize {
        let portrait = portraitSizePoints
        switch orientation {
        case .portrait:
            return portrait
        case .landscape:
            return CGSize(width: portrait.height, height: portrait.width)
        }
    }

    /// Standard printable margin (0.5 in) in points.
    var marginPoints: CGFloat {
        36
    }

    /// Human-readable dimensions for the portrait size (mm for ISO, inches for NA).
    var dimensionsLabel: String {
        switch self {
        case .a3: "297 × 420 mm"
        case .a4: "210 × 297 mm"
        case .a5: "148 × 210 mm"
        case .a6: "105 × 148 mm"
        case .letter: "8.5 × 11 in"
        case .legal: "8.5 × 14 in"
        case .tabloid: "11 × 17 in"
        case .executive: "7.25 × 10.5 in"
        }
    }

    /// Label for pickers, e.g. "A4 (210 × 297 mm)".
    var menuLabel: String {
        "\(displayName) (\(dimensionsLabel))"
    }

    var toolbarIcon: String {
        "doc"
    }

    /// Dimensions label for the active orientation.
    func dimensionsLabel(for orientation: PageOrientation) -> String {
        guard orientation == .landscape else { return dimensionsLabel }
        switch self {
        case .a3: return "420 × 297 mm"
        case .a4: return "297 × 210 mm"
        case .a5: return "210 × 148 mm"
        case .a6: return "148 × 105 mm"
        case .letter: return "11 × 8.5 in"
        case .legal: return "14 × 8.5 in"
        case .tabloid: return "17 × 11 in"
        case .executive: return "10.5 × 7.25 in"
        }
    }
}

// MARK: - Template / appearance

/// Print-safe accent presets for the invoice document.
enum InvoiceAccentTheme: String, Codable, CaseIterable {
    case teal
    case navy
    case slate
    case forest
    case burgundy

    static let `default`: InvoiceAccentTheme = .teal

    var displayName: String {
        switch self {
        case .teal: "Teal"
        case .navy: "Navy"
        case .slate: "Slate"
        case .forest: "Forest"
        case .burgundy: "Burgundy"
        }
    }

    var accentColor: Color {
        switch self {
        case .teal: Color(red: 0.13, green: 0.36, blue: 0.40)
        case .navy: Color(red: 0.12, green: 0.22, blue: 0.42)
        case .slate: Color(red: 0.28, green: 0.32, blue: 0.38)
        case .forest: Color(red: 0.14, green: 0.38, blue: 0.24)
        case .burgundy: Color(red: 0.42, green: 0.14, blue: 0.20)
        }
    }

    /// Short label for toolbar menu buttons.
    var toolbarSummary: String {
        displayName
    }
}

/// Page margin presets (points at 72 dpi).
enum InvoiceMarginPreset: String, Codable, CaseIterable {
    case narrow
    case standard
    case wide

    static let `default`: InvoiceMarginPreset = .standard

    var displayName: String {
        switch self {
        case .narrow: "Narrow"
        case .standard: "Standard"
        case .wide: "Wide"
        }
    }

    /// Margin in points: 0.25 in, 0.5 in, 0.75 in.
    var marginPoints: CGFloat {
        switch self {
        case .narrow: 18
        case .standard: 36
        case .wide: 54
        }
    }

    var menuLabel: String {
        switch self {
        case .narrow: "Narrow (0.25 in)"
        case .standard: "Standard (0.5 in)"
        case .wide: "Wide (0.75 in)"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .narrow: "arrow.up.left.and.arrow.down.right"
        case .standard: "square.inset.filled"
        case .wide: "arrow.down.right.and.arrow.up.left"
        }
    }
}

/// Document type scale density preset.
enum InvoiceTypographyDensity: String, Codable, CaseIterable {
    case compact
    case normal
    case comfortable

    static let `default`: InvoiceTypographyDensity = .normal

    var displayName: String {
        switch self {
        case .compact: "Compact"
        case .normal: "Normal"
        case .comfortable: "Comfortable"
        }
    }

    var scale: CGFloat {
        switch self {
        case .compact: 0.92
        case .normal: 1.0
        case .comfortable: 1.08
        }
    }

    var toolbarIcon: String {
        switch self {
        case .compact: "textformat.size.smaller"
        case .normal: "textformat.size"
        case .comfortable: "textformat.size.larger"
        }
    }
}

/// Label used for the tax totals row in the document preview.
enum InvoiceTaxLabelStyle: String, Codable, CaseIterable {
    case tax
    case gst
    case vat

    static let `default`: InvoiceTaxLabelStyle = .gst

    var displayName: String {
        switch self {
        case .tax: "Tax"
        case .gst: "GST"
        case .vat: "VAT"
        }
    }

    /// Row label when tax is applied.
    var appliedLabel: String {
        displayName
    }

    /// Row label/value when no tax is charged.
    var zeroTaxLabel: String {
        switch self {
        case .tax: "Tax exempt"
        case .gst: "GST-free"
        case .vat: "VAT exempt"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .tax: "percent"
        case .gst: "text.badge.checkmark"
        case .vat: "tag.circle"
        }
    }
}

/// Document header presentation on the printable page.
enum InvoiceHeaderStyle: String, Codable, CaseIterable {
    case fullBleed
    case compact

    static let `default`: InvoiceHeaderStyle = .fullBleed

    var displayName: String {
        switch self {
        case .fullBleed: "Full Bleed"
        case .compact: "Compact"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .fullBleed: "rectangle.topthird.inset.filled"
        case .compact: "rectangle.inset.filled"
        }
    }
}

/// Party block column arrangement (From / Billed To / For).
enum InvoicePartyLayout: String, Codable, CaseIterable {
    case automatic
    case sideBySide
    case stacked

    static let `default`: InvoicePartyLayout = .automatic

    var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .sideBySide: "Side by Side"
        case .stacked: "Stacked"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .automatic: "person.2"
        case .sideBySide: "rectangle.split.2x1"
        case .stacked: "square.split.1x2"
        }
    }
}

extension InvoicePartyLayout {
    func usesSideBySide(contentWidth: CGFloat) -> Bool {
        switch self {
        case .automatic:
            contentWidth >= Self.sideBySideMinContentWidth
        case .sideBySide:
            true
        case .stacked:
            false
        }
    }

    /// Matches `InvoiceDocumentLayout.sideBySideMinWidth`.
    static let sideBySideMinContentWidth: CGFloat = 380
}

/// Line-items table chrome preset.
enum InvoiceTableStyle: String, Codable, CaseIterable {
    case ruled
    case banded
    case borderless

    static let `default`: InvoiceTableStyle = .ruled

    var displayName: String {
        switch self {
        case .ruled: "Ruled"
        case .banded: "Banded"
        case .borderless: "Borderless"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .ruled: "tablecells"
        case .banded: "tablecells.fill"
        case .borderless: "list.bullet.rectangle"
        }
    }

    /// Short label for toolbar menu buttons.
    var toolbarSummary: String {
        displayName
    }

    var showsGridLines: Bool {
        self != .borderless
    }

    var showsHeaderFill: Bool {
        self == .ruled
    }

    var usesZebraRows: Bool {
        self == .banded
    }
}

/// Document typeface preset (SwiftUI system font designs).
enum InvoiceFontFamilyPreset: String, Codable, CaseIterable {
    case system
    case serif
    case rounded

    static let `default`: InvoiceFontFamilyPreset = .system

    var displayName: String {
        switch self {
        case .system: "System"
        case .serif: "Serif"
        case .rounded: "Rounded"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .system: "textformat"
        case .serif: "textformat.alt"
        case .rounded: "character.circle.fill"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        }
    }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: design)
    }
}

/// Date display style for invoice metadata and line-item dates.
enum InvoiceDateFormatStyle: String, Codable, CaseIterable {
    case medium
    case short
    case long

    static let `default`: InvoiceDateFormatStyle = .short

    var displayName: String {
        switch self {
        case .medium: "29 Jun 2026"
        case .short: "29/06/2026"
        case .long: "29 June 2026"
        }
    }

    /// Human-readable style name for menus.
    var styleName: String {
        switch self {
        case .medium: "Medium"
        case .short: "Short"
        case .long: "Long"
        }
    }

    /// Picker label showing style name and example output.
    var menuLabel: String {
        "\(styleName) (\(displayName))"
    }

    var toolbarIcon: String {
        switch self {
        case .medium: "calendar"
        case .short: "calendar.badge.minus"
        case .long: "calendar.badge.plus"
        }
    }

    var dateStyle: DateFormatter.Style {
        switch self {
        case .medium: .medium
        case .short: .short
        case .long: .long
        }
    }
}

/// Vertical rhythm between document sections (independent of type scale).
enum InvoiceDocumentSpacingPreset: String, Codable, CaseIterable {
    case tight
    case normal
    case loose

    static let `default`: InvoiceDocumentSpacingPreset = .normal

    var displayName: String {
        switch self {
        case .tight: "Tight"
        case .normal: "Normal"
        case .loose: "Loose"
        }
    }

    var scale: CGFloat {
        switch self {
        case .tight: 0.85
        case .normal: 1.0
        case .loose: 1.15
        }
    }

    var toolbarIcon: String {
        switch self {
        case .tight: "line.3.horizontal.decrease"
        case .normal: "arrow.up.and.down.text.horizontal"
        case .loose: "line.3.horizontal"
        }
    }
}

/// Rule / border stroke weight for tables, details, and banded cards.
enum InvoiceBorderWeight: String, Codable, CaseIterable {
    case light
    case regular
    case bold

    static let `default`: InvoiceBorderWeight = .regular

    var displayName: String {
        switch self {
        case .light: "Light"
        case .regular: "Regular"
        case .bold: "Bold"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .light: "line.diagonal"
        case .regular: "square"
        case .bold: "square.fill"
        }
    }

    /// Line-items grid rule width.
    var lineItemsBorderWidth: CGFloat {
        switch self {
        case .light: 0.35
        case .regular: 0.5
        case .bold: 1.0
        }
    }

    /// Invoice-details table outer/grid stroke.
    var detailsBorderWidth: CGFloat {
        switch self {
        case .light: 0.5
        case .regular: 1.0
        case .bold: 1.5
        }
    }

    /// Banded card outline and header divider.
    var bandedCardBorderWidth: CGFloat {
        switch self {
        case .light: 0.5
        case .regular: 1.0
        case .bold: 1.5
        }
    }
}

/// How currency amounts are written on the document (independent of `currencyCode`).
enum InvoiceCurrencyDisplayStyle: String, Codable, CaseIterable {
    case symbol
    case code
    case iso

    static let `default`: InvoiceCurrencyDisplayStyle = .symbol

    var displayName: String {
        switch self {
        case .symbol: "Symbol ($)"
        case .code: "Code (AUD)"
        case .iso: "Amount + Code"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .symbol: "dollarsign"
        case .code: "textformat.abc"
        case .iso: "textformat.123"
        }
    }

    /// Short menu summary.
    var toolbarSummary: String {
        switch self {
        case .symbol: "Symbol"
        case .code: "Code"
        case .iso: "ISO"
        }
    }
}

/// Placement for printable business monogram derived from seller name.
enum InvoiceLogoPlacement: String, Codable, CaseIterable {
    case hidden
    case leading
    case trailing

    static let `default`: InvoiceLogoPlacement = .hidden

    var displayName: String {
        switch self {
        case .hidden: "Hidden"
        case .leading: "Leading"
        case .trailing: "Trailing"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .hidden: "eye.slash"
        case .leading: "photo.on.rectangle.angled"
        case .trailing: "rectangle.righthalf.inset.filled"
        }
    }

    var showsPlaceholder: Bool {
        self != .hidden
    }
}

/// Visual weight of the totals block inside the line-items grid.
enum InvoiceTotalsEmphasis: String, Codable, CaseIterable {
    case standard
    case emphasized
    case compact

    static let `default`: InvoiceTotalsEmphasis = .standard

    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .emphasized: "Emphasized"
        case .compact: "Compact"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .standard: "list.number"
        case .emphasized: "bold"
        case .compact: "arrow.up.right.and.arrow.down.left"
        }
    }

    /// Emphasize every totals row (not only the grand total).
    var emphasizesAllRows: Bool {
        self == .emphasized
    }

    /// Use tighter type for non-grand-total rows.
    var usesCompactType: Bool {
        self == .compact
    }

    /// Row-height scale for totals grid measurement.
    var rowHeightScale: CGFloat {
        switch self {
        case .standard, .emphasized: 1.0
        case .compact: 0.88
        }
    }
}

/// One-shot layout/appearance recipes applied from the template toolbar.
enum InvoiceTemplatePreset: String, Codable, CaseIterable {
    case classic
    case compact
    case minimal
    case modern

    static let `default`: InvoiceTemplatePreset = .classic

    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .compact: "Compact"
        case .minimal: "Minimal"
        case .modern: "Modern"
        }
    }

    var toolbarIcon: String {
        switch self {
        case .classic: "doc.richtext"
        case .compact: "rectangle.compress.vertical"
        case .minimal: "minus.rectangle"
        case .modern: "rectangle.stack"
        }
    }

    var helpText: String {
        switch self {
        case .classic: "Full bleed header, ruled table, standard spacing"
        case .compact: "Tighter type and spacing with a compact header"
        case .minimal: "Borderless table, light rules, fewer chrome accents"
        case .modern: "Banded table, serif type, emphasized totals"
        }
    }

    /// Template field values this preset applies (does not change invoice data).
    var configuration: InvoiceTemplateConfiguration {
        switch self {
        case .classic:
            InvoiceTemplateConfiguration()
        case .compact:
            InvoiceTemplateConfiguration(
                marginPreset: .narrow,
                typographyDensity: .compact,
                headerStyle: .compact,
                tableStyle: .ruled,
                documentSpacing: .tight,
                borderWeight: .light,
                totalsEmphasis: .compact
            )
        case .minimal:
            InvoiceTemplateConfiguration(
                accentTheme: .slate,
                typographyDensity: .normal,
                headerStyle: .compact,
                partyLayout: .sideBySide,
                tableStyle: .borderless,
                fontFamily: .system,
                documentSpacing: .loose,
                showProviderPhone: false,
                showProviderEmail: false,
                showProviderTaxID: false,
                borderWeight: .light,
                totalsEmphasis: .compact
            )
        case .modern:
            InvoiceTemplateConfiguration(
                accentTheme: .navy,
                typographyDensity: .comfortable,
                headerStyle: .fullBleed,
                partyLayout: .automatic,
                tableStyle: .banded,
                fontFamily: .serif,
                documentSpacing: .normal,
                borderWeight: .regular,
                currencyDisplayStyle: .symbol,
                logoPlacement: .leading,
                totalsEmphasis: .emphasized
            )
        }
    }
}

/// Snapshot of template appearance fields used by presets and reset-to-defaults.
struct InvoiceTemplateConfiguration: Equatable, Codable {
    var accentTheme: InvoiceAccentTheme = .default
    /// An optional user-selected accent. When absent, the selected preset theme is used.
    var customAccentColor: InvoiceCustomAccentColor?
    var marginPreset: InvoiceMarginPreset = .default
    /// Optional exact page margin in points, overriding `marginPreset`.
    var customMarginPoints: Double?
    var customPageWidthPoints: Double?
    var customPageHeightPoints: Double?
    var customTypographyScale: Double?
    var customSpacingScale: Double?
    var customBorderWidth: Double?
    var typographyDensity: InvoiceTypographyDensity = .default
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
    var columnVisibility: LineItemColumnVisibility = .allVisible
    var headerStyle: InvoiceHeaderStyle = .default
    var partyLayout: InvoicePartyLayout = .default
    var tableStyle: InvoiceTableStyle = .default
    var fontFamily: InvoiceFontFamilyPreset = .default
    var dateFormatStyle: InvoiceDateFormatStyle = .default
    var documentSpacing: InvoiceDocumentSpacingPreset = .default
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
    var currencyDisplayStyle: InvoiceCurrencyDisplayStyle = .default
    var logoPlacement: InvoiceLogoPlacement = .default
    var totalsEmphasis: InvoiceTotalsEmphasis = .default

    static let `default` = InvoiceTemplateConfiguration()
}

/// Safety bounds for editable document geometry. Unbounded persisted values can propagate into
/// SwiftUI/AppKit minimum-size calculations and expand a window to tens of thousands of points.
enum InvoiceTemplateLayoutLimits {
    static let pageDimensionRange = 144.0...2880.0
    static let storedMarginRange = 0.0...1404.0
    static let typographyScaleRange = 0.75...2.0
    static let spacingScaleRange = 0.5...1.75
    static let borderWidthRange = 0.25...3.0
    static let minimumContentDimension: CGFloat = 72

    static func pageDimension(_ value: Double) -> Double {
        finiteValue(value, clampedTo: pageDimensionRange, fallback: pageDimensionRange.lowerBound)
    }

    static func storedMargin(_ value: Double) -> Double {
        finiteValue(value, clampedTo: storedMarginRange, fallback: 0)
    }

    static func optionalValue(_ value: Double?, clampedTo range: ClosedRange<Double>) -> Double? {
        guard let value, value.isFinite else { return nil }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    static func effectiveMargin(_ requested: Double, pageSize: CGSize) -> CGFloat {
        min(CGFloat(storedMargin(requested)), CGFloat(maximumMargin(for: pageSize)))
    }

    static func maximumMargin(for pageSize: CGSize) -> Double {
        let shortestDimension = max(min(pageSize.width, pageSize.height), minimumContentDimension)
        return Double(max((shortestDimension - minimumContentDimension) / 2, 0))
    }

    static func colorComponent(_ value: Double) -> Double {
        finiteValue(value, clampedTo: 0...1, fallback: 0)
    }

    private static func finiteValue(
        _ value: Double,
        clampedTo range: ClosedRange<Double>,
        fallback: Double
    ) -> Double {
        guard value.isFinite else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}

extension InvoiceTemplateConfiguration {
    private enum CodingKeys: String, CodingKey {
        case accentTheme, customAccentColor, marginPreset, customMarginPoints
        case customPageWidthPoints, customPageHeightPoints, customTypographyScale
        case customSpacingScale, customBorderWidth, typographyDensity, taxLabelStyle
        case showPaymentDetails, showPaymentTerms, showPageNumbers, showPageNumberChrome
        case showTitleUnderline, showInvoiceDetailLabels, showLineItemsSectionTitle
        case showLineItemsTableHeader, showPartyLabels, showPartyContactLabels
        case showPartyCardBorders, showPartyCardFill, showPaymentCardBorders
        case showPaymentCardFill, showPaymentDetailLabels, showPaymentDetailRowRules
        case showInvoiceDetailsBorders, showInvoiceDetailGridLines, showTableGridLines
        case showTableZebraRows, showTableHeaderFill, showTotalsFill, columnVisibility
        case headerStyle, partyLayout, tableStyle, fontFamily, dateFormatStyle
        case documentSpacing, showParticipantSection, showProviderPhone, showProviderEmail
        case showProviderTaxID, showIssueDateOnDocument, showDueDateOnDocument
        case showServiceDatesInDescription, showInvoiceNumberOnDocument, showTitleOnDocument
        case borderWeight, currencyDisplayStyle, logoPlacement, totalsEmphasis
    }

    /// Decodes each field independently so older or partially damaged payloads retain
    /// every valid setting while newly introduced or invalid fields adopt current defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self = .default

        accentTheme = container.resilientValue(InvoiceAccentTheme.self, forKey: .accentTheme, default: accentTheme)
        customAccentColor = container.resilientOptionalValue(InvoiceCustomAccentColor.self, forKey: .customAccentColor, default: customAccentColor)
        marginPreset = container.resilientValue(InvoiceMarginPreset.self, forKey: .marginPreset, default: marginPreset)
        customMarginPoints = container.resilientOptionalValue(Double.self, forKey: .customMarginPoints, default: customMarginPoints)
        customPageWidthPoints = container.resilientOptionalValue(Double.self, forKey: .customPageWidthPoints, default: customPageWidthPoints)
        customPageHeightPoints = container.resilientOptionalValue(Double.self, forKey: .customPageHeightPoints, default: customPageHeightPoints)
        customTypographyScale = container.resilientOptionalValue(Double.self, forKey: .customTypographyScale, default: customTypographyScale)
        customSpacingScale = container.resilientOptionalValue(Double.self, forKey: .customSpacingScale, default: customSpacingScale)
        customBorderWidth = container.resilientOptionalValue(Double.self, forKey: .customBorderWidth, default: customBorderWidth)
        typographyDensity = container.resilientValue(InvoiceTypographyDensity.self, forKey: .typographyDensity, default: typographyDensity)
        taxLabelStyle = container.resilientValue(InvoiceTaxLabelStyle.self, forKey: .taxLabelStyle, default: taxLabelStyle)
        showPaymentDetails = container.resilientValue(Bool.self, forKey: .showPaymentDetails, default: showPaymentDetails)
        showPaymentTerms = container.resilientValue(Bool.self, forKey: .showPaymentTerms, default: showPaymentTerms)
        showPageNumbers = container.resilientValue(Bool.self, forKey: .showPageNumbers, default: showPageNumbers)
        showPageNumberChrome = container.resilientValue(Bool.self, forKey: .showPageNumberChrome, default: showPageNumberChrome)
        showTitleUnderline = container.resilientValue(Bool.self, forKey: .showTitleUnderline, default: showTitleUnderline)
        showInvoiceDetailLabels = container.resilientValue(Bool.self, forKey: .showInvoiceDetailLabels, default: showInvoiceDetailLabels)
        showLineItemsSectionTitle = container.resilientValue(Bool.self, forKey: .showLineItemsSectionTitle, default: showLineItemsSectionTitle)
        showLineItemsTableHeader = container.resilientValue(Bool.self, forKey: .showLineItemsTableHeader, default: showLineItemsTableHeader)
        showPartyLabels = container.resilientValue(Bool.self, forKey: .showPartyLabels, default: showPartyLabels)
        showPartyContactLabels = container.resilientValue(Bool.self, forKey: .showPartyContactLabels, default: showPartyContactLabels)
        showPartyCardBorders = container.resilientValue(Bool.self, forKey: .showPartyCardBorders, default: showPartyCardBorders)
        showPartyCardFill = container.resilientValue(Bool.self, forKey: .showPartyCardFill, default: showPartyCardFill)
        showPaymentCardBorders = container.resilientValue(Bool.self, forKey: .showPaymentCardBorders, default: showPaymentCardBorders)
        showPaymentCardFill = container.resilientValue(Bool.self, forKey: .showPaymentCardFill, default: showPaymentCardFill)
        showPaymentDetailLabels = container.resilientValue(Bool.self, forKey: .showPaymentDetailLabels, default: showPaymentDetailLabels)
        showPaymentDetailRowRules = container.resilientValue(Bool.self, forKey: .showPaymentDetailRowRules, default: showPaymentDetailRowRules)
        showInvoiceDetailsBorders = container.resilientValue(Bool.self, forKey: .showInvoiceDetailsBorders, default: showInvoiceDetailsBorders)
        showInvoiceDetailGridLines = container.resilientValue(Bool.self, forKey: .showInvoiceDetailGridLines, default: showInvoiceDetailGridLines)
        showTableGridLines = container.resilientValue(Bool.self, forKey: .showTableGridLines, default: showTableGridLines)
        showTableZebraRows = container.resilientValue(Bool.self, forKey: .showTableZebraRows, default: showTableZebraRows)
        showTableHeaderFill = container.resilientValue(Bool.self, forKey: .showTableHeaderFill, default: showTableHeaderFill)
        showTotalsFill = container.resilientValue(Bool.self, forKey: .showTotalsFill, default: showTotalsFill)
        columnVisibility = container.resilientValue(LineItemColumnVisibility.self, forKey: .columnVisibility, default: columnVisibility)
        headerStyle = container.resilientValue(InvoiceHeaderStyle.self, forKey: .headerStyle, default: headerStyle)
        partyLayout = container.resilientValue(InvoicePartyLayout.self, forKey: .partyLayout, default: partyLayout)
        tableStyle = container.resilientValue(InvoiceTableStyle.self, forKey: .tableStyle, default: tableStyle)
        fontFamily = container.resilientValue(InvoiceFontFamilyPreset.self, forKey: .fontFamily, default: fontFamily)
        dateFormatStyle = container.resilientValue(InvoiceDateFormatStyle.self, forKey: .dateFormatStyle, default: dateFormatStyle)
        documentSpacing = container.resilientValue(InvoiceDocumentSpacingPreset.self, forKey: .documentSpacing, default: documentSpacing)
        showParticipantSection = container.resilientValue(Bool.self, forKey: .showParticipantSection, default: showParticipantSection)
        showProviderPhone = container.resilientValue(Bool.self, forKey: .showProviderPhone, default: showProviderPhone)
        showProviderEmail = container.resilientValue(Bool.self, forKey: .showProviderEmail, default: showProviderEmail)
        showProviderTaxID = container.resilientValue(Bool.self, forKey: .showProviderTaxID, default: showProviderTaxID)
        showIssueDateOnDocument = container.resilientValue(Bool.self, forKey: .showIssueDateOnDocument, default: showIssueDateOnDocument)
        showDueDateOnDocument = container.resilientValue(Bool.self, forKey: .showDueDateOnDocument, default: showDueDateOnDocument)
        showServiceDatesInDescription = container.resilientValue(Bool.self, forKey: .showServiceDatesInDescription, default: showServiceDatesInDescription)
        showInvoiceNumberOnDocument = container.resilientValue(Bool.self, forKey: .showInvoiceNumberOnDocument, default: showInvoiceNumberOnDocument)
        showTitleOnDocument = container.resilientValue(Bool.self, forKey: .showTitleOnDocument, default: showTitleOnDocument)
        borderWeight = container.resilientValue(InvoiceBorderWeight.self, forKey: .borderWeight, default: borderWeight)
        currencyDisplayStyle = container.resilientValue(InvoiceCurrencyDisplayStyle.self, forKey: .currencyDisplayStyle, default: currencyDisplayStyle)
        logoPlacement = container.resilientValue(InvoiceLogoPlacement.self, forKey: .logoPlacement, default: logoPlacement)
        totalsEmphasis = container.resilientValue(InvoiceTotalsEmphasis.self, forKey: .totalsEmphasis, default: totalsEmphasis)

        customMarginPoints = InvoiceTemplateLayoutLimits.optionalValue(
            customMarginPoints,
            clampedTo: InvoiceTemplateLayoutLimits.storedMarginRange
        )
        customPageWidthPoints = InvoiceTemplateLayoutLimits.optionalValue(
            customPageWidthPoints,
            clampedTo: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
        customPageHeightPoints = InvoiceTemplateLayoutLimits.optionalValue(
            customPageHeightPoints,
            clampedTo: InvoiceTemplateLayoutLimits.pageDimensionRange
        )
        customTypographyScale = InvoiceTemplateLayoutLimits.optionalValue(
            customTypographyScale,
            clampedTo: InvoiceTemplateLayoutLimits.typographyScaleRange
        )
        customSpacingScale = InvoiceTemplateLayoutLimits.optionalValue(
            customSpacingScale,
            clampedTo: InvoiceTemplateLayoutLimits.spacingScaleRange
        )
        customBorderWidth = InvoiceTemplateLayoutLimits.optionalValue(
            customBorderWidth,
            clampedTo: InvoiceTemplateLayoutLimits.borderWidthRange
        )
    }
}

/// Persistable sRGB accent value used by the template colour picker.
struct InvoiceCustomAccentColor: Equatable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double = 1
}

extension InvoiceCustomAccentColor {
    private enum CodingKeys: String, CodingKey {
        case red, green, blue, opacity
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            red: InvoiceTemplateLayoutLimits.colorComponent(
                container.resilientValue(Double.self, forKey: .red, default: 0)
            ),
            green: InvoiceTemplateLayoutLimits.colorComponent(
                container.resilientValue(Double.self, forKey: .green, default: 0)
            ),
            blue: InvoiceTemplateLayoutLimits.colorComponent(
                container.resilientValue(Double.self, forKey: .blue, default: 0)
            ),
            opacity: InvoiceTemplateLayoutLimits.colorComponent(
                container.resilientValue(Double.self, forKey: .opacity, default: 1)
            )
        )
    }
}

/// When the For (participant) section appears on plan-managed invoices.
enum InvoiceParticipantVisibility {
    static func showsParticipantSection(
        billParticipantDirectly: Bool,
        showParticipantSection: Bool
    ) -> Bool {
        !billParticipantDirectly && showParticipantSection
    }
}

/// Which optional line-item table columns appear in the document preview.
struct LineItemColumnVisibility: Equatable, Codable {
    var showDate: Bool = true
    var showItemCode: Bool = true
    var showQty: Bool = true
    var showUnit: Bool = true
    var showRate: Bool = true

    static let allVisible = LineItemColumnVisibility()

    /// Grid columns spanned by totals labels (qty + unit + rate region).
    var totalsLabelColumnSpan: Int {
        [showQty, showUnit, showRate].filter { $0 }.count
    }

}

extension LineItemColumnVisibility {
    private enum CodingKeys: String, CodingKey {
        case showDate, showItemCode, showQty, showUnit, showRate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            showDate: container.resilientValue(Bool.self, forKey: .showDate, default: true),
            showItemCode: container.resilientValue(Bool.self, forKey: .showItemCode, default: true),
            showQty: container.resilientValue(Bool.self, forKey: .showQty, default: true),
            showUnit: container.resilientValue(Bool.self, forKey: .showUnit, default: true),
            showRate: container.resilientValue(Bool.self, forKey: .showRate, default: true)
        )
    }
}

private extension KeyedDecodingContainer {
    func resilientValue<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key,
        default defaultValue: Value
    ) -> Value {
        (try? decodeIfPresent(type, forKey: key)) ?? defaultValue
    }

    func resilientOptionalValue<Value: Decodable>(
        _ type: Value.Type,
        forKey key: Key,
        default defaultValue: Value?
    ) -> Value? {
        guard contains(key) else { return defaultValue }
        do {
            return try decodeIfPresent(type, forKey: key)
        } catch {
            return defaultValue
        }
    }
}
