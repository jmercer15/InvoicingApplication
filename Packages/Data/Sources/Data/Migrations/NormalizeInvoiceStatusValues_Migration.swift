import Foundation
import SwiftData

/// Rewrites invoice statuses to canonical persisted tokens.
public enum NormalizeInvoiceStatusValues_Migration {
    public static let version = "1.0.0"

    public static func execute(modelContext: ModelContext) throws {
        print("🔄 Starting invoice status normalization migration (v\(version))")

        let descriptor = FetchDescriptor<InvoiceEntity>()
        let invoices = try modelContext.fetch(descriptor)

        var rewrites = 0
        for invoice in invoices {
            // Assignment forces canonical raw value persistence with current enum encoding.
            invoice.status = invoice.status
            rewrites += 1
        }

        if rewrites > 0 {
            try modelContext.save()
        }

        print("✅ Invoice status normalization migration completed (\(rewrites) rewritten)")
    }

    public static func rollback(modelContext: ModelContext) throws {
        _ = modelContext
        // One-way canonicalization; no rollback needed.
    }
}
