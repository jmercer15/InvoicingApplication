import Foundation
import SwiftData

/// Actor responsible for handling data import operations in the background
@ModelActor
public actor DataImporterActor {
    
    /// Imports all data from the standard JSON files found in the bundle
    public func importAllData() async throws -> [ImportResult] {
        // We use the actor's modelContext which allows safe background execution
        let context = modelContext
        
        // Use SwiftData's actor-isolated context.
        return try UnifiedImportService.importAllData(context: context)
    }
    
    /// Imports all data from the "AllData-Export" JSON file
    public func importAllDataFromExport() async throws -> [ImportResult] {
        let context = modelContext
        return try UnifiedImportService.importAllDataFromExport(context: context)
    }
    
    /// Imports specific data type from provided data
    public func importSpecificData(type: ImportSource, data: Data, fileName: String) async throws -> ImportResult {
        let context = modelContext
        return try UnifiedImportService.importSpecificData(type: type, data: data, fileName: fileName, context: context)
    }
    
    /// Imports NDIS items from a CSV URL
    public func importNDISItemsFromCSV(url: URL, fileName: String) async throws -> ImportResult {
        let context = modelContext
        return try NDISItemImport.importNDISItemsFromCSV(url: url, fileName: fileName, context: context)
    }
    
    /// Imports NDIS items from an Excel URL
    public func importNDISItemsFromExcel(url: URL, fileName: String) async throws -> ImportResult {
        let context = modelContext
        return try NDISItemImport.importNDISItemsFromExcel(url: url, fileName: fileName, context: context)
    }
    
    // MARK: - NDIS Maintenance Helper Methods
    
    /// Fetches all unique effective dates for NDIS items
    public func fetchNDISEffectiveDates() async throws -> [Date] {
        let context = modelContext
        return try NDISVersioningService.fetchEffectiveDates(context: context)
    }
    
    /// Recalculates 'isCurrent' flags for all NDIS items
    public func recalculateAllCurrentFlags() async throws -> Int {
        let context = modelContext
        return try NDISVersioningService.recalculateAllCurrentFlags(context: context)
    }
}
