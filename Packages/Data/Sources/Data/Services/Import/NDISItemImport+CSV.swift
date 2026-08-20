import os
import Foundation
import SwiftData
import Core
import PersistenceModels

extension NDISItemImport {
    
    /// Imports NDIS items from CSV data using the new CSV parsing logic
    internal static func importNDISItemsFromCSV(url: URL, fileName: String, context: ModelContext) throws -> ImportResult {
        let parser = CSVParser()
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        do {
            let parsedData = try parser.parse(url: url)
            
            if parsedData.isEmpty {
                messages.append("Warning: No valid NDIS items found in the CSV file.")
                return ImportResult(
                    source: .ndisItems,
                    successful: 0,
                    failed: 0,
                    messages: messages,
                    fileName: fileName
                )
            }
            
            Logger.importExport.info("Successfully parsed \(parsedData.count) items from CSV. Analyzing column structure...")
            
            // Analyze the column structure
            let columnMapper = NDISColumnMapper()
            let headers = parsedData.first?.keys.map { String($0) } ?? []
            let mappingQuality = columnMapper.analyzeHeaders(headers)
            
            Logger.importExport.info("Column mapping quality: \(String(describing: mappingQuality))")
            Logger.importExport.info("\(columnMapper.getMappingSummary())")
            
            // Check if we have critical fields
            let missingCritical = columnMapper.getMissingCriticalFields()
            if !missingCritical.isEmpty {
                let missingFieldNames = missingCritical.map { $0.rawValue }.joined(separator: ", ")
                messages.append("Warning: Missing critical fields: \(missingFieldNames)")
            }
            
            Logger.importExport.info("Starting SwiftData import...")
            
            let batchSize = 100
            let totalItems = parsedData.count
            
            for i in stride(from: 0, to: totalItems, by: batchSize) {
                let batchEnd = min(i + batchSize, totalItems)
                let batchRows = Array(parsedData[i..<batchEnd])
                Logger.importExport.info("Processing batch \(i/batchSize + 1)/\( (totalItems + batchSize - 1) / batchSize )... (\(batchRows.count) items)")
                
                for row in batchRows {
                    do {
                        try createOrUpdateNDISItemFromCSV(from: row, in: context, using: columnMapper)
                        successful += 1
                    } catch {
                        failed += 1
                        let itemNumber = columnMapper.getValue(for: .itemNumber, from: row) ?? "unknown"
                        messages.append("Failed to import item \(itemNumber): \(error.localizedDescription)")
                    }
                }
                
                // Save changes after each batch
                do {
                    try context.save()
                    Logger.importExport.info("Saved batch \(i/batchSize + 1)")
                } catch {
                    // Reset the context to avoid cascading errors
                    context.rollback()
                    failed += batchRows.count
                    successful -= batchRows.count
                    messages.append("Error saving batch \(i/batchSize + 1): \(error.localizedDescription)")
                    Logger.importExport.warning("Error saving batch \(i/batchSize + 1): \(error)")
                }
            }
            
            // Update current status for all items after import
            do {
                try NDISVersioningService.updateCurrentStatusForAllItems(in: context)
                messages.append("Updated current status for all NDIS items.")
            } catch {
                messages.append("Warning: Could not update current status: \(error.localizedDescription)")
            }
            
            if successful > 0 {
                messages.insert("Successfully imported/updated \(successful) NDIS items from CSV.", at: 0)
            }
            if failed > 0 {
                messages.insert("Failed to import/update \(failed) NDIS items from CSV.", at: failed == 0 ? 0 : 1)
            }
            
            return ImportResult(
                source: .ndisItems,
                successful: successful,
                failed: failed,
                messages: messages,
                fileName: fileName
            )
            
        } catch {
            throw NSError(
                domain: "NDISImportError",
                code: 104,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse CSV data: \(error.localizedDescription)"
                ]
            )
        }
    }
    
    /// Creates or updates an NDIS item from CSV row data using flexible column mapping with versioning support
    internal static func createOrUpdateNDISItemFromCSV(from row: [String: String], in context: ModelContext, using columnMapper: NDISColumnMapper? = nil) throws {
        // Use the column mapper if provided, otherwise fall back to direct column access
        let itemNumber: String
        if let mapper = columnMapper {
            guard let number = mapper.getValue(for: .itemNumber, from: row), !number.isEmpty else {
                throw NSError(domain: "NDISImportError", code: 105, userInfo: [
                    NSLocalizedDescriptionKey: "Missing or empty Support Item Number"
                ])
            }
            itemNumber = number
        } else {
            guard let number = row["Support Item Number"], !number.isEmpty else {
                throw NSError(domain: "NDISImportError", code: 105, userInfo: [
                    NSLocalizedDescriptionKey: "Missing or empty Support Item Number"
                ])
            }
            itemNumber = number
        }
        
        // Extract date information for versioning
        let startDate: Date?
        let endDate: Date?
        
        if let mapper = columnMapper {
            startDate = mapper.getDateValue(for: .startDate, from: row)
            endDate = mapper.getDateValue(for: .endDate, from: row)
        } else {
            startDate = NDISItemImportDateParser.parseDate(row["Start date"]) ?? NDISItemImportDateParser.parseDate(row["Start Date"])
            endDate = NDISItemImportDateParser.parseDate(row["End Date"]) ?? NDISItemImportDateParser.parseDate(row["End date"])
        }
        
        // Get the item name for composite key
        let itemName: String
        if let mapper = columnMapper {
            itemName = mapper.getValue(for: .itemName, from: row) ?? "Unknown Item"
        } else {
            itemName = row["Support Item Name"] ?? "Unknown Item"
        }
        
        // Create version identifier using composite key (item number + name)
        let versionId = NDISVersioningService.createVersionIdentifier(
            itemNumber: itemNumber,
            itemName: itemName,
            startDate: startDate ?? Date(),
            endDate: endDate
        )
        
        let ndisItem = try resolveExistingItem(
            itemNumber: itemNumber,
            itemName: itemName,
            versionIdentifier: versionId,
            effectiveStartDate: startDate,
            effectiveEndDate: endDate,
            context: context
        )
            ?? NDISItem(id: UUID(), itemNumber: itemNumber, name: itemName, versionIdentifier: versionId)
        if ndisItem.modelContext == nil { // If it's a new entity, insert it
            context.insert(ndisItem)
        }
        
        // Set up basic item properties
        ndisItem.itemNumber = itemNumber
        ndisItem.name = itemName
        ndisItem.versionIdentifier = versionId
        ndisItem.effectiveStartDate = startDate
        ndisItem.effectiveEndDate = endDate
        
        // Update current status for all versions of this item based on effective dates
        try updateCurrentStatusForItem(itemNumber: itemNumber, itemName: itemName, context: context)
        
        if let mapper = columnMapper {
            ndisItem.name = mapper.getValue(for: .itemName, from: row) ?? ""
            ndisItem.itemDescription = mapper.getValue(for: .itemName, from: row)
            ndisItem.category = mapper.getValue(for: .categoryName, from: row)
            ndisItem.categoryNamePACE = mapper.getValue(for: .categoryNamePACE, from: row)
            ndisItem.categoryNumber = mapper.getValue(for: .categoryNumber, from: row)
            ndisItem.categoryNumberPACE = mapper.getValue(for: .categoryNumberPACE, from: row)
            ndisItem.registrationGroup = mapper.getValue(for: .registrationGroup, from: row)
            ndisItem.registrationGroupNumber = mapper.getValue(for: .registrationGroupNumber, from: row)
            ndisItem.unit = normalizeUnit(mapper.getValue(for: .unit, from: row))
            ndisItem.status = mapper.getValue(for: .tab, from: row)
            ndisItem.type = mapper.getValue(for: .type, from: row)
            ndisItem.quoteRequired = mapper.getValue(for: .quote, from: row)?.lowercased() == "yes"
            
            // Parse boolean fields for provision and service delivery
            ndisItem.nonFaceToFaceProvision = parseBooleanField(mapper.getValue(for: .nonFaceToFaceProvision, from: row))
            ndisItem.providerTravel = parseBooleanField(mapper.getValue(for: .providerTravel, from: row))
            ndisItem.shortNoticeCancellations = parseBooleanField(mapper.getValue(for: .shortNoticeCancellations, from: row))
            ndisItem.ndiaRequestedReports = parseBooleanField(mapper.getValue(for: .ndiaRequestedReports, from: row))
            ndisItem.irregularSILSupports = parseBooleanField(mapper.getValue(for: .irregularSILSupports, from: row))
        } else {
            // Fallback to original hard-coded column names
            ndisItem.name = row["Support Item Name"] ?? ""
            ndisItem.itemDescription = row["Support Item Name"]
            ndisItem.category = row["Support Category Name"]
            ndisItem.categoryNamePACE = row["Support Category Name (PACE)"]
            ndisItem.categoryNumber = row["Support Category Number"]
            ndisItem.categoryNumberPACE = row["Support Category Number (PACE)"]
            ndisItem.registrationGroup = row["Registration Group Name"]
            ndisItem.registrationGroupNumber = row["Registration Group Number"]
            ndisItem.unit = normalizeUnit(row["Unit"])
            ndisItem.status = row["Tab"]
            ndisItem.type = row["Type"]
            ndisItem.quoteRequired = row["Quote"]?.lowercased() == "yes"
            
            // Parse boolean fields for provision and service delivery
            ndisItem.nonFaceToFaceProvision = parseBooleanField(row["Non-Face-to-Face Support Provision"])
            ndisItem.providerTravel = parseBooleanField(row["Provider Travel"])
            ndisItem.shortNoticeCancellations = parseBooleanField(row["Short Notice Cancellations"])
            ndisItem.ndiaRequestedReports = parseBooleanField(row["NDIA Requested Reports"])
            ndisItem.irregularSILSupports = parseBooleanField(row["Irregular SIL Supports"])
        }
        
        // Handle regional pricing with flexible mapping
        let regionalFields: [NDISColumnMapper.StandardField] = [.act, .nsw, .nt, .qld, .sa, .tas, .vic, .wa, .remote, .veryRemote]
        var incomingPrices: [String: Double] = [:]
        for field in regionalFields {
            let region = field.rawValue
            let priceValue: String?
            
            if let mapper = columnMapper {
                priceValue = mapper.getValue(for: field, from: row)
            } else {
                priceValue = row[region]
            }
            
            if let priceStr = priceValue, let priceVal = Double(priceStr) {
                incomingPrices[region] = priceVal
            }
        }
        replaceRegionalPrices(incomingPrices, for: ndisItem, context: context)
    }
}
