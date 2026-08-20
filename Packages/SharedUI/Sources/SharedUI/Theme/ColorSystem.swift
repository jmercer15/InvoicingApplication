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
        public static let blue = Color(nsColor: NSColor.systemBlue)
        public static let darkBlue = Color(nsColor: NSColor.systemBlue).opacity(0.8)
        public static let lightBlue = Color(nsColor: NSColor.systemBlue).opacity(0.6)
    }
    
    /// Secondary brand colors - using system colors for better adaptation
    public struct Secondary {
        public static let green = Color(nsColor: NSColor.systemGreen)
        public static let orange = Color(nsColor: NSColor.systemOrange)
        public static let purple = Color(nsColor: NSColor.systemPurple)
    }
    
    // MARK: - Navigation Colors

    /// Tint colors for hierarchical navigation (breadcrumbs, tree nodes).
    public struct Navigation {
        public static let categoryTint = Color(nsColor: NSColor.systemPurple)
        public static let groupTint = Color(nsColor: NSColor.systemIndigo)
    }

    // MARK: - Session Colors

    /// Status colors for calendar session display.
    public struct Session {
        public static let completed = Color(nsColor: NSColor.systemGreen)
        public static let cancelled = Color(nsColor: NSColor.systemRed)
        public static let past = Color(nsColor: NSColor.systemGray)
        public static let confirmed = Color(nsColor: NSColor.systemBlue)
        public static let pending = Color(nsColor: NSColor.systemOrange)
        public static let therapist = Color(nsColor: NSColor.systemPurple)
        public static let defaultAccent = Color(nsColor: NSColor.systemBlue)
    }

    // MARK: - Invoice Colors

    /// Status colors for invoice workflow states.
    public struct Invoice {
        public static func statusColor(for status: String) -> Color {
            switch status {
            case AppConstants.invoiceStatusReviewDraft: return Color.secondary
            case AppConstants.invoiceStatusReadyToSend: return Status.highlight
            case AppConstants.invoiceStatusPending: return Primary.blue
            case AppConstants.invoiceStatusReceived: return Status.success
            case AppConstants.invoiceStatusOverdue: return Status.error
            case AppConstants.invoiceStatusCancelled: return Status.warning
            case AppConstants.invoiceStatusVoided: return Secondary.purple
            default: return Primary.blue
            }
        }
    }

    // MARK: - Relationship Colors

    /// Entity-type tint colors for relationship navigation cards.
    public struct Relationships {
        public static let clientTint = Color(nsColor: NSColor.systemBlue)
        public static let payeeTint = Color(nsColor: NSColor.systemOrange)
        public static let planManagerTint = Color(nsColor: NSColor.systemGreen)
        public static let unknownTint = Color(nsColor: NSColor.systemGray)

        public static func tint(forEntityType type: String) -> Color {
            switch type {
            case "client": return clientTint
            case "payee": return payeeTint
            case "planManager": return planManagerTint
            default: return unknownTint
            }
        }

        public static func tint(forNodeID id: String) -> Color {
            if id.contains("client") { return clientTint }
            if id.contains("payee") { return payeeTint }
            if id.contains("plan") { return planManagerTint }
            return unknownTint
        }
    }

    // MARK: - Status Colors
    
    /// Status indicator colors - using system colors for better adaptation
    public struct Status {
        public static let success = Color(nsColor: NSColor.systemGreen)
        public static let warning = Color(nsColor: NSColor.systemOrange)
        public static let error = Color(nsColor: NSColor.systemRed)
        public static let info = Color(nsColor: NSColor.systemBlue)
        public static let highlight = Color(nsColor: NSColor.systemYellow)
        public static let new = Color(nsColor: NSColor.systemMint)
        public static let inactive = Color(nsColor: NSColor.systemGray)
        public static let groupChange = Color(nsColor: NSColor.systemTeal)
    }
    
    // MARK: - Neutral Colors
    
    /// Neutral grayscale colors - using system colors for better adaptation
    public struct Neutral {
        public static let white = Color(nsColor: NSColor.windowBackgroundColor)
        public static let black = Color(nsColor: NSColor.labelColor)
        public static let gray50 = Color(nsColor: NSColor.quinarySystemFill)
        public static let gray100 = Color(nsColor: NSColor.quaternarySystemFill)
        public static let gray200 = Color(nsColor: NSColor.tertiarySystemFill)
        public static let gray300 = Color(nsColor: NSColor.secondarySystemFill)
        public static let gray400 = Color(nsColor: NSColor.systemFill)
        public static let gray500 = Color(nsColor: NSColor.systemGray)
        public static let gray600 = Color(nsColor: NSColor.systemGray).opacity(0.8)
        public static let gray700 = Color(nsColor: NSColor.systemGray).opacity(0.6)
        public static let gray800 = Color(nsColor: NSColor.systemGray).opacity(0.4)
        public static let gray900 = Color(nsColor: NSColor.systemGray).opacity(0.2)
    }
    
    // MARK: - Client Colors
    
    /// Predefined colors for client identification - using system colors
    public struct Client {
        public static let color1 = Color(nsColor: NSColor.systemBlue)
        public static let color2 = Color(nsColor: NSColor.systemGreen)
        public static let color3 = Color(nsColor: NSColor.systemOrange)
        public static let color4 = Color(nsColor: NSColor.systemPurple)
        public static let color5 = Color(nsColor: NSColor.systemRed)
        public static let color6 = Color(nsColor: NSColor.systemCyan)
        public static let color7 = Color(nsColor: NSColor.systemPink)
        public static let color8 = Color(nsColor: NSColor.systemYellow)
        
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
        /// - Parameter clientID: The client's UUID
        /// - Returns: A consistent color for the client
        public static func color(for clientID: UUID) -> Color {
            let hash = clientID.hashValue
            return color(at: hash)
        }
    }
    
    // MARK: - Payee Colors
    
    /// Predefined colors for payee identification - using system colors
    public struct Payee {
        public static let color1 = Color(nsColor: NSColor.systemBlue).opacity(0.8)
        public static let color2 = Color(nsColor: NSColor.systemGreen).opacity(0.8)
        public static let color3 = Color(nsColor: NSColor.systemOrange).opacity(0.8)
        public static let color4 = Color(nsColor: NSColor.systemPurple).opacity(0.8)
        public static let color5 = Color(nsColor: NSColor.systemRed).opacity(0.8)
        public static let color6 = Color(nsColor: NSColor.systemCyan).opacity(0.8)
        public static let color7 = Color(nsColor: NSColor.systemPink).opacity(0.8)
        public static let color8 = Color(nsColor: NSColor.systemYellow).opacity(0.8)
        
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
        /// - Parameter payeeID: The payee's UUID
        /// - Returns: A consistent color for the payee
        public static func color(for payeeID: UUID) -> Color {
            let hash = payeeID.hashValue
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

    /// Build a color from normalised sRGB components (e.g. blended calendar/event colours).
    public static func srgbColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> Color {
        Color(nsColor: NSColor(red: red, green: green, blue: blue, alpha: alpha))
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
