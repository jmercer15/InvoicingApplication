import Foundation

class CSVParser {
    enum CSVParseError: Error {
        case cannotReadFile
        case emptyDocument
        case malformedRow(expected: Int, actual: Int)
    }
    
    /// Parses a CSV file, converting it into an array of dictionaries.
    func parse(url: URL) throws -> [[String: String]] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw CSVParseError.cannotReadFile
        }
        return try parse(content: content)
    }
    
    /// Parses comma-separated text content.
    func parse(content: String) throws -> [[String: String]] {
        try parse(content: content, fieldSeparator: ",")
    }
    
    /// Parses delimited text content using the provided separator.
    func parse(content: String, fieldSeparator: Character) throws -> [[String: String]] {
        let rows = try parseRows(content: content, fieldSeparator: fieldSeparator)
        guard let headerRow = rows.first, !headerRow.isEmpty else {
            throw CSVParseError.emptyDocument
        }
        
        let header = headerRow.map { sanitizeField($0) }
        
        let dataRows = rows.dropFirst()
        var results: [[String: String]] = []
        
        for row in dataRows where !row.isEmpty {
            if row.count != header.count {
                throw CSVParseError.malformedRow(expected: header.count, actual: row.count)
            }
            var dict = [String: String]()
            for (index, headerValue) in header.enumerated() {
                dict[headerValue] = sanitizeField(row[index])
            }
            results.append(dict)
        }
        
        return results
    }
    
    private func parseRows(content: String, fieldSeparator: Character) throws -> [[String]] {
        let rows = tokenize(content: content, fieldSeparator: fieldSeparator)
        if rows.isEmpty {
            throw CSVParseError.emptyDocument
        }
        return rows
    }
    
    private func tokenize(content: String, fieldSeparator: Character) -> [[String]] {
        let separator = fieldSeparator.unicodeScalars.first ?? ","
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = String()
        var inQuotes = false
        let scalars = Array(content.unicodeScalars)
        var index = 0
        
        while index < scalars.count {
            let scalar = scalars[index]
            
            if inQuotes {
                if scalar == "\"" {
                    if index + 1 < scalars.count && scalars[index + 1] == "\"" {
                        currentField.unicodeScalars.append("\"")
                        index += 1
                    } else {
                        inQuotes = false
                    }
                    index += 1
                    continue
                }
                
                currentField.unicodeScalars.append(scalar)
                index += 1
                continue
            }
            
            switch scalar {
            case "\"":
                inQuotes = true
                index += 1
            case "\r":
                if index + 1 < scalars.count && scalars[index + 1] == "\n" {
                    index += 1
                }
                currentRow.append(currentField)
                currentField = ""
                if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow.removeAll(keepingCapacity: true)
                index += 1
            case "\n":
                currentRow.append(currentField)
                currentField = ""
                if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow.removeAll(keepingCapacity: true)
                index += 1
            case separator:
                currentRow.append(currentField)
                currentField = ""
                index += 1
            default:
                if scalar != "\u{200B}" {
                    currentField.unicodeScalars.append(scalar)
                }
                index += 1
            }
        }
        
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(currentRow)
            }
        }
        return rows
    }
    
    private func sanitizeField(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}