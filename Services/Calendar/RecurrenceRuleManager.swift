import Foundation
import EventKit
import SwiftData

/// Error types for recurrence rule operations
enum RecurrenceRuleError: Error {
    case serializationFailed
    case deserializationFailed
    case invalidData
}

/// Manages serialization and deserialization of EKRecurrenceRule objects
class RecurrenceRuleManager {
    static let shared = RecurrenceRuleManager()
    
    private init() {}
    
    /// Serializes an EKRecurrenceRule to Data using NSKeyedArchiver
    func serialize(_ rule: EKRecurrenceRule) -> Data? {
        do {
            return try NSKeyedArchiver.archivedData(withRootObject: rule, requiringSecureCoding: false)
        } catch {
            print("❌ Failed to serialize recurrence rule: \(error)")
            return nil
        }
    }
    
    /// Deserializes a recurrence rule from data using multiple formats
    func deserialize(_ data: Data) -> EKRecurrenceRule? {
        // First, try to detect if this is JSON data (common case with existing data)
        if let jsonString = String(data: data, encoding: .utf8), jsonString.hasPrefix("{") {
            print("📝 Detected JSON format recurrence rule data - parsing JSON")
            return deserializeFromJSON(data)
        }
        
        // Try NSKeyedUnarchiver for properly archived data
        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = false
            let rule = unarchiver.decodeObject(forKey: NSKeyedArchiveRootObjectKey) as? EKRecurrenceRule
            unarchiver.finishDecoding()
            return rule
        } catch {
            print("❌ Failed to deserialize recurrence rule with NSKeyedUnarchiver: \(error)")
            return nil
        }
    }
    
    /// Deserializes a recurrence rule from JSON data (legacy format)
    private func deserializeFromJSON(_ data: Data) -> EKRecurrenceRule? {
        do {
            guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("❌ Failed to parse JSON object from recurrence rule data")
                return nil
            }
            
            // Extract basic properties
            guard let frequencyRaw = jsonObject["frequency"] as? Int,
                  let frequency = EKRecurrenceFrequency(rawValue: frequencyRaw) else {
                print("❌ Invalid or missing frequency in recurrence rule JSON")
                return nil
            }
            
            let interval = jsonObject["interval"] as? Int ?? 1
            
            // Parse optional arrays
            let daysOfTheWeek = parseDaysOfTheWeek(from: jsonObject["daysOfTheWeek"])
            let daysOfTheMonth = parseIntArray(from: jsonObject["daysOfTheMonth"])?.map { NSNumber(value: $0) }
            let monthsOfTheYear = parseIntArray(from: jsonObject["monthsOfTheYear"])?.map { NSNumber(value: $0) }
            let weeksOfTheYear = parseIntArray(from: jsonObject["weeksOfTheYear"])?.map { NSNumber(value: $0) }
            let daysOfTheYear = parseIntArray(from: jsonObject["daysOfTheYear"])?.map { NSNumber(value: $0) }
            let setPositions = parseIntArray(from: jsonObject["setPositions"])?.map { NSNumber(value: $0) }
            
            // Parse recurrence end
            let recurrenceEnd = parseRecurrenceEnd(from: jsonObject["recurrenceEnd"])
            
            let rule = EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: interval,
                daysOfTheWeek: daysOfTheWeek,
                daysOfTheMonth: daysOfTheMonth,
                monthsOfTheYear: monthsOfTheYear,
                weeksOfTheYear: weeksOfTheYear,
                daysOfTheYear: daysOfTheYear,
                setPositions: setPositions,
                end: recurrenceEnd
            )
            
            print("✅ Successfully parsed JSON recurrence rule: \(frequency), interval: \(interval)")
            return rule
            
        } catch {
            print("❌ Failed to deserialize recurrence rule from JSON: \(error)")
            return nil
        }
    }
    
    /// Parses days of the week from JSON array
    private func parseDaysOfTheWeek(from jsonValue: Any?) -> [EKRecurrenceDayOfWeek]? {
        guard let daysArray = jsonValue as? [[String: Any]] else { return nil }
        
        let days = daysArray.compactMap { dayDict -> EKRecurrenceDayOfWeek? in
            guard let weekdayRaw = dayDict["dayOfTheWeek"] as? Int,
                  let weekday = EKWeekday(rawValue: weekdayRaw) else {
                return nil
            }
            
            let weekNumber = dayDict["weekNumber"] as? Int ?? 0
            return EKRecurrenceDayOfWeek(weekday, weekNumber: weekNumber)
        }
        
        return days.isEmpty ? nil : days
    }
    
    /// Parses integer array from JSON
    private func parseIntArray(from jsonValue: Any?) -> [Int]? {
        guard let array = jsonValue as? [Int] else { return nil }
        return array.isEmpty ? nil : array
    }
    
    /// Parses recurrence end from JSON
    private func parseRecurrenceEnd(from jsonValue: Any?) -> EKRecurrenceEnd? {
        guard let endDict = jsonValue as? [String: Any] else { return nil }
        
        if let endDateString = endDict["endDate"] as? String {
            let formatter = ISO8601DateFormatter()
            if let endDate = formatter.date(from: endDateString) {
                return EKRecurrenceEnd(end: endDate)
            }
        }
        
        if let occurrenceCount = endDict["occurrenceCount"] as? Int {
            return EKRecurrenceEnd(occurrenceCount: occurrenceCount)
        }
        
        return nil
    }
    
    /// Deserializes a recurrence rule from data with error handling
    func deserializeWithError(_ data: Data) throws -> EKRecurrenceRule {
        guard let rule = deserialize(data) else {
            throw RecurrenceRuleError.deserializationFailed
        }
        return rule
    }
}

// MARK: - Convenience Extensions

extension SessionEntity {
    /// Gets the EKRecurrenceRule for this session using the unified manager
    var recurrenceRule: EKRecurrenceRule? {
        guard let data = recurrenceRuleData else { return nil }
        return RecurrenceRuleManager.shared.deserialize(data)
    }
    
    /// Sets the EKRecurrenceRule for this session using the unified manager
    func setRecurrenceRule(_ rule: EKRecurrenceRule?) {
        recurrenceRuleData = rule.flatMap { RecurrenceRuleManager.shared.serialize($0) }
    }
} 