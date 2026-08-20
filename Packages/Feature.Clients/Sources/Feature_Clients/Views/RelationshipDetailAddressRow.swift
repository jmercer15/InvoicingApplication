import SwiftUI
import SharedUI

struct RelationshipDetailAddressRow: View {
    let maxLabelWidth: CGFloat
    let hasAddressData: Bool
    let addressText: String
    @Binding var showingMapSheet: Bool
    @Binding var showingAddressEditingSheet: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingSmall) {
            Text("Address:")
                .frame(width: maxLabelWidth, alignment: .trailing)
                .foregroundStyle(StyleGuide.Colors.text)

            HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingMedium) {
                if hasAddressData {
                    Text(addressText)
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.text)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                } else {
                    Text("No address added")
                        .font(StyleGuide.Typography.itemSubtitle)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                        .padding(.vertical, StyleGuide.Dimensions.paddingXXSmall)
                }

                if hasAddressData {
                    HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                        Button { showingMapSheet = true } label: {
                            Image(systemName: "map")
                                .foregroundStyle(ColorSystem.Primary.blue)
                                .font(StyleGuide.Typography.caption)
                                .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel("View address on map")
                        .accessibilityHint("Opens a map viewer showing the address")

                        Button { showingAddressEditingSheet = true } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(ColorSystem.Status.warning)
                                .font(StyleGuide.Typography.caption)
                                .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel("Edit address")
                        .accessibilityHint("Opens a form to edit this address")
                    }
                } else {
                    Button { showingAddressEditingSheet = true } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(ColorSystem.Status.success)
                            .font(StyleGuide.Typography.caption)
                            .padding(.horizontal, StyleGuide.Dimensions.paddingSmall)
                            .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
                    .accessibilityLabel("Add address")
                    .accessibilityHint("Opens a form to add a new address")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
