import Foundation
import Core
import PersistenceModels

public struct CurrencyAnalyticsSummary: Sendable, Equatable, Identifiable {
    public var id: String { currencyCode }
    public let currencyCode: String
    public let totalBilled: Double
    public let totalReceived: Double
    public let totalOutstanding: Double
    public let totalOverdue: Double
    public let draftCount: Int
    public let totalInvoiceCount: Int

    public init(
        currencyCode: String,
        totalBilled: Double,
        totalReceived: Double,
        totalOutstanding: Double,
        totalOverdue: Double,
        draftCount: Int,
        totalInvoiceCount: Int
    ) {
        self.currencyCode = currencyCode
        self.totalBilled = totalBilled
        self.totalReceived = totalReceived
        self.totalOutstanding = totalOutstanding
        self.totalOverdue = totalOverdue
        self.draftCount = draftCount
        self.totalInvoiceCount = totalInvoiceCount
    }
}

public struct RevenueAnalyticsSummary: Sendable, Equatable {
    public let currencySummaries: [CurrencyAnalyticsSummary]
    public let totalDraftCount: Int
    public let totalInvoiceCount: Int

    public init(
        currencySummaries: [CurrencyAnalyticsSummary],
        totalDraftCount: Int,
        totalInvoiceCount: Int
    ) {
        self.currencySummaries = currencySummaries
        self.totalDraftCount = totalDraftCount
        self.totalInvoiceCount = totalInvoiceCount
    }

    public var primarySummary: CurrencyAnalyticsSummary? {
        currencySummaries.first
    }
}

public enum InvoiceAnalyticsEngine {
    public static func calculateSummary(from invoices: [Invoice]) -> RevenueAnalyticsSummary {
        guard !invoices.isEmpty else {
            return RevenueAnalyticsSummary(currencySummaries: [], totalDraftCount: 0, totalInvoiceCount: 0)
        }

        var grouped: [String: [Invoice]] = [:]
        for invoice in invoices {
            let code = invoice.currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
            let currency = code.isEmpty ? "AUD" : code.uppercased()
            grouped[currency, default: []].append(invoice)
        }

        var currencySummaries: [CurrencyAnalyticsSummary] = []
        var globalDraftCount = 0
        let globalTotalCount = invoices.count

        for currencyCode in grouped.keys.sorted() {
            let items = grouped[currencyCode] ?? []
            var totalBilled: Double = 0.0
            var totalReceived: Double = 0.0
            var totalOutstanding: Double = 0.0
            var totalOverdue: Double = 0.0
            var draftCount: Int = 0

            for invoice in items {
                let status = invoice.effectiveStatus

                // Voided and cancelled invoices are excluded from billed/outstanding metrics
                if status == .cancelled || status == .voided {
                    continue
                }

                if status == .reviewDraft {
                    draftCount += 1
                    globalDraftCount += 1
                    continue
                }

                // Use stored list total — avoids faulting InvoiceItem.taxRate during
                // CloudKit history reset when line items may already be invalidated.
                let amount = NSDecimalNumber(decimal: invoice.totalAmount).doubleValue
                totalBilled += amount

                if status == .received {
                    totalReceived += amount
                } else {
                    totalOutstanding += amount
                    if invoice.isOverdue || status == .overdue {
                        totalOverdue += amount
                    }
                }
            }

            currencySummaries.append(
                CurrencyAnalyticsSummary(
                    currencyCode: currencyCode,
                    totalBilled: totalBilled,
                    totalReceived: totalReceived,
                    totalOutstanding: totalOutstanding,
                    totalOverdue: totalOverdue,
                    draftCount: draftCount,
                    totalInvoiceCount: items.count
                )
            )
        }

        return RevenueAnalyticsSummary(
            currencySummaries: currencySummaries,
            totalDraftCount: globalDraftCount,
            totalInvoiceCount: globalTotalCount
        )
    }
}
