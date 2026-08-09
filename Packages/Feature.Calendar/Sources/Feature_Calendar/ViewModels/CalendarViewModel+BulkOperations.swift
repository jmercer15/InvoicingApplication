import Foundation
import Core

// MARK: - Bulk Operations
extension CalendarViewModel {
    func toggleBulkSelectionMode() {
        guard !isBulkOperationInFlight else { return }
        isBulkSelectionMode.toggle()
        if !isBulkSelectionMode {
            bulkSelectedSessionIDs.removeAll()
        }
    }
    
    func selectAllItems() {
        guard !isBulkOperationInFlight else { return }
        let allIDs = displayableItems.compactMap { item -> UUID? in
            item.underlyingSession?.id
        }
        bulkSelectedSessionIDs = Set(allIDs)
    }
    
    func deselectAllItems() {
        guard !isBulkOperationInFlight else { return }
        bulkSelectedSessionIDs.removeAll()
    }

    /// Sessions currently visible on the board (excludes EventKit events). Used by Select All chrome.
    var selectableSessionCount: Int {
        Set(displayableItems.compactMap { $0.underlyingSession?.id }).count
    }

    var areAllSelectableSessionsSelected: Bool {
        let count = selectableSessionCount
        return count > 0 && selectedItemIDs.count == count
    }
    
    func bulkChangeStatus(to newStatus: String) {
        guard !isBulkOperationInFlight else { return }
        let sessionsToUpdate = bulkSelectedSessionIDs
        guard !sessionsToUpdate.isEmpty else { return }
        let targetStatus = Core.SessionStatus(normalized: newStatus)
        let progressAction = CalendarBulkStatusProgressCopy.progressAction(for: targetStatus)
        let resultAction = CalendarBulkStatusProgressCopy.resultAction(for: targetStatus)
        bulkOperationFeedback = nil
        bulkOperationProgress = CalendarBulkOperationProgress(
            action: progressAction,
            completedCount: 0,
            totalCount: sessionsToUpdate.count
        )

        Task {
            var failureCount = 0
            var lockedCount = 0
            var completedTransitionIDs: [UUID] = []
            var skippedInvoiceIDs: [UUID] = []
            for (index, sessionID) in sessionsToUpdate.enumerated() {
                guard let session = resolveSession(for: sessionID) else {
                    failureCount += 1
                    bulkOperationProgress = CalendarBulkOperationProgress(
                        action: progressAction,
                        completedCount: index + 1,
                        totalCount: sessionsToUpdate.count
                    )
                    continue
                }
                // Mirror bulk delete: skip invoiced sessions and report separately.
                if session.invoice != nil {
                    lockedCount += 1
                    if let invoiceID = session.invoice?.id,
                       !skippedInvoiceIDs.contains(invoiceID) {
                        skippedInvoiceIDs.append(invoiceID)
                    }
                    bulkOperationProgress = CalendarBulkOperationProgress(
                        action: progressAction,
                        completedCount: index + 1,
                        totalCount: sessionsToUpdate.count
                    )
                    continue
                }
                let priorStatus = session.status
                do {
                    try await updateSessionStatus(sessionId: sessionID, statusToken: newStatus)
                    if let targetStatus,
                       CalendarSessionCompletionFeedback.shouldNudgeForBillingHub(
                           newStatus: targetStatus,
                           priorStatus: priorStatus
                       ) {
                        completedTransitionIDs.append(sessionID)
                    }
                } catch {
                    failureCount += 1
                }
                bulkOperationProgress = CalendarBulkOperationProgress(
                    action: progressAction,
                    completedCount: index + 1,
                    totalCount: sessionsToUpdate.count
                )
            }

            let succeededCount = sessionsToUpdate.count - lockedCount - failureCount
            let hasSkipsOrFailures = lockedCount > 0 || failureCount > 0
            bulkOperationProgress = nil
            isBulkSelectionMode = false
            bulkSelectedSessionIDs.removeAll()

            // All-success Completed → SessionCompletedNudgeBanner only (no stacked feedback).
            // Partial / non-Completed → feedback banner; attach prepare handoff when any completed.
            if hasSkipsOrFailures || completedTransitionIDs.isEmpty {
                bulkOperationFeedback = CalendarBulkOperationFeedback.result(
                    action: resultAction,
                    succeeded: succeededCount,
                    skipped: lockedCount,
                    failed: failureCount,
                    invoicedInvoiceIDs: skippedInvoiceIDs,
                    billingHubHandoffSessionIDs: hasSkipsOrFailures ? completedTransitionIDs : [],
                    offersBillingHubPrepareStep: hasSkipsOrFailures && !completedTransitionIDs.isEmpty
                )
            }
            if !completedTransitionIDs.isEmpty, !hasSkipsOrFailures {
                setBillingHubNudge(
                    message: CalendarSessionCompletionFeedback.billingHubNudgeMessage(
                        completedCount: completedTransitionIDs.count
                    ),
                    sessionIDs: completedTransitionIDs
                )
            }
            updateDisplayableItems()
        }
    }
    
    func toggleSelection(for sessionId: UUID) {
        guard !isBulkOperationInFlight else { return }
        if bulkSelectedSessionIDs.contains(sessionId) {
            bulkSelectedSessionIDs.remove(sessionId)
        } else {
            bulkSelectedSessionIDs.insert(sessionId)
        }
        updateDisplayableItems()
    }
    
    func isItemSelected(_ item: DisplayableCalendarItem) -> Bool {
        guard let session = item.underlyingSession else { return false }
        return bulkSelectedSessionIDs.contains(session.id)
    }
}
