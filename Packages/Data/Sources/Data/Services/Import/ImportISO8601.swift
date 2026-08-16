import Foundation

/// Cached ISO8601 parse/format for All-Data import/export dictionary payloads.
///
/// Uses the default `ISO8601DateFormatter` options (internet date-time) to match the
/// historical `ISO8601DateFormatter().date(from:)` call sites this replaces.
enum ImportISO8601: Sendable {
    nonisolated(unsafe) private static let formatter = ISO8601DateFormatter()

    nonisolated static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }

    nonisolated static func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return date(from: string)
    }

    nonisolated static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
