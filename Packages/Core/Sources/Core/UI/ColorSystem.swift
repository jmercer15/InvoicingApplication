import SwiftUI
import Foundation

/// Approved color system to replace hex colors
/// 
/// This system provides a consistent, accessible, and maintainable color palette
/// that follows modern design principles and accessibility guidelines.
public struct ColorSystem {
    
    // MARK: - Primary Colors
    
    /// Primary brand colors - using system colors for better adaptation
    public struct Primary {
        public static let blue = Color(NSColor.systemBlue)
        public static let darkBlue = Color(NSColor.systemBlue).opacity(0.8)
        public static let lightBlue = Color(NSColor.systemBlue).opacity(0.6)
    }
    
    /// Secondary brand colors - using system colors for better adaptation
    public struct Secondary {
        public static let green = Color(NSColor.systemGreen)
        public static let orange = Color(NSColor.systemOrange)
        public static let purple = Color(NSColor.systemPurple)
    }
    
    // MARK: - Status Colors
    
    /// Status indicator colors - using system colors for better adaptation
    public struct Status {
        public static let success = Color(NSColor.systemGreen)
        public static let warning = Color(NSColor.systemOrange)
        public static let error = Color(NSColor.systemRed)
        public static let info = Color(NSColor.systemBlue)
    }
    
    // MARK: - Neutral Colors
    
    /// Neutral grayscale colors - using system colors for better adaptation
    public struct Neutral {
        public static let white = Color(NSColor.windowBackgroundColor)
        public static let black = Color(NSColor.labelColor)
        public static let gray50 = Color(NSColor.quinarySystemFill)
        public static let gray100 = Color(NSColor.quaternarySystemFill)
        public static let gray200 = Color(NSColor.tertiarySystemFill)
        public static let gray300 = Color(NSColor.secondarySystemFill)
        public static let gray400 = Color(NSColor.systemFill)
        public static let gray500 = Color(NSColor.systemGray)
        public static let gray600 = Color(NSColor.systemGray).opacity(0.8)
        public static let gray700 = Color(NSColor.systemGray).opacity(0.6)
        public static let gray800 = Color(NSColor.systemGray).opacity(0.4)
        public static let gray900 = Color(NSColor.systemGray).opacity(0.2)
    }
    
    // MARK: - Client Colors
    
    /// Predefined colors for client identification - using system colors
    public struct Client {
        public static let color1 = Color(NSColor.systemBlue)
        public static let color2 = Color(NSColor.systemGreen)
        public static let color3 = Color(NSColor.systemOrange)
        public static let color4 = Color(NSColor.systemPurple)
        public static let color5 = Color(NSColor.systemRed)
        public static let color6 = Color(NSColor.systemCyan)
        public static let color7 = Color(NSColor.systemPink)
        public static let color8 = Color(NSColor.systemYellow)
        
        /// Array of all available client colors
        public static let allColors: [Color] = [
            color1, color2, color3, color4, color5, color6, color7, color8
        ]
        
        /// Get a color by index (for consistent client coloring)
        /// - Parameter index: The index of the color (0-7)
        /// - Returns: The color at the specified index
        public static func color(at index: Int) -> Color {
            let safeIndex = abs(index) % allColors.count
            return allColors[safeIndex]
        }
        
        /// Get a color based on client ID (deterministic coloring)
        /// - Parameter clientId: The client's UUID
        /// - Returns: A consistent color for the client
        public static func color(for clientId: UUID) -> Color {
            let hash = clientId.hashValue
            return color(at: hash)
        }
    }
    
    // MARK: - Payee Colors
    
    /// Predefined colors for payee identification - using system colors
    public struct Payee {
        public static let color1 = Color(NSColor.systemBlue).opacity(0.8)
        public static let color2 = Color(NSColor.systemGreen).opacity(0.8)
        public static let color3 = Color(NSColor.systemOrange).opacity(0.8)
        public static let color4 = Color(NSColor.systemPurple).opacity(0.8)
        public static let color5 = Color(NSColor.systemRed).opacity(0.8)
        public static let color6 = Color(NSColor.systemCyan).opacity(0.8)
        public static let color7 = Color(NSColor.systemPink).opacity(0.8)
        public static let color8 = Color(NSColor.systemYellow).opacity(0.8)
        
        /// Array of all available payee colors
        public static let allColors: [Color] = [
            color1, color2, color3, color4, color5, color6, color7, color8
        ]
        
        /// Get a color by index (for consistent payee coloring)
        /// - Parameter index: The index of the color (0-7)
        /// - Returns: The color at the specified index
        public static func color(at index: Int) -> Color {
            let safeIndex = abs(index) % allColors.count
            return allColors[safeIndex]
        }
        
        /// Get a color based on payee ID (deterministic coloring)
        /// - Parameter payeeId: The payee's UUID
        /// - Returns: A consistent color for the payee
        public static func color(for payeeId: UUID) -> Color {
            let hash = payeeId.hashValue
            return color(at: hash)
        }
    }
    
    // MARK: - Calendar Colors
    
    /// Colors for calendar events and scheduling
    public struct Calendar {
        public static let session = Color(red: 0.2, green: 0.4, blue: 0.8)   // Blue
        public static let travel = Color(red: 1.0, green: 0.5, blue: 0.0)    // Orange
        public static let invoice = Color(red: 0.2, green: 0.7, blue: 0.3)   // Green
        public static let reminder = Color(red: 0.9, green: 0.2, blue: 0.2)  // Red
        public static let holiday = Color(red: 0.5, green: 0.2, blue: 0.7)   // Purple
    }
    
    // MARK: - Accessibility Colors
    
    /// High contrast colors for accessibility
    public struct Accessibility {
        public static let highContrastBlue = Color(red: 0.0, green: 0.0, blue: 1.0)    // Pure Blue
        public static let highContrastGreen = Color(red: 0.0, green: 0.5, blue: 0.0)   // Pure Green
        public static let highContrastRed = Color(red: 1.0, green: 0.0, blue: 0.0)     // Pure Red
        public static let highContrastYellow = Color(red: 1.0, green: 1.0, blue: 0.0)  // Pure Yellow
    }
    
    // MARK: - Utility Methods
    
    /// Convert a legacy hex color to the closest color in the new system
    /// - Parameter hexColor: The legacy hex color string
    /// - Returns: The closest color from the new system
    public static func migrateFromHex(_ hexColor: String) -> Color {
        // Map common hex colors to new system colors
        switch hexColor.uppercased() {
        case "#3F51B5", "#2196F3", "#1976D2":
            return Primary.blue
        case "#4CAF50", "#8BC34A", "#689F38":
            return Secondary.green
        case "#FF9800", "#FF5722", "#F57C00":
            return Secondary.orange
        case "#9C27B0", "#673AB7":
            return Secondary.purple
        case "#F44336", "#E91E63", "#D32F2F":
            return Status.error
        case "#FFC107", "#FFEB3B", "#FFA000":
            return Status.warning
        case "#00BCD4", "#009688", "#4DD0E1":
            return Client.color6
        case "#795548", "#607D8B", "#455A64":
            return Neutral.gray600
        default:
            // Default to primary blue for unknown colors
            return Primary.blue
        }
    }
    
    /// Get a random color from the client color palette
    /// - Returns: A random color suitable for client identification
    public static func randomClientColor() -> Color {
        return Client.allColors.randomElement() ?? Client.color1
    }
    
    /// Get a random color from the payee color palette
    /// - Returns: A random color suitable for payee identification
    public static func randomPayeeColor() -> Color {
        return Payee.allColors.randomElement() ?? Payee.color1
    }
}

// MARK: - Color Extensions

extension Color {
    /// Create a color from a legacy hex string (for migration purposes)
    /// - Parameter hex: The hex color string
    /// - Returns: A SwiftUI Color object
    public init(legacyHex hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Color System Documentation

/// Documentation for the new color system
public struct ColorSystemDocumentation {
    
    /// Guidelines for using the color system
    public static let usageGuidelines = [
        "Use Primary colors for main brand elements and important actions",
        "Use Secondary colors for supporting elements and secondary actions",
        "Use Status colors for feedback and state indication",
        "Use Neutral colors for text, backgrounds, and borders",
        "Use Client/Payee colors for identification and categorization",
        "Use Calendar colors for scheduling and time-based elements",
        "Use Accessibility colors when high contrast is required",
        "Avoid using hex colors directly - use the color system instead",
        "Test colors for accessibility compliance (WCAG 2.1 AA)",
        "Maintain consistency across the application"
    ]
    
    /// Migration guide from hex colors
    public static let migrationGuide = [
        "Replace all hex color strings with ColorSystem colors",
        "Use ColorSystem.migrateFromHex() for automatic migration",
        "Update UI components to use the new color system",
        "Test visual consistency after migration",
        "Remove all colorHex properties from domain models",
        "Update ViewModels to use the new color system",
        "Ensure accessibility compliance with new colors"
    ]
}
