import Foundation
import SwiftData
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// SwiftData Export Service
/// Provides data export capabilities for the InvoicingApplication
public struct SwiftDataExportService {

    // MARK: - Export
    public static func exportAllEntitiesToJSON(context: ModelContext) throws -> Data {
        let exportDict = try collectEntityDictionaries(context: context)
        return try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])
    }

    public static func exportToFile(context: ModelContext, format: SwiftDataExportFormat = .json) throws -> (Data, String) {
        switch format {
        case .json:
            let data = try exportAllEntitiesToJSON(context: context)
            let timestamp = DateFormatter.exportTimestamp.string(from: Date())
            let filename = "InvoicingApp-Export-\(timestamp).json"
            return (data, filename)

        case .csv:
            let exportDict = try collectEntityDictionaries(context: context)
            let csvString = buildCSV(from: exportDict)
            let timestamp = DateFormatter.exportTimestamp.string(from: Date())
            let filename = "InvoicingApp-Export-\(timestamp).csv"
            return (Data(csvString.utf8), filename)

        case .excel:
            let exportDict = try collectEntityDictionaries(context: context)
            let workbookXML = buildSpreadsheetML(from: exportDict)
            let timestamp = DateFormatter.exportTimestamp.string(from: Date())
            let filename = "InvoicingApp-Export-\(timestamp).xml"
            return (Data(workbookXML.utf8), filename)
        }
    }
}

/// Export format options
public enum SwiftDataExportFormat {
    case json
    case csv
    case excel
}

// Extension to add ISO8601 string conversion to Date
extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}

extension DateFormatter {
    static let exportTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

// MARK: - Private Helpers
private extension SwiftDataExportService {
    static func collectEntityDictionaries(context: ModelContext) throws -> [String: [[String: Any]]] {
        var exportDict: [String: [[String: Any]]] = [:]

        let iso = ISO8601DateFormatter()

        let clientDescriptor = FetchDescriptor<ClientEntity>()
        let clients = try context.fetch(clientDescriptor)
        exportDict["ClientEntity"] = clients.map { client -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = client.id.uuidString
            dict["fullName"] = client.fullName
            dict["email"] = client.email ?? ""
            dict["phone"] = client.phone ?? ""
            dict["ndisNumber"] = client.ndisNumber
            dict["status"] = client.status
            dict["notes"] = client.notes ?? ""
            dict["creditAmount"] = client.creditAmount
            dict["isMinor"] = client.isMinor
            dict["hasNdisPlan"] = client.hasNdisPlan
            dict["planManagementType"] = client.planManagementType ?? ""
            dict["billingAuthority"] = client.billingAuthority ?? ""
            dict["sendInvoicesToClient"] = client.sendInvoicesToClient
            dict["sendInvoicesToPayee"] = client.sendInvoicesToPayee
            dict["sendInvoicesToPlanManager"] = client.sendInvoicesToPlanManager
            return dict
        }

        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
        let payees = try context.fetch(payeeDescriptor)
        exportDict["PayeeEntity"] = payees.map { payee -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = payee.id.uuidString
            dict["fullName"] = payee.fullName
            dict["email"] = payee.email ?? ""
            dict["phone"] = payee.phone ?? ""
            dict["payeeID"] = payee.payeeID
            dict["relationToClient"] = payee.relationToClient ?? ""
            dict["status"] = payee.status ?? ""
            return dict
        }

        let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>()
        let planManagers = try context.fetch(planManagerDescriptor)
        exportDict["PlanManagerEntity"] = planManagers.map { planManager -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = planManager.id.uuidString
            dict["businessName"] = planManager.name ?? ""
            dict["contactName"] = planManager.name ?? ""
            dict["email"] = planManager.email ?? ""
            dict["phone"] = planManager.phone ?? ""
            dict["abn"] = planManager.abn
            return dict
        }

        let clientServiceDescriptor = FetchDescriptor<ClientServiceEntity>()
        let clientServices = try context.fetch(clientServiceDescriptor)
        exportDict["ClientServiceEntity"] = clientServices.map { clientService -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = clientService.id.uuidString
            dict["clientId"] = clientService.client?.id.uuidString ?? ""
            dict["serviceName"] = clientService.serviceName
            dict["rate"] = clientService.rate
            dict["unit"] = clientService.unit
            dict["status"] = clientService.status ?? ""
            dict["isActive"] = clientService.isActive
            dict["startDate"] = clientService.startDate.map { iso.string(from: $0) } ?? ""
            dict["endDate"] = clientService.endDate.map { iso.string(from: $0) } ?? ""
            dict["ndisCode"] = clientService.ndisCode ?? ""
            dict["ndisItemId"] = clientService.ndisItem?.id.uuidString ?? ""
            return dict
        }

        let invoiceDescriptor = FetchDescriptor<InvoiceEntity>()
        let invoices = try context.fetch(invoiceDescriptor)
        exportDict["InvoiceEntity"] = invoices.map { invoice -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = invoice.id.uuidString
            dict["invoiceNumber"] = invoice.invoiceNumber
            dict["date"] = iso.string(from: invoice.date)
            dict["issueDate"] = iso.string(from: invoice.issueDate)
            dict["dueDate"] = invoice.dueDate.map { iso.string(from: $0) } ?? ""
            dict["totalAmount"] = invoice.totalAmount
            dict["status"] = invoice.status ?? ""
            dict["clientId"] = invoice.client?.id.uuidString ?? ""
            dict["billingOrder"] = invoice.billingOrder
            return dict
        }

        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        let sessions = try context.fetch(sessionDescriptor)
        exportDict["SessionEntity"] = sessions.map { session -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = session.id.uuidString
            dict["title"] = session.title
            dict["startTime"] = session.startTime.map { iso.string(from: $0) } ?? ""
            dict["endTime"] = session.endTime.map { iso.string(from: $0) } ?? ""
            dict["location"] = session.location ?? ""
            dict["notes"] = session.notes ?? ""
            dict["status"] = session.status ?? ""
            dict["clientId"] = session.client?.id.uuidString ?? ""
            return dict
        }

        return exportDict
    }

    static func buildCSV(from exportDict: [String: [[String: Any]]]) -> String {
        let orderedEntities = exportDict.keys.sorted()
        var sections: [String] = []

        for entityName in orderedEntities {
            guard let rows = exportDict[entityName], !rows.isEmpty else { continue }
            let headers = orderedHeaders(for: rows)
            var csv = "# \(entityName)" + "\n"
            csv += headers.joined(separator: ",") + "\n"

            for row in rows {
                let line = headers
                    .map { header -> String in
                        let value = row[header] ?? ""
                        return escapeCSVField(stringify(value))
                    }
                    .joined(separator: ",")
                csv += line + "\n"
            }
            sections.append(csv.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return sections.joined(separator: "\n\n") + "\n"
    }

    static func buildSpreadsheetML(from exportDict: [String: [[String: Any]]]) -> String {
        let orderedEntities = exportDict.keys.sorted()
        var worksheets: [String] = []

        for entity in orderedEntities {
            guard let rows = exportDict[entity], !rows.isEmpty else { continue }
            let headers = orderedHeaders(for: rows)
            var rowsXML = "    <Row>\n"
            for header in headers {
                rowsXML += "      <Cell><Data ss:Type=\"String\">\(escapeXML(header))</Data></Cell>\n"
            }
            rowsXML += "    </Row>\n"

            for row in rows {
                rowsXML += "    <Row>\n"
                for header in headers {
                    let value = row[header] ?? ""
                    let stringValue = stringify(value)
                    let type = (Double(stringValue) != nil) ? "Number" : "String"
                    rowsXML += "      <Cell><Data ss:Type=\"\(type)\">\(escapeXML(stringValue))</Data></Cell>\n"
                }
                rowsXML += "    </Row>\n"
            }

            let worksheetName = escapeXML(String(entity.prefix(31)))
            let worksheet = "  <Worksheet ss:Name=\"\(worksheetName)\">\n    <Table>\n\(rowsXML)    </Table>\n  </Worksheet>"
            worksheets.append(worksheet)
        }

        let workbook = """
<?xml version=\"1.0\"?>
<Workbook xmlns=\"urn:schemas-microsoft-com:office:spreadsheet\"
          xmlns:o=\"urn:schemas-microsoft-com:office:office\"
          xmlns:x=\"urn:schemas-microsoft-com:office:excel\"
          xmlns:ss=\"urn:schemas-microsoft-com:office:spreadsheet\">
\(worksheets.joined(separator: "\n"))
</Workbook>
"""
        return workbook
    }

    static func orderedHeaders(for rows: [[String: Any]]) -> [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        for row in rows {
            for key in row.keys where !seen.contains(key) {
                ordered.append(key)
                seen.insert(key)
            }
        }
        return ordered
    }

    static func stringify(_ value: Any) -> String {
        switch value {
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let number as NSNumber:
            return number.stringValue
        case let bool as Bool:
            return bool ? "true" : "false"
        case let string as String:
            return string
        case let uuid as UUID:
            return uuid.uuidString
        case let array as [Any]:
            return array.map { stringify($0) }.joined(separator: ";")
        default:
            return String(describing: value)
        }
    }

    static func escapeCSVField(_ value: String) -> String {
        var result = value
        if result.contains(",") || result.contains("\"") || result.contains("\n") {
            result = "\"" + result.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return result
    }

    static func escapeXML(_ value: String) -> String {
        var escaped = value.replacingOccurrences(of: "&", with: "&amp;")
        escaped = escaped.replacingOccurrences(of: "<", with: "&lt;")
        escaped = escaped.replacingOccurrences(of: ">", with: "&gt;")
        escaped = escaped.replacingOccurrences(of: "\"", with: "&quot;")
        escaped = escaped.replacingOccurrences(of: "'", with: "&apos;")
        return escaped
    }
}
