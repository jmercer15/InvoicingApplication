import SwiftUI
import Core
import EventKit
import Foundation
import SwiftData
import SharedUI

// MARK: - DisplayableCalendarItem Enum Definition

/// Main-actor display value. Cases intentionally retain context-bound `Session` and EventKit objects.
/// Do not pass instances across actor boundaries; use UUIDs or snapshots for background work.
enum DisplayableCalendarItem: Identifiable {
    case session(Session)
    case event(EKEvent)
    case recurringSessionInstance(template: Session, instanceStartDate: Date, instanceEndDate: Date, instanceIsAllDay: Bool, originalStartDate: Date?, originalEndDate: Date?)
    case eventSegment(originalEvent: EKEvent, segmentStartDate: Date, segmentEndDate: Date, segmentIsAllDay: Bool, originalStartDate: Date?, originalEndDate: Date?)

    // --- Identifiable Conformance ---
    var id: String {
        switch self {
        case .session(let session):
            return session.id.uuidString
        case .event(let event):
            let base = event.eventIdentifier ?? "unsaved_event"
            let startAnchor = event.startDate.timeIntervalSinceReferenceDate
            return "\(base)_\(startAnchor)"
        case .recurringSessionInstance(let template, let instanceStartDate, _, _, _, _):
            return "\(template.id.uuidString)_\(instanceStartDate.timeIntervalSinceReferenceDate)"
        case .eventSegment(let originalEvent, let segmentStartDate, _, _, _, _):
            // Create a unique, stable ID from the original event and the segment's start time.
            return "\(originalEvent.eventIdentifier ?? "unsaved_event")_\(segmentStartDate.timeIntervalSinceReferenceDate)"
        }
    }

    // --- Common Data Properties ---
    var startDate: Date? {
        switch self {
        case .session(let session): return session.startTime
        case .event(let event): return event.startDate
        case .recurringSessionInstance(_, let instanceStartDate, _, _, _, _): return instanceStartDate
        case .eventSegment(_, let segmentStartDate, _, _, _, _): return segmentStartDate
        }
    }

    var endDate: Date? {
        switch self {
        case .session(let session): return session.endTime
        case .event(let event): return event.endDate
        case .recurringSessionInstance(_, _, let instanceEndDate, _, _, _): return instanceEndDate
        case .eventSegment(_, _, let segmentEndDate, _, _, _): return segmentEndDate
        }
    }

    var title: String {
         switch self {
         case .session(let session): return session.title
         case .event(let event): return event.title ?? "Calendar Event"
         case .recurringSessionInstance(let template, _, _, _, _, _): return template.title
         case .eventSegment(let originalEvent, _, _, _, _, _): return originalEvent.title ?? "Calendar Event"
         }
     }

    var isAllDay: Bool {
         switch self {
         case .session(let session): return session.isAllDay
         case .event(let event): return event.isAllDay
         case .recurringSessionInstance(_, _, _, let instanceIsAllDay, _, _): return instanceIsAllDay
         case .eventSegment(_, _, _, let segmentIsAllDay, _, _): return segmentIsAllDay
         }
     }

    // --- Display & Styling ---
    var displayColor: Color {

        switch self {
        case .session(let session), .recurringSessionInstance(let session, _, _, _, _, _):
            if session.isTravel { return Color("Travel", bundle: .sharedUI) } // Blue for travel sessions

            if let colorId = session.googleColorId,
               let googleColor = GoogleCalendarColors.googleColorMap[colorId] {
                return googleColor
            }
        
            // Parse status string to SessionStatus enum equivalent
            let statusToken = Core.SessionStatus(normalized: session.status?.rawValue ?? "")?.token
            let isCompleted = statusToken == Core.SessionStatus.completed.token
            let isCancelled = statusToken == Core.SessionStatus.cancelled.token
            let currentEndDate = self.endDate ?? Date()
            let isPast = currentEndDate < Date()
            let isConfirmed = statusToken == Core.SessionStatus.scheduled.token
            let isPending = statusToken == Core.SessionStatus.scheduled.token

            // Use clientId from domain model instead of client relationship
            if let clientId = session.clientId {
                return ColorSystem.Client.color(for: clientId)
            } else if isCompleted { return ColorSystem.Session.completed }
            else if isCancelled { return ColorSystem.Session.cancelled }
            else if isPast { return ColorSystem.Session.past }
            else if isConfirmed { return ColorSystem.Session.confirmed }
            else if isPending { return ColorSystem.Session.pending }
            else { return ColorSystem.Session.defaultAccent }

        case .event(let event), .eventSegment(let event, _, _, _, _, _):
             // Use the new color provider system
             let provider = ExternalCalendarColorProviderFactory.provider(for: event.calendar)
             if let color = provider.color(for: event) {
                 return color
             }
             
             // Fallback to calendar's default color
             if let nsColor = event.calendar.color {
                  return Color(nsColor)
              } else {
                  return ColorSystem.Session.past
              }
        }
    }
    
    var isSession: Bool {
        switch self {
        case .session, .recurringSessionInstance: return true
        case .event: return false
        case .eventSegment: return false // Segments of events are not travel sessions themselves
        }
    }

    var isEvent: Bool {
        switch self {
        case .event, .eventSegment: return true
        default: return false
        }
      }

    // --- Layout Calculation Properties ---
    var startHour: CGFloat {
        guard let startTime = self.startDate else { return 0 }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startTime)
        let minute = calendar.component(.minute, from: startTime)
        return CGFloat(hour) + CGFloat(minute) / 60.0
    }

    var durationHours: CGFloat {
        guard let startTime = self.startDate, let endTime = self.endDate, endTime > startTime else {
            return self.isSession ? 0.5 : 0.25
        }
        let calendar = Calendar(identifier: .gregorian)
        let comps = calendar.dateComponents([.hour, .minute, .second], from: startTime, to: endTime)
        let hours = CGFloat(comps.hour ?? 0)
        let minutes = CGFloat(comps.minute ?? 0) / 60.0
        let seconds = CGFloat(comps.second ?? 0) / 3600.0
        let calculatedDuration = hours + minutes + seconds
        let minDuration: CGFloat = self.isSession ? 0.5 : 0.25
        return max(minDuration, calculatedDuration)
    }
    
    // --- Access underlying object if needed ---
    var underlyingSession: Session? {
        switch self {
        case .session(let session): return session
        case .recurringSessionInstance(let template, _, _, _, _, _): return template
        case .event: return nil
        case .eventSegment: return nil
        }
    }
    
    var underlyingEvent: EKEvent? {
        switch self {
        case .event(let event): return event
        case .eventSegment(let originalEvent, _, _, _, _, _): return originalEvent
        default: return nil
        }
    }

    // --- Original Dates ---
    var originalStartDate: Date? {
        switch self {
        case .session(let session):
            return session.startTime
        case .event(let event):
            return event.startDate
        case .recurringSessionInstance(_, _, _, _, let origStart, _):
            return origStart
        case .eventSegment(_, _, _, _, let origStart, _):
            return origStart
        }
    }

    var originalEndDate: Date? {
        switch self {
        case .session(let session):
            return session.endTime
        case .event(let event):
            return event.endDate
        case .recurringSessionInstance(_, _, _, _, _, let origEnd):
            return origEnd
        case .eventSegment(_, _, _, _, _, let origEnd):
            return origEnd
        }
    }

    var actualStartDate: Date? {
        originalStartDate ?? startDate
    }

    var actualEndDate: Date? {
        originalEndDate ?? endDate
    }
}

// MARK: - Color relative luminance & contrast foreground
import AppKit

public extension Color {
    var relativeLuminance: Double {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return 0.5 }
        
        func relativeComponent(_ val: CGFloat) -> Double {
            let v = Double(val)
            if v <= 0.04045 {
                return v / 12.92
            } else {
                return pow((v + 0.055) / 1.055, 2.4)
            }
        }
        
        let r = relativeComponent(rgbColor.redComponent)
        let g = relativeComponent(rgbColor.greenComponent)
        let b = relativeComponent(rgbColor.blueComponent)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    var contrastForeground: Color {
        relativeLuminance >= 0.45 ? .black : .white
    }

    func blended(with backgroundColor: Color, opacity: Double) -> Color {
        let nsForeground = NSColor(self)
        let nsBackground = NSColor(backgroundColor)
        guard let fg = nsForeground.usingColorSpace(.sRGB),
              let bg = nsBackground.usingColorSpace(.sRGB) else { return self }
        
        let r = fg.redComponent * opacity + bg.redComponent * (1.0 - opacity)
        let g = fg.greenComponent * opacity + bg.greenComponent * (1.0 - opacity)
        let b = fg.blueComponent * opacity + bg.blueComponent * (1.0 - opacity)
        let a = fg.alphaComponent * opacity + bg.alphaComponent * (1.0 - opacity)
        
        return ColorSystem.srgbColor(red: r, green: g, blue: b, alpha: a)
    }

    func adjusted(brightness: CGFloat) -> Color {
        let nsColor = NSColor(self)
        guard let rgbColor = nsColor.usingColorSpace(.sRGB) else { return self }
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var b: CGFloat = 0
        var alpha: CGFloat = 0
        rgbColor.getHue(&hue, saturation: &saturation, brightness: &b, alpha: &alpha)
        return Color(nsColor: NSColor(hue: hue, saturation: saturation, brightness: max(0, min(1, b * brightness)), alpha: alpha))
    }
}
