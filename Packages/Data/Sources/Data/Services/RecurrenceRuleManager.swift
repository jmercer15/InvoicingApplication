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
public class RecurrenceRuleManager: @unchecked Sendable {
    public static let shared = RecurrenceRuleManager()
    
    private init() {}
    
    /// Serializes an EKRecurrenceRule to Data using JSON
    public func serialize(_ rule: EKRecurrenceRule) -> Data? {
        do {
            let jsonObject = serializeToJSON(rule)
            return try JSONSerialization.data(withJSONObject: jsonObject)
        } catch {
            print("❌ Failed to serialize recurrence rule: \(error)")
            return nil
        }
    }
    
    /// Serializes an EKRecurrenceRule to a JSON-compatible dictionary
    private func serializeToJSON(_ rule: EKRecurrenceRule) -> [String: Any] {
        var jsonObject: [String: Any] = [
            "frequency": rule.frequency.rawValue,
            "interval": rule.interval
        ]
        
        // Serialize optional arrays
        if let daysOfTheWeek = rule.daysOfTheWeek {
            jsonObject["daysOfTheWeek"] = daysOfTheWeek.map { day in
                [
                    "dayOfTheWeek": day.dayOfTheWeek.rawValue,
                    "weekNumber": day.weekNumber
                ]
            }
        }
        
        if let daysOfTheMonth = rule.daysOfTheMonth {
            jsonObject["daysOfTheMonth"] = daysOfTheMonth.map { $0.intValue }
        }
        
        if let monthsOfTheYear = rule.monthsOfTheYear {
            jsonObject["monthsOfTheYear"] = monthsOfTheYear.map { $0.intValue }
        }
        
        if let weeksOfTheYear = rule.weeksOfTheYear {
            jsonObject["weeksOfTheYear"] = weeksOfTheYear.map { $0.intValue }
        }
        
        if let daysOfTheYear = rule.daysOfTheYear {
            jsonObject["daysOfTheYear"] = daysOfTheYear.map { $0.intValue }
        }
        
        if let setPositions = rule.setPositions {
            jsonObject["setPositions"] = setPositions.map { $0.intValue }
        }
        
        // Serialize recurrence end
        if let recurrenceEnd = rule.recurrenceEnd {
            var endObject: [String: Any] = [:]
            if let endDate = recurrenceEnd.endDate {
                let formatter = ISO8601DateFormatter()
                endObject["endDate"] = formatter.string(from: endDate)
            }
            if recurrenceEnd.occurrenceCount > 0 {
                endObject["occurrenceCount"] = recurrenceEnd.occurrenceCount
            }
            jsonObject["recurrenceEnd"] = endObject
        }
        
        return jsonObject
    }
    
    /// Deserializes a recurrence rule from data using multiple formats
    public func deserialize(_ data: Data) -> EKRecurrenceRule? {
        // First, try to detect if this is JSON data (common case with existing data)
        if let jsonString = String(data: data, encoding: .utf8), jsonString.hasPrefix("{") {
            print("📝 Detected JSON format recurrence rule data - parsing JSON")
            return deserializeFromJSON(data)
        }
        
        // Try NSKeyedUnarchiver for legacy archived data (should be rare now)
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
    
    /// Deserializes a recurrence rule from JSON data
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
            let recurrenceEnd = parseRecurrenceEnd(
                from: jsonObject["recurrenceEnd"],
                legacyEndDate: jsonObject["endDate"],
                legacyEndCount: jsonObject["endCount"]
            )
            
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
        // Preferred format (RecurrenceRuleManager JSON): [{dayOfTheWeek, weekNumber}]
        if let daysArray = jsonValue as? [[String: Any]] {
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

        // Legacy format (EKRecurrenceRule+Extensions Codable): [Int]
        if let weekdayInts = jsonValue as? [Int] {
            let days = weekdayInts.compactMap { weekdayRaw -> EKRecurrenceDayOfWeek? in
                guard let weekday = EKWeekday(rawValue: weekdayRaw) else { return nil }
                return EKRecurrenceDayOfWeek(weekday, weekNumber: 0)
            }
            return days.isEmpty ? nil : days
        }

        return nil
    }
    
    /// Parses integer array from JSON
    private func parseIntArray(from jsonValue: Any?) -> [Int]? {
        guard let array = jsonValue as? [Int] else { return nil }
        return array.isEmpty ? nil : array
    }
    
    /// Parses recurrence end from JSON
    private func parseRecurrenceEnd(
        from jsonValue: Any?,
        legacyEndDate: Any? = nil,
        legacyEndCount: Any? = nil
    ) -> EKRecurrenceEnd? {
        if let endDict = jsonValue as? [String: Any] {
            if let endDateString = endDict["endDate"] as? String {
                let formatter = ISO8601DateFormatter()
                if let endDate = formatter.date(from: endDateString) {
                    return EKRecurrenceEnd(end: endDate)
                }
            }
            
            if let occurrenceCount = endDict["occurrenceCount"] as? Int {
                return EKRecurrenceEnd(occurrenceCount: occurrenceCount)
            }
        }

        // Legacy Codable fields from EKRecurrenceRule+Extensions
        if let endDateString = legacyEndDate as? String {
            let formatter = ISO8601DateFormatter()
            if let endDate = formatter.date(from: endDateString) {
                return EKRecurrenceEnd(end: endDate)
            }
        } else if let endDate = legacyEndDate as? Date {
            return EKRecurrenceEnd(end: endDate)
        }

        if let occurrenceCount = legacyEndCount as? Int {
            return EKRecurrenceEnd(occurrenceCount: occurrenceCount)
        }

        return nil
    }
    
    // deserializeWithError removed - error-throwing variant is never called; optional-returning version is used instead
}

// MARK: - Convenience Extensions

extension SessionEntity {
    /// Gets the EKRecurrenceRule for this session using the unified manager
    var recurrenceRule: EKRecurrenceRule? {
        guard let data = recurrenceRuleData else { return nil }
        return RecurrenceRuleManager.shared.deserialize(data)
    }
    
    /// Sets the EKRecurrenceRule for this session using the unified manager
    public func setRecurrenceRule(_ rule: EKRecurrenceRule?) {
        recurrenceRuleData = rule.flatMap { RecurrenceRuleManager.shared.serialize($0) }
    }
} 
