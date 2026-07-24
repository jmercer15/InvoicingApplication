import SwiftUI
import SharedUI

/// Drag preview capsule shown while reordering Billing Hub kanban cards.
struct BillingHubBoardDragPreview: View {
    let item: BillingHubBoardTransferItem

    private var dragKind: BillingHubBoardDragKind { item.dragKind }

    var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingXMedium) {
            Image(systemName: dragKind.iconName)
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: BillingHubTheme.Dimensions.dragPreviewIconSize, height: BillingHubTheme.Dimensions.dragPreviewIconSize)
                .background { Circle().fill(Color.accentColor.opacity(StyleGuide.Opacity.light + 0.02)) }

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(item.snapshot.title)
                    .font(BillingHubTheme.Typography.dragPreviewTitle)
                    .foregroundStyle(BillingHubTheme.Palette.textPrimary)
                    .lineLimit(1)

                Text(item.snapshot.subtitle)
                    .font(BillingHubTheme.Typography.dragPreviewSubtitle)
                    .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingXMedium - 1)
        .frame(width: BillingHubTheme.Dimensions.dragPreviewWidth, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnCornerRadius, style: .continuous)
                .fill(BillingHubTheme.Surfaces.cardBase)
                .shadow(color: .black.opacity(0.16), radius: StyleGuide.Dimensions.paddingMediumLarge, x: 0, y: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: BillingHubTheme.Dimensions.columnCornerRadius, style: .continuous)
                .stroke(BillingHubTheme.Surfaces.cardStroke, lineWidth: 1)
        }
    }
}
