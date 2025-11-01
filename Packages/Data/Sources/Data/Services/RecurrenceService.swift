//
//  RecurrenceService.swift
//  InvoicingApplication
//
//  Created by AI Assistant for Refactoring Initiative
//
import Foundation
import EventKit
import Core

/// Responsible for handling all recurrence-related logic
/// Extracted from CalendarViewModel for better separation of concerns and testability
public class RecurrenceService {
    
    public init() {}
    
    // MARK: - Recurrence Instance Expansion
    
    /// Expands recurring sessions into individual instances for the specified date range
    /// This is one of the most complex pieces of business logic in the application
    public func expandRecurringSession(
        _ session: SessionEntity, 
        rule: EKRecurrenceRule,
        masterStartTime: Date,
        masterEndTime: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> [RecurrenceExpansion.Instance] {
        
        return RecurrenceExpansion.expandInstances(
            for: session,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }
    
    /// Expands multiple recurring sessions efficiently
    public func expandRecurringSessions(
        _ sessions: [SessionEntity],
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
            
            print("[RecurrenceService] Expanded session '\(session.title)' into \(instances.count) instances")
        }
        
        return expandedData
    }
    
    // MARK: - Recurrence Rule Utilities
    
    /// Decodes a recurrence rule from stored data
    public func decodeRecurrenceRule(from data: Data?) -> EKRecurrenceRule? {
        guard let data = data else { return nil }
        return RecurrenceRuleManager.shared.deserialize(data)
    }
    
    // MARK: - Helper Types
    
    /// Data structure for expanded recurring session information
    public struct SessionRecurrenceData {
        public let masterSession: SessionEntity
        public let rule: EKRecurrenceRule
        public let instances: [RecurrenceExpansion.Instance]
        
        public init(masterSession: SessionEntity, rule: EKRecurrenceRule, instances: [RecurrenceExpansion.Instance]) {
            self.masterSession = masterSession
            self.rule = rule
            self.instances = instances
        }
    }
}
