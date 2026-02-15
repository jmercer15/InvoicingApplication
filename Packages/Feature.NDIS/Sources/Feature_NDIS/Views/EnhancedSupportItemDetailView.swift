import SwiftUI
import Data
import Core
import SharedUI

// MARK: - Main Detail View
struct EnhancedSupportItemDetailView: View {
    let item: NDISItem

    @State private var selectedRegion: String = ""
    
    private var availableRegions: [String] {
        let prices = item.regionalPrices
        let allRegions = Array(prices.compactMap { $0.regionIdentifier }).sorted()
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
        .foregroundColor(Color("Text", bundle: .sharedUI))
        .onAppear {
            if selectedRegion.isEmpty && !availableRegions.isEmpty {
                selectedRegion = availableRegions.first!
            }
        }
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !item.itemNumber.isEmpty {
                Text(item.itemNumber)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }

            Text(item.name)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            Divider()
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}


// MARK: - Modern Card Components
fileprivate struct ModernCombinedPricingCard: View {
    let allPrices: [RegionalPriceSnapshot]
    @Binding var selectedRegion: String
    
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if !allPrices.isEmpty {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 170), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(sortedPricesByValue, id: \.region) { item in
                            Button {
                                selectedRegion = item.region
                            } label: {
                                ModernPriceChip(
                                    region: item.region,
                                    price: item.price,
                                    isSelected: item.region == selectedRegion
                                )
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                            .buttonStyle(.plain)
                            .pointerStyle(.link)
                        }
                    }
                    .animation(.easeInOut(duration: 0.4), value: selectedRegion)
                } else {
                    NoPriceCard()
                }
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "dollarsign.circle.fill", title: "Regional Pricing") {
                Text("\(allPrices.count) regions")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pricing information for \(allPrices.count) regions")
        .accessibilityHint("Tap to view pricing details")
    }
    
    private var sortedPricesByValue: [(region: String, price: Double)] {
        return allPrices.compactMap { price in
            let region = price.regionIdentifier
            guard !region.isEmpty, price.amount > 0 else { return nil }
            return (region: region, price: price.amount)
        }.sorted { $0.price > $1.price }
    }
}

// MARK: - Modern Card Components
fileprivate struct ModernCombinedInfoCard: View {
    let item: NDISItem

    var body: some View {
        GroupBox {
            combinedInfoGrid
                .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "info.circle.fill", title: "Item Information")
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: item.category)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Item information with classification, registration, and service details")
        .accessibilityHint("Contains detailed information about the NDIS support item")
    }

    private var combinedInfoGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                valueColor: item.quoteRequired == true ? Color("Orange", bundle: .sharedUI) : Color("Active", bundle: .sharedUI)
            )
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String, valueColor: Color? = nil) -> some View {
        let resolvedValueColor = valueColor ?? Color("Text", bundle: .sharedUI)

        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(value)
                    .font(.system(size: 12))
                    .foregroundColor(resolvedValueColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                    .lineLimit(2)

                Text(value)
                    .font(.system(size: 12))
                    .foregroundColor(resolvedValueColor)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("White05", bundle: .sharedUI))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("White15", bundle: .sharedUI), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


fileprivate struct ModernProvisionCard: View {
    let item: NDISItem
    
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
                columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
                spacing: 12
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
    }
}

fileprivate struct ModernServiceDeliveryChip: View {
    let title: String
    let isAvailable: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(isAvailable ? Color("Active", bundle: .sharedUI) : Color("Cancelled", bundle: .sharedUI))
                .padding(.top, 1)

            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isAvailable ? Color("Active", bundle: .sharedUI).opacity(0.1) : Color("Cancelled", bundle: .sharedUI).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isAvailable ? Color("Active", bundle: .sharedUI).opacity(0.3) : Color("Cancelled", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
        )
    }
}

fileprivate struct ModernFeaturesCard: View {
    let features: [String]
    
    var body: some View {
        GroupBox {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                ForEach(features, id: \.self) { feature in
                    ModernFeatureChip(feature: feature)
                }
            }
            .padding(DetailSectionTokens.contentPadding)
        } label: {
            DetailSectionHeader(icon: "star.fill", title: "Features") {
                Text("\(features.count) features")
                    .font(.caption)
                    .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
            }
        }
    }
}

fileprivate struct ModernPriceChip: View {
    let region: String
    let price: Double
    let isSelected: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(region)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? Color("Primary", bundle: .sharedUI) : Color("Text", bundle: .sharedUI))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 8)
            
            Text(price.currencyString)
                .font(.caption.weight(.semibold))
                .foregroundColor(isSelected ? Color("Primary", bundle: .sharedUI) : Color("TextSecondary", bundle: .sharedUI))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color("Primary", bundle: .sharedUI) : Color("White15", bundle: .sharedUI), lineWidth: 1)
        )
    }
}

fileprivate struct NoPriceCard: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(Color("Inactive", bundle: .sharedUI))
            
            Text("No Pricing Data Available")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(Color("Text", bundle: .sharedUI))
            
            Text("This item may require a quote or have pricing determined by individual service providers.")
                .font(.caption)
                .foregroundColor(Color("TextSecondary", bundle: .sharedUI))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("Inactive", bundle: .sharedUI).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color("Inactive", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
        )
    }
}

fileprivate struct ModernFeatureChip: View {
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
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundColor(Color("Green", bundle: .sharedUI))
                .padding(.top, 1)
            Text(feature)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color("Text", bundle: .sharedUI))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color("Green", bundle: .sharedUI).opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color("Green", bundle: .sharedUI).opacity(0.3), lineWidth: 1)
        )
    }
}

private extension Double {
    var currencyString: String {
        "$\(String(format: "%.2f", self))"
    }
}
