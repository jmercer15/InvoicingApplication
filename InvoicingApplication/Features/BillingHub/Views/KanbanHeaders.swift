//
//  KanbanHeaders.swift
//  InvoicingApplication
//
//  Created by AI Assistant on 21/7/2025.
//

import SwiftUI

struct KanbanSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    let count: String

    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingLarge) {
                    Image(systemName: icon)
                .font(.largeTitle)
                .foregroundColor(StyleGuide.Colors.text)

                        Text(title)
                .font(.title)
                            .foregroundColor(StyleGuide.Colors.text)
                            .lineLimit(1)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 60)
        .background(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.light))
        // Not interactive; force the standard pointer
        .pointerStyle(.default)

        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StyleGuide.Colors.border),
            alignment: .bottom
        )
    }
}

struct KanbanColumnHeader: View {
    let title: String
    let icon: String
    let color: Color
    let count: String

    var body: some View {
        VStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
            HStack(spacing: StyleGuide.Dimensions.paddingMedium) {
                        Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(StyleGuide.Colors.text)

                        Text(count)
                    .font(.title3)
                    .fontWeight(.bold)
                            .foregroundColor(color)
                    }

                    Text(title)
                .font(.body)
                        .foregroundColor(StyleGuide.Colors.text.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXSmall)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .frame(maxWidth: .infinity, minHeight: 50, maxHeight: 50)
        .background(StyleGuide.Colors.background.opacity(StyleGuide.Opacity.subtle))
        // Not interactive; force the standard pointer
        .pointerStyle(.default)

        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(StyleGuide.Colors.border),
            alignment: .bottom
                                )
                        }
                    }
