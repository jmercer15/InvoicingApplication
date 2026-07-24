import Foundation

// MARK: - Bulk Operations
extension CalendarViewModel {
    func toggleBulkSelectionMode() {
        isBulkSelectionMode.toggle()
        if !isBulkSelectionMode {
            bulkSelectedSessionIDs.removeAll()
        }
    }
    
    func selectAllItems() {
        let allIDs = displayableItems.compactMap { item -> UUID? in
            if case .session(let session) = item {
                return session.id
            }
            return nil
        }
        bulkSelectedSessionIDs = Set(allIDs)
    }
    
    func deselectAllItems() {
        bulkSelectedSessionIDs.removeAll()
    }
    
    func bulkChangeStatus(to newStatus: String) {
        let sessionsToUpdate = bulkSelectedSessionIDs
        guard !sessionsToUpdate.isEmpty else { return }
        
        Task {
            var failureCount = 0
            for sessionID in sessionsToUpdate {
                do {
                    try await updateSessionStatus(sessionId: sessionID, statusToken: newStatus)
                } catch {
                    failureCount += 1
                }
            }
            
            await MainActor.run {
                self.isBulkSelectionMode = false
                self.bulkSelectedSessionIDs.removeAll()
                if failureCount > 0 {
                    self.operationErrorMessage = "Bulk status update failed for \(failureCount) session(s)."
                }
                // Force refresh
                self.updateDisplayableItems()
            }
        }
    }
    
    func toggleSelection(for sessionId: UUID) {
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
