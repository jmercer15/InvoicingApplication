import Core
import PersistenceModels
import Foundation
import SwiftData

/// Rewrites invoice statuses to canonical persisted tokens.
public enum NormalizeInvoiceStatusValues_Migration {
    public static let version = "1.0.0"

    public static func execute(modelContext: ModelContext) throws {
        print("🔄 Starting invoice status normalization migration (v\(version))")

        let descriptor = FetchDescriptor<Invoice>()
        let invoices = try modelContext.fetch(descriptor)

        var rewrites = 0
        for invoice in invoices {
            // Normalize nil or invalid status to canonical value so cast never fails on next load.
            invoice.status = invoice.status ?? .reviewDraft
            rewrites += 1
        }

        if rewrites > 0 {
            try modelContext.save()
        }

        print("✅ Invoice status normalization migration completed (\(rewrites) rewritten)")
    }

    public static func rollback(modelContext _: ModelContext) throws {
        // One-way canonicalization; no rollback needed.
    }
}
