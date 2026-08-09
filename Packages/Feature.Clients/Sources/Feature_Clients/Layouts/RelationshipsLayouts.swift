import SwiftUI
import SharedUI

// MARK: - Navigation Group Card
struct RelationshipGroupCard: View, Equatable {
    nonisolated static func == (lhs: RelationshipGroupCard, rhs: RelationshipGroupCard) -> Bool {
        lhs.node.id == rhs.node.id &&
        lhs.count == rhs.count &&
        lhs.isListStyle == rhs.isListStyle
    }

    let node: TreeItem
    let count: Int
    var isListStyle: Bool = false
    let onSelect: () -> Void
    
    private var tint: Color {
        ColorSystem.Relationships.tint(forNodeID: node.id)
    }
    
    private var iconName: String {
        node.id.contains("client") ? "person.2" :
        node.id.contains("payee") ? "person.text.rectangle" :
        node.id.contains("plan") ? "briefcase" : "square.grid.2x2"
    }
    
    var body: some View {
        Button(action: onSelect) {
            cardBody
                .background(
                    cardShape
                        .fill(tint.opacity(StyleGuide.Opacity.faint))
                        .overlay(
                            cardShape
                                .stroke(tint.opacity(StyleGuide.Opacity.medium), lineWidth: 0.8)
                        )
                )
                .shadow(
                    color: tint.opacity(0.05),
                    radius: 2,
                    x: 0,
                    y: 1
                )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(node.title), \(node.subtitle ?? "group")")
        .accessibilityHint("Double tap to browse this group. Contains \(count) items.")
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isListStyle ? StyleGuide.Dimensions.cornerRadiusMedium : StyleGuide.Dimensions.cornerRadiusCardLarge,
            style: .continuous
        )
    }

    @ViewBuilder
    private var cardBody: some View {
        Group {
            if isListStyle {
                listLayout
            } else {
                gridLayout
            }
        }
        .contentShape(cardShape)
    }
    
    // Token-aligned with NavigationListRow.parent; tinted card chrome kept (not glass).
    private var listLayout: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingLarge) {
            Circle()
                .fill(tint.opacity(StyleGuide.Opacity.light + 0.02))
                .frame(
                    width: StyleGuide.Dimensions.entityIconCircleSize,
                    height: StyleGuide.Dimensions.entityIconCircleSize
                )
                .overlay(
                    Image(systemName: iconName)
                        .font(StyleGuide.Typography.entityCardIcon)
                        .foregroundStyle(tint)
                )

            VStack(alignment: .leading, spacing: ListRowTokens.titleSubtitleSpacing) {
                Text(node.title)
                    .font(StyleGuide.Typography.itemTitle)
                    .foregroundStyle(StyleGuide.Colors.text)

                Text(node.subtitle ?? "Group")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }

            Spacer()

            Text("\(count)")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(tint)
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall - 1)
                .background(tint.opacity(StyleGuide.Opacity.light))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(StyleGuide.Typography.micro.weight(.bold))
                .foregroundStyle(tint.opacity(ListRowTokens.hoverStrokeOpacity))
        }
        .padding(ListRowTokens.rowPadding)
    }
    
    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            HStack(alignment: .top) {
                Circle()
                    .fill(tint.opacity(StyleGuide.Opacity.light + 0.02))
                    .frame(
                        width: StyleGuide.Dimensions.entityIconCircleSizeLarge,
                        height: StyleGuide.Dimensions.entityIconCircleSizeLarge
                    )
                    .overlay(
                        Image(systemName: iconName)
                            .font(StyleGuide.Typography.entityGridIcon)
                            .foregroundColor(tint)
                    )
                
                Spacer()
                
                Text("\(count)")
                    .font(StyleGuide.Typography.sectionTitle)
                    .foregroundColor(tint)
                    .padding(.horizontal, StyleGuide.Dimensions.paddingXMedium)
                    .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                    .background(tint.opacity(StyleGuide.Opacity.light))
                    .clipShape(Capsule())
            }
            
            Spacer(minLength: 0)
            
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                Text(node.title)
                    .font(StyleGuide.Typography.sectionTitle)
                    .foregroundColor(.primary)
                
                Text(node.subtitle ?? "Group")
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            
            HStack {
                Text("Browse Group")
                    .font(StyleGuide.Typography.caption)
                    .foregroundColor(tint)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(StyleGuide.Typography.caption)
                    .foregroundColor(tint.opacity(0.7))
            }
            .padding(.top, StyleGuide.Dimensions.paddingMedium)
        }
        .padding(StyleGuide.Dimensions.paddingCard)
    }
}

// MARK: - Entity Card
struct RelationshipCard: View, Equatable {
    nonisolated static func == (lhs: RelationshipCard, rhs: RelationshipCard) -> Bool {
        lhs.title == rhs.title &&
        lhs.subtitle == rhs.subtitle &&
        lhs.entityType == rhs.entityType &&
        lhs.status == rhs.status &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isListStyle == rhs.isListStyle
    }

    let title: String
    let subtitle: String?
    let entityType: String // "client", "payee", "planManager"
    let status: String?
    let isSelected: Bool
    var isListStyle: Bool = false
    let onSelect: () -> Void
    
    private var tint: Color {
        ColorSystem.Relationships.tint(forEntityType: entityType)
    }
    
    private var iconName: String {
        switch entityType {
        case "client": return "person.crop.circle"
        case "payee": return "person.text.rectangle"
        case "planManager": return "briefcase"
        default: return "doc"
        }
    }
    
    private var statusColor: Color {
        guard let status = status?.lowercased() else { return .secondary }
        switch status {
        case "active": return ColorSystem.Status.success
        case "inactive": return ColorSystem.Status.inactive
        case "archived": return ColorSystem.Status.warning
        default: return .secondary
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            cardBody
                .background(
                    cardShape
                        .fill(isSelected 
                              ? tint.opacity(StyleGuide.Opacity.faint) 
                              : StyleGuide.Colors.background)
                        .overlay(
                            cardShape
                                .stroke(isSelected 
                                        ? tint.opacity(StyleGuide.Opacity.strong) 
                                        : StyleGuide.Colors.border, 
                                        lineWidth: isSelected ? 1.2 : 0.6)
                        )
                )
                .shadow(
                    color: isSelected 
                        ? tint.opacity(0.15) 
                        : StyleGuide.Colors.background.opacity(0.1),
                    radius: 2,
                    x: 0,
                    y: 1
                )
                .animation(.easeInOut(duration: StyleGuide.Animations.durationShort), value: isSelected)
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(entityType.capitalized), Status \(status ?? "unknown"), \(isSelected ? "Selected" : "Not selected")")
        .accessibilityHint("Double tap to select \(title)")
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: isListStyle ? StyleGuide.Dimensions.cornerRadiusMedium : StyleGuide.Dimensions.cornerRadiusLarge,
            style: .continuous
        )
    }

    @ViewBuilder
    private var cardBody: some View {
        Group {
            if isListStyle {
                listLayout
            } else {
                gridLayout
            }
        }
        .contentShape(cardShape)
    }
    
    private var listLayout: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            Image(systemName: iconName)
                .font(StyleGuide.Typography.sectionTitle)
                .foregroundColor(tint.opacity(0.8))
                .frame(width: StyleGuide.Dimensions.entityListIconWidth)
            
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXXSmall) {
                Text(title)
                    .font(StyleGuide.Typography.bodyMedium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let sub = subtitle {
                    Text(sub)
                        .font(StyleGuide.Typography.caption)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let status = status {
                HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                    Circle()
                        .fill(statusColor)
                        .frame(
                            width: StyleGuide.Dimensions.statusDotSize,
                            height: StyleGuide.Dimensions.statusDotSize
                        )
                    Text(status)
                        .font(StyleGuide.Typography.micro)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
                .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                .padding(.vertical, StyleGuide.Dimensions.paddingXSmall - 1)
                .background(Color.secondary.opacity(StyleGuide.Opacity.light))
                .clipShape(Capsule())
            }
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(tint)
                    .font(StyleGuide.Typography.itemSubtitle)
            }
        }
        .padding(StyleGuide.Dimensions.paddingMediumLarge)
    }
    
    private var gridLayout: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXMedium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                    Text(title)
                        .font(StyleGuide.Typography.itemTitle)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let sub = subtitle {
                        Text(sub)
                            .font(StyleGuide.Typography.caption)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                    }
                }
                
                Spacer(minLength: 0)
                
                Image(systemName: iconName)
                    .font(StyleGuide.Typography.sectionTitle)
                    .foregroundColor(tint.opacity(0.8))
            }
            
            Spacer(minLength: 0)
            
            HStack {
                if let status = status {
                    HStack(spacing: StyleGuide.Dimensions.paddingXSmall) {
                        Circle()
                            .fill(statusColor)
                            .frame(
                                width: StyleGuide.Dimensions.statusDotSize,
                                height: StyleGuide.Dimensions.statusDotSize
                            )
                        Text(status)
                            .font(StyleGuide.Typography.micro)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                    }
                    .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
                    .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)
                    .background(Color.secondary.opacity(StyleGuide.Opacity.light))
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(tint)
                }
            }
        }
        .padding(StyleGuide.Dimensions.paddingLarge)
    }
}
