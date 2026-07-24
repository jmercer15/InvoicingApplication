import Foundation

extension CalendarViewModel {
    
    // --- Calendar Visibility ---
    
    func initializeCalendarVisibility() {
        let calendars = eventKitService.getCalendars()
        let currentIds = Set(calendars.map { $0.calendarIdentifier })

        guard let savedIds = UserDefaults.standard.stringArray(forKey: "VisibleCalendars") else {
            // No preference saved — show all by default
            visibleCalendarIdentifiers = currentIds
            saveCalendarVisibility()
            return
        }

        let savedSet = Set(savedIds)

        // Keep only saved IDs that still exist in EventKit (drop stale ones)
        let reconciledVisible = savedSet.intersection(currentIds)

        // Any calendars EventKit knows about that weren't in the saved set
        // are new — show them by default so the user isn't surprised.
        let newCalendars = currentIds.subtracting(savedSet)

        if reconciledVisible.isEmpty && !currentIds.isEmpty {
            // All saved IDs were stale — fall back to showing everything
            print("[CalendarViewModel] All saved calendar IDs are stale (\(savedSet.count) saved, 0 matched \(currentIds.count) current). Resetting to show all.")
            visibleCalendarIdentifiers = currentIds
        } else {
            visibleCalendarIdentifiers = reconciledVisible.union(newCalendars)
            if !newCalendars.isEmpty {
                print("[CalendarViewModel] Auto-enabled \(newCalendars.count) new calendar(s).")
            }
        }

        saveCalendarVisibility()
    }
    
    func toggleCalendarVisibility(id: String) {
        if visibleCalendarIdentifiers.contains(id) {
            visibleCalendarIdentifiers.remove(id)
        } else {
            visibleCalendarIdentifiers.insert(id)
        }
        saveCalendarVisibility()
        updateDisplayableItems() // Refresh to hide/show events
    }
    
    func saveCalendarVisibility() {
        UserDefaults.standard.set(Array(visibleCalendarIdentifiers), forKey: "VisibleCalendars")
    }
}
