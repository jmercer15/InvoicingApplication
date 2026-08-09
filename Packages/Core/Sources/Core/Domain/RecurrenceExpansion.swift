import EventKit
import Foundation

public struct RecurrenceExpansion {
    public struct Instance {
        public let instanceStart: Date
        public let instanceEnd: Date
        
        public init(instanceStart: Date, instanceEnd: Date) {
            self.instanceStart = instanceStart
            self.instanceEnd = instanceEnd
        }
    }

    /// Expands a recurring session snapshot into all instances within the given date range.
    public static func expandInstances(
        for snapshot: SessionSnapshot,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        expandInstances(
            isAllDay: snapshot.isAllDay,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    /// Internal implementation that only needs `isAllDay`.
    private static func expandInstances(
        isAllDay: Bool,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        guard rangeStart < rangeEnd, masterEndTime >= masterStartTime else { return [] }
        let duration = masterEndTime.timeIntervalSince(masterStartTime)

        if #available(macOS 15.0, iOS 18.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, *),
           let foundationRule = makeFoundationRule(from: rule, calendar: Calendar.current) {
            let recurrenceRange = rangeStart..<rangeEnd
            let recurrenceSequence = foundationRule.recurrences(of: masterStartTime, in: recurrenceRange)

            return recurrenceSequence.compactMap { start in
                let end = start.addingTimeInterval(duration)
                guard overlaps(
                    instanceStart: start,
                    instanceEnd: end,
                    rangeStart: rangeStart,
                    rangeEnd: rangeEnd
                ) else {
                    return nil
                }
                return Instance(instanceStart: start, instanceEnd: end)
            }
        }

        return expandInstancesLegacy(
            isAllDay: isAllDay,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    internal static func overlaps(
        instanceStart: Date,
        instanceEnd: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> Bool {
        instanceStart < rangeEnd && instanceEnd > rangeStart
    }
}
