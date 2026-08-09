import Foundation
import Core
import PersistenceModels
import SwiftData
import EventKit

/// Confirmation prompt shown before an edit that touches a session already linked to an invoice.
/// Editing such a session will not retroactively update the invoice, so the user must opt in.
struct InvoicedSessionAction: Identifiable {
    let id = UUID()
    /// Allows Calendar's soft-lock dialog to route to the existing invoice instead of forcing an
    /// edit-or-cancel decision with no reconciliation path.
    let invoiceID: UUID?
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let perform: () async -> Void
}

extension CalendarViewModel: CalendarSessionActionCoordinatorHost {}

extension CalendarViewModel {
    
    // --- Session Manipulation Methods (called from Views) ---

    func requireInvoiceConfirmation(
        for session: Session,
        message: String,
        confirmTitle: String = "Continue",
        isDestructive: Bool = false,
        perform: @escaping () async -> Void
    ) -> Bool {
        sessionActionCoordinator.requireInvoiceConfirmation(
            for: session,
            message: message,
            confirmTitle: confirmTitle,
            isDestructive: isDestructive,
            perform: perform
        )
    }

    func confirmPendingInvoicedSessionAction() {
        sessionActionCoordinator.confirmPendingInvoicedSessionAction()
    }

    func cancelPendingInvoicedSessionAction() {
        sessionActionCoordinator.cancelPendingInvoicedSessionAction()
    }
    
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
                    groupID: nil,
                    groupedPosition: 0,
                    travelDistanceKM: session.travelDistanceKM,
                    travelTimeMinutes: session.travelTimeMinutes,
                    recurrenceRuleData: session.recurrenceRuleData,
                    assignedServiceName: session.assignedServiceName,
                    assignedRate: session.assignedRate
                )
                newSession.client = session.client
                newSession.clientService = session.clientService
                newSession.address = session.address
                newSession.sessionLatitude = session.sessionLatitude
                newSession.sessionLongitude = session.sessionLongitude
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
                let presentScopePicker = {
                    self.pendingRecurringModification = (
                        session: session,
                        modification: RecurringModificationType.move(newStartTime: newStartDate),
                        originalInstanceDate: occurrenceDate
                    )
                    self.showingRecurringModificationDialog = true
                }
                // Soft-lock before scope picker so invoiced recurring moves require opt-in first.
                let locked = requireInvoiceConfirmation(
                    for: session,
                    message: "This session is linked to an invoice. Choosing This Occurrence creates a new uninvoiced occurrence; the invoice is unchanged. Continue?",
                    confirmTitle: "Move Anyway"
                ) {
                    presentScopePicker()
                }
                if locked { return }
                presentScopePicker()
                return
            }

            let locked = requireInvoiceConfirmation(
                for: session,
                message: "This session is linked to an invoice. Moving it will not update the invoice. Continue?",
                confirmTitle: "Move Anyway"
            ) {
                await self.applyReschedule(session: session, newStartDate: newStartDate, newEndDate: newEndDate, isAllDay: isAllDay)
            }
            if locked { return }

            await applyReschedule(session: session, newStartDate: newStartDate, newEndDate: newEndDate, isAllDay: isAllDay)
        }
    }

    private func applyReschedule(session: Session, newStartDate: Date, newEndDate: Date, isAllDay: Bool) async {
        do {
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
                let presentScopePicker = {
                    self.pendingRecurringModification = (
                        session: session,
                        modification: RecurringModificationType.resize(
                            newStartTime: newStartTime,
                            newEndTime: newEndTime
                        ),
                        originalInstanceDate: originalInstanceDate
                    )
                    self.showingRecurringModificationDialog = true
                }
                // Soft-lock before scope picker so invoiced recurring resizes require opt-in first.
                let locked = requireInvoiceConfirmation(
                    for: session,
                    message: "This session is linked to an invoice. Choosing This Occurrence creates a new uninvoiced occurrence; the invoice is unchanged. Continue?",
                    confirmTitle: "Resize Anyway"
                ) {
                    presentScopePicker()
                }
                if locked { return }
                presentScopePicker()
                return
            }

            let locked = requireInvoiceConfirmation(
                for: session,
                message: "This session is linked to an invoice. Resizing it will not update the invoice. Continue?",
                confirmTitle: "Resize Anyway"
            ) {
                await self.applyResize(session: session, newStartTime: newStartTime, newEndTime: newEndTime)
            }
            if locked { return }

            await applyResize(session: session, newStartTime: newStartTime, newEndTime: newEndTime)
        }
    }

    private func applyResize(session: Session, newStartTime: Date, newEndTime: Date) async {
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
        session.lastModifiedDate = Date()
        try modelContext.save()
    }

    func deleteSession(sessionId: UUID, force: Bool = false) async throws {
        guard let session = resolveSession(for: sessionId) else { return }
        if !force, session.invoice != nil {
            throw CalendarActionError.sessionInvoiced
        }
        modelContext.delete(session)
        try modelContext.save()
    }

    func markSession(_ session: Session, as status: Core.SessionStatus) async {
        let locked = requireInvoiceConfirmation(
            for: session,
            message: "This session is linked to an invoice. Changing its status will not update the invoice. Continue?",
            confirmTitle: "Change Status Anyway"
        ) { [weak self] in
            await self?.performMarkSession(session, as: status)
        }
        if locked { return }
        await performMarkSession(session, as: status)
    }

    private func performMarkSession(_ session: Session, as status: Core.SessionStatus) async {
        let priorStatus = session.status
        do {
            try await updateSessionStatus(sessionId: session.id, statusToken: status.token)
            updateDisplayableItems()
            if CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
                newStatus: status,
                priorStatus: priorStatus
            ) {
                setBillingHubNudge(
                    message: CalendarSessionCompletionFeedback.billingHubNudgeMessage,
                    sessionIDs: [session.id]
                )
            }
        } catch {
            reportOperationFailure("Update session status", error: error)
        }
    }

    func deleteSessionFromCalendar(sessionID: UUID) async {
        guard let session = resolveSession(for: sessionID) else {
            operationErrorMessage = "Delete session failed: Session could not be found."
            return
        }
        let locked = requireInvoiceConfirmation(
            for: session,
            message: "This session is linked to an invoice. Deleting it will not remove or update the invoice. Continue?",
            confirmTitle: "Delete Anyway",
            isDestructive: true
        ) { [weak self] in
            await self?.performDeleteSessionFromCalendar(sessionID: sessionID)
        }
        if locked { return }
        await performDeleteSessionFromCalendar(sessionID: sessionID)
    }

    private func performDeleteSessionFromCalendar(sessionID: UUID) async {
        do {
            try await deleteSession(sessionId: sessionID, force: true)
            updateDisplayableItems()
        } catch {
            reportOperationFailure("Delete session", error: error)
        }
    }

    func reportOperationFailure(_ operation: String, error: any Error) {
        operationErrorMessage = "\(operation) failed: \(error.localizedDescription)"
    }
}

enum CalendarActionError: Error, LocalizedError {
    case sessionInvoiced

    var errorDescription: String? {
        switch self {
        case .sessionInvoiced:
            return "This session is linked to an invoice."
        }
    }
}
