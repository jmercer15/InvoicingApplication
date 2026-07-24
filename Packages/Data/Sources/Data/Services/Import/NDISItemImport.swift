import Foundation
import SwiftData
import Core

// Representations of data for NDIS item creation/update
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
        return lhs.itemNumber == rhs.itemNumber
            && lhs.name == rhs.name
            && lhs.effectiveStartDate == rhs.effectiveStartDate
            && lhs.effectiveEndDate == rhs.effectiveEndDate
    }
}

struct NDISItemImport {
    
    static func importNDISItems(data: Data, fileName: String, context: ModelContext) throws -> ImportResult {
        guard let _ = try? context.fetch(FetchDescriptor<NDISItem>()) else {
            throw NSError(
                domain: "NDISImportError",
                code: 1000,
                userInfo: [
                    NSLocalizedDescriptionKey: "Entity 'NDISItem' not found in SwiftData model",
                    NSLocalizedFailureReasonErrorKey: "The application's data model doesn't include the NDISItem. Please update your model or contact support."
                ]
            )
        }

        var messages: [String] = []

        do {
            let parsedItems = try NDISItemImportParser.parse(data: data, messages: &messages)

            if parsedItems.isEmpty {
                 messages.append("Warning: No valid NDIS items found in the imported data.")
                 return ImportResult(
                     source: .ndisItems,
                     successful: 0,
                     failed: 0,
                     messages: messages,
                     fileName: fileName
                 )
            }

            print("Successfully parsed \(parsedItems.count) items. Starting SwiftData import...")
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

    private static func processParsedItems(_ items: [NDISItemData], fileName: String, context: ModelContext, initialMessages: [String]) throws -> ImportResult {
        var successful = 0
        var failed = 0
        var messages = initialMessages
        let batchSize = 100
        let totalItems = items.count
        let deduplicatedItems = items
            .reduce(into: [String: NDISItemData]()) { uniqueItems, item in
                uniqueItems[versionDeduplicationKey(for: item)] = item
            }
            .values
            .sorted { versionSortingKey(for: $0) < versionSortingKey(for: $1) }
        let deduplicatedTotal = deduplicatedItems.count

        print("Starting batch processing for \(deduplicatedTotal) unique items (\(totalItems) total input rows)...")

        for i in stride(from: 0, to: deduplicatedTotal, by: batchSize) {
            let batchEnd = min(i + batchSize, deduplicatedTotal)
            let batchItems = Array(deduplicatedItems[i..<batchEnd])
            print("Processing batch \(i/batchSize + 1)/\( (deduplicatedTotal + batchSize - 1) / batchSize )... (\(batchItems.count) items)")

            for itemData in batchItems {
                let versionId = versionIdentifier(for: itemData)
                
                let itemNumber = itemData.itemNumber
                let itemName = itemData.name
                let fetchDescriptor = FetchDescriptor<NDISItem>(predicate: #Predicate<NDISItem> {
                    $0.itemNumber == itemNumber && $0.name == itemName && $0.versionIdentifier == versionId
                })
                
                let entity: NDISItem
                if let existingEntity = try? context.fetch(fetchDescriptor).first {
                    entity = existingEntity
                } else {
                    entity = NDISItem(id: UUID(), itemNumber: itemData.itemNumber, name: itemData.name, versionIdentifier: versionId)
                    context.insert(entity)
                }

                entity.itemNumber = itemData.itemNumber
                entity.name = itemData.name
                entity.itemDescription = itemData.description
                entity.unit = itemData.unit
                entity.category = itemData.category
                entity.registrationGroup = itemData.registrationGroup
                entity.features = itemData.features.joined(separator: ",")
                entity.status = "Active"
                entity.quoteRequired = itemData.quoteRequired
                entity.effectiveStartDate = itemData.effectiveStartDate
                entity.effectiveEndDate = itemData.effectiveEndDate

                if let pricesData = itemData.regionalPricesData {
                    for (region, amount) in pricesData {
                        let priceEntity = RegionalPrice(id: UUID())
                        priceEntity.regionIdentifier = region
                        priceEntity.amount = amount
                        priceEntity.ndisItem = entity
                        context.insert(priceEntity)
                    }
                }
                
                successful += 1
            }

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

            do {
                try context.save()
                print("Saved batch \(i/batchSize + 1)")
            } catch {
                failed += batchItems.count
                successful -= batchItems.count
                messages.append("Error saving batch \(i/batchSize + 1): \(error.localizedDescription)")
                print("Error saving batch \(i/batchSize + 1): \(error)")
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
        return ImportResult(
            source: .ndisItems,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }

    private static func versionDeduplicationKey(for item: NDISItemData) -> String {
        versionIdentifier(for: item)
    }
    
    private static func versionIdentifier(for item: NDISItemData) -> String {
        let startDate = item.effectiveStartDate ?? Date()
        return NDISVersioningService.createVersionIdentifier(
            itemNumber: item.itemNumber,
            itemName: item.name,
            startDate: startDate,
            endDate: item.effectiveEndDate
        )
    }
    
    private static func versionSortingKey(for item: NDISItemData) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let startDate = item.effectiveStartDate ?? Date()
        let startString = formatter.string(from: startDate)
        let endString = item.effectiveEndDate.flatMap { formatter.string(from: $0) } ?? "ongoing"
        return "\(item.itemNumber)|\(item.name)|\(startString)|\(endString)"
    }

    internal static func updateCurrentStatusForItem(itemNumber: String, itemName: String, context: ModelContext) throws {
        let allVersions = try NDISVersioningService.findAllVersions(itemNumber: itemNumber, itemName: itemName, in: context)
        guard !allVersions.isEmpty else { return }
        for version in allVersions {
            version.isCurrent = false
        }
    }
    
    internal static func parseBooleanField(_ value: String?) -> Bool {
        return value?.lowercased().trimmingCharacters(in: .whitespaces) == "y"
    }
    
    internal static func normalizeUnit(_ rawUnit: String?) -> String {
        guard let unit = rawUnit, !unit.isEmpty else { return "Each" }
        let lower = unit.lowercased()
        if lower.contains("hour") || lower == "h" || lower == "hr" {
            return "Hour"
        } else if lower.contains("day") || lower == "d" {
            return "Day"
        } else if lower.contains("week") || lower == "w" || lower == "wk" {
            return "Week"
        } else if lower.contains("year") || lower == "y" || lower == "yr" || lower == "annual" {
            return "Year"
        } else if lower.contains("km") || lower == "kilometre" || lower == "kilometer" {
            return "Km"
        } else {
            return "Each"
        }
    }
}
