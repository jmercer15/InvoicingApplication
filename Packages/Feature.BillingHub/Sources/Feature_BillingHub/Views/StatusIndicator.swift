//
//  StatusIndicator.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI
import SharedUI

struct StatusIndicator: View {
    let color: Color
    let label: String
    let count: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: BillingHubTheme.Dimensions.statusIndicatorOuter, height: BillingHubTheme.Dimensions.statusIndicatorOuter)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.55), lineWidth: 1.5)
                    )

                Circle()
                    .fill(color.opacity(0.65))
                    .frame(width: BillingHubTheme.Dimensions.statusIndicatorInner, height: BillingHubTheme.Dimensions.statusIndicatorInner)
                    .overlay(
                        Circle()
                            .fill(color)
                            .frame(width: BillingHubTheme.Dimensions.statusIndicatorDot, height: BillingHubTheme.Dimensions.statusIndicatorDot)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(count)
                    .font(BillingHubTheme.Typography.statusCount)
                    .foregroundStyle(BillingHubTheme.Palette.textPrimary)

                Text(label)
                    .font(BillingHubTheme.Typography.statusLabel)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .padding(.horizontal, StyleGuide.Dimensions.paddingXMedium)
        .background(
            RoundedRectangle(cornerRadius: StyleGuide.Dimensions.paddingXMedium, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: StyleGuide.Dimensions.paddingXMedium, style: .continuous)
                        .stroke(color.opacity(0.45), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) status indicator")
        .accessibilityValue("\(count) items")
    }
}
