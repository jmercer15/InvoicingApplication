//
//  View+ToolbarStyled.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 23/3/2025.
//

import SwiftUI

// MARK: - Standard Toolbar Button Style
public struct StandardToolbarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovering = false
    public var tintColor: Color = .accentColor // Default accent color

    public init(tintColor: Color = .accentColor) {
        self.tintColor = tintColor
    }

    public func makeBody(configuration: Configuration) -> some View {
        // Determine the primary color for the gradient based on enabled state and tintColor
        let primaryFillColor = isEnabled ? tintColor : Color.gray.opacity(0.2)
        let secondaryFillColor = isEnabled ? tintColor.opacity(0.8) : Color.gray.opacity(0.1)

        // Determine the border color
        let borderColor = isEnabled ? tintColor.opacity(0.2) : Color.gray.opacity(0.2)

        // Determine the foreground color
        let foreground = isEnabled ? .white : Color.gray // Default to white, change to gray if disabled

        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(height: 28)
            .font(.system(size: 12))
            .foregroundColor(foreground) // Apply the determined foreground color
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [primaryFillColor, secondaryFillColor]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                    RoundedRectangle(cornerRadius: 6)
                                .stroke(borderColor, lineWidth: 1)
                        )
                }
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : (isHovering ? 0.85 : 1.0)) : 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovering)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}
