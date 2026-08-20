import SwiftUI
import SharedUI

struct RelationshipDetailHeaderBar: View {
    let systemImage: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack(spacing: DetailToolbarTokens.titleBadgeSpacing) {
                Image(systemName: systemImage)
                    .font(StyleGuide.Typography.detailHeaderIcon)
                    .foregroundStyle(StyleGuide.Colors.text.opacity(0.9))

                VStack(alignment: .leading, spacing: DetailToolbarTokens.titleSubtitleSpacing) {
                    Text(title)
                        .font(StyleGuide.Typography.hero)
                        .kerning(5.0)
                        .foregroundStyle(StyleGuide.Colors.text)
                        .lineLimit(1)

                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(StyleGuide.Colors.textSecondary.opacity(StyleGuide.Opacity.strong))
                }
                .fixedSize(horizontal: true, vertical: true)
                Spacer()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
        .padding(.top, StyleGuide.Dimensions.paddingXLarge)
        .padding(.bottom, StyleGuide.Dimensions.paddingLarge)
    }
}
