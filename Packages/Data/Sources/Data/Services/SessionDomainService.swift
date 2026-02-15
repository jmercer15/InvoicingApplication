//
//  SessionDomainService.swift
//  Data
//
//  Domain service for session business operations
//

import Foundation
import SwiftData
import Core

/// Implementation of SessionDomainServiceProtocol.
/// Encapsulates complex session operations including EventKit sync.
@MainActor
public final class SessionDomainService: SessionDomainServiceProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    
    private let unitOfWork: UnitOfWorkService
    private let syncService: SyncService?
    
    // MARK: - Initialization
    
    public init(unitOfWork: UnitOfWorkService, syncService: SyncService? = nil) {
        self.unitOfWork = unitOfWork
        self.syncService = syncService
    }
    
    // MARK: - SessionDomainServiceProtocol
    
    public func createSession(_ session: Session, syncToCalendar: Bool) async throws -> Session {
        // Create the session
        let createdSession = try await unitOfWork.sessions.create(session)
        try await unitOfWork.saveChanges()
        
        // Sync to calendar if enabled
        if syncToCalendar, let syncService = syncService, syncService.syncEnabled {
            try await syncService.sync(session: createdSession)
        }
        
        return createdSession
    }
    
    public func updateSession(_ session: Session, syncToCalendar: Bool) async throws -> Session {
        let updatedSession = try await unitOfWork.sessions.update(session)
        try await unitOfWork.saveChanges()
        
        // Update in calendar if enabled
        if syncToCalendar, let syncService = syncService, syncService.syncEnabled {
            try await syncService.update(session: updatedSession)
        }
        
        return updatedSession
    }
    
    public func deleteSession(_ sessionId: UUID, syncToCalendar: Bool) async throws {
        // Get session first for sync identifier
        let session = try await unitOfWork.sessions.fetch(byId: sessionId)
        
        // Delete from database
        try await unitOfWork.sessions.delete(id: sessionId)
        try await unitOfWork.saveChanges()
        
        // Delete from calendar if enabled
        if syncToCalendar,
           let syncService = syncService,
           syncService.syncEnabled,
           let syncId = session?.eventIdentifier {
            try await syncService.delete(syncIdentifier: syncId)
        }
    }
    
    public func handleExternalCalendarChanges() async {
        guard let syncService = syncService else { return }
        
        do {
            try await syncService.handleExternalChanges()
        } catch {
            // Log error but don't throw - external changes are best-effort
            print("Failed to handle external calendar changes: \(error)")
        }
    }
    
    public func expandRecurrence(for session: Session, until date: Date) async throws -> [Session] {
        guard let masterStart = session.startTime,
              let masterEnd = session.endTime,
              date > masterStart else {
            return []
        }

        guard let recurrenceData = session.recurrenceRuleData,
              let recurrenceRule = RecurrenceRuleManager.shared.deserialize(recurrenceData) else {
            // Non-recurring sessions return themselves if the master start is in range.
            return masterStart <= date ? [session] : []
        }

        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: masterStart)
        let rangeEnd = date

        let instances = RecurrenceExpansion.expandInstances(
            for: session,
            rule: recurrenceRule,
            masterStartTime: masterStart,
            masterEndTime: masterEnd,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd
        )

        return instances.map { instance in
            Session(
                id: session.id,
                title: session.title,
                startTime: instance.instanceStart,
                endTime: instance.instanceEnd,
                isAllDay: session.isAllDay,
                location: session.location,
                notes: session.notes,
                status: session.status,
                isTravel: session.isTravel,
                isDetached: session.isDetached,
                occurrenceDate: instance.instanceStart,
                clientId: session.clientId,
                clientServiceId: session.clientServiceId,
                addressId: session.addressId,
                groupID: session.groupID,
                groupedPosition: session.groupedPosition,
                eventIdentifier: session.eventIdentifier,
                eventExternalIdentifier: session.eventExternalIdentifier,
                calendarIdentifier: session.calendarIdentifier,
                lastModifiedDate: session.lastModifiedDate,
                lastSyncTag: session.lastSyncTag,
                recurrenceRuleData: session.recurrenceRuleData,
                attendeesCount: session.attendeesCount,
                derivedFromEKEventID: session.derivedFromEKEventID,
                googleColorId: session.googleColorId,
                sessionLatitude: session.sessionLatitude,
                sessionLongitude: session.sessionLongitude,
                assignedServiceName: session.assignedServiceName,
                assignedRate: session.assignedRate,
                travelDistanceKM: session.travelDistanceKM,
                travelTimeMinutes: session.travelTimeMinutes,
                travelTollsAmount: session.travelTollsAmount
            )
        }
    }
    
    public func syncAllWithCalendar() async throws {
        guard let syncService = syncService, syncService.syncEnabled else { return }
        
        let allSessions = try await unitOfWork.sessions.fetchAll()
        for session in allSessions {
            try await syncService.sync(session: session)
        }
    }
}
