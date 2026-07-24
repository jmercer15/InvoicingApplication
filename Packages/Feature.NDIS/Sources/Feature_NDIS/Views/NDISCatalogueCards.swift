import SwiftUI
import Core
import SharedUI

struct NDISCatalogueNavigationNodeCard: View {
    let node: NDISCatalogueTreeNode
    let level: Int
    let count: Int
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    private var iconName: String {
        if node.id.hasPrefix("group_") { return "square.stack.3d.forward.dottedline" }
        return "square.grid.2x2"
    }

    private var tint: Color {
        if node.id.hasPrefix("group_") { return ColorSystem.Navigation.groupTint }
        return ColorSystem.Navigation.categoryTint
    }

    private var subtitle: String {
        if let subtitle = node.subtitle, !subtitle.isEmpty {
            return subtitle
        }
        return "\(count) \(count == 1 ? "item" : "items")"
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXMedium) {
                HStack(alignment: .center, spacing: StyleGuide.Dimensions.paddingXMedium) {
                    Circle()
                        .fill(tint.opacity(StyleGuide.Opacity.medium))
                        .frame(
                            width: StyleGuide.Dimensions.iconCircleSize,
                            height: StyleGuide.Dimensions.iconCircleSize
                        )
                        .overlay(
                            Image(systemName: iconName)
                                .font(StyleGuide.Typography.sectionTitle)
                                .foregroundColor(tint)
                        )

                    VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                        Text(node.title)
                            .font(StyleGuide.Typography.itemTitle)
                            .foregroundStyle(StyleGuide.Colors.text)
                            .lineLimit(2)

                        Text(subtitle)
                            .font(StyleGuide.Typography.itemSubtitle)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                HStack {
                    Label("Browse \(count) \(count == 1 ? "item" : "items")", systemImage: "rectangle.3.group")
                        .font(StyleGuide.Typography.caption)
                        .foregroundColor(tint)
                        .labelStyle(.titleAndIcon)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(StyleGuide.Typography.itemTitle)
                        .foregroundStyle(StyleGuide.Colors.textSecondary)
                }
            }
            .padding(StyleGuide.Dimensions.paddingLarge)
            .frame(
                maxWidth: .infinity,
                minHeight: StyleGuide.Dimensions.cardMinHeightSmall,
                alignment: .topLeading
            )
            .contentShape(shape)
            .background(
                shape
                    .fill(tint.opacity(StyleGuide.Opacity.subtle))
                    .overlay(
                        shape
                            .stroke(isFocused ? Color.accentColor : tint.opacity(StyleGuide.Opacity.medium), lineWidth: isFocused ? ListRowTokens.selectedStrokeWidth : ListRowTokens.defaultStrokeWidth)
                    )
            )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .focusable()
        .focused($isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Folder: \(node.title). \(subtitle)")
        .accessibilityHint("Double tap to browse folder content")
    }
}

struct NDISCatalogueCard: View, Equatable {
    nonisolated static func == (lhs: NDISCatalogueCard, rhs: NDISCatalogueCard) -> Bool {
        MainActor.assumeIsolated {
            lhs.item.id == rhs.item.id &&
            lhs.preferredRegion == rhs.preferredRegion &&
            lhs.isSelected == rhs.isSelected
        }
    }

    let item: NDISItemSnapshot
    let preferredRegion: String?
    let isSelected: Bool
    let onSelect: () -> Void

    @FocusState private var isFocused: Bool

    private enum PricingState {
        case national(Double)
        case regional(Double, String)
        case quoteRequired
        case unavailable
    }

    private var pricingState: PricingState {
        if let region = normalizedPreferredRegion,
           let regionalPrice = price(forNormalizedRegion: region) {
            let raw = regionalPrice.regionIdentifier ?? ""
            let regionLabel = (!raw.isEmpty) ? raw : preferredRegion ?? region
            return .regional(regionalPrice.amount, regionLabel)
        }

        if let nationalPrice = price(forNormalizedRegion: "NATIONAL")?.amount {
            return .national(nationalPrice)
        }

        let meaningfulPrices = item.regionalPrices.filter { !(($0.regionIdentifier ?? "").isEmpty) && $0.amount > 0 }
        let fallbackPrices = item.regionalPrices.filter { $0.amount > 0 }

        if let price = (meaningfulPrices.isEmpty ? fallbackPrices : meaningfulPrices)
            .min(by: { $0.amount < $1.amount }) {
            let region = !((price.regionIdentifier ?? "").isEmpty) ? (price.regionIdentifier ?? "") : "Regional"
            return .regional(price.amount, region)
        }

        if item.quoteRequired == true {
            return .quoteRequired
        }

        return .unavailable
    }

    private var normalizedPreferredRegion: String? {
        guard let preferredRegion = preferredRegion, !preferredRegion.isEmpty else { return nil }
        let scalars = preferredRegion.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let normalized = String(String.UnicodeScalarView(scalars)).uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    private func price(forNormalizedRegion region: String) -> RegionalPriceSnapshot? {
        item.regionalPrices.first { price in
            guard let identifier = normalizedRegionIdentifier(price.regionIdentifier) else { return false }
            return identifier == region && price.amount > 0
        }
    }

    private func normalizedRegionIdentifier(_ value: String?) -> String? {
        guard let value = value, !value.isEmpty else { return nil }
        let scalars = value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let normalized = String(String.UnicodeScalarView(scalars)).uppercased()
        return normalized.isEmpty ? nil : normalized
    }

    private var priceText: String {
        switch pricingState {
        case .national(let amount):
            return NumberFormatter.currency.string(from: NSNumber(value: amount))
                ?? "$\(String(format: "%.2f", amount))"
        case .regional(let amount, let region):
            let formatted = NumberFormatter.currency.string(from: NSNumber(value: amount))
                ?? "$\(String(format: "%.2f", amount))"
            return "\(region): \(formatted)"
        case .quoteRequired:
            return "Quote Required"
        case .unavailable:
            return "Pricing Unavailable"
        }
    }

    private var priceIcon: String {
        switch pricingState {
        case .national, .regional:
            return "dollarsign.circle"
        case .quoteRequired:
            return "doc.text.magnifyingglass"
        case .unavailable:
            return "questionmark.circle"
        }
    }

    private var priceColor: Color {
        switch pricingState {
        case .national, .regional:
            return ColorSystem.Primary.blue
        case .quoteRequired:
            return Color(red: 0.75, green: 0.35, blue: 0.0)
        case .unavailable:
            return StyleGuide.Colors.textSecondary
        }
    }

    private var subtitleColor: Color {
        StyleGuide.Colors.textSecondary
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium, style: .continuous)
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXMedium) {
                HStack(alignment: .top, spacing: DetailToolbarTokens.titleBadgeSpacing) {
                    Text(item.name)
                        .font(StyleGuide.Typography.itemTitle)
                        .foregroundStyle(StyleGuide.Colors.text)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if !item.isCurrent {
                        StatusBadge(
                            "Historical",
                            color: ColorSystem.Status.warning,
                            icon: "clock.arrow.circlepath"
                        )
                    }
                }

                Text(item.itemNumber)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundColor(subtitleColor)

                Spacer(minLength: 0)

                Divider()
                    .padding(.vertical, StyleGuide.Dimensions.paddingXSmall)

                HStack(alignment: .center) {
                    Label(priceText, systemImage: priceIcon)
                        .font(StyleGuide.Typography.caption)
                        .foregroundColor(priceColor)
                        .labelStyle(.titleAndIcon)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(StyleGuide.Typography.caption)
                        .foregroundColor(subtitleColor.opacity(ListRowTokens.hoverStrokeOpacity))
                }
            }
            .padding(StyleGuide.Dimensions.paddingXLarge)
            .frame(
                maxWidth: .infinity,
                minHeight: StyleGuide.Dimensions.cardMinHeight,
                alignment: .topLeading
            )
            .contentShape(shape)
            .background(
                shape
                    .fill(StyleGuide.Colors.background)
                    .overlay(
                        shape
                            .stroke(isFocused || isSelected ? Color.accentColor : StyleGuide.Colors.border, lineWidth: isFocused || isSelected ? ListRowTokens.selectedStrokeWidth : ListRowTokens.defaultStrokeWidth)
                    )
            )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .focusable()
        .focused($isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.name), Support item number \(item.itemNumber). \(priceText)")
        .accessibilityHint(isSelected ? "Selected. Double tap to clear selection" : "Double tap to select this item")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
