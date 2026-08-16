import Foundation

/// Encode/decode EventKit sync-tag watermarks (ISO8601 + legacy wire format).
enum EventKitSyncTagFormatting: Sendable {
    // Cached formatters are immutable after setup; marked unsafe for cross-actor sync paths.
    nonisolated(unsafe) private static let writeFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let readFormatters: [ISO8601DateFormatter] = {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let internetDateTime = ISO8601DateFormatter()
        internetDateTime.formatOptions = [.withInternetDateTime]

        return [withFractional, internetDateTime]
    }()

    private static let legacyFormatter: DateFormatter = {
        // Parses legacy EventKit sync tags written as `ExportMachineFormatting.eventKitLegacySyncTag`.
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()

    nonisolated static func encode(_ date: Date?) -> String? {
        guard let date else { return nil }
        return writeFormatter.string(from: date)
    }

    nonisolated static func decode(_ rawValue: String?) -> Date? {
        guard let rawValue, !rawValue.isEmpty else { return nil }

        for formatter in readFormatters {
            if let parsed = formatter.date(from: rawValue) {
                return parsed
            }
        }

        return legacyFormatter.date(from: rawValue)
    }
}
