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
