//
//  SystemColorExtensions.swift
//  Feature.InvoiceTemplateEditor
//
//  System color extensions for consistent theming
//

import SwiftUI
import AppKit

extension Color {
    // MARK: - Color Conversion Methods
    
    func toHex() -> String {
        let nsColor = NSColor(self)
        let red = Int(nsColor.redComponent * 255)
        let green = Int(nsColor.greenComponent * 255)
        let blue = Int(nsColor.blueComponent * 255)
        return String(format: "%02X%02X%02X", red, green, blue)
    }
    
    init(hex: String) {
        let hex = hex.replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: hex)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            let red = Double((hexNumber & 0xFF0000) >> 16) / 255.0
            let green = Double((hexNumber & 0x00FF00) >> 8) / 255.0
            let blue = Double(hexNumber & 0x0000FF) / 255.0
            
            self.init(red: red, green: green, blue: blue)
        } else {
            self.init(red: 0, green: 0, blue: 0) // Default to black if parsing fails
        }
    }
    
    // MARK: - Background Colors (Depth-based hierarchy)
    
    /// Primary background - deepest level (main window background)
    static var primaryBackground: LinearGradient {
        let top = NSColor.windowBackgroundColor.blended(withFraction: 0.08, of: NSColor.controlBackgroundColor) ?? NSColor.windowBackgroundColor
        let bottom = NSColor.underPageBackgroundColor.blended(withFraction: 0.18, of: NSColor.controlBackgroundColor) ?? NSColor.underPageBackgroundColor

        return LinearGradient(
            colors: [
                Color(nsColor: top),
                Color(nsColor: bottom)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Primary surface - main content areas
    static var primarySurface: Color {
        Color(nsColor: NSColor.windowBackgroundColor)
    }
    
    /// Secondary surface - elevated content areas (cards, panels)
    static var secondarySurface: Color {
        Color(nsColor: NSColor.controlBackgroundColor)
    }
    
    /// Tertiary surface - more elevated areas (modals, popovers)
    static var tertiarySurface: Color {
        Color(nsColor: NSColor.selectedContentBackgroundColor)
    }
    
    /// Quaternary surface - highest elevation (tooltips, overlays)
    static var quaternarySurface: Color {
        Color(nsColor: NSColor.unemphasizedSelectedContentBackgroundColor)
    }
    
    /// Quinary surface - maximum elevation (floating elements)
    static var quinarySurface: Color {
        Color(nsColor: NSColor.controlBackgroundColor)
    }

    // MARK: - Fill Colors (Depth-based hierarchy)
    
    /// Primary fill - standard UI elements
    static var primaryFill: Color {
        Color(nsColor: NSColor.systemFill)
    }
    
    /// Secondary fill - slightly elevated elements
    static var secondaryFill: Color {
        Color(nsColor: NSColor.secondarySystemFill)
    }
    
    /// Tertiary fill - more elevated elements
    static var tertiaryFill: Color {
        Color(nsColor: NSColor.tertiarySystemFill)
    }
    
    /// Quaternary fill - highly elevated elements
    static var quaternaryFill: Color {
        Color(nsColor: NSColor.quaternarySystemFill)
    }
    
    /// Quinary fill - maximum elevation elements
    static var quinaryFill: Color {
        Color(nsColor: NSColor.quinarySystemFill)
    }

    // MARK: - Legacy Surface Properties (for backward compatibility)
    
    static var elevatedSurface: Color {
        secondarySurface
    }

    static var activeSurface: Color {
        let blended = NSColor.selectedControlColor.blended(withFraction: 0.35, of: NSColor.controlBackgroundColor) ?? NSColor.selectedControlColor
        return Color(nsColor: blended)
    }

    // MARK: - Text Colors
    
    static var primaryText: Color {
        Color(nsColor: NSColor.labelColor)
    }

    static var secondaryText: Color {
        Color(nsColor: NSColor.secondaryLabelColor)
    }

    static var tertiaryText: Color {
        Color(nsColor: NSColor.tertiaryLabelColor)
    }
    
    static var quaternaryText: Color {
        Color(nsColor: NSColor.quaternaryLabelColor)
    }
    
    static var quinaryText: Color {
        Color(nsColor: NSColor.quinaryLabel)
    }

    static var accentText: Color {
        Color(nsColor: NSColor.alternateSelectedControlTextColor)
    }
    
    static var selectedText: Color {
        Color(nsColor: NSColor.selectedControlTextColor)
    }
    
    static var disabledText: Color {
        Color(nsColor: NSColor.disabledControlTextColor)
    }

    // MARK: - Border and Separator Colors
    
    static var primaryOutline: Color {
        Color(nsColor: NSColor.separatorColor)
    }

    static var strongOutline: Color {
        Color(nsColor: NSColor.separatorColor.withAlphaComponent(0.7))
    }

    static var primarySeparator: Color {
        Color(nsColor: NSColor.separatorColor.withAlphaComponent(0.5))
    }
    
    static var primaryGrid: Color {
        Color(nsColor: NSColor.gridColor)
    }

    // MARK: - Control Colors
    
    static var primaryControl: Color {
        Color(nsColor: NSColor.controlColor)
    }
    
    static var controlText: Color {
        Color(nsColor: NSColor.controlTextColor)
    }
    
    static var selectedControl: Color {
        Color(nsColor: NSColor.selectedControlColor)
    }
    
    static var selectedControlText: Color {
        Color(nsColor: NSColor.selectedControlTextColor)
    }
    
    static var controlAccent: Color {
        Color(nsColor: NSColor.controlAccentColor)
    }
    
    static var keyboardFocusIndicator: Color {
        Color(nsColor: NSColor.keyboardFocusIndicatorColor)
    }

    // MARK: - Interactive Elements
    
    static var selectedChipBackground: Color {
        Color.accentColor
    }

    static var unselectedChipBackground: Color {
        secondaryFill
    }

    static var chipText: Color {
        primaryText
    }

    static var hoverHighlight: Color {
        Color(nsColor: NSColor.selectedContentBackgroundColor.withAlphaComponent(0.22))
    }
    
    static var linkColor: Color {
        Color(nsColor: NSColor.linkColor)
    }
    
    static var placeholderText: Color {
        Color(nsColor: NSColor.placeholderTextColor)
    }

    // MARK: - Status Colors
    
    static var warningColor: Color {
        Color(nsColor: NSColor.systemRed)
    }
    
    static var successColor: Color {
        Color(nsColor: NSColor.systemGreen)
    }
    
    static var infoColor: Color {
        Color(nsColor: NSColor.systemBlue)
    }

    // MARK: - Shadow and Effects
    
    static var primaryShadow: Color {
        Color(nsColor: NSColor.shadowColor)
    }

    static var subtleShadow: Color {
        Color(nsColor: NSColor.shadowColor.withAlphaComponent(0.18))
    }
    
    static var findHighlight: Color {
        Color(nsColor: NSColor.findHighlightColor)
    }

    // MARK: - Canvas and Document Colors

    static var canvasBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }

    static var canvasOutline: Color {
        Color(nsColor: NSColor.separatorColor.withAlphaComponent(0.35))
    }
    
    static var textBackground: Color {
        Color(nsColor: NSColor.textBackgroundColor)
    }
    
    static var selectedTextBackground: Color {
        Color(nsColor: NSColor.selectedTextBackgroundColor)
    }
    
    static var unemphasizedSelectedTextBackground: Color {
        Color(nsColor: NSColor.unemphasizedSelectedTextBackgroundColor)
    }
    
    static var selectedTextColor: Color {
        Color(nsColor: NSColor.selectedTextColor)
    }
    
    static var unemphasizedSelectedTextColor: Color {
        Color(nsColor: NSColor.unemphasizedSelectedTextColor)
    }
    
    static var windowFrameText: Color {
        Color(nsColor: NSColor.windowFrameTextColor)
    }
    
    static var selectedMenuItemText: Color {
        Color(nsColor: NSColor.selectedMenuItemTextColor)
    }
    
    static var headerText: Color {
        Color(nsColor: NSColor.headerTextColor)
    }
}



