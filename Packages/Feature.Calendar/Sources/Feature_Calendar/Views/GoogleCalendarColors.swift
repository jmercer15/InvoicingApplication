import SwiftUI
import EventKit
import SharedUI

struct EKCalendarColor: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct GoogleCalendarColors {
    static let standard: [EKCalendarColor] = [
        EKCalendarColor(id: "1", name: "Lavender", color: Color("Lavender", bundle: .sharedUI)),
        EKCalendarColor(id: "2", name: "Sage", color: Color("Sage", bundle: .sharedUI)),
        EKCalendarColor(id: "3", name: "Grape", color: Color("Grape", bundle: .sharedUI)),
        EKCalendarColor(id: "4", name: "Flamingo", color: Color("Flamingo", bundle: .sharedUI)),
        EKCalendarColor(id: "5", name: "Banana", color: Color("Banana", bundle: .sharedUI)),
        EKCalendarColor(id: "6", name: "Tangerine", color: Color("Tangerine", bundle: .sharedUI)),
        EKCalendarColor(id: "7", name: "Peacock", color: Color("Peacock", bundle: .sharedUI)),
        EKCalendarColor(id: "8", name: "Graphite", color: Color("Graphite", bundle: .sharedUI)),
        EKCalendarColor(id: "9", name: "Blueberry", color: Color("Blueberry", bundle: .sharedUI)),
        EKCalendarColor(id: "10", name: "Basil", color: Color("Basil", bundle: .sharedUI)),
        EKCalendarColor(id: "11", name: "Tomato", color: Color("Tomato", bundle: .sharedUI)),
    ]
    static let googleColorMap: [String: Color] = Dictionary(uniqueKeysWithValues: standard.map { ($0.id, $0.color) })
    static func getGoogleEventColorId(_ event: EKEvent) -> String? {
        // If using extended properties, parse here. For now, check title for [colorId]
        if let title = event.title, let match = title.range(of: "\\[(\\d+)\\]", options: .regularExpression) {
            return String(title[match].dropFirst().dropLast())
        }
        // Add more robust extraction if needed
        return nil
    }
} 
