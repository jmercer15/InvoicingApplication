import Foundation
import EventKit

/// Extension to provide Data serialization for EKRecurrenceRule
extension EKRecurrenceRule {
    /// Serialize the recurrence rule to Data for storage in domain models
    public var data: Data? {
        let codable = CodableRecurrenceRule(rule: self)
        return try? JSONEncoder().encode(codable)
    }
    
    /// Initialize from serialized Data
    static func fromData(_ data: Data) -> EKRecurrenceRule? {
        guard let codable = try? JSONDecoder().decode(CodableRecurrenceRule.self, from: data) else {
            return nil
        }
        return codable.toEKRecurrenceRule()
    }
}

/// Helper struct for Codable support
private struct CodableRecurrenceRule: Codable {
    let frequency: Int
    let interval: Int
    let endDate: Date?
    let endCount: Int?
    let daysOfTheWeek: [Int]? // Raw values for EKWeekday
    let daysOfTheMonth: [Int]?
    let monthsOfTheYear: [Int]?
    let weeksOfTheYear: [Int]?
    let daysOfTheYear: [Int]?
    let setPositions: [Int]?
    
    init(rule: EKRecurrenceRule) {
        self.frequency = rule.frequency.rawValue
        self.interval = rule.interval
        self.endDate = rule.recurrenceEnd?.endDate
        self.endCount = rule.recurrenceEnd?.occurrenceCount
        
        // Simplified mapping for common recurrence patterns (Add more if needed)
        self.daysOfTheWeek = rule.daysOfTheWeek?.map { $0.dayOfTheWeek.rawValue }
        self.daysOfTheMonth = rule.daysOfTheMonth?.map { $0.intValue }
        self.monthsOfTheYear = rule.monthsOfTheYear?.map { $0.intValue }
        self.weeksOfTheYear = rule.weeksOfTheYear?.map { $0.intValue }
        self.daysOfTheYear = rule.daysOfTheYear?.map { $0.intValue }
        self.setPositions = rule.setPositions?.map { $0.intValue }
    }
    
    func toEKRecurrenceRule() -> EKRecurrenceRule {
        let freq = EKRecurrenceFrequency(rawValue: self.frequency) ?? .daily
        
        var end: EKRecurrenceEnd? = nil
        if let endDate = self.endDate {
            end = EKRecurrenceEnd(end: endDate)
        } else if let endCount = self.endCount {
            end = EKRecurrenceEnd(occurrenceCount: endCount)
        }
        
        let days: [EKRecurrenceDayOfWeek]? = self.daysOfTheWeek?.compactMap {
             guard let weekday = EKWeekday(rawValue: $0) else { return nil }
             return EKRecurrenceDayOfWeek(weekday)
        }
        
        return EKRecurrenceRule(
            recurrenceWith: freq,
            interval: self.interval,
            daysOfTheWeek: days,
            daysOfTheMonth: self.daysOfTheMonth?.map { NSNumber(value: $0) },
            monthsOfTheYear: self.monthsOfTheYear?.map { NSNumber(value: $0) },
            weeksOfTheYear: self.weeksOfTheYear?.map { NSNumber(value: $0) },
            daysOfTheYear: self.daysOfTheYear?.map { NSNumber(value: $0) },
            setPositions: self.setPositions?.map { NSNumber(value: $0) },
            end: end
        )
    }
}
