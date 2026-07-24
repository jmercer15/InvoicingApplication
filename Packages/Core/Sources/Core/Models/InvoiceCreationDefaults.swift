import Foundation

/// Stable preference keys shared by Settings and every invoice creation entry point.
public enum InvoicePreferenceKey {
    public static let paymentTermsDays = "defaultPaymentTerms"
    public static let taxRate = "defaultTaxRate"
    public static let showsTaxSummary = "showTaxColumn"
    public static let autoGeneratesInvoiceNumbers = "autogenerateInvoiceNumbers"
    public static let notes = "defaultNotes"
    public static let paymentTermsText = "defaultPaymentTermsText"
}

/// Validated defaults applied atomically when a new invoice graph is created.
public struct InvoiceCreationDefaults: Equatable, Sendable {
    public static let standard = InvoiceCreationDefaults()

    public var paymentTermsDays: Int
    public var taxRate: Double
    public var showsTaxSummary: Bool
    public var autoGeneratesInvoiceNumbers: Bool
    public var notes: String
    public var paymentTermsText: String

    public init(
        paymentTermsDays: Int = 14,
        taxRate: Double = 10,
        showsTaxSummary: Bool = true,
        autoGeneratesInvoiceNumbers: Bool = true,
        notes: String = "",
        paymentTermsText: String = "Payment due within 14 days."
    ) {
        self.paymentTermsDays = max(0, paymentTermsDays)
        self.taxRate = min(max(taxRate.isFinite ? taxRate : 0, 0), 100)
        self.showsTaxSummary = showsTaxSummary
        self.autoGeneratesInvoiceNumbers = autoGeneratesInvoiceNumbers
        self.notes = notes
        self.paymentTermsText = paymentTermsText
    }

    public static func load(from preferences: UserDefaults) -> Self {
        let fallback = Self.standard
        return Self(
            paymentTermsDays: preferences.object(forKey: InvoicePreferenceKey.paymentTermsDays) == nil
                ? fallback.paymentTermsDays
                : preferences.integer(forKey: InvoicePreferenceKey.paymentTermsDays),
            taxRate: preferences.object(forKey: InvoicePreferenceKey.taxRate) == nil
                ? fallback.taxRate
                : preferences.double(forKey: InvoicePreferenceKey.taxRate),
            showsTaxSummary: preferences.object(forKey: InvoicePreferenceKey.showsTaxSummary) == nil
                ? fallback.showsTaxSummary
                : preferences.bool(forKey: InvoicePreferenceKey.showsTaxSummary),
            autoGeneratesInvoiceNumbers: preferences.object(
                forKey: InvoicePreferenceKey.autoGeneratesInvoiceNumbers
            ) == nil
                ? fallback.autoGeneratesInvoiceNumbers
                : preferences.bool(forKey: InvoicePreferenceKey.autoGeneratesInvoiceNumbers),
            notes: preferences.string(forKey: InvoicePreferenceKey.notes) ?? fallback.notes,
            paymentTermsText: preferences.string(forKey: InvoicePreferenceKey.paymentTermsText)
                ?? fallback.paymentTermsText
        )
    }

    /// Editor state applied by every invoice-creation workflow.
    public var editorConfiguration: InvoiceEditorConfiguration {
        InvoiceEditorConfiguration(showsTaxSummary: showsTaxSummary)
    }
}
