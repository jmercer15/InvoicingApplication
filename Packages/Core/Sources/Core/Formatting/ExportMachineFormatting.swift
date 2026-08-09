import Foundation

/// Fixed-pattern strings for filenames, export tokens, and other non-UI literals.
///
/// Do not use for user-facing labels — prefer locale-aware FormatStyle at the UI layer.
public enum ExportMachineFormatting {
    /// Export filename segment: `yyyy-MM-dd-HHmmss` (JSON/CSV/XML bundle exports).
    public static func exportTimestamp(_ date: Date = Date()) -> String {
        fixedPattern("yyyy-MM-dd-HHmmss", date: date)
    }

    /// BPR CSV export filename segment: `yyyyMMdd_HHmmss`.
    public static func bprExportTimestamp(_ date: Date = Date()) -> String {
        fixedPattern("yyyyMMdd_HHmmss", date: date)
    }

    /// BPR CSV support-delivery date column: `yyyy-MM-dd`.
    public static func exportDate(_ date: Date) -> String {
        fixedPattern("yyyy-MM-dd", date: date, timeZone: TimeZone(secondsFromGMT: 0))
    }

    /// EventKit sync-tag legacy wire format: `yyyy-MM-dd HH:mm:ss Z`.
    public static func eventKitLegacySyncTag(_ date: Date) -> String {
        fixedPattern("yyyy-MM-dd HH:mm:ss Z", date: date, timeZone: TimeZone(secondsFromGMT: 0))
    }

    /// NDIS/BPR hours column from decimal quantity (e.g. `003:30`).
    public static func claimHoursToken(fromHourQuantity quantity: Decimal) -> String {
        let totalMinutes = max(Int((NSDecimalNumber(decimal: quantity).doubleValue * 60).rounded()), 0)
        return claimHoursToken(hours: totalMinutes / 60, minutes: totalMinutes % 60)
    }

    /// NDIS/BPR hours column from legacy double quantity (e.g. `003:30`).
    public static func claimHoursToken(fromHourQuantity quantity: Double) -> String {
        claimHoursToken(fromHourQuantity: Decimal(quantity))
    }

    /// NDIS/BPR hours column token (e.g. `003:30`).
    public static func claimHoursToken(hours: Int, minutes: Int) -> String {
        String(format: "%03d:%02d", max(hours, 0), max(minutes, 0))
    }

    /// Fixed three-decimal export quantity (trailing zeros trimmed).
    public static func exportDecimal3(_ value: Decimal) -> String {
        var rounded = value
        var result = Decimal()
        NSDecimalRound(&result, &rounded, 3, .plain)
        var text = result.formatted(.number.precision(.fractionLength(3)).locale(posixLocale))
        while text.contains(".") && text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text
    }

    /// Fixed three-decimal export quantity from legacy double input.
    public static func exportDecimal3(_ value: Double) -> String {
        exportDecimal3(Decimal(value))
    }

    /// Fixed two-decimal export amount.
    public static func exportDecimal2(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(2)).locale(posixLocale))
    }

    /// Fixed two-decimal export amount from legacy double input.
    public static func exportDecimal2(_ value: Double) -> String {
        exportDecimal2(Decimal(value))
    }

    /// Fixed clock time for export columns: `HH:mm`.
    public static func exportTime(_ date: Date) -> String {
        fixedPattern("HH:mm", date: date, timeZone: TimeZone(secondsFromGMT: 0))
    }

    /// Lowercase SHA-256 hex digest for export checksum columns.
    public static func sha256Hex<D: Sequence<UInt8>>(digest: D) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static var posixLocale: Locale {
        Locale(identifier: "en_US_POSIX")
    }

    private static func fixedPattern(_ pattern: String, date: Date, timeZone: TimeZone? = nil) -> String {
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone ?? .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}
