import Core
import EventKit
import Foundation
import os

extension RecurrenceService {
    /// Expands recurring sessions into individual instances for the specified date range.
    public func expandRecurringSession(
        _ session: Session,
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [RecurrenceExpansion.Instance] {
        RecurrenceExpansion.expandInstances(
            for: session,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }

    /// Expands multiple recurring sessions efficiently.
    public func expandRecurringSessions(
        _ sessions: [Session],
        rangeStart: Date,
        rangeEnd: Date
    ) -> [SessionRecurrenceData] {
        var expandedData: [SessionRecurrenceData] = []

        for session in sessions {
            guard let ruleData = session.recurrenceRuleData,
                  let rule = decodeRecurrenceRule(from: ruleData),
                  let startTime = session.startTime,
                  let endTime = session.endTime else {
                continue
            }

            let instances = expandRecurringSession(
                session,
                rule: rule,
                masterStartTime: startTime,
                masterEndTime: endTime,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            )

            expandedData.append(SessionRecurrenceData(
                masterSession: session,
                rule: rule,
                instances: instances
            ))

            Logger.calendar.debug("Expanded session '\(session.title)' into \(instances.count) instances")
        }

        return expandedData
    }
}

extension RecurrenceService {
    /// Data structure for expanded recurring session information.
    public struct SessionRecurrenceData {
        public let masterSession: Session
        public let rule: EKRecurrenceRule
        public let instances: [RecurrenceExpansion.Instance]

        public init(masterSession: Session, rule: EKRecurrenceRule, instances: [RecurrenceExpansion.Instance]) {
            self.masterSession = masterSession
            self.rule = rule
            self.instances = instances
        }
    }
}
