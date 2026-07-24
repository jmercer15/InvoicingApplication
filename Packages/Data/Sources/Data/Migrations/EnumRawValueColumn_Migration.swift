import Core
import Foundation
import os
import SQLite3
import SwiftData

/// Migration that backfills all `*Raw` String columns that replaced stored enum properties.
///
/// When enums are converted to `@Transient` computed properties backed by `*Raw: String` columns,
/// upon first launch after the update the old column data still exists in SQLite under the original
/// column name. SwiftData does NOT auto-rename columns — we must do it via SQLite directly.
///
/// Columns backfilled by this migration:
///   - ZSERVERSSTATUS         → Z_STATUSRAW    (Client)
///   - ZINVOICESTATUS         → Z_STATUSRAW    (Invoice)
///   - ZSESSIONSTATUS         → Z_STATUSRAW    (Session)
///   - ZBILLINGAUTHORITY      → Z_BILLINGAUTHORITYRAW  (Client, Invoice)
///   - ZCLAIMTYPE             → Z_CLAIMTYPERAW  (InvoiceItem)
///   - ZVEHICLETYPE           → Z_VEHICLETYPERAW  (TravelCharge)
///   - ZCHARGETYPE            → Z_CHARGETYPERAW  (TravelCharge)
///   - ZTRAVELDIRECTION       → Z_TRAVELDIRECTIONRAW  (TravelCharge)
///
/// SwiftData uses CoreData's naming conventions (Z-prefixed columns, entity tables named Z<ENTITY>).
/// The actual table and column names depend on the compiled schema.
/// This migration uses ModelContext-level fetch/save to be SQLite-agnostic, relying on the fact
/// that the old column values are still accessible as unknown KV pairs on the persistent record.
///
/// Strategy: fetch each entity, use the @Transient computed property getter (which reads *Raw),
/// detect if *Raw is empty while we can derive the value from the stored raw representation,
/// and backfill. Since the old column is now unknown to SwiftData, we rely on the fact that
/// SwiftData will have already migrated the SQLite schema — adding the new column with NULL —
/// so we need to use a different approach: SQLite PRAGMA-based column copy.
public enum EnumRawValueColumn_Migration {
    public static let version = "1.0.0"

    public static func execute(modelContext: ModelContext) throws {
        Logger.migration.info("🔄 Starting enum rawValue column backfill migration (v\(version, privacy: .public))")

        guard let store = modelContext.container.configurations.first?.url else {
            Logger.migration.warning("⚠️ Could not locate persistent store URL — skipping raw value migration")
            return
        }

        var db: OpaquePointer?
        guard sqlite3_open(store.path, &db) == SQLITE_OK, let db else {
            Logger.migration.error("❌ Could not open SQLite store at \(store.path, privacy: .public)")
            throw MigrationError.migrationFailed("Cannot open SQLite database for raw-value column backfill")
        }
        defer { sqlite3_close(db) }

        // Map of (tableName, oldColumn, newColumn) to copy.
        // SwiftData Core Data schema uses ZUPPER naming. These are the canonical names from
        // the generated store. Adjust if your schema uses different identifiers.
        let columnMappings: [(table: String, old: String, new: String)] = [
            // Client
            ("ZCLIENTENTITY", "ZSTATUS", "ZSTATUSRAW"),
            ("ZCLIENTENTITY", "ZBILLINGAUTHORITY", "ZBILLINGAUTHORITYRAW"),
            // Invoice
            ("ZINVOICEENTITY", "ZSTATUS", "ZSTATUSRAW"),
            ("ZINVOICEENTITY", "ZBILLINGAUTHORITY", "ZBILLINGAUTHORITYRAW"),
            // Session
            ("ZSESSIONENTITY", "ZSTATUS", "ZSTATUSRAW"),
            // InvoiceItem
            ("ZINVOICEITEMENTITY", "ZCLAIMTYPE", "ZCLAIMTYPERAW"),
            // TravelCharge
            ("ZTRAVELCHARGEENTITY", "ZVEHICLETYPE", "ZVEHICLETYPERAW"),
            ("ZTRAVELCHARGEENTITY", "ZCHARGETYPE", "ZCHARGETYPERAW"),
            ("ZTRAVELCHARGEENTITY", "ZTRAVELDIRECTION", "ZTRAVELDIRECTIONRAW")
        ]

        var totalCopied = 0

        for mapping in columnMappings {
            // Check both columns exist before attempting copy
            guard columnExists(db: db, table: mapping.table, column: mapping.old),
                  columnExists(db: db, table: mapping.table, column: mapping.new) else {
                Logger.migration.info("⏭️ Skipping \(mapping.table).\(mapping.old) → \(mapping.new): column(s) not found")
                continue
            }

            // Only backfill rows where the new column is NULL but the old column has a value
            let sql = """
            UPDATE \(mapping.table)
            SET \(mapping.new) = \(mapping.old)
            WHERE \(mapping.new) IS NULL AND \(mapping.old) IS NOT NULL
            """
            var errMsg: UnsafeMutablePointer<CChar>?
            let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)
            if rc != SQLITE_OK {
                let msg = errMsg.map { String(cString: $0) } ?? "unknown error"
                sqlite3_free(errMsg)
                Logger.migration.warning("⚠️ Failed to copy \(mapping.table).\(mapping.old): \(msg, privacy: .public)")
            } else {
                let rowsAffected = Int(sqlite3_changes(db))
                totalCopied += rowsAffected
                Logger.migration.info("✅ Copied \(rowsAffected, privacy: .public) rows: \(mapping.table).\(mapping.old) → \(mapping.new)")
            }
        }

        Logger.migration.notice("✅ EnumRawValue backfill complete — \(totalCopied, privacy: .public) rows updated across all tables")
    }

    public static func rollback(modelContext _: ModelContext) throws {
        // Intentionally a no-op: the old column data is untouched, so rolling back
        // simply means the app will fall back to empty rawValue columns (which default
        // to nil/empty for optional properties). A full rollback would require reverting
        // the entity schema change itself, which is managed at the SwiftData schema level.
        Logger.migration.info("↩️ EnumRawValueColumn rollback — no-op (old columns untouched)")
    }

    // MARK: - Private Helpers

    private static func columnExists(db: OpaquePointer, table: String, column: String) -> Bool {
        let sql = "PRAGMA table_info(\(table))"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let rawName = sqlite3_column_text(stmt, 1) {
                let colName = String(cString: rawName).uppercased()
                if colName == column.uppercased() { return true }
            }
        }
        return false
    }
}
