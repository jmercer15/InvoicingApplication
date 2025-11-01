import SwiftUI
import EventKit

public struct EKCalendarColor: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let color: Color
    
    public init(id: String, name: String, color: Color) {
        self.id = id
        self.name = name
        self.color = color
    }
}

public struct GoogleCalendarColors {
    public static let standard: [EKCalendarColor] = [
        EKCalendarColor(id: "1", name: "Lavender", color: Self.color(hex: 0x7986CB)),
        EKCalendarColor(id: "2", name: "Sage", color: Self.color(hex: 0x33B679)),
        EKCalendarColor(id: "3", name: "Grape", color: Self.color(hex: 0x8E24AA)),
        EKCalendarColor(id: "4", name: "Flamingo", color: Self.color(hex: 0xE67C73)),
        EKCalendarColor(id: "5", name: "Banana", color: Self.color(hex: 0xF6BF26)),
        EKCalendarColor(id: "6", name: "Tangerine", color: Self.color(hex: 0xF4511E)),
        EKCalendarColor(id: "7", name: "Peacock", color: Self.color(hex: 0x0B8043)),
        EKCalendarColor(id: "8", name: "Graphite", color: Self.color(hex: 0x616161)),
        EKCalendarColor(id: "9", name: "Blueberry", color: Self.color(hex: 0x039BE5)),
        EKCalendarColor(id: "10", name: "Basil", color: Self.color(hex: 0x7CB342)),
        EKCalendarColor(id: "11", name: "Tomato", color: Self.color(hex: 0xD50000)),
    ]
    public static let googleColorMap: [String: Color] = Dictionary(uniqueKeysWithValues: standard.map { ($0.id, $0.color) })
    
    public static func getGoogleEventColorId(_ event: EKEvent) -> String? {
        // If using extended properties, parse here. For now, check title for [colorId]
        if let title = event.title, let match = title.range(of: "\\[(\\d+)\\]", options: .regularExpression) {
            return String(title[match].dropFirst().dropLast())
        }
        // Add more robust extraction if needed
        return nil
    }
    
    public static func extractEventColor(from event: EKEvent) -> Color? {
        if let colorId = getGoogleEventColorId(event) {
            return googleColorMap[colorId]
        }
        return nil
    }
}

private extension GoogleCalendarColors {
    static func color(hex: UInt32) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1.0)
    }
}
