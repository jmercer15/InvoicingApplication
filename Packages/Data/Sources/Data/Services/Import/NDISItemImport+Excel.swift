import Foundation
import SwiftData
import Core

extension NDISItemImport {
    
    /// Imports NDIS items from Excel data using the new Excel parsing logic
    internal static func importNDISItemsFromExcel(url: URL, fileName: String, context: ModelContext) throws -> ImportResult {
        let excelParser = ExcelParser()
        var successful = 0
        var failed = 0
        var messages: [String] = []
        
        do {
            let parsedData = try excelParser.parse(url: url)
            
            if parsedData.isEmpty {
                messages.append("Warning: No valid NDIS items found in the Excel file.")
                return ImportResult(
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
             
             print("Starting SwiftData import...")
             
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
            
            return ImportResult(
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
}
