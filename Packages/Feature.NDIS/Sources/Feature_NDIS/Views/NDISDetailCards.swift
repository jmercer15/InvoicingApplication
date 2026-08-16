import SwiftUI
import Core
import SharedUI

// MARK: - Modern Card Components
struct ModernCombinedPricingCard: View {
    let allPrices: [RegionalPriceSnapshot]
    @Binding var selectedRegion: String
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DetailSectionTokens.sectionListSpacing) {
                if !allPrices.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: DetailSectionTokens.priceChipMinWidth), spacing: StyleGuide.Dimensions.paddingMedium)],
                        spacing: StyleGuide.Dimensions.paddingMedium
                    ) {
                        ForEach(sortedPricesByValue, id: \.region) { item in
                            ModernPriceChip(
                                region: item.region,
                                price: item.price,
                                isSelected: item.region == selectedRegion,
                                onSelect: {
                                    selectedRegion = item.region
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .scale.combined(with: .opacity)
                            ))
                        }
                    }
                    .animation(.easeInOut(duration: StyleGuide.Animations.durationMedium), value: selectedRegion)
                } else {
                    NoPriceCard()
                }
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "dollarsign.circle.fill", title: "Regional Pricing") {
                Text("\(allPrices.count) regions")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pricing information for \(allPrices.count) regions")
        .accessibilityHint("Tap to view pricing details")
    }
    
    private var sortedPricesByValue: [(region: String, price: Double)] {
        return allPrices.compactMap { price in
            guard let region = price.regionIdentifier, !region.isEmpty, price.amount > 0 else { return nil }
            return (region: region, price: NSDecimalNumber(decimal: price.amount).doubleValue)
        }.sorted { $0.price > $1.price }
    }
}

// MARK: - Modern Card Components
struct ModernCombinedInfoCard: View {
    let item: NDISItemSnapshot

    var body: some View {
        GroupBox {
            combinedInfoGrid
                .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "info.circle.fill", title: "Item Information")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
        .animation(.spring(response: StyleGuide.Animations.springResponse, dampingFraction: StyleGuide.Animations.springDamping), value: item.category)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Item information with classification, registration, and service details")
        .accessibilityHint("Contains detailed information about the NDIS support item")
    }

    private var combinedInfoGrid: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingMedium) {
            // PACE information
            if let categoryNamePACE = item.categoryNamePACE, !categoryNamePACE.isEmpty {
                infoRow(label: "Category (PACE)", value: categoryNamePACE)
            }
            
            if let categoryNumberPACE = item.categoryNumberPACE, !categoryNumberPACE.isEmpty {
                infoRow(label: "Category # (PACE)", value: categoryNumberPACE)
            }
            
            // Classification information
            infoRow(label: "Category", value: item.category ?? "N/A")
            
            if let categoryNumber = item.categoryNumber, !categoryNumber.isEmpty {
                infoRow(label: "Category #", value: categoryNumber)
            }
            
            // Registration information
            infoRow(label: "Group", value: item.registrationGroup ?? "N/A")
            
            if let registrationGroupNumber = item.registrationGroupNumber, !registrationGroupNumber.isEmpty {
                infoRow(label: "Group #", value: registrationGroupNumber)
            }
            
            // Service details
            if let type = item.type, !type.isEmpty {
                infoRow(label: "Type", value: type)
            }
            
            infoRow(
                label: "Quote Required",
                value: item.quoteRequired == true ? "Yes" : "No",
                valueColor: item.quoteRequired == true ? Color(red: 0.75, green: 0.35, blue: 0.0) : ColorSystem.Status.success
            )
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, valueColor: Color? = nil) -> some View {
        let resolvedValueColor = valueColor ?? StyleGuide.Colors.text

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: StyleGuide.Dimensions.paddingMediumLarge) {
                Text(label)
                    .font(StyleGuide.Typography.label)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(value)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(resolvedValueColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, StyleGuide.Dimensions.paddingXMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)

            VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingXSmall) {
                Text(label)
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
                    .lineLimit(2)

                Text(value)
                    .font(StyleGuide.Typography.itemSubtitle)
                    .foregroundStyle(resolvedValueColor)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, StyleGuide.Dimensions.paddingXMedium)
            .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        }
        .ndisBorderedSurface(
            fill: PanelShellTokens.panelSecondaryBackground,
            stroke: StyleGuide.Colors.border.opacity(StyleGuide.Opacity.medium)
        )
    }
}


struct ModernProvisionCard: View {
    let item: NDISItemSnapshot
    
    private var serviceDeliveryItems: [(title: String, isAvailable: Bool)] {
        [
            ("Non-Face-to-Face", item.nonFaceToFaceProvision == true),
            ("Provider Travel", item.providerTravel == true),
            ("Short Notice Cancellations", item.shortNoticeCancellations == true),
            ("NDIA Requested Reports", item.ndiaRequestedReports == true),
            ("Irregular SIL Supports", item.irregularSILSupports == true)
        ]
    }
    
    var body: some View {
        GroupBox {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: DetailSectionTokens.catalogueChipMinWidth), spacing: StyleGuide.Dimensions.paddingMediumLarge)],
                spacing: StyleGuide.Dimensions.paddingMediumLarge
            ) {
                ForEach(serviceDeliveryItems, id: \.title) { item in
                    ModernServiceDeliveryChip(
                        title: item.title,
                        isAvailable: item.isAvailable
                    )
                }
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "gearshape.fill", title: "Service Delivery")
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}

struct ModernServiceDeliveryChip: View {
    let title: String
    let isAvailable: Bool

    var body: some View {
        HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingSmall) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(isAvailable ? ColorSystem.Status.success : ColorSystem.Status.error)

            Text(title)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.text)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        .ndisTintedBorderedSurface(
            tint: isAvailable ? ColorSystem.Status.success : ColorSystem.Status.error
        )
    }
}

struct ModernFeaturesCard: View {
    let features: [String]
    
    var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: DetailSectionTokens.catalogueChipMinWidth), spacing: DetailSectionTokens.sectionListSpacing)], spacing: DetailSectionTokens.sectionListSpacing) {
                ForEach(features, id: \.self) { feature in
                    ModernFeatureChip(feature: feature)
                }
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "star.fill", title: "Features") {
                Text("\(features.count) features")
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}

struct ModernPriceChip: View {
    let region: String
    let price: Double
    let isSelected: Bool
    let onSelect: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: StyleGuide.Dimensions.paddingMedium) {
                Text(region)
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(isSelected ? Color.accentColor : StyleGuide.Colors.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer(minLength: 8)
                
                Text(price.currencyString)
                    .font(StyleGuide.Typography.caption)
                    .foregroundStyle(isSelected ? Color.accentColor : StyleGuide.Colors.textSecondary)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity)
            .padding(StyleGuide.Dimensions.paddingXMedium)
            .ndisInteractiveBorderedSurface(
                fill: isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                idleStroke: StyleGuide.Colors.border.opacity(StyleGuide.Opacity.medium),
                isEmphasized: isFocused || isSelected
            )
        }
        .buttonStyle(.plain)
        .pointerStyle(.link)
        .focusable()
        .focused($isFocused)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(region) pricing: \(price.currencyString)")
        .accessibilityHint(isSelected ? "Selected region" : "Select this region")
    }
}

struct NoPriceCard: View {
    var body: some View {
        VStack(spacing: DetailSectionTokens.sectionListSpacing) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(StyleGuide.Typography.hero)
                .foregroundStyle(ColorSystem.Status.inactive)
            
            Text("No Pricing Data Available")
                .font(StyleGuide.Typography.sectionTitle)
                .foregroundStyle(StyleGuide.Colors.text)
            
            Text("This item may require a quote or have pricing determined by individual service providers.")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(StyleGuide.Dimensions.paddingXLarge)
        .ndisTintedBorderedSurface(
            tint: ColorSystem.Status.inactive,
            cornerRadius: StyleGuide.Dimensions.cornerRadiusMedium
        )
    }
}

struct ModernFeatureChip: View {
    let feature: String
    
    private static let iconMapping: [String: String] = [
        "travel": "car.fill", "support": "person.2.fill", "therapy": "cross.case.fill",
        "equipment": "wrench.and.screwdriver.fill", "training": "graduationcap.fill",
        "plan": "doc.text.fill", "community": "person.3.fill", "communication": "bubble.left.and.bubble.right.fill",
        "transport": "bus.fill", "home": "house.fill", "care": "heart.fill",
        "assistive": "figure.walk", "consumable": "cart.fill", "interpreter": "mic.fill",
        "building": "building.2.fill", "education": "book.fill", "employment": "briefcase.fill",
        "assessment": "checkmark.seal.fill", "coordination": "arrow.triangle.branch",
        "management": "gearshape.fill"
    ]
    
    private var iconName: String {
        let lowercasedFeature = feature.lowercased()
        for (key, icon) in Self.iconMapping {
            if lowercasedFeature.contains(key) {
                return icon
            }
        }
        return "star.fill"
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: DetailSectionTokens.formRowSpacing) {
            Image(systemName: iconName)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(ColorSystem.Secondary.green)
            Text(feature)
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.text)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, StyleGuide.Dimensions.paddingMediumLarge)
        .padding(.vertical, StyleGuide.Dimensions.paddingMedium)
        .ndisTintedBorderedSurface(tint: ColorSystem.Secondary.green)
    }
}

private extension Double {
    var currencyString: String {
        CurrencyFormatting.display(self)
    }
}
