import Foundation
@_exported import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.invoicing.app"

    /// Logs related to calendar synchronization and management.
    public static let calendar = Logger(subsystem: subsystem, category: "Calendar")

    /// Logs related to data persistence and storage operations.
    public static let data = Logger(subsystem: subsystem, category: "Data")

    /// Logs related to invoicing and billing logic.
    public static let billing = Logger(subsystem: subsystem, category: "Billing")

    /// Logs related to client management.
    public static let clients = Logger(subsystem: subsystem, category: "Clients")

    /// Logs related to data import/export operations.
    public static let importExport = Logger(subsystem: subsystem, category: "ImportExport")

    /// Logs related to travel charge automation and business rules.
    public static let automation = Logger(subsystem: subsystem, category: "Automation")

    /// Logs related to database migrations.
    public static let migration = Logger(subsystem: subsystem, category: "Migration")
}
