import os
import Foundation
import UniformTypeIdentifiers
import CoreXLSX

class ExcelParser {
    /// Parses an Excel file by first attempting to convert it to CSV using system tools
    /// - Parameter url: The URL of the Excel file
    /// - Returns: An array of dictionaries representing the rows and columns
    /// - Throws: An error if the file cannot be read or converted
    func parse(url: URL) throws -> [[String: String]] {
        // For Excel files, we'll try multiple approaches:
        // 1. Use system tools to convert to CSV
        // 2. Try to read as a simple delimited format if it's actually tab-separated
        
        let fileExtension = url.pathExtension.lowercased()
        
        if fileExtension == "xlsx" || fileExtension == "xls" {
            return try parseExcelFile(url: url)
        } else {
            throw NSError(domain: "ExcelParserError", code: 100, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported file format: \(fileExtension)"
            ])
        }
    }
    
    private func parseExcelFile(url: URL) throws -> [[String: String]] {
        // Try native XLSX parsing first (now available with CoreXLSX)
        do {
            return try parseXLSXNatively(url: url)
        } catch {
            // If native parsing fails, fall back to conversion approaches
            Logger.importExport.warning("Native XLSX parsing failed: \(error.localizedDescription)")
            
            // Attempt 2: Try to use system conversion tools
            if let csvData = try? convertExcelToCSVUsingSystemTools(url: url) {
                return try parseCSVData(csvData)
            }
            
            // Attempt 3: If the file is actually a tab-separated file with .xlsx extension
            if let tabData = try? String(contentsOf: url, encoding: .utf8) {
                return try parseTabSeparatedData(tabData)
            }
            
            // If all attempts fail, re-throw the original error from native parsing
            throw error
        }
    }
    
    private func parseXLSXNatively(url: URL) throws -> [[String: String]] {
        guard let file = XLSXFile(filepath: url.path) else {
            throw NSError(domain: "ExcelParserError", code: 103, userInfo: [
                NSLocalizedDescriptionKey: "Failed to open XLSX file"
            ])
        }
        
        // Parse shared strings (may be nil if no shared strings in file)
        let sharedStrings = try? file.parseSharedStrings()
        let worksheets = try file.parseWorksheetPaths()
        
        guard !worksheets.isEmpty else {
            throw NSError(domain: "ExcelParserError", code: 104, userInfo: [
                NSLocalizedDescriptionKey: "No worksheets found in XLSX file"
            ])
        }
        
        // For NDIS files, prefer the 'current' sheet if it exists, otherwise use first sheet
        let worksheetPath: String
        if worksheets.count > 1 {
            // Try to find a 'current' sheet (case-insensitive)
            if let currentSheet = worksheets.first(where: { path in
                let name = (path as NSString).lastPathComponent.lowercased()
                return name.contains("current") || name.contains("active") || 
                       name.contains("sheet1") || name == "sheet1.xml"
            }) {
                worksheetPath = currentSheet
                Logger.importExport.info("Found preferred sheet for NDIS data: \(worksheetPath)")
            } else {
                // Use first sheet as fallback
                worksheetPath = worksheets.first!
                Logger.importExport.info("Using first sheet as fallback: \(worksheetPath)")
            }
        } else {
            worksheetPath = worksheets.first!
        }
        
        let worksheet = try file.parseWorksheet(at: worksheetPath)
        
        // Convert worksheet data to [[String: String]] format
        var result: [[String: String]] = []
        var headers: [String] = []
        
        // Extract headers from first row
        if let headerRow = worksheet.data?.rows.first {
            headers = headerRow.cells.compactMap { cell in
                return cell.stringValue(sharedStrings)
            }
            Logger.importExport.info("Excel headers found: \(headers)")
        }
        
        // Process data rows (skip header row)
        for (index, row) in worksheet.data?.rows.enumerated() ?? [].enumerated() {
            if index == 0 { continue } // Skip header row
            
            var rowDict: [String: String] = [:]
            
            for (columnIndex, cell) in row.cells.enumerated() {
                if columnIndex < headers.count {
                    let header = headers[columnIndex]
                    let value = cell.stringValue(sharedStrings) ?? ""
                    rowDict[header] = value
                }
            }
            
            result.append(rowDict)
        }
        
        Logger.importExport.info("Excel parsing completed: \(result.count) rows extracted")
        return result
    }
    
    private func convertExcelToCSVUsingSystemTools(url: URL) throws -> String {
        // Create a more helpful error message with specific instructions for NDIS files
        let fileName = url.lastPathComponent
        
        throw NSError(domain: "ExcelParserError", code: 102, userInfo: [
            NSLocalizedDescriptionKey: "Excel file '\(fileName)' needs to be converted to CSV format for import.",
            NSLocalizedRecoverySuggestionErrorKey: """
            To import Excel files:
            
            1. Open '\(fileName)' in Excel, Numbers, or Google Sheets
            2. Select the data sheet (usually the first sheet)
            3. Save/Export as CSV format
            4. Use the CSV file for import
            
            The CSV should contain columns: Support Item Number, Support Item Name, Support Category Name, Registration Group Name, Unit, Tab, Quote, and regional pricing columns (ACT, NSW, NT, QLD, SA, TAS, VIC, WA, Remote, Very Remote).
            """
        ])
    }
    
    private func parseCSVData(_ csvString: String) throws -> [[String: String]] {
        let parser = CSVParser()
        return try parser.parse(content: csvString, fieldSeparator: ",")
    }
    
    private func parseTabSeparatedData(_ content: String) throws -> [[String: String]] {
        let parser = CSVParser()
        return try parser.parse(content: content, fieldSeparator: "\t")
    }
}

// Extension to get string values from cells
extension Cell {
    func stringValue(_ sharedStrings: SharedStrings?) -> String? {
        guard let type = type else { return value }
        
        switch type {
        case .sharedString:
            guard let sharedStrings = sharedStrings,
                  let value = value,
                  let index = Int(value),
                  index < sharedStrings.items.count else { return value }
            return sharedStrings.items[index].text
        default:
            return value
        }
    }
} 
 
