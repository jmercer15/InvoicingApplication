import Foundation
import SwiftUI
import SwiftData
import Data
import Core

@MainActor
class DataImportService: ObservableObject {
    
    @Published var isImporting = false
    @Published var importProgress: Double = 0.0
    @Published var importError: Error?
    
    private let parser = CSVParser()
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Imports NDIS data from a specified file URL (CSV or Excel) into your SwiftData model.
    func importData(from url: URL) async {
        isImporting = true
        importProgress = 0.0
        importError = nil
        
        do {
            // Determine parser type based on file extension
            let parsedData: [[String: String]]
            let fileExtension = url.pathExtension.lowercased()
            
            if fileExtension == "xlsx" || fileExtension == "xls" {
                let excelParser = ExcelParser()
                parsedData = try excelParser.parse(url: url)
            } else {
                parsedData = try parser.parse(url: url)
            }
            let totalItems = Double(parsedData.count)
            var processedCount = 0.0

            // Analyze column structure
            let columnMapper = NDISColumnMapper()
            let headers = parsedData.first?.keys.map { String($0) } ?? []
            let mappingQuality = columnMapper.analyzeHeaders(headers)
            print("DataImportService - Column mapping quality: \(mappingQuality)")

            var processedCompositeKeys = Set<String>()
            for row in parsedData {
                if let itemNumber = columnMapper.getValue(for: .itemNumber, from: row),
                   let itemName = columnMapper.getValue(for: .itemName, from: row) {
                    processedCompositeKeys.insert("\(itemNumber)|\(itemName)")
                }
                self.createOrUpdateNDISItem(from: row, in: modelContext, using: columnMapper)
                processedCount += 1
                let progress = processedCount / totalItems
                DispatchQueue.main.async {
                    self.importProgress = progress
                }
            }
            // Update current status for all processed items
            for compositeKey in processedCompositeKeys {
                let components = compositeKey.split(separator: "|")
                if components.count == 2 {
                    let itemNumber = String(components[0])
                    let itemName = String(components[1])
                    do {
                        try self.updateCurrentStatusForItem(itemNumber: itemNumber, itemName: itemName, context: modelContext)
                    } catch {
                        print("Warning: Failed to update current status for \(itemNumber) - \(itemName): \(error)")
                    }
                }
            }
            try modelContext.save()
        } catch {
            DispatchQueue.main.async {
                self.importError = error
                print("Failed to import data: \(error.localizedDescription)")
            }
        }
        isImporting = false
    }
    
    /// Updates the current status for all versions of a specific NDIS item.
    private func updateCurrentStatusForItem(itemNumber: String, itemName: String, context: ModelContext) throws {
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate { $0.itemNumber == itemNumber && $0.name == itemName })
        let allVersions = try context.fetch(descriptor)
        guard !allVersions.isEmpty else { return }
        for version in allVersions {
            version.isCurrent = false
        }
        // Actual isCurrent determination should be done globally after all imports
    }
    
    /// Maps a single row from the CSV to your `NDISItemEntity` and `RegionalPriceEntity`.
    private func createOrUpdateNDISItem(from row: [String: String], in context: ModelContext, using columnMapper: NDISColumnMapper) {
        guard let itemNumber = columnMapper.getValue(for: .itemNumber, from: row), !itemNumber.isEmpty else { return }
        guard let itemName = columnMapper.getValue(for: .itemName, from: row), !itemName.isEmpty else { return }
        let descriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate { $0.itemNumber == itemNumber && $0.name == itemName })
        let startDate = columnMapper.getDateValue(for: .startDate, from: row)
        let endDate = columnMapper.getDateValue(for: .endDate, from: row)
        let versionId = NDISVersioningService.createVersionIdentifier(
            itemNumber: itemNumber,
            itemName: itemName,
            startDate: startDate ?? Date(),
            endDate: endDate
        )
        let ndisItem = (try? context.fetch(descriptor).first) ?? NDISItemEntity(id: UUID(), itemNumber: itemNumber, name: itemName, versionIdentifier: versionId)
        // ID is already set in the initializer
        ndisItem.itemNumber = itemNumber
        ndisItem.name = itemName
        ndisItem.itemDescription = columnMapper.getValue(for: .itemName, from: row)
        ndisItem.category = columnMapper.getValue(for: .categoryName, from: row)
        ndisItem.registrationGroup = columnMapper.getValue(for: .registrationGroup, from: row)
        ndisItem.unit = NDISItemImport.normalizeUnit(columnMapper.getValue(for: .unit, from: row))
        ndisItem.status = columnMapper.getValue(for: .tab, from: row)
        ndisItem.quoteRequired = columnMapper.getValue(for: .quote, from: row)?.lowercased() == "yes"
        ndisItem.effectiveStartDate = startDate
        ndisItem.effectiveEndDate = endDate
        ndisItem.versionIdentifier = versionId

        ndisItem.regionalPrices.removeAll()
        let regionalFields: [NDISColumnMapper.StandardField] = [.act, .nsw, .nt, .qld, .sa, .tas, .vic, .wa, .remote, .veryRemote]
        var newPrices: [RegionalPriceEntity] = []
        for field in regionalFields {
            let region = field.rawValue
            if let priceStr = columnMapper.getValue(for: field, from: row), let priceVal = Double(priceStr) {
                let regionalPrice = RegionalPriceEntity(id: UUID())
                regionalPrice.regionIdentifier = region
                regionalPrice.amount = priceVal
                regionalPrice.ndisItem = ndisItem
                newPrices.append(regionalPrice)
            }
        }
        ndisItem.regionalPrices = newPrices
        if ndisItem.modelContext == nil { context.insert(ndisItem) }
    }
} 
