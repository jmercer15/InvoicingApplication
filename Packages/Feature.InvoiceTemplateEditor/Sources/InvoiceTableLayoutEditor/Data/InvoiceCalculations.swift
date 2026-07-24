import Core
import Foundation

enum InvoiceBillingAuthorityResolution {
    static func resolve(
        rawValue: String,
        billsParticipantDirectly: Bool
    ) -> Core.BillingAuthority? {
        if billsParticipantDirectly { return .client }
        return Core.BillingAuthority(rawValue: rawValue)
    }
}

enum InvoiceCalculations {
    struct LineItemInput: Sendable, Equatable {
        let quantity: Decimal
        let unitPrice: Decimal
        let taxRate: Decimal
    }

    struct InvoiceTotals: Sendable, Equatable {
        let subtotal: Decimal
        let taxTotal: Decimal
        let grandTotal: Decimal
    }

    static func currencyRounded(_ amount: Decimal) -> Decimal {
        InvoiceFinancialCalculator.currencyRounded(amount)
    }

    static func lineSubtotal(quantity: Decimal, unitPrice: Decimal) -> Decimal {
        InvoiceFinancialCalculator.lineSubtotal(quantity: quantity, unitPrice: unitPrice)
    }

    static func lineTax(subtotal: Decimal, taxRate: Decimal) -> Decimal {
        InvoiceFinancialCalculator.lineTax(subtotal: subtotal, taxRate: taxRate)
    }

    static func lineTotal(subtotal: Decimal, taxRate: Decimal) -> Decimal {
        InvoiceFinancialCalculator.lineTotal(subtotal: subtotal, taxRate: taxRate)
    }

    static func invoiceTotals(
        lineItems: [LineItemInput],
        discountAmount: Decimal,
        discountPercent: Decimal = 0,
        creditApplied: Decimal = 0
    ) -> InvoiceTotals {
        let totals = InvoiceFinancialCalculator.calculate(
            lineItems: lineItems.map {
                InvoiceFinancialCalculator.LineItem(
                    quantity: $0.quantity,
                    unitPrice: $0.unitPrice,
                    taxRate: $0.taxRate
                )
            },
            fixedDiscount: discountAmount,
            percentageDiscount: discountPercent,
            creditApplied: creditApplied
        )

        return InvoiceTotals(
            subtotal: totals.subtotal,
            taxTotal: totals.taxTotal,
            grandTotal: totals.grandTotal
        )
    }

    static func discountValue(
        subtotal: Decimal,
        discountAmount: Decimal,
        discountPercent: Decimal
    ) -> Decimal {
        InvoiceFinancialCalculator.discountValue(
            subtotal: subtotal,
            fixedDiscount: discountAmount,
            percentageDiscount: discountPercent
        )
    }
}

enum InvoiceNumberGenerator {
    static func nextNumber(existingNumbers: [String], issueDate: Date = .now) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let year = calendar.component(.year, from: issueDate)
        let prefix = "INV-\(year)-"

        let sequenceNumbers = existingNumbers
            .filter { $0.hasPrefix(prefix) }
            .compactMap { number -> Int? in
                let suffix = number.dropFirst(prefix.count)
                return Int(suffix)
            }

        let next = (sequenceNumbers.max() ?? 0) + 1
        return String(format: "%@%03d", prefix, next)
    }
}

enum InvoiceValidation {
    struct Result: Sendable, Equatable {
        let isValid: Bool
        let errors: [String]
    }

    static func validate(draft: InvoiceDraft) -> Result {
        var errors = validate(
            clientName: draft.client.name,
            issueDate: draft.issueDate,
            dueDate: draft.dueDate,
            currencyCode: draft.currencyCode,
            defaultTaxRate: draft.defaultTaxRate,
            discountAmount: draft.adjustments.discountAmount,
            discountPercent: draft.adjustments.discountPercent,
            creditApplied: draft.adjustments.creditApplied,
            lineItems: draft.lineItems.map(\.calculationInput)
        ).errors

        let lineItemIDs = draft.lineItems.map(\.id)
        if draft.invoiceNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Invoice number is required.")
        }
        if Set(lineItemIDs).count != lineItemIDs.count {
            errors.append("Duplicate line items must be removed before saving.")
        }

        return Result(isValid: errors.isEmpty, errors: errors)
    }

    static func validate(
        clientName: String,
        issueDate: Date? = nil,
        dueDate: Date? = nil,
        currencyCode: String = InvoiceCurrencyCode.defaultValue,
        defaultTaxRate: Decimal = 0,
        discountAmount: Decimal = 0,
        discountPercent: Decimal = 0,
        creditApplied: Decimal = 0,
        lineItems: [InvoiceCalculations.LineItemInput]
    ) -> Result {
        var errors: [String] = []

        if clientName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Client name is required.")
        }

        if let issueDate, let dueDate, dueDate < issueDate {
            errors.append("Due date cannot be earlier than the issue date.")
        }

        if !InvoiceCurrencyCode.isValid(currencyCode) {
            errors.append("Currency must be a three-letter ISO code, such as AUD or USD.")
        }

        if defaultTaxRate < 0 {
            errors.append("Default tax rate cannot be negative.")
        }

        if defaultTaxRate > 100 {
            errors.append("Default tax rate must be between 0 and 100.")
        }

        if discountPercent < 0 || discountPercent > 100 {
            errors.append("Discount percentage must be between 0 and 100.")
        }

        if discountAmount < 0 {
            errors.append("Discount amount cannot be negative.")
        }

        if creditApplied < 0 {
            errors.append("Credit applied cannot be negative.")
        }

        if lineItems.isEmpty {
            errors.append("At least one line item is required.")
        }

        if lineItems.contains(where: {
            $0.quantity <= 0 || $0.unitPrice < 0 || $0.taxRate < 0
        }) {
            errors.append("Line item quantity must be greater than zero; price and tax rate cannot be negative.")
        }

        if lineItems.contains(where: { $0.taxRate > 100 }) {
            errors.append("Line item tax rate must be between 0 and 100.")
        }

        return Result(isValid: errors.isEmpty, errors: errors)
    }
}
