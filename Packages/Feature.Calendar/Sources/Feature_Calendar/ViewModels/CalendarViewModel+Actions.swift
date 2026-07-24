import Foundation
import Core
import SwiftData
import EventKit

extension CalendarViewModel {
    
    // --- Session Manipulation Methods (called from Views) ---
    
    /// Convert an EKEvent to a Session (triggers the event conversion sheet)
    func convertEventToSession(_ event: EKEvent) {
        selectedSessionInfo = nil
        eventToConvert = event
    }
    
    /// Duplicate a session
    func duplicateSession(_ session: Session) {
        Task {
            do {
                // Safely unwrap optional dates
                guard let startTime = session.startTime,
                      let endTime = session.endTime else {
                    operationErrorMessage = "Duplicate session failed: Session has no start or end time."
                    return
                }
                
                let newSession = Session(
                    id: UUID(),
                    title: session.title,
                    startTime: startTime.addingTimeInterval(3600),
                    endTime: endTime.addingTimeInterval(3600),
                    isAllDay: session.isAllDay,
                    location: session.location,
                    notes: session.notes,
                    status: session.status,
                    isTravel: session.isTravel,
                    groupID: session.groupID,
                    groupedPosition: session.groupedPosition,
                    travelDistanceKM: session.travelDistanceKM,
                    travelTimeMinutes: session.travelTimeMinutes,
                    recurrenceRuleData: session.recurrenceRuleData,
                    assignedServiceName: session.assignedServiceName,
                    assignedRate: session.assignedRate
                )
                newSession.client = session.client
                newSession.clientService = session.clientService
                newSession.address = session.address
                modelContext.insert(newSession)
                try modelContext.save()
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                reportOperationFailure("Duplicate session", error: error)
            }
        }
    }
    
    /// Reschedule a session to a new date/time
    func rescheduleSession(with sessionId: UUID, originalInstanceDate: Date?, to newStartDate: Date, isAllDay: Bool = false) {
        Task {
            do {
                guard let session = resolveSession(for: sessionId) else {
                    operationErrorMessage = "Reschedule session failed: Session could not be found."
                    return
                }
                
                // Safely unwrap optional dates
                guard let sessionStartTime = session.startTime,
                      let sessionEndTime = session.endTime else {
                    operationErrorMessage = "Reschedule session failed: Session has no start or end time."
                    return
                }
                
                // Calculate duration
                let duration = sessionEndTime.timeIntervalSince(sessionStartTime)
                let newEndDate = newStartDate.addingTimeInterval(duration)

                if session.recurrenceRuleData != nil,
                   let occurrenceDate = originalInstanceDate {
                    await MainActor.run {
                        self.pendingRecurringModification = (
                            session: session,
                            modification: RecurringModificationType.move(newStartTime: newStartDate),
                            originalInstanceDate: occurrenceDate
                        )
                        self.showingRecurringModificationDialog = true
                    }
                    return
                }

                session.startTime = newStartDate
                session.endTime = newEndDate
                session.isAllDay = isAllDay
                session.lastModifiedDate = Date()
                try modelContext.save()
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                reportOperationFailure("Reschedule session", error: error)
            }
        }
    }
    
    /// Resize a session from the calendar view (drag handle interaction)
    func resizeSession(with instanceId: UUID, originalInstanceDate: Date, edge: CalendarInteractionHandler.ResizeEdge, timeDelta: TimeInterval) {
        Task {
            let session = resolveSession(for: instanceId)
            guard let session else {
                operationErrorMessage = "Resize session failed: Session could not be found."
                return
            }

            // Determine new start/end times based on edge
            var newStartTime = session.startTime ?? originalInstanceDate
            var newEndTime = session.endTime ?? originalInstanceDate.addingTimeInterval(3600)
            
            if edge == .top {
                newStartTime = newStartTime.addingTimeInterval(timeDelta)
            } else {
                newEndTime = newEndTime.addingTimeInterval(timeDelta)
            }
            
            // Check validity
            if newEndTime <= newStartTime { return }

            if session.recurrenceRuleData != nil {
                await MainActor.run {
                    self.pendingRecurringModification = (
                        session: session,
                        modification: RecurringModificationType.resize(newStartTime: newStartTime, newEndTime: newEndTime),
                        originalInstanceDate: originalInstanceDate
                    )
                    self.showingRecurringModificationDialog = true
                }
                return
            }

            do {
                session.startTime = newStartTime
                session.endTime = newEndTime
                session.lastModifiedDate = Date()
                try modelContext.save()
                await MainActor.run {
                    updateDisplayableItems()
                }
            } catch {
                reportOperationFailure("Resize session", error: error)
            }
        }
    }

    /// Registry first (working set from projection), then **bounded** single-row fetch for ids outside the current window (e.g. Billing Hub → Calendar).
    func resolveSession(for id: UUID) -> Session? {
        if let cached = sessionRegistry[id] {
            return cached
        }
        if let existing = filteredSessions.first(where: { $0.id == id }) {
            sessionRegistry[id] = existing
            return existing
        }
        guard let fetched = try? sessionResolver.fetchSession(id: id) else { return nil }
        sessionRegistry[id] = fetched
        return fetched
    }
    
    public func openSession(sessionID: UUID) async {
        guard let session = resolveSession(for: sessionID) else { return }
        if let start = session.startTime {
            selectedDate = start
        }
        selectedSessionInfo = (
            session: session,
            instanceStart: session.startTime,
            instanceEnd: session.endTime
        )
    }

    func updateSessionStatus(sessionId: UUID, statusToken: String) async throws {
        guard let session = resolveSession(for: sessionId) else { return }
        if let status = Core.SessionStatus(normalized: statusToken) {
            session.status = SessionStatus(rawValue: status.rawValue)
        }
        try modelContext.save()
    }

    func deleteSession(sessionId: UUID) async throws {
        guard let session = resolveSession(for: sessionId) else { return }
        modelContext.delete(session)
        try modelContext.save()
    }

    func markSession(_ session: Session, as status: Core.SessionStatus) async {
        do {
            try await updateSessionStatus(sessionId: session.id, statusToken: status.token)
            updateDisplayableItems()
        } catch {
            reportOperationFailure("Update session status", error: error)
        }
    }

    func deleteSessionFromCalendar(sessionID: UUID) async {
        do {
            try await deleteSession(sessionId: sessionID)
            updateDisplayableItems()
        } catch {
            reportOperationFailure("Delete session", error: error)
        }
    }

    func reportOperationFailure(_ operation: String, error: any Error) {
        operationErrorMessage = "\(operation) failed: \(error.localizedDescription)"
    }
}
