//
//  RecurrenceService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import EventKit
import Foundation
import os

/// Responsible for handling all recurrence-related logic
/// Extracted from CalendarViewModel for better separation of concerns and testability
public class RecurrenceService {
    private let recurrenceRuleManager: RecurrenceRuleManager

    public init(recurrenceRuleManager: RecurrenceRuleManager) {
        self.recurrenceRuleManager = recurrenceRuleManager
    }

    // MARK: - Recurrence Instance Expansion

    /// Expands recurring sessions into individual instances for the specified date range
    /// Overload for Session domain model
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

    /// Expands multiple recurring sessions efficiently
    /// Overload for Session domain models
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

    /// Expands recurring sessions represented as snapshots (no live `Session` models required).
    public func expandRecurringSnapshots(
        _ snapshots: [SessionSnapshot],
        rangeStart: Date,
        rangeEnd: Date
    ) -> [SessionRecurrenceSnapshotData] {
        var expandedData: [SessionRecurrenceSnapshotData] = []

        for snapshot in snapshots {
            guard let ruleData = snapshot.recurrenceRuleData,
                  let rule = recurrenceRuleManager.deserialize(ruleData),
                  let startTime = snapshot.startTime,
                  let endTime = snapshot.endTime else {
                continue
            }

            let instances = RecurrenceExpansion.expandInstances(
                for: snapshot,
                rule: rule,
                masterStartTime: startTime,
                masterEndTime: endTime,
                rangeStart: rangeStart,
                rangeEnd: rangeEnd
            )

            expandedData.append(SessionRecurrenceSnapshotData(
                masterSnapshot: snapshot,
                instances: instances
            ))

            Logger.calendar.debug("Expanded snapshot session '\(snapshot.title)' into \(instances.count) instances")
        }

        return expandedData
    }

    // MARK: - Recurrence Rule Utilities

    /// Decodes a recurrence rule from stored data
    public func decodeRecurrenceRule(from data: Data?) -> EKRecurrenceRule? {
        guard let data = data else { return nil }
        return recurrenceRuleManager.deserialize(data)
    }

    // MARK: - Helper Types

    /// Data structure for expanded recurring session information
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

    /// Expanded recurring session data using ``SessionSnapshot`` (safe for background expansion).
    public struct SessionRecurrenceSnapshotData {
        public let masterSnapshot: SessionSnapshot
        public let instances: [RecurrenceExpansion.Instance]

        public init(masterSnapshot: SessionSnapshot, instances: [RecurrenceExpansion.Instance]) {
            self.masterSnapshot = masterSnapshot
            self.instances = instances
        }
    }
}
