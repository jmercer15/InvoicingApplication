import Core
import Foundation
import SwiftData

/// Data now uses the shared domain import source type.
public typealias ImportSource = Core.ImportSource

/// Public wrapper for import results
public struct ImportResult: Sendable {
    public let source: ImportSource
    public let success: Bool
    public let successful: Int
    public let failed: Int
    public let importedCounts: [String: Int]
    public let messages: [String]
    public let fileName: String
    public let timestamp: Date
    
    public init(
        source: ImportSource,
        successful: Int,
        failed: Int,
        importedCounts: [String: Int] = [:],
        messages: [String],
        fileName: String,
        timestamp: Date = Date()
    ) {
        self.source = source
        self.success = failed == 0
        self.successful = successful
        self.failed = failed
        self.importedCounts = importedCounts
        self.messages = messages
        self.fileName = fileName
        self.timestamp = timestamp
    }
}

/// Unified import service that handles all JSON data types
public struct UnifiedImportService {
    
    /// Imports all data from the provided JSON files (public interface)
    public static func importAllData(context: ModelContext) throws -> [ImportResult] {
        return try importAllDataInternal(context: context)
    }
    
    /// Internal method that does the actual work
    static func importAllDataInternal(context: ModelContext) throws -> [ImportResult] {
        var results: [ImportResult] = []
        let importJobs: [(source: ImportSource, fileName: String, importer: (Data, String, ModelContext) throws -> ImportResult)] = [
            (.payees, "payees.json", { data, fileName, context in
                try PayeeImport.importPayees(data: data, fileName: fileName, context: context)
            }),
            (.clients, "clients.json", { data, fileName, context in
                try ClientImport.importClients(data: data, fileName: fileName, context: context)
            }),
            (.services, "services.json", { data, fileName, context in
                try ServiceImport.importServices(data: data, fileName: fileName, context: context)
            }),
            (.invoices, "invoices.json", { data, fileName, context in
                try InvoiceImport.importInvoices(data: data, fileName: fileName, context: context)
            }),
            (.ndisItems, "NDIS_Support_Catalogue.json", { data, fileName, context in
                try NDISItemImport.importNDISItems(data: data, fileName: fileName, context: context)
            })
        ]
        
        for job in importJobs {
            guard let data = loadJSONData(from: job.fileName) else { continue }
            do {
                results.append(try job.importer(data, job.fileName, context))
            } catch {
                results.append(ImportResult(
                    source: job.source,
                    successful: 0,
                    failed: 1,
                    messages: ["Failed to import \(job.source.description.lowercased()): \(error.localizedDescription)"],
                    fileName: job.fileName
                ))
            }
        }
        
        return results
    }
    
    /// Imports all data from the AllData-Export JSON file (public interface)
    public static func importAllDataFromExport(context: ModelContext) throws -> [ImportResult] {
        return try importAllDataFromExportInternal(context: context)
    }
    
    /// Internal method that does the actual work
    static func importAllDataFromExportInternal(context: ModelContext) throws -> [ImportResult] {
        guard let allDataURL = Bundle.main.url(forResource: "AllData-Export-2025-07-21-174716", withExtension: "json") else {
            throw NSError(
                domain: "ImportError",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "AllData-Export file not found in app bundle"]
            )
        }
        
        do {
            let data = try Data(contentsOf: allDataURL)
            return try AllDataImportService.importAllData(from: data, context: context)
        } catch {
            throw NSError(
                domain: "ImportError",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Failed to import AllData-Export: \(error.localizedDescription)"]
            )
        }
    }
    
    /// Loads JSON data from a file in the app bundle
    private static func loadJSONData(from fileName: String) -> Data? {
        guard let url = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".json", with: ""), withExtension: "json") else {
            print("Could not find \(fileName) in app bundle")
            return nil
        }
        
        do {
            return try Data(contentsOf: url)
        } catch {
            print("Failed to load \(fileName): \(error)")
            return nil
        }
    }
    
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
