import Foundation
import SwiftData

/// Historical migration: legacy Double money columns were mirrored into Decimal fields (schema v2).
///
/// Schema v3 removes legacy doubles; this step is retained as a no-op for stores that already ran
/// the backfill under v2. Fresh v3 installs skip legacy columns entirely.
public enum BackfillMoneyDecimalFields_v1 {
    public static let migrationID = "backfill_money_decimal_fields_v1"

    public static func execute(modelContext: ModelContext) throws {
        _ = modelContext
    }

    public static func rollback(modelContext: ModelContext) throws {
        _ = modelContext
    }
}
