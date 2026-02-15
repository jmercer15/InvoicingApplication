//
//  StatusIndicator.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI

struct StatusIndicator: View {
    let color: Color
    let label: String
    let count: String

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle()
                            .stroke(color.opacity(0.55), lineWidth: 1.5)
                    )

                Circle()
                    .fill(color.opacity(0.65))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(count)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(BillingHubTheme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.28), color.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(color.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.3), radius: 10, x: 0, y: 6)
        )
    }
}
