import SwiftUI
import Data
import Core
import SharedUI

// MARK: - Main Detail View
struct EnhancedSupportItemDetailView: View {
    let item: NDISItemSnapshot

    @State private var selectedRegion: String = ""
    
    private var availableRegions: [String] {
        let allRegions = Array(item.regionalPrices.compactMap { $0.regionIdentifier }).sorted()
        let priorityRegions = ["NATIONAL", "NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT", "Remote", "Very Remote"]
        var sortedRegions: [String] = []
        
        for region in priorityRegions {
            if allRegions.contains(region) {
                sortedRegions.append(region)
            }
        }
        
        for region in allRegions {
            if !sortedRegions.contains(region) {
                sortedRegions.append(region)
            }
        }
        
        return sortedRegions
    }

    private var parsedFeatures: [String] {
        guard let features = item.features, !features.isEmpty else { return [] }
        return features
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            detailHeader

            DetailCardsLayout(minCardWidth: DetailSectionTokens.detailCardMinimumWidth) {
                ModernCombinedInfoCard(item: item)

                ModernCombinedPricingCard(
                    allPrices: item.regionalPrices,
                    selectedRegion: $selectedRegion
                )

                ModernProvisionCard(item: item)

                if !parsedFeatures.isEmpty {
                    ModernFeaturesCard(features: parsedFeatures)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.clear)
        .foregroundStyle(StyleGuide.Colors.text)
        .onAppear {
            if selectedRegion.isEmpty && !availableRegions.isEmpty {
                selectedRegion = availableRegions.first!
            }
        }
    }


    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: StyleGuide.Dimensions.paddingLarge) {
            HStack(alignment: .top, spacing: DetailToolbarTokens.titleBadgeSpacing) {
                VStack(alignment: .leading, spacing: DetailToolbarTokens.titleSubtitleSpacing) {
                    if !item.itemNumber.isEmpty {
                        Text(item.itemNumber)
                            .font(StyleGuide.Typography.bodyLarge)
                            .foregroundStyle(StyleGuide.Colors.textSecondary)
                    }

                    Text(item.name)
                        .font(StyleGuide.Typography.hero)
                        .foregroundStyle(StyleGuide.Colors.text)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                if !item.isCurrent {
                    StatusBadge(
                        "Historical",
                        color: ColorSystem.Status.warning,
                        icon: "clock.arrow.circlepath"
                    )
                }
            }

            Divider()
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingXLarge)
        .padding(.top, StyleGuide.Dimensions.paddingXLarge)
        .padding(.bottom, StyleGuide.Dimensions.paddingXLarge)
    }
}
