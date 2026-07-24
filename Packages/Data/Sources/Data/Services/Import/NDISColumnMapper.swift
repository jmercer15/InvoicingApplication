import Foundation

/// Handles flexible column mapping for NDIS Support Catalogue files across different years
class NDISColumnMapper {
    
    // MARK: - Standardized Field Names
    enum StandardField: String, CaseIterable {
        case itemNumber = "Support Item Number"
        case itemName = "Support Item Name"
        case categoryName = "Support Category Name"
        case categoryNamePACE = "Support Category Name (PACE)"
        case categoryNumber = "Support Category Number"
        case categoryNumberPACE = "Support Category Number (PACE)"
        case registrationGroup = "Registration Group Name"
        case registrationGroupNumber = "Registration Group Number"
        case unit = "Unit"
        case quote = "Quote"
        case tab = "Tab"
        case type = "Type"
        // Date fields for versioning
        case startDate = "Start date"
        case endDate = "End Date"
        // Provision and service delivery fields
        case nonFaceToFaceProvision = "Non-Face-to-Face Support Provision"
        case providerTravel = "Provider Travel"
        case shortNoticeCancellations = "Short Notice Cancellations"
        case ndiaRequestedReports = "NDIA Requested Reports"
        case irregularSILSupports = "Irregular SIL Supports"
        // Regional pricing
        case act = "ACT"
        case nsw = "NSW"
        case nt = "NT"
        case qld = "QLD"
        case sa = "SA"
        case tas = "TAS"
        case vic = "VIC"
        case wa = "WA"
        case remote = "Remote"
        case veryRemote = "Very Remote"
    }
    
    // MARK: - Column Variations
    private static let columnVariations: [StandardField: [String]] = [
        .itemNumber: [
            "Support Item Number",
            "Item Number",
            "NDIS Item Number",
            "Support Item No",
            "Item No",
            "Number"
        ],
        .itemName: [
            "Support Item Name",
            "Item Name",
            "Support Item Description",
            "Description",
            "Name",
            "Item Description"
        ],
        .categoryName: [
            "Support Category Name",
            "Category Name",
            "Category",
            "Support Category"
        ],
        .categoryNamePACE: [
            "Support Category Name (PACE)",
            "PACE Category Name",
            "PACE Category"
        ],
        .categoryNumber: [
            "Support Category Number",
            "Category Number",
            "Category No",
            "Support Category No"
        ],
        .categoryNumberPACE: [
            "Support Category Number (PACE)",
            "PACE Category Number",
            "PACE Category No"
        ],
        .registrationGroup: [
            "Registration Group Name",
            "Registration Group",
            "Reg Group Name",
            "Reg Group",
            "Group Name",
            "Group"
        ],
        .registrationGroupNumber: [
            "Registration Group Number",
            "Registration Group No",
            "Reg Group Number",
            "Reg Group No",
            "Group Number",
            "Group No"
        ],
        .unit: [
            "Unit",
            "Unit of Measure",
            "UOM",
            "Measure"
        ],
        .quote: [
            "Quote",
            "Quote Required",
            "Requires Quote",
            "Quote Req"
        ],
        .tab: [
            "Tab",
            "Status",
            "Active",
            "Current"
        ],
        .startDate: [
            "Start date",
            "Start Date",
            "Effective Start Date",
            "Effective From",
            "Valid From",
            "From Date"
        ],
        .endDate: [
            "End Date",
            "End date", 
            "Effective End Date",
            "Effective To",
            "Valid To",
            "To Date",
            "Expiry Date"
        ],
        .type: [
            "Type",
            "Item Type",
            "Support Type"
        ],
        .nonFaceToFaceProvision: [
            "Non-Face-to-Face Support Provision",
            "Non-Face-to-Face Provision",
            "Non Face to Face Provision",
            "Remote Provision",
            "Non-Face-to-Face"
        ],
        .providerTravel: [
            "Provider Travel",
            "Travel",
            "Provider Travel Included",
            "Travel Included"
        ],
        .shortNoticeCancellations: [
            "Short Notice Cancellations",
            "Short Notice",
            "Cancellations",
            "Short Notice Cancel"
        ],
        .ndiaRequestedReports: [
            "NDIA Requested Reports",
            "NDIA Reports",
            "Reports Required",
            "NDIA Reporting"
        ],
        .irregularSILSupports: [
            "Irregular SIL Supports",
            "Irregular SIL",
            "SIL Irregular",
            "Irregular Supports"
        ],
        // Regional pricing columns are generally consistent
        .act: ["ACT"],
        .nsw: ["NSW"],
        .nt: ["NT"],
        .qld: ["QLD"],
        .sa: ["SA"],
        .tas: ["TAS"],
        .vic: ["VIC"],
        .wa: ["WA"],
        .remote: ["Remote"],
        .veryRemote: ["Very Remote", "VeryRemote", "Very_Remote"]
    ]
    
    // MARK: - Instance Properties
    private var columnMapping: [StandardField: String] = [:]
    private var availableColumns: [String] = []
    private var mappingQuality: MappingQuality = .unknown
    
    enum MappingQuality {
        case excellent  // All critical fields found with exact matches
        case good      // All critical fields found, some with fuzzy matches
        case acceptable // Most critical fields found
        case poor      // Missing several critical fields
        case unknown   // Not yet analyzed
    }
    
    // MARK: - Public Methods
    
    /// Analyzes the column headers and creates a mapping
    func analyzeHeaders(_ headers: [String]) -> MappingQuality {
        availableColumns = headers.map { $0.trimmingCharacters(in: .whitespaces) }
        columnMapping.removeAll()
        
        var criticalFieldsFound = 0
        let criticalFields: [StandardField] = [.itemNumber, .itemName, .unit]
        
        // Try to map each standard field
        for field in StandardField.allCases {
            if let mappedColumn = findBestMatch(for: field, in: availableColumns) {
                columnMapping[field] = mappedColumn
                if criticalFields.contains(field) {
                    criticalFieldsFound += 1
                }
            }
        }
        
        // Determine mapping quality
        let totalCriticalFields = criticalFields.count
        let hasAllCritical = criticalFieldsFound == totalCriticalFields
        let hasMostCritical = criticalFieldsFound >= totalCriticalFields - 1
        
        if hasAllCritical && columnMapping.count >= 10 {
            mappingQuality = .excellent
        } else if hasAllCritical {
            mappingQuality = .good
        } else if hasMostCritical {
            mappingQuality = .acceptable
        } else {
            mappingQuality = .poor
        }
        
        return mappingQuality
    }
    
    /// Extracts value for a standard field from a row
    func getValue(for field: StandardField, from row: [String: String]) -> String? {
        guard let columnName = columnMapping[field] else { return nil }
        return row[columnName]
    }
    
    /// Extracts and parses a date value for a standard field from a row
    func getDateValue(for field: StandardField, from row: [String: String]) -> Date? {
        guard let columnName = columnMapping[field],
              let dateString = row[columnName],
              !dateString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            return nil 
        }
        
        return parseDate(from: dateString)
    }
    
    /// Parses date from various common formats found in NDIS files
    private func parseDate(from dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle special NDIS end date format (99991231 = indefinite)
        if trimmed == "99991231" || trimmed == "9999-12-31" || trimmed == "31/12/9999" {
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
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        return nil
    }
    
    private func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_AU") // Australian locale for NDIS
        formatter.timeZone = TimeZone(identifier: "Australia/Sydney")
        return formatter
    }
    
    /// Gets a summary of the mapping for debugging
    func getMappingSummary() -> String {
        var summary = "NDIS Column Mapping Summary:\n"
        summary += "Quality: \(mappingQuality)\n"
        summary += "Available columns: \(availableColumns.count)\n"
        summary += "Mapped fields: \(columnMapping.count)\n\n"
        
        for field in StandardField.allCases {
            if let mappedColumn = columnMapping[field] {
                summary += "✓ \(field.rawValue) → '\(mappedColumn)'\n"
            } else {
                summary += "✗ \(field.rawValue) → NOT FOUND\n"
            }
        }
        
        return summary
    }
    
    /// Gets missing critical fields
    func getMissingCriticalFields() -> [StandardField] {
        let criticalFields: [StandardField] = [.itemNumber, .itemName, .unit]
        return criticalFields.filter { columnMapping[$0] == nil }
    }
    
    // MARK: - Private Methods
    
    private func findBestMatch(for field: StandardField, in headers: [String]) -> String? {
        guard let variations = Self.columnVariations[field] else { return nil }
        
        // First try exact matches (case insensitive)
        for variation in variations {
            if let exactMatch = headers.first(where: { $0.caseInsensitiveCompare(variation) == .orderedSame }) {
                return exactMatch
            }
        }
        
        // Then try partial matches
        for variation in variations {
            if let partialMatch = headers.first(where: { $0.localizedCaseInsensitiveContains(variation) }) {
                return partialMatch
            }
        }
        
        // Finally try reverse partial matches (variation contains header)
        for header in headers {
            for variation in variations {
                if variation.localizedCaseInsensitiveContains(header) && header.count > 3 {
                    return header
                }
            }
        }
        
        return nil
    }
} 