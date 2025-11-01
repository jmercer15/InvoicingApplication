//
//  KanbanHeaders.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import SharedUI

// Subtle vignette that darkens edges compared to the center
private struct EdgeDarkenedBackground: View {
    var color: Color
    var baseOpacity: Double
    var edgeExtraOpacity: Double

    var body: some View {
        ZStack {
            BillingHubTheme.Palette.surfacePrimary.opacity(0.9)
            // Accent wash
            LinearGradient(
                colors: [
                    color.opacity(baseOpacity),
                    color.opacity(baseOpacity * 0.25)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .blendMode(.plusLighter)

            // Horizontal edge darkening (left/right)
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: BillingHubTheme.Palette.surfacePrimary.opacity(edgeExtraOpacity), location: 0.0),
                    .init(color: .clear, location: 0.12),
                    .init(color: .clear, location: 0.88),
                    .init(color: BillingHubTheme.Palette.surfacePrimary.opacity(edgeExtraOpacity), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            // Vertical edge darkening (top/bottom)
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: BillingHubTheme.Palette.surfacePrimary.opacity(edgeExtraOpacity), location: 0.0),
                    .init(color: .clear, location: 0.18),
                    .init(color: .clear, location: 0.82),
                    .init(color: BillingHubTheme.Palette.surfacePrimary.opacity(edgeExtraOpacity), location: 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .allowsHitTesting(false)
    }
}

struct KanbanSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    let count: String
    var isCollapsed: Binding<Bool>? = nil
    @State private var isHovered: Bool = false

    var body: some View {
        // Core visual header
        let core = HStack(spacing: StyleGuide.Dimensions.paddingLarge) {

            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Spacer(minLength: 0)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(count)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(color.opacity(0.10))
                        .overlay(
                            Capsule()
                                .strokeBorder(color.opacity(0.35), lineWidth: 1, antialiased: true)
                                .allowsHitTesting(false)
                        )
                )
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 60)
        .background(
            EdgeDarkenedBackground(
                color: color,
                baseOpacity: isHovered ? 0.32 : 0.24,
                edgeExtraOpacity: isHovered ? 0.16 : 0.12
            )
        )
        .background(BillingHubTheme.Palette.surfaceSecondary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(BillingHubTheme.Palette.surfaceStroke)
                .allowsHitTesting(false),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(BillingHubTheme.Animations.hover) { isHovered = hovering }
        }

        if let binding = isCollapsed {
            Button {
                withAnimation(BillingHubTheme.Animations.spring) {
                    binding.wrappedValue = true
                }
            } label: {
                core
            }
            .buttonStyle(.plain)
            .pointerStyle(.pointingHand)
#if os(macOS)
            .help("Collapse \(title)")
#endif
        } else {
            core
        }
    }
}

struct KanbanColumnHeader: View {
    let title: String
    let icon: String
    let color: Color
    let count: String
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(BillingHubTheme.Palette.textPrimary)

            Spacer(minLength: 0)

            Text(title)
                .font(.body)
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(count)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(BillingHubTheme.Palette.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(color.opacity(0.10))
                        .overlay(
                            Capsule()
                                .strokeBorder(color.opacity(0.35), lineWidth: 1, antialiased: true)
                                .allowsHitTesting(false)
                        )
                )
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
        .background(
            EdgeDarkenedBackground(
                color: color,
                baseOpacity: isHovered ? 0.22 : 0.16,
                edgeExtraOpacity: isHovered ? 0.12 : 0.08
            )
        )
        .background(BillingHubTheme.Palette.surfaceSecondary)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(BillingHubTheme.Palette.surfaceStroke)
                .allowsHitTesting(false),
            alignment: .bottom
        )
        .onHover { hovering in
            withAnimation(BillingHubTheme.Animations.hover) { isHovered = hovering }
        }
}
}
