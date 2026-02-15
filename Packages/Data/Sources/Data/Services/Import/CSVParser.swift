import Foundation

class CSVParser {
    /// Parses a CSV file, converting it into an array of dictionaries.
    /// - Parameter url: The URL of the CSV file.
    /// - Returns: An array of dictionaries, where each dictionary represents a row with headers as keys.
    /// - Throws: An error if the file content cannot be read.
    func parse(url: URL) throws -> [[String: String]] {
        let content = try String(contentsOf: url, encoding: .utf8)
        let rows = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        
        guard let headerRow = rows.first else { return [] }
        
        // Sanitize header to remove BOM characters and trim whitespace.
        let header = headerRow
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        let dataRows = rows.dropFirst()
        
        return dataRows.map { row in
            let values = row.components(separatedBy: ",")
            var dict = [String: String]()
            for (index, headerValue) in header.enumerated() {
                if index < values.count {
                    dict[headerValue] = values[index].trimmingCharacters(in: .whitespaces)
                }
            }
            return dict
        }
    }
} 