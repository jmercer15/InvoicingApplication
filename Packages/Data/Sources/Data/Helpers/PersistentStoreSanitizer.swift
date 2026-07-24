import Core
import Foundation
import SQLite3

/// Performs idempotent in-place cleanup of legacy status values before SwiftData loads the store.
public enum PersistentStoreSanitizer {
    public static func sanitizeLegacyStatusesIfNeeded() {
        let defaultsKey = "hasSanitizedLegacyStatuses_v1"
        if UserDefaults.standard.bool(forKey: defaultsKey) { return }

        for path in candidateStorePaths() {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            sanitizeStoreIfNeeded(at: path)
        }
        
        UserDefaults.standard.set(true, forKey: defaultsKey)
    }

    private static func candidateStorePaths() -> [String] {
        let fileManager = FileManager.default
        var candidates = Set<String>()

        if let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            candidates.insert(appSupport.appendingPathComponent("default.store").path)

            if let enumerator = fileManager.enumerator(
                at: appSupport,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) {
                for case let url as URL in enumerator {
                    guard url.lastPathComponent == "default.store" else { continue }
                    candidates.insert(url.path)
                }
            }
        }

        let homeDefault = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/default.store")
            .path
        candidates.insert(homeDefault)

        return Array(candidates)
    }

    private static func sanitizeStoreIfNeeded(at path: String) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK, let db else {
            return
        }
        defer { sqlite3_close(db) }

        let invoiceTables = tables(in: db).filter { $0.localizedCaseInsensitiveContains("invoice") }
        let sessionTables = tables(in: db).filter { $0.localizedCaseInsensitiveContains("session") }

        for table in invoiceTables where hasColumn(in: db, table: table, column: "ZSTATUS") {
            execute("UPDATE \(table) SET ZSTATUS = 'review_draft' WHERE ZSTATUS IS NULL OR TRIM(ZSTATUS) = '';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'review_draft' WHERE LOWER(TRIM(ZSTATUS)) IN ('draft', 'review draft');", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'ready_to_send' WHERE LOWER(TRIM(ZSTATUS)) = 'ready to send';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'pending' WHERE LOWER(TRIM(ZSTATUS)) = 'sent';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'received' WHERE LOWER(TRIM(ZSTATUS)) IN ('paid', 'completed');", db: db)
        }

        for table in sessionTables where hasColumn(in: db, table: table, column: "ZSTATUS") {
            execute("UPDATE \(table) SET ZSTATUS = 'needs_travel' WHERE LOWER(TRIM(ZSTATUS)) IN ('needs services', 'needs_services');", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'scheduled' WHERE LOWER(TRIM(ZSTATUS)) = 'scheduled';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'completed' WHERE LOWER(TRIM(ZSTATUS)) = 'completed';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'cancelled' WHERE LOWER(TRIM(ZSTATUS)) = 'cancelled';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'no_show' WHERE LOWER(TRIM(ZSTATUS)) = 'no show';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'rescheduled' WHERE LOWER(TRIM(ZSTATUS)) = 'rescheduled';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'grouped' WHERE LOWER(TRIM(ZSTATUS)) = 'grouped';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'needs_travel' WHERE LOWER(TRIM(ZSTATUS)) = 'needs travel';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'review_draft' WHERE LOWER(TRIM(ZSTATUS)) = 'review draft';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'ready_to_send' WHERE LOWER(TRIM(ZSTATUS)) IN ('ready to send', 'ready to send');", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'pending' WHERE LOWER(TRIM(ZSTATUS)) = 'pending';", db: db)
            execute("UPDATE \(table) SET ZSTATUS = 'received' WHERE LOWER(TRIM(ZSTATUS)) = 'received';", db: db)
        }
    }

    private static func execute(_ sql: String, db: OpaquePointer) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    private static func tables(in db: OpaquePointer) -> [String] {
        var names: [String] = []
        var statement: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type = 'table';"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return names
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                names.append(String(cString: cString))
            }
        }
        return names
    }

    private static func hasColumn(in db: OpaquePointer, table: String, column: String) -> Bool {
        var statement: OpaquePointer?
        let sql = "PRAGMA table_info(\(table));"
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 1) {
                if String(cString: cString).caseInsensitiveCompare(column) == .orderedSame {
                    return true
                }
            }
        }
        return false
    }
}
