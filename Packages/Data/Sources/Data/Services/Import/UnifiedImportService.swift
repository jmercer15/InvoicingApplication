import Core
import Foundation
import SwiftData

/// Data now uses the shared domain import source type.
public typealias ImportSource = Core.ImportSource

/// Public wrapper for import results (Core domain type).
public typealias ImportResult = Core.ImportResult

extension ImportResult {
    /// Convenience initializer matching legacy Data import services (derives `success` from `failed`).
    public init(
        source: ImportSource,
        successful: Int,
        failed: Int,
        importedCounts: [String: Int] = [:],
        messages: [String],
        fileName: String,
        timestamp: Date = Date()
    ) {
        self.init(
            source: source,
            success: failed == 0,
            successful: successful,
            failed: failed,
            importedCounts: importedCounts,
            messages: messages,
            fileName: fileName,
            timestamp: timestamp
        )
    }
}

/// Unified import service that handles all JSON data types
public struct UnifiedImportService {
    
    /// Imports specific data type from JSON file (public interface)
    public static func importSpecificData(type: ImportSource, data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        return try importSpecificDataInternal(type: type, data: data, fileName: fileName, context: context)
    }
    
    /// Internal method that does the actual work
    static func importSpecificDataInternal(type: ImportSource, data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        switch type {
        case .payees:
            return try PayeeImport.importPayees(data: data, fileName: fileName, context: context)
        case .clients:
            return try ClientImport.importClients(data: data, fileName: fileName, context: context)
        case .services:
            return try ServiceImport.importServices(data: data, fileName: fileName, context: context)
        case .invoices:
            return try InvoiceImport.importInvoices(data: data, fileName: fileName, context: context)
        case .ndisItems:
            return try NDISItemImport.importNDISItems(data: data, fileName: fileName, context: context)
        case .sessions:
            return try SessionImport.importSessions(data: data, fileName: fileName, context: context)
        case .allData:
            let results = try AllDataImportService.importAllData(from: data, context: context)
            // Combine all results into a single summary
            let totalSuccessful = results.reduce(0) { $0 + $1.successful }
            let totalFailed = results.reduce(0) { $0 + $1.failed }
            var allMessages: [String] = []
            
            for result in results {
                allMessages.append("=== \(result.source.description) ===")
                allMessages.append("Successful: \(result.successful), Failed: \(result.failed)")
                allMessages.append(contentsOf: result.messages)
                allMessages.append("")
            }
            
            return ImportResult(
                source: .allData,
                successful: totalSuccessful,
                failed: totalFailed,
                messages: allMessages,
                fileName: fileName
            )
        case .unknown:
            throw NSError(
                domain: "ImportError",
                code: 999,
                userInfo: [
                    NSLocalizedDescriptionKey: "Unknown import source type"
                ]
            )
        }
    }
    
    /// Validates JSON data structure before import
    public static func validateJSONStructure(data: Data, expectedType: ImportSource) -> Bool {
        return validateJSONStructureInternal(data: data, expectedType: expectedType)
    }
    
    /// Internal method that validates JSON structure
    static func validateJSONStructureInternal(data: Data, expectedType: ImportSource) -> Bool {
        do {
            switch expectedType {
            case .payees:
                _ = try JSONDecoder().decode([PayeeImportJSON].self, from: data)
            case .clients:
                _ = try JSONDecoder().decode([ClientPayeeImportJSON].self, from: data)
            case .services:
                _ = try JSONDecoder().decode([ServicesImportJSON].self, from: data)
            case .invoices:
                _ = try JSONDecoder().decode([TabularInvoicePayload].self, from: data)
            case .ndisItems:
                // NDIS items have complex structure, just check if it's valid JSON
                _ = try JSONSerialization.jsonObject(with: data)
            case .sessions:
                _ = try JSONDecoder().decode([SessionImportJSON].self, from: data)
            case .allData:
                // AllData-Export has a specific structure with entity names as keys
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let expectedEntities = ["Address", "Business", "Client", "ClientService",
                                      "CreditHistoryEntry",
                                      "Invoice", "InvoiceItem", "NDISItem", "Payee",
                                      "PlanManager", "RegionalPrice", "Session",
                                      "TravelChargeAuditLog", "TravelCharge", "TravelChargeReviewItem"]
                return json != nil && expectedEntities.contains { json!.keys.contains($0) }
            case .unknown:
                return false
            }
            return true
        } catch {
            return false
        }
    }
} 
