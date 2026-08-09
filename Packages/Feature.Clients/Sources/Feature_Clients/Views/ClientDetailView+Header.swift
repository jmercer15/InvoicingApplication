import SwiftUI
import SharedUI

extension ClientDetailView {
    var clientHeaderBar: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            HStack(spacing: DetailToolbarTokens.titleBadgeSpacing) {
                Image(systemName: "person.circle.fill")
                    .font(StyleGuide.Typography.detailHeaderIcon)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)

                VStack(alignment: .leading, spacing: DetailToolbarTokens.titleSubtitleSpacing) {
                    Text(viewModel.editableFullName.isEmpty ? "New Client" : viewModel.editableFullName)
                        .font(StyleGuide.Typography.hero)
                        .kerning(5.0)
                        .foregroundStyle(StyleGuide.Colors.text)
                        .lineLimit(1)

                    Rectangle()
                        .frame(height: 2)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
                .fixedSize(horizontal: true, vertical: true)

                if !viewModel.editableStatus.isEmpty {
                    StatusBadge(status: viewModel.editableStatus.capitalized)
                }

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
