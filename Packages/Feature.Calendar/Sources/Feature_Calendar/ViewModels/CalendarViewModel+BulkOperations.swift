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
            for sessionID in sessionsToUpdate {
                do {
                    if let session = try await unitOfWork.sessions.fetch(byId: sessionID) {
                        var updatedSession = session
                        // Since Session is a struct (Core.Session), we modify a copy and update
                        // But wait, Session struct doesn't have mutable implementation logic here,
                        // we need to call update on repo with modified session.
                        // However, Session properties are 'let'. We cannot modify 'status'.
                        // We must use 'updateStatus' method on repository if available.
                        try await unitOfWork.sessions.updateStatus(id: session.id, status: newStatus)
                    }
                } catch {
                    print("[CalendarViewModel] Failed to update status for session \(sessionID): \(error)")
                }
            }
            // ...
            
            do {
                try await unitOfWork.saveChanges()
            } catch {
                print("[CalendarViewModel] Failed to save bulk status changes: \(error)")
            }
            
            await MainActor.run {
                self.isBulkSelectionMode = false
                self.bulkSelectedSessionIDs.removeAll()
                // Force refresh
                self.updateDisplayableItems()
            }
        }
    }
}
