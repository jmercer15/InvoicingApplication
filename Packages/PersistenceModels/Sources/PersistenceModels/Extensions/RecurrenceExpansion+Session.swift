import Core
import EventKit
import Foundation

extension RecurrenceExpansion {
    /// Expands a recurring session into all instances within the given date range.
    public static func expandInstances(
        for templateSession: Session,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [Instance] {
        expandInstances(
            for: SessionSnapshot(templateSession),
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }
}
