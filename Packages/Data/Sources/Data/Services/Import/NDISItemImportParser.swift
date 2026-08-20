import os
import Core
import Foundation

enum NDISItemImportDateParser {
    static func date(from value: Any?) -> Date? {
        guard let value else { return nil }

        if let date = value as? Date {
            return date
        }

        if let stringValue = value as? String {
            return parseDate(stringValue)
        }

        if let doubleValue = value as? Double {
            return Date(timeIntervalSince1970: doubleValue)
        }

        if let intValue = value as? Int {
            return Date(timeIntervalSince1970: Double(intValue))
        }

        if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            if doubleValue > 946_684_800 && doubleValue < 4_102_444_800 {
                return Date(timeIntervalSince1970: doubleValue)
            }
        }

        return nil
    }

    static func parseDate(_ dateString: String?) -> Date? {
        guard let dateString else { return nil }

        let formatter = DateFormatter()
        let formats = ["dd/MM/yyyy", "dd-MM-yyyy", "yyyy-MM-dd", "d/M/yyyy", "d-M-yyyy"]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }
}

enum NDISItemImportParser {
    static func parse(data: Data, messages: inout [String]) throws -> [NDISItemData] {
        if let jsonDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let currentItems = jsonDict["Current Support Items"] as? [[String: Any]] {
            Logger.importExport.info("Parsing as NDIS Catalogue structure...")
            return parseNDISCatalogueFormat(items: currentItems, messages: &messages)
        }

        if let simpleItems = try? JSONDecoder().decode([NDISItemJSON].self, from: data) {
            Logger.importExport.info("Parsing as simple NDISItemJSON array...")
            return simpleItems.map(simpleItemData)
        }

        if let singleItem = try? JSONDecoder().decode(NDISItemJSON.self, from: data) {
            Logger.importExport.info("Parsing as single NDISItemJSON object...")
            return [simpleItemData(from: singleItem)]
        }

        throw NSError(domain: "NDISImportError", code: 101, userInfo: [
            NSLocalizedDescriptionKey: "Invalid JSON structure: Could not parse as NDIS Catalogue or simple item list."
        ])
    }

    private static func simpleItemData(from item: NDISItemJSON) -> NDISItemData {
        NDISItemData(
            itemNumber: item.itemNumber,
            name: item.description ?? item.itemNumber,
            description: item.description ?? "",
            unit: NDISItemImport.normalizeUnit(item.unit),
            regionalPricesData: regionalPrices(from: item),
            category: item.category,
            registrationGroup: nil,
            features: [],
            quoteRequired: nil,
            effectiveStartDate: Date(),
            effectiveEndDate: nil
        )
    }

    private static func regionalPrices(from item: NDISItemJSON) -> [String: Double]? {
        if let rateVal = item.rateValue {
            return ["NATIONAL": rateVal]
        }

        if let rateStr = item.rate,
           let parsedRate = Double(rateStr.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
            return ["NATIONAL": parsedRate]
        }

        return nil
    }

    private static func parseNDISCatalogueFormat(items: [[String: Any]], messages: inout [String]) -> [NDISItemData] {
        var parsedItems: [NDISItemData] = []

        for itemDict in items {
            guard let supportItem = itemDict["Support Item"] as? [String: Any],
                  let itemNumber = supportItem["Number"] as? String,
                  !itemNumber.isEmpty else {
                messages.append("Skipped item: Missing or empty Support Item Number.")
                continue
            }

            let name = supportItem["Name"] as? String ?? itemNumber
            let description = (supportItem["Description"] as? String) ?? name
            let unit = NDISItemImport.normalizeUnit(supportItem["Unit"] as? String)

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
                if (metadata["Short Notice Cancellations."] as? String)?.uppercased() == "Y" { features.append("Cancellations") }
                if (metadata["NDIA Requested Reports"] as? String)?.uppercased() == "Y" { features.append("NDIA Requested Reports") }
                if (metadata["Irregular SIL Supports"] as? String)?.uppercased() == "Y" { features.append("Irregular SIL Support") }
            }

            var quoteRequired: Bool?
            if let quoteInfo = itemDict["Quote Info"] as? [String: Any] {
                quoteRequired = quoteInfo["Quote Required"] as? Bool
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
                effectiveStartDate: effectiveStartDate(from: itemDict, supportItem: supportItem),
                effectiveEndDate: effectiveEndDate(from: itemDict, supportItem: supportItem)
            ))
        }

        return parsedItems
    }

    private static func effectiveStartDate(from itemDict: [String: Any], supportItem: [String: Any]) -> Date {
        var effectiveStartDate = NDISItemImportDateParser.date(from: supportItem["Start Date"]) ??
            NDISItemImportDateParser.date(from: supportItem["Effective Start Date"]) ??
            NDISItemImportDateParser.date(from: supportItem["Start date"]) ??
            NDISItemImportDateParser.date(from: supportItem["effectiveStartDate"])

        if let metaDict = itemDict["Metadata"] as? [String: Any],
           let startDate = NDISItemImportDateParser.date(from: metaDict["effectiveStartDate"]) ??
            NDISItemImportDateParser.date(from: metaDict["Start Date"]) ??
            NDISItemImportDateParser.date(from: metaDict["Effective Start Date"]) {
            effectiveStartDate = startDate
        }

        if effectiveStartDate == nil {
            effectiveStartDate = NDISItemImportDateParser.date(from: itemDict["Start Date"]) ??
                NDISItemImportDateParser.date(from: itemDict["Effective Start Date"]) ??
                NDISItemImportDateParser.date(from: itemDict["effectiveStartDate"])
        }

        return effectiveStartDate ?? Date()
    }

    private static func effectiveEndDate(from itemDict: [String: Any], supportItem: [String: Any]) -> Date? {
        var effectiveEndDate = NDISItemImportDateParser.date(from: supportItem["End Date"]) ??
            NDISItemImportDateParser.date(from: supportItem["Effective End Date"]) ??
            NDISItemImportDateParser.date(from: supportItem["End date"]) ??
            NDISItemImportDateParser.date(from: supportItem["effectiveEndDate"])

        if let metaDict = itemDict["Metadata"] as? [String: Any],
           let endDate = NDISItemImportDateParser.date(from: metaDict["effectiveEndDate"]) ??
            NDISItemImportDateParser.date(from: metaDict["End Date"]) ??
            NDISItemImportDateParser.date(from: metaDict["Effective End Date"]) {
            effectiveEndDate = endDate
        }

        if effectiveEndDate == nil {
            effectiveEndDate = NDISItemImportDateParser.date(from: itemDict["End Date"]) ??
                NDISItemImportDateParser.date(from: itemDict["Effective End Date"]) ??
                NDISItemImportDateParser.date(from: itemDict["effectiveEndDate"])
        }

        return effectiveEndDate
    }
}
