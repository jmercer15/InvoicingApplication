import SwiftUI

/// Calendar view type options
public enum CalendarViewType: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    public var id: String { self.rawValue }
} 