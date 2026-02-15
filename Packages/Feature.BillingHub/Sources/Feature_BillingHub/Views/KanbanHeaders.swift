import SwiftUI
import SharedUI

struct KanbanSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    let count: String
    var isCollapsed: Binding<Bool>? = nil

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 220
            let veryCompact = proxy.size.width < 150

            let core = HStack(spacing: compact ? 8 : StyleGuide.Dimensions.paddingLarge) {
                if !veryCompact {
                    Image(systemName: icon)
                        .font(compact ? .body.weight(.semibold) : .title2)
                        .foregroundColor(color)
                }

                Text(title.uppercased())
                    .font(.system(size: compact ? 16 : 21, weight: .bold))
                    .tracking(compact ? 1.8 : 3.0)
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .truncationMode(.tail)

                Text(count)
                    .font(.system(size: compact ? 11 : 12, weight: .bold))
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)
                    .padding(.horizontal, compact ? 6 : 8)
                    .padding(.vertical, compact ? 2 : 3)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(color.opacity(0.35), lineWidth: 1, antialiased: true)
                                    .allowsHitTesting(false)
                            )
                    )
            }
            .padding(.horizontal, compact ? 10 : StyleGuide.Dimensions.paddingMediumLarge)
            .padding(.vertical, compact ? 8 : StyleGuide.Dimensions.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .center)

            Group {
                if let binding = isCollapsed {
                    Button {
                        withAnimation(BillingHubTheme.Animations.spring) {
                            binding.wrappedValue = true
                        }
                    } label: {
                        core
                    }
                    .buttonStyle(.plain)
                    .pointerStyle(.link)
    #if os(macOS)
                    .help("Collapse \(title)")
    #endif
                } else {
                    core
                }
            }
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, minHeight: 60, maxHeight: 60)
    }
}

struct KanbanColumnHeader: View {
    let title: String
    let icon: String
    let color: Color
    let count: String
    var total: String? = nil
    var sortOption: ColumnSortOption? = nil
    var onSortChange: ((ColumnSortOption) -> Void)? = nil
    @State private var isHovered: Bool = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 180
            let hideIcon = proxy.size.width < 135

            HStack(spacing: compact ? 6 : 8) {
                if !hideIcon {
                    Image(systemName: icon)
                        .font(.system(size: compact ? 12 : 14, weight: .semibold))
                        .foregroundColor(color)
                        .frame(width: compact ? 20 : 24, height: compact ? 20 : 24)
                        .background(
                            Circle()
                                .fill(color.opacity(0.14))
                        )
                }

                Spacer(minLength: compact ? 4 : 6)

                Text(title)
                    .font(.system(size: compact ? 12 : 13, weight: .semibold))
                    .foregroundColor(BillingHubTheme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)

                Spacer(minLength: compact ? 4 : 6)

                sortMenu(compact: compact)
            }
            .padding(.horizontal, compact ? 8 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 56)
        .background(BillingHubTheme.Surfaces.subcolumnHeaderBackground(for: color, hovered: isHovered))
        .overlay(
            Rectangle()
                .fill(BillingHubTheme.Surfaces.subcolumnStroke)
                .frame(height: BillingHubTheme.Surfaces.subcolumnHeaderDividerHeight),
            alignment: .bottom
        )
        .onHover { hovering in
            withAnimation(BillingHubTheme.Animations.hover) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private func sortMenu(compact: Bool) -> some View {
        if let currentSort = sortOption, let onSortChange = onSortChange {
            Menu {
                ForEach(ColumnSortOption.allCases, id: \.self) { option in
                    if (total != nil && option.applicableToInvoices) || (total == nil && option.applicableToSessions) {
                        Button {
                            onSortChange(option)
                        } label: {
                            if option == currentSort {
                                Label(option.displayName, systemImage: "checkmark")
                            } else {
                                Text(option.displayName)
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: currentSort == .manual ? "arrow.up.arrow.down" : currentSort.icon)
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundColor(currentSort == .manual ? BillingHubTheme.Palette.textSecondary : BillingHubTheme.Palette.textPrimary)
                    .padding(compact ? 4 : 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(currentSort == .manual ? Color.clear : color.opacity(0.14))
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }
}
