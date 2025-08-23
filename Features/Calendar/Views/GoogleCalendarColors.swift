import SwiftUI
import EventKit

struct EKCalendarColor: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct GoogleCalendarColors {
    static let standard: [EKCalendarColor] = [
        EKCalendarColor(id: "1", name: "Lavender", color: Color(hex: "#7986CB")),
        EKCalendarColor(id: "2", name: "Sage", color: Color(hex: "#33B679")),
        EKCalendarColor(id: "3", name: "Grape", color: Color(hex: "#8E24AA")),
        EKCalendarColor(id: "4", name: "Flamingo", color: Color(hex: "#E67C73")),
        EKCalendarColor(id: "5", name: "Banana", color: Color(hex: "#F6BF26")),
        EKCalendarColor(id: "6", name: "Tangerine", color: Color(hex: "#F4511E")),
        EKCalendarColor(id: "7", name: "Peacock", color: Color(hex: "#039BE5")),
        EKCalendarColor(id: "8", name: "Graphite", color: Color(hex: "#616161")),
        EKCalendarColor(id: "9", name: "Blueberry", color: Color(hex: "#3F51B5")),
        EKCalendarColor(id: "10", name: "Basil", color: Color(hex: "#0B8043")),
        EKCalendarColor(id: "11", name: "Tomato", color: Color(hex: "#D50000")),
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
    static func extractEventColor(from event: EKEvent) -> Color? {
        if let colorId = getGoogleEventColorId(event) {
            return googleColorMap[colorId]
        }
        return nil
    }
} 