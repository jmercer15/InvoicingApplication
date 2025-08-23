import SwiftUI

/// Calendar view type options
enum CalendarViewType: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case agenda = "Agenda"
    case timeline = "Timeline"
    var id: String { self.rawValue }
} 