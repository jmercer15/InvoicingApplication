import SwiftUI
import EventKit

// MARK: - External Calendar Color Provider Protocol

/// Protocol for extracting color information from external calendar events
/// This abstraction allows for different implementations for various calendar systems
protocol ExternalCalendarColorProvider {
    /// Extracts color information from an EKEvent
    /// - Parameter event: The EKEvent to extract color from
    /// - Returns: The extracted color, or nil if no color information is available
    func color(for event: EKEvent) -> Color?
    
    // providerName property removed - protocol property is implemented but never accessed
}

// MARK: - Google Calendar Color Provider

/// Implementation for Google Calendar color extraction
/// Handles the specific format used by Google Calendar for color identification
struct GoogleCalendarColorProvider: ExternalCalendarColorProvider {
    // providerName removed - property is never accessed
    private static let colorIdRegex = try? NSRegularExpression(pattern: "\\[(\\d+)\\]", options: [])
    
    func color(for event: EKEvent) -> Color? {
        if let colorId = getGoogleEventColorId(event) {
            return GoogleCalendarColors.googleColorMap[colorId]
        }
        return nil
    }
    
    /// Extracts Google Calendar color ID from event title
    /// Uses regex pattern to find [colorId] format in the event title
    private func getGoogleEventColorId(_ event: EKEvent) -> String? {
        guard let title = event.title, let regex = Self.colorIdRegex else { return nil }
        
        let range = NSRange(location: 0, length: title.utf16.count)
        guard let match = regex.firstMatch(in: title, options: [], range: range) else {
            return nil
        }
        
        // Extract the color ID from the matched group
        let colorIdRange = match.range(at: 1)
        guard colorIdRange.location != NSNotFound else { return nil }
        
        let nsString = title as NSString
        return nsString.substring(with: colorIdRange)
    }
}

// MARK: - Outlook Calendar Color Provider

/// Implementation for Microsoft Outlook calendar color extraction
/// Placeholder for future Outlook integration
struct OutlookCalendarColorProvider: ExternalCalendarColorProvider {
    // providerName removed - property is never accessed
    
    func color(for event: EKEvent) -> Color? {
        // Outlook-specific color extraction logic
        // This would involve parsing Outlook's color metadata or using
        // the calendar's color property with Outlook-specific mapping
        
        // For now, fall back to the calendar's default color
        if let nsColor = event.calendar.color {
            return Color(nsColor)
        }
        return nil
    }
}

// MARK: - Apple Calendar Color Provider

/// Implementation for Apple Calendar color extraction
/// Uses the native calendar color property
struct AppleCalendarColorProvider: ExternalCalendarColorProvider {
    // providerName removed - property is never accessed
    
    func color(for event: EKEvent) -> Color? {
        if let nsColor = event.calendar.color {
            return Color(nsColor)
        }
        return nil
    }
}

// MARK: - Provider Factory

/// Factory for creating appropriate color providers based on calendar source
struct ExternalCalendarColorProviderFactory {
    
    /// Creates the appropriate color provider for a given calendar
    /// - Parameter calendar: The EKCalendar to determine the provider for
    /// - Returns: The appropriate color provider
    static func provider(for calendar: EKCalendar) -> ExternalCalendarColorProvider {
        // Determine provider based on calendar source
        switch calendar.source.sourceType {
        case .calDAV:
            // CalDAV could be Google Calendar, Outlook, or other services
            // For now, we'll use Google provider as it's most common
            return GoogleCalendarColorProvider()
            
        case .exchange:
            // Exchange is typically Outlook/Office 365
            return OutlookCalendarColorProvider()
            
        case .local, .mobileMe, .subscribed:
            // Local calendars, iCloud, and subscribed calendars
            return AppleCalendarColorProvider()
            
        case .birthdays:
            // Birthday calendars - use Apple provider
            return AppleCalendarColorProvider()
            
        @unknown default:
            // Fallback to Apple provider for unknown sources
            return AppleCalendarColorProvider()
        }
    }
}

