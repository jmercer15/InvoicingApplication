import SwiftUI
import SharedUI

struct NativeSessionFormHeaderView: View {
    let isEditing: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                Text(isEditing ? "Edit Session" : "New Session")
                    .font(StyleGuide.Typography.sectionTitle)
                    .fontWeight(.semibold)
                    .foregroundColor(StyleGuide.Colors.text)

                Text(isEditing ? "Modify the session details" : "Create a new session for your calendar")
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundColor(StyleGuide.Colors.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingLarge)
        .padding(.top, StyleGuide.Dimensions.paddingLarge)
    }
}
