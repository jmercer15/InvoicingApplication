import Core
import PersistenceModels
import Foundation
import SwiftData

/// Actor responsible for handling data import operations in the background.
public actor DataImporterActor: ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }
    
    /// Imports specific data type from provided data
    public func importSpecificData(type: ImportSource, data: Data, fileName: String) async throws -> ImportResult {
        try withAutosaveDisabled { context in
            try UnifiedImportService.importSpecificData(type: type, data: data, fileName: fileName, context: context)
        }
    }

    /// Overload for callers that only have the raw value (e.g. Core.ImportSource.rawValue) to avoid naming Data.ImportSource.
    public func importSpecificData(typeRawValue: String, data: Data, fileName: String) async throws -> ImportResult {
        let source = ImportSource(rawValue: typeRawValue) ?? .unknown
        return try await importSpecificData(type: source, data: data, fileName: fileName)
    }
    
    /// Imports NDIS items from a CSV URL
    public func importNDISItemsFromCSV(url: URL, fileName: String) async throws -> ImportResult {
        try withAutosaveDisabled { context in
            try NDISItemImport.importNDISItemsFromCSV(url: url, fileName: fileName, context: context)
        }
    }
    
    /// Imports NDIS items from an Excel URL
    public func importNDISItemsFromExcel(url: URL, fileName: String) async throws -> ImportResult {
        try withAutosaveDisabled { context in
            try NDISItemImport.importNDISItemsFromExcel(url: url, fileName: fileName, context: context)
        }
    }
    
    // MARK: - NDIS Maintenance Helper Methods
    
    /// Fetches all unique effective dates for NDIS items
    public func fetchNDISEffectiveDates() async throws -> [Date] {
        try withAutosaveDisabled { context in
            try NDISVersioningService.fetchEffectiveDates(context: context)
        }
    }
    
    /// Recalculates 'isCurrent' flags for all NDIS items
    public func recalculateAllCurrentFlags() async throws -> Int {
        try withAutosaveDisabled { context in
            try NDISVersioningService.recalculateAllCurrentFlags(context: context)
        }
    }

    /// Counts total NDIS items in the store.
    public func countNDISItems() async throws -> Int {
        try withAutosaveDisabled { context in
            try context.fetchCount(FetchDescriptor<NDISItem>())
        }
    }

    /// Deletes all NDIS items and regional prices.
    public func clearAllNDISItems() async throws -> (deletedItems: Int, deletedPrices: Int) {
        try withAutosaveDisabled { context in
            context.autosaveEnabled = false
            let itemsCount = try context.fetchCount(FetchDescriptor<NDISItem>())
            let pricesCount = try context.fetchCount(FetchDescriptor<RegionalPrice>())
            try context.delete(model: RegionalPrice.self)
            try context.delete(model: NDISItem.self)
            try context.save()
            return (deletedItems: itemsCount, deletedPrices: pricesCount)
        }
    }
    
    private func withAutosaveDisabled<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        let previousAutosave = modelContext.autosaveEnabled
        defer { modelContext.autosaveEnabled = previousAutosave }
        modelContext.autosaveEnabled = false
        return try operation(modelContext)
    }
}
