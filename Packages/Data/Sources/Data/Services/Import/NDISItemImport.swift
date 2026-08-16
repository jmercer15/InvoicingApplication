import Foundation
import SwiftData
import Core
import PersistenceModels
import os

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
        _ = try context.fetchCount(FetchDescriptor<NDISItem>())

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

            Logger.data.debug("NDIS import parsed \(parsedItems.count, privacy: .public) items")
            return try processParsedItems(parsedItems, fileName: fileName, context: context, initialMessages: messages)

        } catch {
            Logger.data.error("NDIS import parsing failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
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

        Logger.data.debug("NDIS import processing \(deduplicatedTotal, privacy: .public) unique items from \(totalItems, privacy: .public) rows")

        for i in stride(from: 0, to: deduplicatedTotal, by: batchSize) {
            let batchEnd = min(i + batchSize, deduplicatedTotal)
            let batchItems = Array(deduplicatedItems[i..<batchEnd])

            for itemData in batchItems {
                let versionId = versionIdentifier(for: itemData)
                
                let itemNumber = itemData.itemNumber
                let itemName = itemData.name
                let entity: NDISItem
                if let existingEntity = try resolveExistingItem(
                    itemNumber: itemNumber,
                    itemName: itemName,
                    versionIdentifier: versionId,
                    effectiveStartDate: itemData.effectiveStartDate,
                    effectiveEndDate: itemData.effectiveEndDate,
                    context: context
                ) {
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
                    replaceRegionalPrices(pricesData, for: entity, context: context)
                }
                
                successful += 1
            }

            let uniqueCompositeKeys = Set(batchItems.map { "\($0.itemNumber)|\($0.name)" })
            for compositeKey in uniqueCompositeKeys {
                let components = compositeKey.split(separator: "|")
                if components.count == 2 {
                    let itemNumber = String(components[0])
                    let itemName = String(components[1])
                    try updateCurrentStatusForItem(itemNumber: itemNumber, itemName: itemName, context: context)
                }
            }

            do {
                try context.save()
            } catch {
                failed += batchItems.count
                successful -= batchItems.count
                messages.append("Error saving batch \(i/batchSize + 1): \(error.localizedDescription)")
                Logger.data.error("NDIS import save failed: \(error.localizedDescription, privacy: .private(mask: .hash))")
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

        return ImportResult(
            source: .ndisItems,
            successful: successful,
            failed: failed,
            messages: messages,
            fileName: fileName
        )
    }

    static func replaceRegionalPrices(
        _ pricesData: [String: Double],
        for item: NDISItem,
        context: ModelContext
    ) {
        for existingPrice in item.regionalPrices ?? [] {
            context.delete(existingPrice)
        }
        item.regionalPrices = []

        for (region, amount) in pricesData.sorted(by: { $0.key < $1.key }) {
            let price = RegionalPrice(id: UUID())
            price.regionIdentifier = region
            price.amount = MoneyDecimalImport.decimal(from: amount)
            price.ndisItem = item
            context.insert(price)
        }
    }

    static func resolveExistingItem(
        itemNumber: String,
        itemName: String,
        versionIdentifier: String,
        effectiveStartDate: Date?,
        effectiveEndDate: Date?,
        context: ModelContext
    ) throws -> NDISItem? {
        let exactDescriptor = FetchDescriptor<NDISItem>(predicate: #Predicate<NDISItem> {
            $0.itemNumber == itemNumber && $0.name == itemName && $0.versionIdentifier == versionIdentifier
        })
        if let existing = try context.fetch(exactDescriptor).first {
            return existing
        }

        // Pre-stable-hash stores have a process-random version identifier. Resolve those rows
        // by their immutable version dates, then rewrite to the stable identifier on import.
        let legacyDescriptor = FetchDescriptor<NDISItem>(predicate: #Predicate<NDISItem> {
            $0.itemNumber == itemNumber && $0.name == itemName
        })
        return try context.fetch(legacyDescriptor).first {
            $0.effectiveStartDate == effectiveStartDate && $0.effectiveEndDate == effectiveEndDate
        }
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
        let startDate = item.effectiveStartDate ?? Date()
        let startString = ImportCalendarDate.string(from: startDate)
        let endString = item.effectiveEndDate.map(ImportCalendarDate.string(from:)) ?? "ongoing"
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
