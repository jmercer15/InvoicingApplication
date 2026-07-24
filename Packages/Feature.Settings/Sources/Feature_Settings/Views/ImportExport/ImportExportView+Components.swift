import SwiftUI
import Data
import Core
import SharedUI

extension ImportExportView {
    // Compact option pill to avoid wide segmented controls
    internal struct OptionPillButton: View {
        let title: String
        let isSelected: Bool
        let action: () -> Void
        
        @ScaledMetric(relativeTo: .body) private var paddingSmall = StyleGuide.Dimensions.paddingSmall

        var body: some View {
            ZStack {
                // The background glass is outside the button so the entire area is clickable
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                Button(action: action) {
                    Text(title)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, paddingSmall)
                        .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact, style: .continuous))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                    .fill(StyleGuide.Colors.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                            .stroke(StyleGuide.Colors.border, lineWidth: 0.6)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusCompact, style: .continuous))
            .pointerStyle(.link)
        }
    }
}
