import Foundation
import SwiftUI

@MainActor
final class CalendarFilterState: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedClientFilterIDs: Set<UUID> = []
    @Published var showCancelledSessions: Bool = false
    @Published var filterStatuses: Set<String> = []

    var selectedStatusFilter: String? {
        get {
            if filterStatuses.isEmpty { return nil }
            if filterStatuses.count == 1 { return filterStatuses.first }
            return nil
        }
        set {
            if let newValue = newValue {
                filterStatuses = [newValue]
            } else {
                filterStatuses.removeAll()
            }
        }
    }

    var selectedClientFilter: UUID? {
        get {
            if selectedClientFilterIDs.isEmpty { return nil }
            if selectedClientFilterIDs.count == 1 { return selectedClientFilterIDs.first }
            return nil
        }
        set {
            if let newValue = newValue {
                selectedClientFilterIDs = [newValue]
            } else {
                selectedClientFilterIDs.removeAll()
            }
        }
    }
}


