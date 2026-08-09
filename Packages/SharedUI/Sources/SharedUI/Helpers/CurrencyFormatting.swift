import Foundation
import Core

/// Locale-aware currency and measurement display for UI surfaces.
public enum CurrencyFormatting {
    public static func display(
        _ amount: Double,
        code: String = "AUD",
        locale: Locale = .current
    ) -> String {
        Decimal(amount).formatted(.currency(code: code).locale(locale))
    }

    public static func display(
        _ amount: Decimal,
        code: String = "AUD",
        locale: Locale = .current
    ) -> String {
        amount.formatted(.currency(code: code).locale(locale))
    }

    /// Numeric text for editable amount fields (no currency symbol).
    public static func editableAmount(_ amount: Double, fractionDigits: Int = 2) -> String {
        amount.formatted(.number.precision(.fractionLength(fractionDigits)))
    }

    public static func editableAmount(_ amount: Decimal, fractionDigits: Int = 2) -> String {
        amount.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}

/// Locale-aware calendar dates and clock times for UI surfaces.
public enum DateFormatting {
    public static func shortDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .numeric, time: .omitted).locale(locale))
    }

    public static func mediumDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }

    public static func longDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .long, time: .omitted).locale(locale))
    }

    public static func timeOnly(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    /// Compact weekday label for calendar column headers (e.g. "Mon").
    public static func weekdayAbbreviation(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).locale(locale))
    }

    /// Day-of-month numeral for calendar cells (e.g. "12").
    public static func dayNumber(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(.dateTime.day(.defaultDigits).locale(locale))
    }

    /// Hour-of-day label for week time column (e.g. "3 PM").
    public static func hourMeridiemLabel(forHour hour: Int, locale: Locale = .current) -> String {
        var components = DateComponents()
        components.hour = hour
        guard let date = Calendar.current.date(from: components) else {
            return String(hour)
        }
        return date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)).locale(locale))
    }

    /// Spoken date for accessibility labels.
    public static func fullAccessibilityDate(_ date: Date, locale: Locale = .current) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day().year().locale(locale))
    }
}

/// Fixed-pattern strings for filenames, export tokens, and other non-UI literals.
///
/// Do not use for user-facing labels — prefer `DateFormatting`, `CurrencyFormatting`, or
/// `MeasurementFormatting`. See `DEVELOPER_NOTES.md` (FormatStyle section).
public enum MachineFormatting {
    /// Export filename segment: `yyyy-MM-dd-HHmmss` (JSON/CSV/XML bundle exports).
    public static func exportTimestamp(_ date: Date = Date()) -> String {
        ExportMachineFormatting.exportTimestamp(date)
    }

    /// BPR CSV export filename segment: `yyyyMMdd_HHmmss`.
    public static func bprExportTimestamp(_ date: Date = Date()) -> String {
        ExportMachineFormatting.bprExportTimestamp(date)
    }

    /// BPR CSV support-delivery date column: `yyyy-MM-dd`.
    public static func exportDate(_ date: Date) -> String {
        ExportMachineFormatting.exportDate(date)
    }

    /// EventKit sync-tag legacy wire format: `yyyy-MM-dd HH:mm:ss Z`.
    public static func eventKitLegacySyncTag(_ date: Date) -> String {
        ExportMachineFormatting.eventKitLegacySyncTag(date)
    }

    /// NDIS/BPR hours column from decimal quantity (e.g. `003:30`).
    public static func claimHoursToken(fromHourQuantity quantity: Double) -> String {
        ExportMachineFormatting.claimHoursToken(fromHourQuantity: quantity)
    }

    /// NDIS/BPR hours column token (e.g. `003:30`).
    public static func claimHoursToken(hours: Int, minutes: Int) -> String {
        ExportMachineFormatting.claimHoursToken(hours: hours, minutes: minutes)
    }

    /// Fixed three-decimal export quantity (trailing zeros trimmed).
    public static func exportDecimal3(_ value: Decimal) -> String {
        ExportMachineFormatting.exportDecimal3(value)
    }

    /// Fixed two-decimal export amount.
    public static func exportDecimal2(_ value: Decimal) -> String {
        ExportMachineFormatting.exportDecimal2(value)
    }

    /// Lowercase SHA-256 hex digest for export checksum columns.
    public static func sha256Hex<D: Sequence<UInt8>>(digest: D) -> String {
        ExportMachineFormatting.sha256Hex(digest: digest)
    }
}

/// Non-currency numeric labels for travel, duration, and support-log strings.
public enum MeasurementFormatting {
    public static func kilometers(_ value: Double, fractionDigits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits))) + " km"
    }

    public static func minutes(_ value: Double, fractionDigits: Int = 0) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits))) + " min"
    }

    public static func hoursShort(_ value: Double, fractionDigits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits))) + "h"
    }

    public static func decimal(_ value: Double, fractionDigits: Int) -> String {
        value.formatted(.number.precision(.fractionLength(fractionDigits)))
    }
}
