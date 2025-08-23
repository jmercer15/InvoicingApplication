import Foundation
import SwiftUI
import SwiftData

/// Unified import service that handles all JSON data types
struct UnifiedImportService {
    
    /// Imports all data from the provided JSON files
    static func importAllData(context: ModelContext) async throws -> [ImportExportView.ImportResults] {
        var results: [ImportExportView.ImportResults] = []
        
        // Import payees
        if let payeesData = loadJSONData(from: "payees.json") {
            do {
                let payeeResult = try PayeeImport.importPayees(data: payeesData, fileName: "payees.json", context: context)
                results.append(payeeResult)
            } catch {
                results.append(ImportExportView.ImportResults(
                    source: .payees,
                    successful: 0,
                    failed: 1,
                    messages: ["Failed to import payees: \(error.localizedDescription)"],
                    fileName: "payees.json"
                ))
            }
        }
        
        // Import clients
        if let clientsData = loadJSONData(from: "clients.json") {
            do {
                let clientResult = try ClientImport.importClients(data: clientsData, fileName: "clients.json", context: context)
                results.append(clientResult)
            } catch {
                results.append(ImportExportView.ImportResults(
                    source: .clients,
                    successful: 0,
                    failed: 1,
                    messages: ["Failed to import clients: \(error.localizedDescription)"],
                    fileName: "clients.json"
                ))
            }
        }
        
        // Import services
        if let servicesData = loadJSONData(from: "services.json") {
            do {
                let serviceResult = try ServiceImport.importServices(data: servicesData, fileName: "services.json", context: context)
                results.append(serviceResult)
            } catch {
                results.append(ImportExportView.ImportResults(
                    source: .services,
                    successful: 0,
                    failed: 1,
                    messages: ["Failed to import services: \(error.localizedDescription)"],
                    fileName: "services.json"
                ))
            }
        }
        
        // Import invoices
        if let invoicesData = loadJSONData(from: "invoices.json") {
            do {
                let invoiceResult = try InvoiceImport.importInvoices(data: invoicesData, fileName: "invoices.json", context: context)
                results.append(invoiceResult)
            } catch {
                results.append(ImportExportView.ImportResults(
                    source: .invoices,
                    successful: 0,
                    failed: 1,
                    messages: ["Failed to import invoices: \(error.localizedDescription)"],
                    fileName: "invoices.json"
                ))
            }
        }
        
        // Import NDIS items
        if let ndisData = loadJSONData(from: "NDIS_Support_Catalogue.json") {
            do {
                let ndisResult = try NDISItemImport.importNDISItems(data: ndisData, fileName: "NDIS_Support_Catalogue.json", context: context)
                results.append(ndisResult)
            } catch {
                results.append(ImportExportView.ImportResults(
                    source: .ndisItems,
                    successful: 0,
                    failed: 1,
                    messages: ["Failed to import NDIS items: \(error.localizedDescription)"],
                    fileName: "NDIS_Support_Catalogue.json"
                ))
            }
        }
        
        return results
    }
    
    /// Imports all data from the AllData-Export JSON file
    static func importAllDataFromExport(context: ModelContext) async throws -> [ImportExportView.ImportResults] {
        guard let allDataURL = Bundle.main.url(forResource: "AllData-Export-2025-07-21-174716", withExtension: "json") else {
            throw NSError(
                domain: "ImportError",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "AllData-Export file not found in app bundle"]
            )
        }
        
        do {
            let data = try Data(contentsOf: allDataURL)
            return try await AllDataImportService.importAllData(from: data, context: context)
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
    
    /// Imports specific data type from JSON file
    static func importSpecificData(type: ImportExportView.ImportSource, data: Data, fileName: String, context: ModelContext) async throws -> ImportExportView.ImportResults {
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
            let results = try await AllDataImportService.importAllData(from: data, context: context)
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
            
            return ImportExportView.ImportResults(
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
    static func validateJSONStructure(data: Data, expectedType: ImportExportView.ImportSource) -> Bool {
        do {
            switch expectedType {
            case .payees:
                _ = try JSONDecoder().decode([PayeeImportJSON].self, from: data)
            case .clients:
                _ = try JSONDecoder().decode([ClientPayeeImportJSON].self, from: data)
            case .services:
                _ = try JSONDecoder().decode([ServicesImportJSON].self, from: data)
            case .invoices:
                _ = try JSONDecoder().decode([InvoiceImportJSON].self, from: data)
            case .ndisItems:
                // NDIS items have complex structure, just check if it's valid JSON
                _ = try JSONSerialization.jsonObject(with: data)
            case .sessions:
                _ = try JSONDecoder().decode([SessionImportJSON].self, from: data)
            case .allData:
                // AllData-Export has a specific structure with entity names as keys
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let expectedEntities = ["AddressEntity", "BusinessEntity", "ClientEntity", "ClientServiceEntity", 
                                      "CreditHistoryEntryEntity", "ExpenseCategoryEntity", "ExpenseEntity", 
                                      "InvoiceEntity", "InvoiceItemEntity", "NDISItemEntity", "PayeeEntity", 
                                      "PlanManagerEntity", "RegionalPriceEntity", "ServiceEntity", "SessionEntity", 
                                      "TravelChargeAuditLog", "TravelChargeEntity", "TravelChargeReviewItem"]
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