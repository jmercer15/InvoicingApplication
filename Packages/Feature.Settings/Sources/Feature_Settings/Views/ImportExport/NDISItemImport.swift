import Foundation
import SwiftUI
import SwiftData // Import SwiftData
import Data
import Core

// Represents the structure expected by the NDISItem creation logic
struct NDISItemData: Equatable {
    let itemNumber: String
    let name: String
    let description: String
    let unit: String
    let regionalPricesData: [String: Double]?
    let category: String?
    let registrationGroup: String?
    let features: [String]
    let quoteRequired: Bool?
    let effectiveStartDate: Date?
    let effectiveEndDate: Date?
    
    static func == (lhs: NDISItemData, rhs: NDISItemData) -> Bool {
        return lhs.itemNumber == rhs.itemNumber && lhs.name == rhs.name
    }
}

struct NDISItemImport {
    
    /// Imports NDIS items from Excel data using the new Excel parsing logic
    static func importNDISItemsFromExcel(url: URL, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        let excelParser = ExcelParser()
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        do {
            let parsedData = try excelParser.parse(url: url)
            
            if parsedData.isEmpty {
                messages.append("Warning: No valid NDIS items found in the Excel file.")
                return ImportExportView.ImportResults(
                    source: .ndisItems,
                    successful: 0,
                    failed: 0,
                    messages: messages,
                    fileName: fileName
                )
            }
            
                         print("Successfully parsed \(parsedData.count) items from Excel. Analyzing column structure...")
             
             // Analyze the column structure
             let columnMapper = NDISColumnMapper()
             let headers = parsedData.first?.keys.map { String($0) } ?? []
             let mappingQuality = columnMapper.analyzeHeaders(headers)
             
             print("Column mapping quality: \(mappingQuality)")
             print(columnMapper.getMappingSummary())
             
             // Check if we have critical fields
             let missingCritical = columnMapper.getMissingCriticalFields()
             if !missingCritical.isEmpty {
                 let missingFieldNames = missingCritical.map { $0.rawValue }.joined(separator: ", ")
                 messages.append("Warning: Missing critical fields: \(missingFieldNames)")
             }
             
             print("Starting SwiftData import...") // Changed from Core Data import
             
             let batchSize = 100
             let totalItems = parsedData.count
             
             for i in stride(from: 0, to: totalItems, by: batchSize) {
                 let batchEnd = min(i + batchSize, totalItems)
                 let batchRows = Array(parsedData[i..<batchEnd])
                 print("Processing batch \(i/batchSize + 1)/\( (totalItems + batchSize - 1) / batchSize )... (\(batchRows.count) items)")
                 
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
                     print("Saved batch \(i/batchSize + 1)")
                 } catch {
                     // Reset the context to avoid cascading errors
                     context.rollback()
                     failed += batchRows.count
                     successful -= batchRows.count
                     messages.append("Error saving batch \(i/batchSize + 1): \(error.localizedDescription)")
                     print("Error saving batch \(i/batchSize + 1): \(error)")
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
                messages.insert("Successfully imported/updated \(successful) NDIS items from Excel.", at: 0)
            }
            if failed > 0 {
                messages.insert("Failed to import/update \(failed) NDIS items from Excel.", at: failed == 0 ? 0 : 1)
            }
            
            return ImportExportView.ImportResults(
                source: .ndisItems,
                successful: successful,
                failed: failed,
                messages: messages,
                fileName: fileName
            )
            
        } catch {
            var userInfo: [String: Any] = [
                NSLocalizedDescriptionKey: "Failed to parse Excel data: \(error.localizedDescription)"
            ]
            
            // Add recovery suggestion if the error has one
            let nsError = error as NSError
            if let recoverySuggestion = nsError.userInfo[NSLocalizedRecoverySuggestionErrorKey] as? String {
                userInfo[NSLocalizedRecoverySuggestionErrorKey] = recoverySuggestion
            }
            
            throw NSError(
                domain: "NDISImportError",
                code: 106,
                userInfo: userInfo
            )
        }
    }
    
    /// Imports NDIS items from CSV data using the new CSV parsing logic
    static func importNDISItemsFromCSV(url: URL, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        let parser = CSVParser()
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        do {
            let parsedData = try parser.parse(url: url)
            
            if parsedData.isEmpty {
                messages.append("Warning: No valid NDIS items found in the CSV file.")
                return ImportExportView.ImportResults(
                    source: .ndisItems,
                    successful: 0,
                    failed: 0,
                    messages: messages,
                    fileName: fileName
                )
            }
            
            print("Successfully parsed \(parsedData.count) items from CSV. Analyzing column structure...")
            
            // Analyze the column structure
            let columnMapper = NDISColumnMapper()
            let headers = parsedData.first?.keys.map { String($0) } ?? []
            let mappingQuality = columnMapper.analyzeHeaders(headers)
            
            print("Column mapping quality: \(mappingQuality)")
            print(columnMapper.getMappingSummary())
            
            // Check if we have critical fields
            let missingCritical = columnMapper.getMissingCriticalFields()
            if !missingCritical.isEmpty {
                let missingFieldNames = missingCritical.map { $0.rawValue }.joined(separator: ", ")
                messages.append("Warning: Missing critical fields: \(missingFieldNames)")
            }
            
            print("Starting SwiftData import...") // Changed from Core Data import
            
            let batchSize = 100
            let totalItems = parsedData.count
            
            for i in stride(from: 0, to: totalItems, by: batchSize) {
                let batchEnd = min(i + batchSize, totalItems)
                let batchRows = Array(parsedData[i..<batchEnd])
                print("Processing batch \(i/batchSize + 1)/\( (totalItems + batchSize - 1) / batchSize )... (\(batchRows.count) items)")
                
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
                    print("Saved batch \(i/batchSize + 1)")
                } catch {
                    // Reset the context to avoid cascading errors
                    context.rollback()
                    failed += batchRows.count
                    successful -= batchRows.count
                    messages.append("Error saving batch \(i/batchSize + 1): \(error.localizedDescription)")
                    print("Error saving batch \(i/batchSize + 1): \(error)")
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
            
            return ImportExportView.ImportResults(
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
    private static func createOrUpdateNDISItemFromCSV(from row: [String: String], in context: ModelContext, using columnMapper: NDISColumnMapper? = nil) throws {
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
            startDate = parseDate(row["Start date"]) ?? parseDate(row["Start Date"])
            endDate = parseDate(row["End Date"]) ?? parseDate(row["End date"])
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
        
        // Check if this specific version already exists using composite key
        let fetchDescriptor = FetchDescriptor<NDISItemEntity>(predicate: #Predicate {
            $0.itemNumber == itemNumber && $0.name == itemName && $0.versionIdentifier == versionId
        })
        
        let ndisItem = (try? context.fetch(fetchDescriptor).first) ?? NDISItemEntity(id: UUID(), itemNumber: itemNumber, name: itemName, versionIdentifier: versionId)
        if ndisItem.modelContext == nil { // If it's a new entity, insert it
            context.insert(ndisItem)
        }
        
        // Set up basic item properties
        ndisItem.itemNumber = itemNumber
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
        
        // Clear existing regional prices for this item before adding new ones
        // SwiftData handles relationships differently, ensure old regional prices are removed before re-adding
        let currentPrices = ndisItem.regionalPrices
        for priceObject in currentPrices {
            context.delete(priceObject)
        }
        ndisItem.regionalPrices.removeAll()
        
        // Handle regional pricing with flexible mapping
        let regionalFields: [NDISColumnMapper.StandardField] = [.act, .nsw, .nt, .qld, .sa, .tas, .vic, .wa, .remote, .veryRemote]
        
        for field in regionalFields {
            let region = field.rawValue
            let priceValue: String?
            
            if let mapper = columnMapper {
                priceValue = mapper.getValue(for: field, from: row)
            } else {
                priceValue = row[region]
            }
            
            if let priceStr = priceValue, let priceVal = Double(priceStr) {
                let regionalPrice = RegionalPriceEntity(id: UUID())
                regionalPrice.regionIdentifier = region
                regionalPrice.amount = priceVal
                regionalPrice.ndisItem = ndisItem // Link to parent NDISItem
                context.insert(regionalPrice)
            }
        }
    }
    
    static func importNDISItems(data: Data, fileName: String, context: ModelContext) throws -> ImportExportView.ImportResults {
        guard let _ = try? context.fetch(FetchDescriptor<NDISItemEntity>()) else {
            throw NSError(
                domain: "NDISImportError",
                code: 1000,
                userInfo: [
                    NSLocalizedDescriptionKey: "Entity 'NDISItem' not found in SwiftData model", // Updated error message
                    NSLocalizedFailureReasonErrorKey: "The application's data model doesn't include the NDISItem. Please update your model or contact support."
                ]
            )
        }

        var parsedItems: [NDISItemData] = []
        var messages: [String] = []

        do {
            // Attempt 1: Parse as the complex NDIS Catalogue structure
            if let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let currentItems = jsonDict["Current Support Items"] as? [[String: Any]] {
                print("Parsing as NDIS Catalogue structure...")
                parsedItems = parseNDISCatalogueFormat(items: currentItems, messages: &messages)
            }
            // Attempt 2: Parse as a simple array of NDISItemJSON
            else if let simpleItems = try? JSONDecoder().decode([ImportExportView.NDISItemJSON].self, from: data) {
                print("Parsing as simple NDISItemJSON array...")
                parsedItems = simpleItems.map { item -> NDISItemData in
                    var regionalPricesForSimpleItem: [String: Double]? = nil
                    if let rateVal = item.rateValue {
                        regionalPricesForSimpleItem = ["NATIONAL": rateVal]
                    } else if let rateStr = item.rate, let parsedRate = Double(rateStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                        regionalPricesForSimpleItem = ["NATIONAL": parsedRate]
                    }
                    return NDISItemData(
                        itemNumber: item.itemNumber,
                        name: item.description ?? item.itemNumber, // Use itemNumber if name/desc missing
                        description: item.description ?? "",
                        unit: NDISItemImport.normalizeUnit(item.unit),
                        regionalPricesData: regionalPricesForSimpleItem,
                        category: item.category,
                        registrationGroup: nil, // Not available in this format
                        features: [], // Not available in this format
                        quoteRequired: nil, // Not available in this format
                        effectiveStartDate: Date(), // Simple JSON format doesn't include dates - use import date
                        effectiveEndDate: nil // Simple JSON format - no end date specified
                    )
                }
            }
             // Attempt 3: Parse as a single NDISItemJSON object
            else if let singleItem = try? JSONDecoder().decode(ImportExportView.NDISItemJSON.self, from: data) {
                 print("Parsing as single NDISItemJSON object...")
                 var regionalPricesForSingleItem: [String: Double]? = nil
                 if let rateVal = singleItem.rateValue {
                     regionalPricesForSingleItem = ["NATIONAL": rateVal]
                 } else if let rateStr = singleItem.rate, let parsedRate = Double(rateStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                     regionalPricesForSingleItem = ["NATIONAL": parsedRate]
                 }
                 parsedItems = [NDISItemData(
                     itemNumber: singleItem.itemNumber,
                     name: singleItem.description ?? singleItem.itemNumber,
                     description: singleItem.description ?? "",
                     unit: NDISItemImport.normalizeUnit(singleItem.unit),
                     regionalPricesData: regionalPricesForSingleItem,
                     category: singleItem.category,
                     registrationGroup: nil,
                     features: [],
                     quoteRequired: nil,
                     effectiveStartDate: Date(), // Simple JSON format doesn't include dates - use import date  
                     effectiveEndDate: nil // Simple JSON format - no end date specified
                 )]
            } else {
                throw NSError(domain: "NDISImportError", code: 101, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid JSON structure: Could not parse as NDIS Catalogue or simple item list."
                ])
            }

            if parsedItems.isEmpty {
                 messages.append("Warning: No valid NDIS items found in the imported data.")
                 // Return success with 0 items if parsing succeeded but found no items
                 return ImportExportView.ImportResults(
                     source: .ndisItems,
                     successful: 0,
                     failed: 0,
                     messages: messages,
                     fileName: fileName
                 )
            }

            print("Successfully parsed \(parsedItems.count) items. Starting SwiftData import...") // Changed from Core Data import
            return try processParsedItems(parsedItems, fileName: fileName, context: context, initialMessages: messages)

        } catch {
            print("NDIS import error during parsing: \(error)")
            throw NSError(
                domain: "NDISImportError",
                code: 103,
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to parse NDIS data: \(error.localizedDescription)"
                ]
            )
        }
    }

    private static func parseNDISCatalogueFormat(items: [[String: Any]], messages: inout [String]) -> [NDISItemData] {
        var parsedItems: [NDISItemData] = []
        for itemDict in items {
            guard let supportItem = itemDict["Support Item"] as? [String: Any],
                  let itemNumber = supportItem["Number"] as? String, !itemNumber.isEmpty else {
                messages.append("Skipped item: Missing or empty Support Item Number.")
                continue
            }

            let name = supportItem["Name"] as? String ?? itemNumber
            let description = (supportItem["Description"] as? String) ?? name 
            let rawUnit = supportItem["Unit"] as? String
            let unit = NDISItemImport.normalizeUnit(rawUnit)

            var category: String?
            var registrationGroup: String?
            if let categoryInfo = itemDict["Category Info"] as? [String: Any] {
                if let regGroupDict = categoryInfo["Registration Group"] as? [String: Any] {
                    registrationGroup = regGroupDict["Name"] as? String
                }
                if let supportCatDict = categoryInfo["Support Category"] as? [String: Any] {
                    category = supportCatDict["Name"] as? String
                }
            }

            var regionalPricesData: [String: Double] = [:]
            if let prices = itemDict["Prices"] as? [String: Any] {
                for (key, value) in prices {
                    if let doubleValue = value as? Double {
                        regionalPricesData[key] = doubleValue
                    } else if let stringValue = value as? String,
                              let doubleValueFromString = Double(stringValue.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                        regionalPricesData[key] = doubleValueFromString
                    }
                }
            }

            var features: [String] = []
            if let metadata = itemDict["Metadata"] as? [String: Any] {
                if (metadata["Non-Face-to-Face Support Provision"] as? String)?.uppercased() == "Y" { features.append("Non-Face-to-Face Support") }
                if (metadata["Provider Travel"] as? String)?.uppercased() == "Y" { features.append("Provider Travel") }
                if (metadata["Short Notice Cancellations."] as? String)?.uppercased() == "Y" { features.append("Cancellations") } // Note the dot
                if (metadata["NDIA Requested Reports"] as? String)?.uppercased() == "Y" { features.append("NDIA Requested Reports") }
                if (metadata["Irregular SIL Supports"] as? String)?.uppercased() == "Y" { features.append("Irregular SIL Support") }
                // Add more metadata checks if needed
            }

            var quoteRequired: Bool? = nil
            if let quoteInfo = itemDict["Quote Info"] as? [String: Any] {
                quoteRequired = quoteInfo["Quote Required"] as? Bool
            }

            // Extract effective dates from JSON structure
            var effectiveStartDate: Date? = nil
            var effectiveEndDate: Date? = nil
            
            // Try to extract dates from various possible locations in the JSON structure
            
            // 1. Check Support Item level for dates
            if let supportItem = itemDict["Support Item"] as? [String: Any] {
                effectiveStartDate = extractDateFromValue(supportItem["Start Date"]) ?? 
                                   extractDateFromValue(supportItem["Effective Start Date"]) ??
                                   extractDateFromValue(supportItem["Start date"]) ??
                                   extractDateFromValue(supportItem["effectiveStartDate"])
                                   
                effectiveEndDate = extractDateFromValue(supportItem["End Date"]) ??
                                 extractDateFromValue(supportItem["Effective End Date"]) ??
                                 extractDateFromValue(supportItem["End date"]) ??
                                 extractDateFromValue(supportItem["effectiveEndDate"])
            }
            
            // 2. Check Metadata level for dates (override Support Item dates if found)
            if let metaDict = itemDict["Metadata"] as? [String: Any] {
                if let startDate = extractDateFromValue(metaDict["effectiveStartDate"]) ??
                                  extractDateFromValue(metaDict["Start Date"]) ??
                                  extractDateFromValue(metaDict["Effective Start Date"]) {
                    effectiveStartDate = startDate
                }
                
                if let endDate = extractDateFromValue(metaDict["effectiveEndDate"]) ??
                                extractDateFromValue(metaDict["End Date"]) ??
                                extractDateFromValue(metaDict["Effective End Date"]) {
                    effectiveEndDate = endDate
                }
            }
            
            // 3. Check top-level item dictionary for dates
            if effectiveStartDate == nil {
                effectiveStartDate = extractDateFromValue(itemDict["Start Date"]) ??
                                   extractDateFromValue(itemDict["Effective Start Date"]) ??
                                   extractDateFromValue(itemDict["effectiveStartDate"])
            }
            
            if effectiveEndDate == nil {
                effectiveEndDate = extractDateFromValue(itemDict["End Date"]) ??
                                 extractDateFromValue(itemDict["Effective End Date"]) ??
                                 extractDateFromValue(itemDict["effectiveEndDate"])
            }
            
            // Default to current date if no start date found
            if effectiveStartDate == nil {
                effectiveStartDate = Date()
            }

            parsedItems.append(NDISItemData(
                itemNumber: itemNumber,
                name: name,
                description: description,
                unit: unit,
                regionalPricesData: regionalPricesData.isEmpty ? nil : regionalPricesData,
                category: category,
                registrationGroup: registrationGroup,
                features: features,
                quoteRequired: quoteRequired,
                effectiveStartDate: effectiveStartDate,
                effectiveEndDate: effectiveEndDate
            ))
        }
        return parsedItems
    }
    
    /// Extracts a Date from various possible value types (Date, String, Number)
    private static func extractDateFromValue(_ value: Any?) -> Date? {
        guard let value = value else { return nil }
        
        // Handle Date objects directly
        if let date = value as? Date {
            return date
        }
        
        // Handle string representations
        if let stringValue = value as? String {
            return parseDate(stringValue)
        }
        
        // Handle numeric timestamps (seconds since 1970)
        if let doubleValue = value as? Double {
            return Date(timeIntervalSince1970: doubleValue)
        }
        
        if let intValue = value as? Int {
            return Date(timeIntervalSince1970: Double(intValue))
        }
        
        // Handle numeric string timestamps
        if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            // Check if it looks like a timestamp (reasonable range)
            if doubleValue > 946684800 && doubleValue < 4102444800 { // Between 2000 and 2100
                return Date(timeIntervalSince1970: doubleValue)
            }
        }
        
        return nil
    }

    private static func processParsedItems(_ items: [NDISItemData], fileName: String, context: ModelContext, initialMessages: [String]) throws -> ImportExportView.ImportResults {
        var successful = 0
        var failed = 0
        var messages = initialMessages
        let batchSize = 100 // Process in batches to manage memory
        let totalItems = items.count

        print("Starting batch processing for \(totalItems) items...")

        for i in stride(from: 0, to: totalItems, by: batchSize) {
            let batchEnd = min(i + batchSize, totalItems)
            let batchItems = Array(items[i..<batchEnd])
            print("Processing batch \(i/batchSize + 1)/\( (totalItems + batchSize - 1) / batchSize )... (\(batchItems.count) items)")



            for itemData in batchItems {
                
                // Check if this is a duplicate of an already imported item in this batch
                let currentIndex = items.firstIndex(of: itemData) ?? 0
                let isDuplicateInBatch = items.prefix(currentIndex)
                    .contains { existing in
                        existing.itemNumber == itemData.itemNumber && 
                        existing.name == itemData.name
                    }
                
                if isDuplicateInBatch {
                    // Skip exact duplicates within the same import batch
                    continue
                }
                
                // Always create a new entity for imported items
                // The updateCurrentStatusForItem function will handle setting isCurrent appropriately
                let entity = NDISItemEntity(id: UUID(), itemNumber: itemData.itemNumber, name: itemData.name, versionIdentifier: NDISVersioningService.createVersionIdentifier(itemNumber: itemData.itemNumber, itemName: itemData.name, startDate: itemData.effectiveStartDate ?? Date(), endDate: itemData.effectiveEndDate))
                // messages.append("Created NDIS item: \(itemData.itemNumber) - \(itemData.name)")

                // Set values directly since we know the properties exist
                entity.itemNumber = itemData.itemNumber
                entity.name = itemData.name
                entity.itemDescription = itemData.description
                entity.unit = itemData.unit
                entity.category = itemData.category
                entity.registrationGroup = itemData.registrationGroup
                entity.features = itemData.features.joined(separator: ",")
                entity.status = "Active"
                entity.quoteRequired = itemData.quoteRequired
                // Set effective dates for version tracking
                entity.effectiveStartDate = itemData.effectiveStartDate
                entity.effectiveEndDate = itemData.effectiveEndDate

                // Handle RegionalPriceEntity creation
                // Since we're always creating new entities, no need to clear existing prices

                if let pricesData = itemData.regionalPricesData {
                    for (region, amount) in pricesData {
                        let priceEntity = RegionalPriceEntity(id: UUID())
                        priceEntity.regionIdentifier = region
                        priceEntity.amount = amount
                        priceEntity.ndisItem = entity // Link to parent NDISItem
                        context.insert(priceEntity)
                    }
                }
                
                successful += 1
            }

            // Update current status for all items in this batch
            let uniqueCompositeKeys = Set(batchItems.map { "\($0.itemNumber)|\($0.name)" })
            for compositeKey in uniqueCompositeKeys {
                let components = compositeKey.split(separator: "|")
                if components.count == 2 {
                    let itemNumber = String(components[0])
                    let itemName = String(components[1])
                    do {
                        try updateCurrentStatusForItem(itemNumber: itemNumber, itemName: itemName, context: context)
                    } catch {
                        print("Warning: Failed to update current status for \(itemNumber) - \(itemName): \(error)")
                    }
                }
            }

            // Save changes after each batch
            do {
                try context.save()
                print("Saved batch \(i/batchSize + 1)")
            } catch {
                // Handle batch save error - potentially rollback or log failures
                failed += batchItems.count // Assume all in batch failed if save fails
                successful -= batchItems.count // Adjust success count
                messages.append("Error saving batch \(i/batchSize + 1): \(error.localizedDescription)")
                print("Error saving batch \(i/batchSize + 1): \(error)")
                // Consider stopping the import or trying to continue with the next batch
                // For now, we'll just log and continue
            }
        }

        if successful > 0 {
             messages.insert("Successfully imported/updated \(successful) NDIS items.", at: 0)
        }
        if failed > 0 {
             messages.insert("Failed to import/update \(failed) NDIS items.", at: failed == 0 ? 0 : 1)
        }
        if successful == 0 && failed == 0 && items.isEmpty {
             messages.insert("No NDIS items were found in the file to import.", at: 0)
        } else if successful == 0 && failed == 0 {
             messages.insert("File parsed, but no items were processed (check format or existing data).", at: 0)
        }


        print("Import finished. Success: \(successful), Failed: \(failed)")
        return ImportExportView.ImportResults(
            source: .ndisItems,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }

    /// Updates the current status for all versions of a specific NDIS item.
    /// Individual isCurrent flags will be properly set by updateCurrentStatusForAllItems() 
    /// which uses global most recent effective date logic.
    private static func updateCurrentStatusForItem(itemNumber: String, itemName: String, context: ModelContext) throws {
        // Get all versions of this specific item (same number + name)
        let allVersions = try NDISVersioningService.findAllVersions(itemNumber: itemNumber, itemName: itemName, in: context)
        
        guard !allVersions.isEmpty else { return }
        
        // Temporarily set all versions to not current - the global update will set the correct values
        // based on the most recent effective start date across ALL items
        for version in allVersions {
            version.isCurrent = false
        }
        

    }

    // New, correct normalizeUnit function
    static func normalizeUnit(_ unit: String?) -> String {
        guard let unit = unit?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return "Each" }

        // First, try to find an exact match in the standardized options
        let unitOptions = ["Each", "Hour", "Day", "Week", "Month", "Year", "Session", "Item", "Unit"]
        if unitOptions.map({ $0.lowercased() }).contains(unit) {
            return unitOptions.first(where: { $0.lowercased() == unit }) ?? "Each"
        }

        // Handle common variations for "Hour", "Session", "Item", "Each", "Day", "Week", "Month", "Project"
        switch unit {
        case "h", "hr", "hrs":
            return "Hour"
        case "sess", "sessions":
            return "Session"
        case "e", "ea", "pce", "pieces":
            return "Each"
        case "d", "dayz", "days":
            return "Day"
        case "wk", "wks":
            return "Week"
        case "mon", "mons", "mnth":
            return "Month"
        case "yr":
            return "Year"
        case "proj", "projects":
            return "Project"
        default:
            // Fallback to "each" if no match found
            return "Each"
        }
    }
    
    /// Parses date from various common formats found in NDIS files
    private static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !dateString.isEmpty else { return nil }
        
        // Handle special NDIS end date format (99991231 = indefinite)
        if dateString == "99991231" || dateString == "9999-12-31" || dateString == "31/12/9999" {
            return nil // Return nil to indicate indefinite end date
        }
        
        // Common date formats found in NDIS files
        let formatters = [
            createDateFormatter(format: "yyyyMMdd"),       // 20240701 (common in NDIS files)
            createDateFormatter(format: "dd/MM/yyyy"),     // 01/07/2024
            createDateFormatter(format: "d/M/yyyy"),       // 1/7/2024
            createDateFormatter(format: "yyyy-MM-dd"),     // 2024-07-01
            createDateFormatter(format: "dd-MM-yyyy"),     // 01-07-2024
            createDateFormatter(format: "MM/dd/yyyy"),     // 07/01/2024 (US format)
            createDateFormatter(format: "dd MMM yyyy"),    // 01 Jul 2024
            createDateFormatter(format: "d MMM yyyy"),     // 1 Jul 2024
            createDateFormatter(format: "MMMM d, yyyy"),   // July 1, 2024
            createDateFormatter(format: "d MMMM yyyy"),    // 1 July 2024
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private static func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_AU") // Australian locale for NDIS
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        return formatter
    }
    
    /// Parses boolean fields from various text representations found in NDIS files
    private static func parseBooleanField(_ value: String?) -> Bool? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        
        let normalized = value.lowercased()
        switch normalized {
        case "yes", "y", "true", "1", "on":
            return true
        case "no", "n", "false", "0", "off":
            return false
        default:
            return nil // Return nil for unknown values
        }
    }
} 
