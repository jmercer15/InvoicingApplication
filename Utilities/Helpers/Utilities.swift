import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import SwiftData

// MARK: - Date Formatters
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    static let mediumDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Number Formatters
extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "AUD"  // Set default currency
        return formatter
    }()
}

// MARK: - Date Extensions
extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeek: Date {
        // Create a calendar that starts the week on Monday
        var mondayFirstCalendar = Calendar(identifier: .gregorian)
        mondayFirstCalendar.firstWeekday = 2  // 2 corresponds to Monday

        // Use the Monday-first calendar to calculate the start of week
        return mondayFirstCalendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: self).date ?? self
    }

    var endOfWeek: Date {
        let components = DateComponents(day: 7, second: -1)
        return Calendar.current.date(byAdding: components, to: startOfWeek) ?? self
    }

    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }

    var endOfMonth: Date {
        let components = DateComponents(month: 1, day: -1)
        return Calendar.current.date(byAdding: components, to: startOfMonth) ?? self
    }

    // Add currentWeek computed property
    var currentWeek: [Date] {
        // Assuming startOfWeek correctly calculates the start based on Monday being the first day
        let start = self.startOfWeek
        // Generate the 7 days of the week starting from 'start'
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    func formattedTime() -> String {
        DateFormatter.timeOnly.string(from: self)
    }

    func formattedMediumDate() -> String {
        DateFormatter.mediumDate.string(from: self)
    }
}

// MARK: - Color Extensions
extension Color {
    static let systemBackground = Color(NSColor.windowBackgroundColor)
    static let secondarySystemBackground = Color(NSColor.underPageBackgroundColor)
    static let tertiarySystemBackground = Color(NSColor.textBackgroundColor)
    static let secondary = Color(NSColor.secondaryLabelColor)
    static let lightGray = Color(NSColor.lightGray)
    static let systemGray = Color(NSColor.systemGray)
    static let systemRed = Color(NSColor.systemRed)
    static let systemBlue = Color(NSColor.systemBlue)
    static let systemGreen = Color(NSColor.systemGreen)
    static let systemOrange = Color(NSColor.systemOrange)
}

// Add an extension to EnvironmentValues to find views in the environment
extension EnvironmentValues {
    static func findView<T: View>(ofType type: T.Type) -> T? {
        // This is a placeholder implementation - in a real app, you might use a different approach
        // such as a shared environment object or a different view hierarchy traversal.
        // For demonstration purposes, this stub is included to represent the concept.

        // In a real implementation, you might:
        // 1. Use a shared view model or environment object
        // 2. Use a ViewModifier to scan the view hierarchy
        // 3. Use a coordinator pattern

        // For now, this will return nil, and you'll need to implement a proper view reference system
        // One approach would be to use PreferenceKeys to bubble up view references
        return nil
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

// MARK: - Invoice PDF and Sharing Service
public struct InvoiceSharingService {
    @MainActor
    public static func renderPDFData(invoice: InvoiceEntity, business: BusinessEntity, context: ModelContext) -> Data? {
        let sheet = A4InvoiceSheetView(invoice: invoice, business: business)
            .environment(\.modelContext, context)
            .environment(\.colorScheme, .light)
            .background(Color.white)
            .frame(width: 595, height: 842)

        let renderer = ImageRenderer(content: sheet)
        renderer.proposedSize = .init(width: 595, height: 842)
        renderer.scale = 3.0
        renderer.isOpaque = true
        if let cg = renderer.cgImage {
            let nsImage = NSImage(cgImage: cg, size: NSSize(width: 595, height: 842))
            guard let page = PDFPage(image: nsImage) else { return nil }
            let doc = PDFDocument()
            doc.insert(page, at: 0)
            return doc.dataRepresentation()
        }
        if let ns = renderer.nsImage, let page = PDFPage(image: ns) {
            let doc = PDFDocument()
            doc.insert(page, at: 0)
            return doc.dataRepresentation()
        }
        return nil
    }

    @MainActor
    public static func temporaryPDFURL(invoice: InvoiceEntity, business: BusinessEntity, context: ModelContext) -> URL? {
        guard let data = renderPDFData(invoice: invoice, business: business, context: context) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Invoice-\(invoice.invoiceNumber).pdf")
        do { try data.write(to: url) } catch { return nil }
        return url
    }

    @MainActor
    public static func pdfItemProvider(invoice: InvoiceEntity, business: BusinessEntity, context: ModelContext) -> NSItemProvider? {
        guard let data = renderPDFData(invoice: invoice, business: business, context: context) else { return nil }
        let provider = NSItemProvider()
        provider.suggestedName = "Invoice-\(invoice.invoiceNumber).pdf"
        provider.registerDataRepresentation(forTypeIdentifier: UTType.pdf.identifier, visibility: .all) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}
