import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import SwiftData
import Data

// MARK: - Date Formatters
public extension DateFormatter {
    public static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    public static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    public static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Number Formatters
public extension NumberFormatter {
    public static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"  // Set default currency
        return formatter
    }()
}

// MARK: - Date Extensions
public extension Date {
    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    public var startOfWeek: Date {
        // Create a calendar that starts the week on Monday
        var mondayFirstCalendar = Calendar(identifier: .gregorian)
        mondayFirstCalendar.firstWeekday = 2  // 2 corresponds to Monday

        // Use the Monday-first calendar to calculate the start of week
        return mondayFirstCalendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date ?? self
    }

    public var endOfWeek: Date {
        let components = DateComponents(day: 7, second: -1)
        return Calendar.current.date(byAdding: components, to: startOfWeek) ?? self
    }

    public var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    public var endOfMonth: Date {
        let components = DateComponents(month: 1, day: -1)
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }

    // Add currentWeek computed property
    public var currentWeek: [Date] {
        // Assuming startOfWeek correctly calculates the start based on Monday being the first day
        let start = self.startOfWeek
        // Generate the 7 days of the week starting from 'start'
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    public func formattedTime() -> String {
        DateFormatter.timeOnly.string(from: self)
    }

    public func formattedMediumDate() -> String {
        DateFormatter.mediumDate.string(from: self)
    }
}

// MARK: - Invoice Numbering Service
public struct InvoiceNumberingService {
    public static func nextNumber(for client: ClientEntity?, context: ModelContext) -> String {
        if let client = client {
            let nameParts = client.fullName.split(separator: " ").map { String($0) }
            if let first = nameParts.first, let last = nameParts.last, !first.isEmpty, !last.isEmpty {
                let surnamePart = String(last.uppercased().prefix(4))
                let firstInitial = String(first.uppercased().prefix(1))
                let prefix = "\(surnamePart)-\(firstInitial)-"
                let fetch = FetchDescriptor<InvoiceEntity>()
                let all = (try? context.fetch(fetch)) ?? []
                let clientInvoices = all.filter { $0.invoiceNumber.starts(with: prefix) && $0.client?.id == client.id }
                let suffixes = clientInvoices.compactMap { inv -> Int? in
                    guard inv.invoiceNumber.starts(with: prefix) else { return nil }
                    return Int(String(inv.invoiceNumber.dropFirst(prefix.count)))
                }
                let next = (suffixes.max() ?? 0) + 1
                return "\(prefix)\(String(format: "%04d", next))"
            }
        }
        // Generic fallback INV-####
        let fetch = FetchDescriptor<InvoiceEntity>()
        let all = (try? context.fetch(fetch)) ?? []
        let suffixes = all.compactMap { inv -> Int? in
            let parts = inv.invoiceNumber.split(separator: "-")
            guard parts.count >= 2 else { return nil }
            return Int(parts.last!)
        }
        let next = (suffixes.max() ?? 0) + 1
        return String(format: "INV-%04d", next)
    }
}
