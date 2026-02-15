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
    
    // Legacy SessionEntity overload removed. Use Session domain model.
    
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
        
        return RecurrenceExpansion.expandInstances(
            for: session,
            rule: rule,
            masterStartTime: masterStartTime,
            masterEndTime: masterEndTime,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )
    }
    
    // Legacy SessionEntity overload removed.

    
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
