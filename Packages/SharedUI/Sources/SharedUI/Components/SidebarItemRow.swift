import SwiftUI

public struct SidebarItemRow: View {
    public let icon: String
    public let title: String

    public init(icon: String, title: String) {
        self.icon = icon
        self.title = title
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 18)
            Text(title)
            Spacer(minLength: 0)
        }
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
        .contentShape(Rectangle())
        .cornerRadius(StyleGuide.Dimensions.cornerRadiusSmall)
    }
}


