import Foundation
import SwiftUI
import AppKit

public extension Color {
    /// The standard background color for selected list items.
    static let listSelectionBackground = Color("Primary", bundle: .sharedUI).opacity(0.3)
    /// The standard background color for hovered list items.
    static let listHoverBackground = Color("Surface", bundle: .sharedUI).opacity(0.4)
    
    // MARK: - Status Colors
    
    /// Returns the SwiftUI color for a given status string
    static func statusColor(for status: String) -> Color {
        Color(nsColor: status.statusColor)
    }
    
    /// Active status color (green)
    static let statusActive = Color("Active", bundle: .sharedUI)
    
    /// Inactive status color (orange)
    static let statusInactive = Color("Inactive", bundle: .sharedUI)
    
    /// Archived status color (gray)
    static let statusArchived = Color("Archived", bundle: .sharedUI)
    
    /// Draft/Planned status color (blue)
    static let statusDraft = Color("Draft", bundle: .sharedUI)
    
    /// Cancelled/Error status color (red)
    static let statusCancelled = Color("Cancelled", bundle: .sharedUI)
    
    // MARK: - Entity Colors
    
    /// Default color for client entities
    static let clientDefault = Color("Client", bundle: .sharedUI)
    
    /// Default color for payee entities
    static let payeeDefault = Color("Payee", bundle: .sharedUI)
    
    /// Default color for plan manager entities
    static let planManagerDefault = Color("PlanManager", bundle: .sharedUI)
    
    /// Default color for service entities
    static let serviceDefault = Color("Service", bundle: .sharedUI)
    
    /// Default color for invoice entities
    static let invoiceDefault = Color("Invoice", bundle: .sharedUI)
    
    // MARK: - UI Component Colors
    
    /// Background color for cards
    static let cardBackground = Color("Background", bundle: .sharedUI)
    
    /// Border color for cards
    static let cardBorder = Color("Border", bundle: .sharedUI)
    
    /// Shadow color for cards
    static let cardShadow = Color("Shadow", bundle: .sharedUI)
    
    /// Background color for details
    static let detailBackground = Color("Background", bundle: .sharedUI)
    
    // MARK: - Enhanced Status Styles
    
    /// Returns an enhanced status background gradient for a status
    static func statusGradient(for status: String) -> LinearGradient {
        switch status.lowercased() {
        case "active", "paid", "completed":
            return LinearGradient(
                gradient: Gradient(colors: [Color("Green20", bundle: .sharedUI), Color("Green20", bundle: .sharedUI).opacity(0.25)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case "inactive", "outstanding", "issued":
            return LinearGradient(
                gradient: Gradient(colors: [Color("Orange20", bundle: .sharedUI), Color("Orange20", bundle: .sharedUI).opacity(0.25)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case "archived":
            return LinearGradient(
                gradient: Gradient(colors: [Color("Gray20", bundle: .sharedUI), Color("Gray10", bundle: .sharedUI)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case "draft", "planned":
            return LinearGradient(
                gradient: Gradient(colors: [Color("Blue70", bundle: .sharedUI), Color("Blue70", bundle: .sharedUI).opacity(0.25)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case "cancelled", "error", "overdue", "no show":
            return LinearGradient(
                gradient: Gradient(colors: [Color("Red70", bundle: .sharedUI), Color("Red70", bundle: .sharedUI).opacity(0.25)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                gradient: Gradient(colors: [Color("Gray20", bundle: .sharedUI), Color("Gray10", bundle: .sharedUI)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    /// Background color for category/feature tags
    static func tagBackground(for category: String) -> Color {
        switch category.lowercased() {
        case "client":
            return clientDefault.opacity(0.1)
        case "payee", "provider":
            return payeeDefault.opacity(0.1)
        case "service", "support":
            return serviceDefault.opacity(0.1)
        case "invoice", "payment":
            return invoiceDefault.opacity(0.1)
        default:
            return Color("Primary", bundle: .sharedUI).opacity(0.1)
        }
    }
    
    /// Gradient background for category/feature tags
    static func tagGradient(for category: String) -> LinearGradient {
        switch category.lowercased() {
        case "client":
            return LinearGradient(
                gradient: Gradient(colors: [clientDefault.opacity(0.15), clientDefault.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case "payee", "provider":
            return LinearGradient(
                gradient: Gradient(colors: [payeeDefault.opacity(0.15), payeeDefault.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case "service", "support":
            return LinearGradient(
                gradient: Gradient(colors: [serviceDefault.opacity(0.15), serviceDefault.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        case "invoice", "payment":
            return LinearGradient(
                gradient: Gradient(colors: [invoiceDefault.opacity(0.15), invoiceDefault.opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                gradient: Gradient(colors: [Color("Primary", bundle: .sharedUI).opacity(0.15), Color("Primary", bundle: .sharedUI).opacity(0.05)]),
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
    
    /// Text color for category/feature tags
    static func tagForeground(for category: String) -> Color {
        switch category.lowercased() {
        case "client":
            return clientDefault
        case "payee", "provider":
            return payeeDefault
        case "service", "support":
            return serviceDefault
        case "invoice", "payment":
            return invoiceDefault
        default:
            return Color("Primary", bundle: .sharedUI)
        }
    }
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit) -> RGB (24-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0) // Fallback to clear or black
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    /// Convert Color to hex string
    func toHex() -> String {
        let components = self.cgColor?.components ?? [0, 0, 0, 1]
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - NSColor Extension for Color Conversion
extension NSColor {
    /// Convert SwiftUI Color to NSColor
    convenience init(_ color: Color) {
        let components = color.cgColor?.components ?? [0, 0, 0, 0]
        self.init(red: components[0], 
                 green: components[1], 
                  blue: components[2], 
                 alpha: components.count > 3 ? components[3] : 1.0)
    }
    
    // Helper for creating NSColor from hex
    convenience init(hex: String) {
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
            srgbRed: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
    
    convenience init(components: [CGFloat]) {
        precondition(components.count >= 3, "At least 3 components required")
        self.init(
            srgbRed: components[0],
            green: components[1],
            blue: components[2],
            alpha: components.count > 3 ? components[3] : 1.0)
    }
}

// MARK: - View Extensions
extension View {
    /// Apply beautiful empty state styling with icon, title and message
    func emptyStateView(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        actionIcon: String? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            
            VStack(spacing: 24) {
                // Decorative icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color("Primary", bundle: .sharedUI).opacity(0.15), Color("Primary", bundle: .sharedUI).opacity(0.05)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: icon)
                        .font(.system(size: 40))
                        .foregroundColor(Color("Primary", bundle: .sharedUI).opacity(0.7))
                }
                .shadow(color: Color("Shadow", bundle: .sharedUI).opacity(0.3), radius: 4, x: 0, y: 2)
                
                // Title and message
                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("Text", bundle: .sharedUI))
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }
                
                // Optional action button
                if let actionTitle = actionTitle, let action = action {
                    Button(action: action) {
                        HStack {
                            if let actionIcon = actionIcon {
                                Image(systemName: actionIcon)
                                    .font(.body)
                            }
                            Text(actionTitle)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
                        .padding(.vertical, StyleGuide.Dimensions.paddingMediumLarge)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color("Primary", bundle: .sharedUI), Color("Primary", bundle: .sharedUI).opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .foregroundColor(Color("White", bundle: .sharedUI))
                    }
                    .appInteractiveCursor()
                    .buttonStyle(.plain)
                    .shadow(color: Color("Primary", bundle: .sharedUI).opacity(0.3), radius: 4, x: 0, y: 2)
                    .padding(.top, 8)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("EmptyStateBackground", bundle: .sharedUI).opacity(0.7) as Color)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color("Border", bundle: .sharedUI), lineWidth: 1)
            )
            .shadow(color: Color("Shadow", bundle: .sharedUI).opacity(0.2), radius: 8, x: 0, y: 4)
            .padding()
        }
    }

} 
