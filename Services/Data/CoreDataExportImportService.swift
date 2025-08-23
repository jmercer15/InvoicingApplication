import Foundation
import SwiftData
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// Comprehensive SwiftData Export/Import Service
/// Provides unified data management capabilities for the InvoicingApplication
struct SwiftDataExportImportService {
    
    // MARK: - Export
    static func exportAllEntitiesToJSON(context: ModelContext) throws -> Data {
        // SwiftData doesn't have a managed object model like Core Data
        // We'll need to manually specify the entities we want to export
        var exportDict: [String: [[String: Any]]] = [:]
        _ = ISO8601DateFormatter()
        
        // Export Clients
        let clientDescriptor = FetchDescriptor<ClientEntity>()
        let clients = try context.fetch(clientDescriptor)
        exportDict["ClientEntity"] = clients.map { client -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = client.id.uuidString
            dict["fullName"] = client.fullName
            dict["email"] = client.email
            dict["phone"] = client.phone
            dict["ndisNumber"] = client.ndisNumber
            dict["isMinor"] = client.isMinor
            dict["hasNdisPlan"] = client.hasNdisPlan
            dict["planManagementType"] = client.planManagementType
            dict["billingAuthority"] = client.billingAuthority
            dict["creditAmount"] = client.creditAmount
            dict["status"] = client.status
            dict["color"] = colorToHexString(value: client.color)
            
            // Handle address
            if let address = client.address {
                dict["address"] = [
                    "unitNumber": address.unitNumber,
                    "streetNumber": address.streetNumber,
                    "streetName": address.streetName,
                    "suburb": address.suburb,
                    "state": address.state,
                    "postcode": address.postcode,
                    "country": address.country,
                    "poBox": address.poBox
                ]
            }
            
            return dict
        }
        
        // Export Payees
        let payeeDescriptor = FetchDescriptor<PayeeEntity>()
        let payees = try context.fetch(payeeDescriptor)
        exportDict["PayeeEntity"] = payees.map { payee -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = payee.id.uuidString
            dict["fullName"] = payee.fullName
            dict["email"] = payee.email
            dict["phone"] = payee.phone
            dict["status"] = payee.status
            dict["relationToClient"] = payee.relationToClient
            
            // Handle address
            if let address = payee.address {
                dict["address"] = [
                    "unitNumber": address.unitNumber,
                    "streetNumber": address.streetNumber,
                    "streetName": address.streetName,
                    "suburb": address.suburb,
                    "state": address.state,
                    "postcode": address.postcode,
                    "country": address.country,
                    "poBox": address.poBox
                ]
            }
            
            return dict
        }
        
        // Export Services
        let serviceDescriptor = FetchDescriptor<ServiceEntity>()
        let services = try context.fetch(serviceDescriptor)
        exportDict["ServiceEntity"] = services.map { service -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = service.id.uuidString
            dict["name"] = service.name
            dict["descriptionText"] = service.descriptionText
            dict["unit"] = service.unit
            dict["rate"] = service.rate
            dict["ndisCode"] = service.ndisItem?.itemNumber ?? ""
            dict["quoteRequired"] = service.ndisItem?.quoteRequired ?? false
            dict["isCustom"] = service.ndisItem == nil
            return dict
        }
        
        // Export NDIS Items
        let ndisDescriptor = FetchDescriptor<NDISItemEntity>()
        let ndisItems = try context.fetch(ndisDescriptor)
        exportDict["NDISItemEntity"] = ndisItems.map { item -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = item.id.uuidString
            dict["itemNumber"] = item.itemNumber
            dict["itemDescription"] = item.itemDescription
            dict["category"] = item.category
            dict["registrationGroup"] = item.registrationGroup
            dict["unit"] = item.unit
            dict["quoteRequired"] = item.quoteRequired
            dict["isCurrent"] = item.isCurrent
            dict["effectiveStartDate"] = item.effectiveStartDate?.iso8601String() ?? ""
            dict["effectiveEndDate"] = item.effectiveEndDate?.iso8601String() ?? ""
            dict["regionalPrices"] = item.regionalPrices ?? [:]
            dict["features"] = item.features ?? []
            return dict
        }
        
        // Export Invoices
        let invoiceDescriptor = FetchDescriptor<InvoiceEntity>()
        let invoices = try context.fetch(invoiceDescriptor)
        exportDict["InvoiceEntity"] = invoices.map { invoice -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = invoice.id.uuidString
            dict["invoiceNumber"] = invoice.invoiceNumber
            dict["date"] = invoice.date.iso8601String()
            dict["dueDate"] = invoice.dueDate?.iso8601String()
            dict["totalAmount"] = invoice.totalAmount
            dict["status"] = invoice.status
            dict["clientId"] = invoice.client?.id.uuidString
            return dict
        }
        
        // Export Sessions
        let sessionDescriptor = FetchDescriptor<SessionEntity>()
        let sessions = try context.fetch(sessionDescriptor)
        exportDict["SessionEntity"] = sessions.map { session -> [String: Any] in
            var dict: [String: Any] = [:]
            dict["id"] = session.id.uuidString
            dict["title"] = session.title
            dict["startTime"] = session.startTime?.iso8601String()
            dict["endTime"] = session.endTime?.iso8601String()
            dict["location"] = session.location
            dict["notes"] = session.notes
            dict["status"] = session.status
            dict["clientId"] = session.client?.id.uuidString
            return dict
        }
        
        let data = try JSONSerialization.data(withJSONObject: exportDict, options: [.prettyPrinted, .sortedKeys])
        return data
    }

    // MARK: - Import
    /// Comprehensive import functionality that supports multiple formats
    static func importAllEntitiesFromJSON(json: Data, context: ModelContext) async throws -> [ImportExportView.ImportResults] {
        // First, try to detect the format of the JSON data
        guard let jsonObject = try? JSONSerialization.jsonObject(with: json) else {
            throw ImportError.invalidJSONFormat
        }
        
        // Check if this is an AllData-Export format (comprehensive export)
        if let jsonDict = jsonObject as? [String: Any],
           jsonDict.keys.contains("ClientEntity") && 
           jsonDict.keys.contains("PayeeEntity") && 
           jsonDict.keys.contains("ServiceEntity") {
            // This is a comprehensive export format - use AllDataImportService
            return try await AllDataImportService.importAllData(from: json, context: context)
        }
        
        // Check if this is a specific entity format (single entity import)
        if let jsonArray = jsonObject as? [[String: Any]], !jsonArray.isEmpty {
            // Try to determine the entity type from the first object
            let firstObject = jsonArray[0]
            
            if firstObject["fullName"] != nil && firstObject["ndisNumber"] != nil {
                // This looks like client data
                return [try ClientImport.importClients(data: json, fileName: "clients.json", context: context)]
            } else if firstObject["fullName"] != nil && firstObject["relationToClient"] != nil {
                // This looks like payee data
                return [try PayeeImport.importPayees(data: json, fileName: "payees.json", context: context)]
            } else if firstObject["name"] != nil && firstObject["rate"] != nil {
                // This looks like service data
                return [try ServiceImport.importServices(data: json, fileName: "services.json", context: context)]
            } else if firstObject["invoiceNumber"] != nil {
                // This looks like invoice data
                return [try InvoiceImport.importInvoices(data: json, fileName: "invoices.json", context: context)]
            } else if firstObject["itemNumber"] != nil {
                // This looks like NDIS item data
                return [try NDISItemImport.importNDISItems(data: json, fileName: "ndis_items.json", context: context)]
            }
        }
        
        // If we can't determine the format, throw an error
        throw ImportError.missingRequiredField("Unknown data format")
    }
    
    /// Import data from CSV or Excel files
    @MainActor
    static func importFromFile(url: URL, context: ModelContext) async throws -> [ImportExportView.ImportResults] {
        let fileExtension = url.pathExtension.lowercased()
        
        switch fileExtension {
        case "csv", "xlsx", "xls":
            // Use the existing DataImportService for CSV/Excel files
            let importService = DataImportService(modelContext: context)
            await importService.importData(from: url)
            
            // Return a basic result since DataImportService doesn't return detailed results
            return [ImportExportView.ImportResults(
                source: .clients, // Default to clients, but could be enhanced to detect
                successful: 1,
                failed: 0,
                messages: ["Data imported successfully from \(url.lastPathComponent)"],
                fileName: url.lastPathComponent
            )]
            
        case "json":
            let data = try Data(contentsOf: url)
            return try await importAllEntitiesFromJSON(json: data, context: context)
            
        default:
            throw ImportError.missingRequiredField("Unsupported file format: \(fileExtension)")
        }
    }
    
    /// Export data to a specific file format
    static func exportToFile(context: ModelContext, format: ExportFormat = .json) throws -> (Data, String) {
        switch format {
        case .json:
            let data = try exportAllEntitiesToJSON(context: context)
            let timestamp = DateFormatter.exportTimestamp.string(from: Date())
            let filename = "InvoicingApp-Export-\(timestamp).json"
            return (data, filename)
            
        case .csv:
            // TODO: Implement CSV export
            throw ImportError.missingRequiredField("CSV export not yet implemented")
            
        case .excel:
            // TODO: Implement Excel export
            throw ImportError.missingRequiredField("Excel export not yet implemented")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Validate import data before processing
    static func validateImportData(_ data: Data) throws -> ImportValidationResult {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) else {
            throw ImportError.invalidJSONFormat
        }
        
        if let jsonDict = jsonObject as? [String: Any] {
            // Comprehensive export format
            let entityCounts = jsonDict.mapValues { (value) -> Int in
                if let array = value as? [[String: Any]] {
                    return array.count
                }
                return 0
            }
            
            return ImportValidationResult(
                isValid: true,
                format: .comprehensive,
                entityCounts: entityCounts,
                totalRecords: entityCounts.values.reduce(0, +)
            )
        } else if let jsonArray = jsonObject as? [[String: Any]] {
            // Single entity format
            let entityType = detectEntityType(from: jsonArray.first)
            return ImportValidationResult(
                isValid: true,
                format: .singleEntity,
                entityCounts: [entityType.rawValue: jsonArray.count],
                totalRecords: jsonArray.count
            )
        }
        
        throw ImportError.missingRequiredField("Unknown data format")
    }
    
    /// Detect entity type from a sample object
    private static func detectEntityType(from object: [String: Any]?) -> ImportExportView.ImportSource {
        guard let object = object else { return .clients }
        
        if object["fullName"] != nil && object["ndisNumber"] != nil {
            return .clients
        } else if object["fullName"] != nil && object["relationToClient"] != nil {
            return .payees
        } else if object["name"] != nil && object["rate"] != nil {
            return .services
        } else if object["invoiceNumber"] != nil {
            return .invoices
        } else if object["itemNumber"] != nil {
            return .ndisItems
        } else if object["title"] != nil && object["startTime"] != nil {
            return .sessions
        }
        
        return .clients // Default fallback
    }

    // MARK: - Color to Hex String
    private static func colorToHexString(value: Any) -> String? {
        #if canImport(AppKit)
        if let color = value as? NSColor {
            let rgbColor = color.usingColorSpace(.deviceRGB) ?? color
            let r = Int(round(rgbColor.redComponent * 255))
            let g = Int(round(rgbColor.greenComponent * 255))
            let b = Int(round(rgbColor.blueComponent * 255))
            let a = Int(round(rgbColor.alphaComponent * 255))
            if a < 255 {
                return String(format: "#%02X%02X%02X%02X", r, g, b, a)
            } else {
                return String(format: "#%02X%02X%02X", r, g, b)
            }
        }
        #endif
        #if canImport(UIKit)
        if let color = value as? UIColor {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            let ri = Int(round(r * 255))
            let gi = Int(round(g * 255))
            let bi = Int(round(b * 255))
            let ai = Int(round(a * 255))
            if ai < 255 {
                return String(format: "#%02X%02X%02X%02X", ri, gi, bi, ai)
            } else {
                return String(format: "#%02X%02X%02X", ri, gi, bi)
            }
        }
        #endif
        return nil
    }

    // MARK: - Hex String to Color
    private static func colorFromHexString(hex: String) -> Any? {
        #if canImport(AppKit)
        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let r, g, b, a: CGFloat
        switch hexString.count {
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        default:
            return nil
        }
        return NSColor(red: r, green: g, blue: b, alpha: a)
        #elseif canImport(UIKit)
        var hexString = hex
        if hexString.hasPrefix("#") { hexString.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: hexString).scanHexInt64(&rgb)
        let r, g, b, a: CGFloat
        switch hexString.count {
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        default:
            return nil
        }
        return UIColor(red: r, green: g, blue: b, alpha: a)
        #else
        return nil
        #endif
    }
}

// MARK: - Supporting Types

/// Export format options
enum ExportFormat {
    case json
    case csv
    case excel
}

/// Import validation result
struct ImportValidationResult {
    let isValid: Bool
    let format: ImportFormat
    let entityCounts: [String: Int]
    let totalRecords: Int
}

/// Import format types
enum ImportFormat {
    case comprehensive
    case singleEntity
}

// MARK: - Extensions

extension DateFormatter {
    static let exportTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

// Extension to add ISO8601 string conversion to Date
extension Date {
    func iso8601String() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
} 
