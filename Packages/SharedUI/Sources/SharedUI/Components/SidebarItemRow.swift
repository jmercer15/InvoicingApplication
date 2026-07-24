import SwiftUI

public struct SidebarItemRow: View {
    public let icon: String
    public let title: String
    public let isSelected: Bool

    public init(icon: String, title: String, isSelected: Bool = false) {
        self.icon = icon
        self.title = title
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingXMedium) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .font(StyleGuide.Typography.bodyMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityValue(isSelected ? "Selected" : "")
    }
}

