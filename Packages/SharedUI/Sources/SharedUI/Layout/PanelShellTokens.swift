import SwiftUI
import AppKit

/// Shared design tokens for standardized panel shells.
public enum PanelShellTokens {
    public static let panelHorizontalPadding: CGFloat = 16
    public static let panelVerticalPadding: CGFloat = 12
    public static let panelCornerRadius: CGFloat = 10
    public static let panelBorderOpacity: Double = 0.12
    public static let shellTransition: Animation = .easeInOut(duration: StyleGuide.Animations.durationMedium)
    public static let contentListHorizontalInset: CGFloat = 24
    public static let contentListVerticalInset: CGFloat = 16
    public static let contentListGridSpacing: CGFloat = 16

    public static var sidebarPanelBackground: Color {
        dynamicPanelColor(
            name: "PanelShellSidebarBackground",
            light: NSColor(srgbRed: 0.92, green: 0.94, blue: 0.96, alpha: 1),
            dark: NSColor(srgbRed: 0.13, green: 0.15, blue: 0.18, alpha: 1)
        )
    }

    public static var contentPanelBackground: Color {
        dynamicPanelColor(
            name: "PanelShellContentBackground",
            light: NSColor(srgbRed: 0.97, green: 0.98, blue: 0.99, alpha: 1),
            dark: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.21, alpha: 1)
        )
    }

    public static var detailPanelBackground: Color {
        dynamicPanelColor(
            name: "PanelShellDetailBackground",
            light: NSColor(srgbRed: 0.95, green: 0.96, blue: 0.98, alpha: 1),
            dark: NSColor(srgbRed: 0.14, green: 0.16, blue: 0.19, alpha: 1)
        )
    }

    public static var sidebarDividerColor: Color {
        Color(NSColor.separatorColor).opacity(0.45)
    }

    public static var panelBackground: Color {
        detailPanelBackground
    }

    public static var panelSecondaryBackground: Color {
        Color(NSColor.controlBackgroundColor).opacity(0.35)
    }

    private static func dynamicPanelColor(
        name: String,
        light: NSColor,
        dark: NSColor
    ) -> Color {
        let tokenName = NSColor.Name(name)
        return Color(
            NSColor(name: tokenName) { appearance in
                switch appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight]) {
                case .darkAqua, .vibrantDark:
                    return dark
                default:
                    return light
                }
            }
        )
    }
}
